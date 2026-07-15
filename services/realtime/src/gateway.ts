/**
 * JSON-over-WebSocket gateway for native clients (the Flutter app).
 *
 * Colyseus doesn't speak plain JSON on the wire, and a Dart Colyseus client is a fragile dependency.
 * Instead, each mobile socket is bridged here: the gateway joins the target Colyseus room as a
 * `colyseus.js` client on the phone's behalf and relays plain JSON both ways. One source of truth
 * (the GameRoom); the phone speaks trivial JSON.
 *
 * Wire protocol (phone → gateway):
 *   { t: "join",   code, name, wallet }
 *   { t: "answer", questionIndex, choice }
 *   { t: "ping" }
 * (gateway → phone):
 *   { t: "joined", sessionId }
 *   { t: "state",  phase, questionIndex, endsAt, players:[{name,score,hasAnswered}], you:{score,rank} }
 *   { t: "question" | "reveal" | "podium" | "settled" | "anchored" | "chainReady" | "error", ... }
 *   { t: "pong" } | { t: "left" }
 */
import { WebSocketServer, type WebSocket } from "ws";
import { Client, type Room } from "colyseus.js";
import { matchMaker } from "colyseus";
import type { Server as HttpServer } from "node:http";

const RELAY = ["question", "reveal", "podium", "settled", "anchored", "chainReady", "error"] as const;

// Colyseus room ids are a case-sensitive, symbol-including nanoid (a-zA-Z0-9_-). The phone's join
// field forces upper-case and strips symbols for typability, so a raw string match would fail for
// almost every real code. Resolve the typed code against live rooms, ignoring case and symbols.
const normalizeCode = (s: string) => s.toUpperCase().replace(/[^A-Z0-9]/g, "");

async function resolveRoomId(typedCode: string): Promise<string> {
  const target = normalizeCode(typedCode);
  try {
    const rooms = await matchMaker.query({ name: "quivo" });
    const match = rooms.find((r) => normalizeCode(r.roomId) === target);
    return match?.roomId ?? typedCode;
  } catch {
    return typedCode;
  }
}

type GatewayOptions =
  | { port: number; colyseusEndpoint: string }
  | { server: HttpServer; path: string; colyseusEndpoint: string };

/** Native clients use this plain JSON gateway; in production it shares Railway's public port. */
export function startMobileGateway(options: GatewayOptions) {
  const wss =
    "server" in options
      ? new WebSocketServer({ server: options.server, path: options.path })
      : new WebSocketServer({ port: options.port });
  const colyseusEndpoint = options.colyseusEndpoint;

  wss.on("connection", (ws: WebSocket) => {
    let room: Room | null = null;
    const send = (obj: unknown) => ws.readyState === ws.OPEN && ws.send(JSON.stringify(obj));

    const pushState = () => {
      if (!room) return;
      const s: any = room.state;
      const players: { name: string; score: number; hasAnswered: boolean }[] = [];
      let you: { score: number; rank: number } | null = null;
      const rows: { sid: string; score: number }[] = [];
      s.players?.forEach((p: any, sid: string) => {
        players.push({ name: p.name, score: p.score, hasAnswered: p.hasAnswered });
        rows.push({ sid, score: p.score });
      });
      rows.sort((a, b) => b.score - a.score);
      const meIdx = rows.findIndex((r) => r.sid === room!.sessionId);
      if (meIdx >= 0) you = { score: rows[meIdx].score, rank: meIdx + 1 };
      send({ t: "state", phase: s.phase, questionIndex: s.questionIndex, endsAt: s.endsAt, players, you });
    };

    ws.on("message", async (raw) => {
      let msg: any;
      try {
        msg = JSON.parse(raw.toString());
      } catch {
        return;
      }
      if (msg.t === "ping") return send({ t: "pong" });

      if (msg.t === "join") {
        if (room) return;
        try {
          const roomId = await resolveRoomId(String(msg.code ?? "").trim());
          const client = new Client(colyseusEndpoint);
          room = await client.joinById(roomId, { name: msg.name ?? "player", wallet: msg.wallet });
          send({ t: "joined", sessionId: room.sessionId });
          room.onStateChange(() => pushState());
          for (const type of RELAY) room.onMessage(type, (m: any) => send({ t: type, ...m }));
          room.onLeave(() => send({ t: "left" }));
        } catch (e: any) {
          send({ t: "error", code: "join_failed", message: String(e?.message ?? e) });
        }
        return;
      }

      if (msg.t === "answer" && room) {
        room.send("answer", { questionIndex: msg.questionIndex, choice: msg.choice });
      }
    });

    ws.on("close", () => {
      room?.leave();
      room = null;
    });
    ws.on("error", () => {
      room?.leave();
      room = null;
    });
  });

  const label = "server" in options ? options.path : `:${options.port}`;
  console.log(`[quivo] mobile JSON gateway on ${label} → ${colyseusEndpoint}`);
  return wss;
}
