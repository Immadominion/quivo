"use client";
/**
 * Stage — the host / big-screen view. Create a game → QR joins → live question + countdown +
 * leaderboard → podium → the on-chain payout reveal. Simple placeholder UI, redesign later.
 */
import { useEffect, useRef, useState } from "react";
import { Client, type Room } from "colyseus.js";
import { QRCodeSVG } from "qrcode.react";

type LB = { sessionId: string; name: string; wallet: string; score: number; rank: number; delta: number };
type Winner = { wallet: string; rank: number; amount: string };
type Settlement = { txSig: string; potMint: string; winners: Winner[] };

const OPTION_COLORS = ["#e74c3c", "#3498db", "#f1c40f", "#2ecc71"];

const wsUrl = () =>
  process.env.NEXT_PUBLIC_REALTIME_URL ?? `ws://${window.location.hostname}:2567`;

export default function Stage() {
  const roomRef = useRef<Room | null>(null);
  const [phase, setPhase] = useState<string>("idle");
  const [roomId, setRoomId] = useState("");
  const [players, setPlayers] = useState<string[]>([]);
  const [question, setQuestion] = useState<{ index: number; prompt: string; options: string[] } | null>(null);
  const [endsAt, setEndsAt] = useState(0);
  const [now, setNow] = useState(0);
  const [correct, setCorrect] = useState<number | null>(null);
  const [board, setBoard] = useState<LB[]>([]);
  const [settlement, setSettlement] = useState<Settlement | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 100);
    return () => clearInterval(t);
  }, []);

  async function createGame() {
    setBusy(true);
    setError("");
    try {
      const client = new Client(wsUrl());
      const room = await client.create("quivo", { host: true, name: "HOST", potAmount: "5000000" });
      roomRef.current = room;
      setRoomId(room.roomId);
      setPhase("lobby");
      room.onStateChange((s: any) => {
        setPhase(s.phase);
        const list: string[] = [];
        s.players?.forEach((p: any) => list.push(p.name));
        setPlayers(list);
      });
      room.onMessage("question", (m: any) => {
        setQuestion(m.question);
        setEndsAt(m.endsAt);
        setCorrect(null);
      });
      room.onMessage("reveal", (m: any) => {
        setCorrect(m.correctChoice);
        setBoard(m.leaderboard);
      });
      room.onMessage("podium", (m: any) => setBoard(m.leaderboard));
      room.onMessage("settled", (m: any) => setSettlement(m.settlement));
      room.onMessage("error", (m: any) => setError(m.message));
    } catch (e: any) {
      setError(String(e?.message ?? e));
      setPhase("idle");
    } finally {
      setBusy(false);
    }
  }

  const joinUrl =
    typeof window !== "undefined" && roomId ? `${window.location.origin}/play?c=${roomId}` : "";
  const secondsLeft = Math.max(0, Math.ceil((endsAt - now) / 1000));

  return (
    <main style={{ maxWidth: 900, margin: "0 auto", padding: "48px 24px", textAlign: "center" }}>
      <h1 style={{ fontSize: 40, margin: "0 0 4px" }}>
        QUIVO <span style={{ fontSize: 16, opacity: 0.5 }}>· live game show · real prizes · devnet</span>
      </h1>

      {phase === "idle" && (
        <div style={{ marginTop: 80 }}>
          <p style={{ opacity: 0.7 }}>Host a live quiz. The room plays on their phones. Winners get paid on-chain, instantly.</p>
          <button onClick={createGame} disabled={busy} style={btn("#7c5cff", 22)}>
            {busy ? "Creating game + escrowing pot…" : "▶ Create game (5 test-USDC pot)"}
          </button>
        </div>
      )}

      {phase === "lobby" && (
        <div style={{ marginTop: 24 }}>
          <p style={{ fontSize: 20 }}>Scan to join</p>
          {joinUrl && (
            <div style={{ background: "#fff", display: "inline-block", padding: 16, borderRadius: 12 }}>
              <QRCodeSVG value={joinUrl} size={220} />
            </div>
          )}
          <p style={{ fontSize: 14, opacity: 0.6 }}>{joinUrl}</p>
          <p style={{ fontSize: 22, letterSpacing: 2 }}>
            code: <b>{roomId}</b>
          </p>
          <p style={{ fontSize: 18 }}>
            {players.length} player{players.length === 1 ? "" : "s"} in:{" "}
            <span style={{ opacity: 0.8 }}>{players.join(" · ") || "—"}</span>
          </p>
          <button
            onClick={() => roomRef.current?.send("host:start")}
            disabled={players.length === 0}
            style={btn("#2ecc71", 20)}
          >
            ▶ Start
          </button>
        </div>
      )}

      {(phase === "question" || phase === "reveal") && question && (
        <div style={{ marginTop: 32 }}>
          <p style={{ opacity: 0.5 }}>
            Question {question.index + 1} · {phase === "question" ? `${secondsLeft}s` : "answer locked"}
          </p>
          <h2 style={{ fontSize: 32, margin: "8px 0 24px" }}>{question.prompt}</h2>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            {question.options.map((o, i) => (
              <div
                key={i}
                style={{
                  padding: "22px 16px",
                  borderRadius: 12,
                  fontSize: 20,
                  background: OPTION_COLORS[i % 4],
                  opacity: correct === null ? 1 : correct === i ? 1 : 0.25,
                  outline: correct === i ? "4px solid #fff" : "none",
                }}
              >
                {o}
              </div>
            ))}
          </div>
          {phase === "reveal" && <Board board={board} />}
        </div>
      )}

      {(phase === "settling" || phase === "complete") && (
        <div style={{ marginTop: 32 }}>
          <h2 style={{ fontSize: 34 }}>🏆 Podium</h2>
          <Board board={board.slice(0, 5)} big />
          {phase === "settling" && !settlement && (
            <p style={{ fontSize: 20, color: "#f1c40f" }}>⏳ Paying winners on-chain…</p>
          )}
          {settlement && (
            <div style={{ marginTop: 16, padding: 20, background: "#16161f", borderRadius: 12 }}>
              <p style={{ fontSize: 22, color: "#2ecc71", margin: "0 0 8px" }}>✅ Winners paid on-chain</p>
              {settlement.winners.map((w) => (
                <p key={w.rank} style={{ margin: 4, fontFamily: "monospace", fontSize: 14 }}>
                  #{w.rank} {w.wallet.slice(0, 4)}…{w.wallet.slice(-4)} +{Number(w.amount) / 1e6} USDC
                </p>
              ))}
              {settlement.txSig !== "stub-signature" ? (
                <a
                  href={`https://explorer.solana.com/tx/${settlement.txSig}?cluster=devnet`}
                  target="_blank"
                  style={{ color: "#7c5cff" }}
                >
                  view the settlement transaction ↗
                </a>
              ) : (
                <p style={{ opacity: 0.5, fontSize: 13 }}>(stub mode — no relayer key on the server)</p>
              )}
            </div>
          )}
        </div>
      )}

      {error && <p style={{ color: "#e74c3c", marginTop: 24 }}>⚠ {error}</p>}
    </main>
  );
}

function Board({ board, big = false }: { board: LB[]; big?: boolean }) {
  return (
    <div style={{ marginTop: 20, textAlign: "left", maxWidth: 460, marginInline: "auto" }}>
      {board.map((r) => (
        <div
          key={r.sessionId}
          style={{
            display: "flex",
            justifyContent: "space-between",
            padding: big ? "12px 16px" : "8px 16px",
            fontSize: big ? 20 : 16,
            background: r.rank === 1 ? "#2a2340" : "#16161f",
            borderRadius: 8,
            marginBottom: 6,
          }}
        >
          <span>
            {r.rank === 1 ? "🥇" : r.rank === 2 ? "🥈" : r.rank === 3 ? "🥉" : ` ${r.rank}.`} {r.name}
          </span>
          <span>
            {r.delta > 0 && <span style={{ color: "#2ecc71", marginRight: 8 }}>+{r.delta}</span>}
            <b>{r.score}</b>
          </span>
        </div>
      ))}
    </div>
  );
}

const btn = (bg: string, size: number): React.CSSProperties => ({
  marginTop: 24,
  padding: "16px 40px",
  fontSize: size,
  fontWeight: 700,
  color: "#fff",
  background: bg,
  border: "none",
  borderRadius: 12,
  cursor: "pointer",
});
