"use client";
/**
 * Player — join by QR/code, answer on big thumb buttons, get paid on-chain if you podium.
 * An ephemeral Solana keypair is minted on first open (localStorage) — no signup, no wallet app.
 * Simple placeholder UI, redesign later.
 */
import { useEffect, useRef, useState } from "react";
import { Client, type Room } from "colyseus.js";
import { Keypair } from "@solana/web3.js";

type LB = { sessionId: string; name: string; wallet: string; score: number; rank: number; delta: number };
type Winner = { wallet: string; rank: number; amount: string };
type Settlement = { txSig: string; potMint: string; winners: Winner[] };

const OPTION_COLORS = ["#e74c3c", "#3498db", "#f1c40f", "#2ecc71"];
const WALLET_KEY = "quivo-ephemeral-wallet";

const wsUrl = () =>
  process.env.NEXT_PUBLIC_REALTIME_URL ?? `ws://${window.location.hostname}:2567`;

function myWallet(): string {
  const stored = localStorage.getItem(WALLET_KEY);
  if (stored) return Keypair.fromSecretKey(Uint8Array.from(JSON.parse(stored))).publicKey.toBase58();
  const kp = Keypair.generate();
  localStorage.setItem(WALLET_KEY, JSON.stringify(Array.from(kp.secretKey)));
  return kp.publicKey.toBase58();
}

export default function Play() {
  const roomRef = useRef<Room | null>(null);
  const [code, setCode] = useState("");
  const [name, setName] = useState("");
  const [wallet, setWallet] = useState("");
  const [phase, setPhase] = useState("join");
  const [question, setQuestion] = useState<{ index: number; prompt: string; options: string[] } | null>(null);
  const [choice, setChoice] = useState<number | null>(null);
  const [correct, setCorrect] = useState<number | null>(null);
  const [me, setMe] = useState<LB | null>(null);
  const [settlement, setSettlement] = useState<Settlement | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    setWallet(myWallet());
    const c = new URLSearchParams(window.location.search).get("c");
    if (c) setCode(c);
  }, []);

  async function join() {
    setError("");
    try {
      const client = new Client(wsUrl());
      const room = await client.joinById(code.trim(), { name: name.trim() || "player", wallet });
      roomRef.current = room;
      setPhase("lobby");
      room.onStateChange((s: any) => setPhase((p) => (p === "join" ? p : s.phase)));
      room.onMessage("question", (m: any) => {
        setQuestion(m.question);
        setChoice(null);
        setCorrect(null);
      });
      room.onMessage("reveal", (m: any) => {
        setCorrect(m.correctChoice);
        setMe(m.leaderboard.find((r: LB) => r.sessionId === room.sessionId) ?? null);
      });
      room.onMessage("podium", (m: any) =>
        setMe(m.leaderboard.find((r: LB) => r.sessionId === room.sessionId) ?? null),
      );
      room.onMessage("settled", (m: any) => setSettlement(m.settlement));
      room.onMessage("error", (m: any) => setError(m.message));
    } catch (e: any) {
      setError(String(e?.message ?? e));
    }
  }

  function answer(i: number) {
    if (choice !== null || !question) return;
    setChoice(i);
    roomRef.current?.send("answer", { questionIndex: question.index, choice: i });
  }

  const myPayout = settlement?.winners.find((w) => w.wallet === wallet);

  return (
    <main style={{ maxWidth: 480, margin: "0 auto", padding: "32px 20px", textAlign: "center" }}>
      <h1 style={{ fontSize: 24, margin: "0 0 16px" }}>QUIVO</h1>

      {phase === "join" && (
        <div style={{ display: "flex", flexDirection: "column", gap: 12, marginTop: 24 }}>
          <input value={code} onChange={(e) => setCode(e.target.value)} placeholder="game code" style={input} />
          <input value={name} onChange={(e) => setName(e.target.value)} placeholder="your name" style={input} />
          <button onClick={join} disabled={!code} style={bigBtn("#7c5cff")}>
            Join game
          </button>
          <p style={{ fontSize: 11, opacity: 0.5, fontFamily: "monospace" }}>
            your wallet {wallet ? `${wallet.slice(0, 4)}…${wallet.slice(-4)}` : "…"} (created on this phone)
          </p>
        </div>
      )}

      {phase === "lobby" && (
        <p style={{ marginTop: 60, fontSize: 20 }}>
          ✅ You're in. Eyes on the big screen — the game starts soon.
        </p>
      )}

      {(phase === "question" || phase === "reveal") && question && (
        <div style={{ marginTop: 16 }}>
          <p style={{ fontSize: 15, opacity: 0.7 }}>{question.prompt}</p>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, marginTop: 12 }}>
            {question.options.map((o, i) => (
              <button
                key={i}
                onClick={() => answer(i)}
                disabled={choice !== null}
                style={{
                  ...bigBtn(OPTION_COLORS[i % 4]),
                  minHeight: 110,
                  fontSize: 16,
                  opacity: correct !== null ? (correct === i ? 1 : 0.25) : choice !== null && choice !== i ? 0.4 : 1,
                  outline: choice === i ? "4px solid #fff" : "none",
                }}
              >
                {o}
              </button>
            ))}
          </div>
          {choice !== null && correct === null && <p style={{ opacity: 0.6 }}>locked in…</p>}
          {correct !== null && me && (
            <p style={{ fontSize: 18 }}>
              {choice === correct ? `✅ +${me.delta}` : "❌ 0"} · score <b>{me.score}</b> · rank #{me.rank}
            </p>
          )}
        </div>
      )}

      {(phase === "settling" || phase === "complete") && (
        <div style={{ marginTop: 40 }}>
          {me && (
            <p style={{ fontSize: 22 }}>
              You finished <b>#{me.rank}</b> with <b>{me.score}</b> points
            </p>
          )}
          {!settlement && <p style={{ color: "#f1c40f" }}>⏳ settling on-chain…</p>}
          {settlement && myPayout && (
            <div style={{ padding: 20, background: "#153822", borderRadius: 12, marginTop: 12 }}>
              <p style={{ fontSize: 26, margin: 0 }}>💸 You got paid!</p>
              <p style={{ fontSize: 20 }}>+{Number(myPayout.amount) / 1e6} USDC → your wallet</p>
              {settlement.txSig !== "stub-signature" && (
                <a
                  href={`https://explorer.solana.com/tx/${settlement.txSig}?cluster=devnet`}
                  target="_blank"
                  style={{ color: "#8ef0b3" }}
                >
                  see it on-chain ↗
                </a>
              )}
            </div>
          )}
          {settlement && !myPayout && <p style={{ opacity: 0.7 }}>No payout this time — run it back 🔁</p>}
        </div>
      )}

      {error && <p style={{ color: "#e74c3c", marginTop: 20 }}>⚠ {error}</p>}
    </main>
  );
}

const input: React.CSSProperties = {
  padding: "14px 16px",
  fontSize: 18,
  borderRadius: 10,
  border: "1px solid #333",
  background: "#16161f",
  color: "#fff",
  textAlign: "center",
};

const bigBtn = (bg: string): React.CSSProperties => ({
  padding: "16px",
  fontSize: 18,
  fontWeight: 700,
  color: "#fff",
  background: bg,
  border: "none",
  borderRadius: 12,
  cursor: "pointer",
});
