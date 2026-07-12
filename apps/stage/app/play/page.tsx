"use client";
/**
 * Player, the phone view. Floodlight (docs/DESIGN.md): thumb-first four-color answer tiles,
 * instant optimistic "locked in", reveal feedback, and the payout money-moment with haptics + sound.
 * Ephemeral Solana wallet minted silently on first open. No signup, no wallet app.
 */
import { useEffect, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Client, type Room } from "colyseus.js";
import { Keypair } from "@solana/web3.js";
import { T, ANSWERS, playerHue, springy, squircle } from "../theme";
import { unlock, sfx, buzz } from "../sound";

type LB = { sessionId: string; name: string; wallet: string; score: number; rank: number; delta: number };
type Winner = { wallet: string; rank: number; amount: string };
type Settlement = { txSig: string; potMint: string; winners: Winner[] };
const WALLET_KEY = "quivo-ephemeral-wallet";
const wsUrl = () => process.env.NEXT_PUBLIC_REALTIME_URL ?? `ws://${window.location.hostname}:2567`;

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
  const [question, setQuestion] = useState<{ index: number; prompt: string; options: string[]; durationMs: number } | null>(null);
  const [endsAt, setEndsAt] = useState(0);
  const [now, setNow] = useState(0);
  const [choice, setChoice] = useState<number | null>(null);
  const [correct, setCorrect] = useState<number | null>(null);
  const [me, setMe] = useState<LB | null>(null);
  const [settlement, setSettlement] = useState<Settlement | null>(null);
  const [error, setError] = useState("");
  const [connecting, setConnecting] = useState(false);

  useEffect(() => {
    setWallet(myWallet());
    const c = new URLSearchParams(window.location.search).get("c");
    if (c) setCode(c);
    const t = setInterval(() => setNow(Date.now()), 100);
    return () => clearInterval(t);
  }, []);

  const secondsLeft = Math.max(0, Math.ceil((endsAt - now) / 1000));
  const lastTick = useRef(-1);
  useEffect(() => {
    if (phase === "question" && choice === null && secondsLeft <= 5 && secondsLeft > 0 && secondsLeft !== lastTick.current) {
      lastTick.current = secondsLeft;
      buzz(secondsLeft <= 3 ? 40 : 18); // HQ-Trivia-style: feel the countdown
    }
  }, [secondsLeft, phase, choice]);

  async function join() {
    unlock();
    setError("");
    setConnecting(true);
    try {
      const client = new Client(wsUrl());
      const room = await client.joinById(code.trim(), { name: name.trim() || "player", wallet });
      roomRef.current = room;
      setPhase("lobby");
      buzz(20);
      room.onStateChange((s: any) => setPhase((p) => (p === "join" ? p : s.phase)));
      room.onMessage("question", (m: any) => {
        setQuestion({ ...m.question });
        setEndsAt(m.endsAt);
        setChoice(null);
        setCorrect(null);
        sfx.question();
      });
      room.onMessage("reveal", (m: any) => {
        setCorrect(m.correctChoice);
        const mine = m.leaderboard.find((r: LB) => r.sessionId === room.sessionId) ?? null;
        setMe(mine);
        if (choiceRef.current === m.correctChoice) {
          sfx.correct();
          buzz([0, 30, 40, 60]);
        } else {
          sfx.wrong();
          buzz(80);
        }
      });
      room.onMessage("podium", (m: any) => setMe(m.leaderboard.find((r: LB) => r.sessionId === room.sessionId) ?? null));
      room.onMessage("settled", (m: any) => {
        setSettlement(m.settlement);
        const paid = m.settlement.winners.find((w: Winner) => w.wallet === wallet);
        if (paid) {
          sfx.coin();
          buzz([0, 40, 30, 40, 30, 80]);
        }
      });
      room.onMessage("error", (m: any) => setError(m.message));
    } catch (e: any) {
      setError(joinError(String(e?.message ?? e)));
    } finally {
      setConnecting(false);
    }
  }

  const choiceRef = useRef<number | null>(null);
  function answer(i: number) {
    if (choice !== null || !question) return;
    setChoice(i);
    choiceRef.current = i;
    sfx.lock();
    buzz(30);
    roomRef.current?.send("answer", { questionIndex: question.index, choice: i });
  }

  const myPayout = settlement?.winners.find((w) => w.wallet === wallet);

  return (
    <main style={{ minHeight: "100dvh", maxWidth: 520, margin: "0 auto", padding: "22px 18px", display: "flex", flexDirection: "column" }}>
      <div style={{ textAlign: "center", fontFamily: "'Clash Display', sans-serif", fontWeight: 900, fontSize: 22, color: T.ink, marginBottom: 8 }}>QUIVO</div>

      <AnimatePresence mode="wait">
        {phase === "join" && (
          <motion.div key="join" initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} style={{ marginTop: "8vh" }}>
            <div style={cardBox}>
              <div style={{ fontFamily: "'Clash Display', sans-serif", fontWeight: 900, fontSize: 20, color: T.ink, textAlign: "center", marginBottom: 16 }}>Join the game</div>
              <input value={code} onChange={(e) => setCode(e.target.value)} placeholder="game code" style={{ ...input, fontFamily: "var(--font-mono)" }} />
              <input value={name} onChange={(e) => setName(e.target.value)} placeholder="your name" style={{ ...input, marginTop: 10 }} />
              <BigButton onClick={join} disabled={!code || connecting} grad={T.primaryGrad} rgb="124,58,237" style={{ marginTop: 14 }}>
                {connecting ? "Joining…" : "Join game"}
              </BigButton>
              <div style={{ marginTop: 14, display: "flex", alignItems: "center", gap: 8, justifyContent: "center", color: T.muted, fontWeight: 700, fontSize: 12 }}>
                <div style={{ width: 22, height: 22, borderRadius: "50%", background: wallet ? playerHue(wallet) : T.muted }} />
                wallet <span style={{ fontFamily: "var(--font-mono)" }}>{wallet ? `${wallet.slice(0, 4)}…${wallet.slice(-4)}` : "…"}</span> · made on this phone
              </div>
            </div>
          </motion.div>
        )}

        {phase === "lobby" && (
          <motion.div key="lobby" initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0 }} style={{ margin: "auto", textAlign: "center" }}>
            <motion.div animate={{ scale: [1, 1.06, 1] }} transition={{ duration: 1.6, repeat: Infinity }} style={{ fontSize: 56 }}>✅</motion.div>
            <div style={{ fontFamily: "'Clash Display', sans-serif", fontWeight: 900, fontSize: 22, color: T.ink, marginTop: 8 }}>You're in!</div>
            <div style={{ color: T.muted, fontWeight: 700, marginTop: 4 }}>Eyes on the big screen, starting soon.</div>
          </motion.div>
        )}

        {(phase === "question" || phase === "reveal") && question && (
          <motion.div key="q" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} style={{ display: "flex", flexDirection: "column", flex: 1 }}>
            <div style={{ textAlign: "center", padding: "6px 4px 12px" }}>
              <div style={{ fontWeight: 700, color: T.muted, fontSize: 12, letterSpacing: 0.8, textTransform: "uppercase" }}>Question {question.index + 1}</div>
              <div style={{ fontWeight: 800, color: T.body, fontSize: 16, marginTop: 4, textWrap: "balance" } as any}>{question.prompt}</div>
              {phase === "question" && choice === null && (
                <div style={{ fontFamily: "var(--font-mono)", fontWeight: 900, fontSize: 34, color: secondsLeft <= 3 ? T.danger : T.ink, marginTop: 6, fontVariantNumeric: "tabular-nums" }}>{secondsLeft}</div>
              )}
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, flex: 1, minHeight: 300 }}>
              {question.options.map((opt, i) => {
                const a = ANSWERS[i % 4];
                const dimReveal = correct !== null && correct !== i;
                const winReveal = correct === i;
                const dimPick = choice !== null && choice !== i && correct === null;
                return (
                  <motion.button
                    key={i}
                    whileTap={{ scale: 0.95 }}
                    onClick={() => answer(i)}
                    disabled={choice !== null}
                    animate={{ opacity: dimReveal || dimPick ? 0.32 : 1, scale: winReveal ? 1.04 : 1 }}
                    transition={springy}
                    style={{
                      border: "none",
                      ...squircle(20),
                      background: a.grad,
                      color: "#fff",
                      fontFamily: "inherit",
                      display: "flex",
                      flexDirection: "column",
                      alignItems: "center",
                      justifyContent: "center",
                      gap: 8,
                      padding: 14,
                      boxShadow: winReveal ? `0 0 0 5px #fff, ${T.shadowBtn(a.rgb)}` : T.shadowBtn(a.rgb),
                      outline: choice === i ? "5px solid #fff" : "none",
                    }}
                  >
                    <span style={{ fontSize: 30, opacity: 0.9 }}>{a.glyph}</span>
                    <span style={{ fontWeight: 900, fontSize: 17, textShadow: "0 2px 5px rgba(0,0,0,.18)" }}>{opt}</span>
                  </motion.button>
                );
              })}
            </div>

            <div style={{ textAlign: "center", minHeight: 40, marginTop: 12 }}>
              {choice !== null && correct === null && <span style={{ fontWeight: 800, color: T.primaryText }}>locked in ✓</span>}
              {correct !== null && me && (
                <motion.span initial={{ scale: 0.7 }} animate={{ scale: 1 }} style={{ fontFamily: "var(--font-mono)", fontWeight: 900, fontSize: 18, color: choiceRef.current === correct ? T.winLime : T.danger }}>
                  {choiceRef.current === correct ? `✅ +${me.delta}` : "❌ +0"} · score {me.score} · #{me.rank}
                </motion.span>
              )}
            </div>
          </motion.div>
        )}

        {(phase === "settling" || phase === "complete") && (
          <motion.div key="end" initial={{ opacity: 0 }} animate={{ opacity: 1 }} style={{ margin: "auto", textAlign: "center", width: "100%" }}>
            {me && (
              <div style={{ fontFamily: "var(--font-mono)", fontWeight: 900, fontSize: 24, color: T.ink }}>
                You finished #{me.rank} · {me.score} pts
              </div>
            )}
            {!settlement && <div style={{ marginTop: 14, fontWeight: 800, color: T.amber }}>⏳ settling on-chain…</div>}
            <AnimatePresence>
              {settlement && myPayout && (
                <motion.div key="paid" initial={{ scale: 0.7, opacity: 0, y: 20 }} animate={{ scale: 1, opacity: 1, y: 0 }} transition={{ type: "spring", stiffness: 260, damping: 16 }} style={{ ...cardBox, marginTop: 18, background: T.cardWash }}>
                  <motion.div initial={{ y: -30, rotate: -20 }} animate={{ y: 0, rotate: 0 }} transition={{ type: "spring", stiffness: 300, damping: 12 }} style={{ display: "flex", justifyContent: "center" }}>
                    <div style={{ width: 64, height: 64, borderRadius: "50%", background: T.coin, boxShadow: T.coinShadow, display: "grid", placeItems: "center" }}>
                      <div style={{ width: 26, height: 26, borderRadius: "50%", background: "radial-gradient(circle at 35% 30%,#ffe0a8,#f0a835)" }} />
                    </div>
                  </motion.div>
                  <div style={{ fontFamily: "'Clash Display', sans-serif", fontWeight: 900, fontSize: 26, color: T.winLime, marginTop: 12 }}>You got paid!</div>
                  <CountUp to={Number(myPayout.amount) / 1e6} />
                  {settlement.txSig !== "stub-signature" && (
                    <a href={`https://explorer.solana.com/tx/${settlement.txSig}?cluster=devnet`} target="_blank" style={{ color: T.winLime, fontWeight: 800, display: "inline-block", marginTop: 8 }}>
                      see it on-chain ↗
                    </a>
                  )}
                </motion.div>
              )}
              {settlement && !myPayout && (
                <motion.div key="np" initial={{ opacity: 0 }} animate={{ opacity: 1 }} style={{ marginTop: 16, fontWeight: 800, color: T.muted }}>
                  No payout this round, run it back 🔁
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
        )}
      </AnimatePresence>

      {error && (
        <div style={{ position: "fixed", bottom: 20, left: 18, right: 18, background: T.danger, color: "#fff", fontWeight: 800, padding: "12px 16px", ...squircle(14), textAlign: "center" }}>⚠ {error}</div>
      )}
    </main>
  );
}

function CountUp({ to }: { to: number }) {
  const [v, setV] = useState(0);
  useEffect(() => {
    let raf = 0;
    const start = performance.now();
    const dur = 900;
    const tick = (t: number) => {
      const p = Math.min(1, (t - start) / dur);
      setV(to * (1 - Math.pow(1 - p, 3)));
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [to]);
  return <div style={{ fontFamily: "var(--font-mono)", fontWeight: 900, fontSize: 30, color: T.ink }}>+{v.toFixed(2)} USDC</div>;
}

function BigButton({ children, onClick, disabled, grad, rgb, style }: any) {
  return (
    <motion.button
      whileTap={{ scale: 0.95 }}
      onClick={onClick}
      disabled={disabled}
      style={{ width: "100%", border: "none", ...squircle(16), padding: 16, fontWeight: 900, fontSize: 18, color: "#fff", background: disabled ? "#b9bccb" : grad, boxShadow: disabled ? "none" : `0 6px 14px rgba(${rgb},.4)`, fontFamily: "inherit", cursor: disabled ? "not-allowed" : "pointer", ...style }}
    >
      {children}
    </motion.button>
  );
}

function joinError(raw: string): string {
  if (/not found|no room/i.test(raw)) return "That game code wasn't found, check the screen.";
  if (/fetch|network|socket|timeout/i.test(raw)) return "Couldn't reach the game, retrying helps on venue wifi.";
  return raw;
}

const cardBox: React.CSSProperties = { background: T.card, ...squircle(T.rCard), padding: 22, boxShadow: T.shadowFloat };
const input: React.CSSProperties = { width: "100%", boxSizing: "border-box", padding: "14px 16px", fontSize: 18, fontWeight: 800, ...squircle(14), border: "2px solid #ece7f7", background: T.cardTint, color: T.ink, textAlign: "center", fontFamily: "inherit" };
