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

const RELAY = ["question", "reveal", "podium", "settled", "anchored", "chainReady", "error"] as const;

/** Runs on its own port (default 2568) to avoid WS-upgrade contention with Colyseus. */
export function startMobileGateway(port: number, colyseusEndpoint: string) {
  const wss = new WebSocketServer({ port });

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
          const client = new Client(colyseusEndpoint);
          room = await client.joinById(String(msg.code).trim(), { name: msg.name ?? "player", wallet: msg.wallet });
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

  console.log(`[quivo] mobile JSON gateway on :${port} → ${colyseusEndpoint}`);
  return wss;
}
