"use client";
/**
 * Stage — the host / big-screen (projector) view. Candy Arcade design (docs/DESIGN.md), full
 * choreography via framer-motion, procedural sound, and the live "anchored on-chain" ticker that
 * makes the MagicBlock moment visible. See docs/ROADMAP.md §1.
 */
import { useEffect, useMemo, useRef, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Client, type Room } from "colyseus.js";
import { QRCodeSVG } from "qrcode.react";
import { T, ANSWERS, playerHue, springy } from "./theme";
import { unlock, sfx } from "./sound";

type LB = { sessionId: string; name: string; wallet: string; score: number; rank: number; delta: number };
type Winner = { wallet: string; rank: number; amount: string };
type Settlement = { txSig: string; potMint: string; winners: Winner[] };
type Anchor = { id: number; name: string; questionIndex: number; ms: number };

const wsUrl = () => process.env.NEXT_PUBLIC_REALTIME_URL ?? `ws://${window.location.hostname}:2567`;

export default function Stage() {
  const roomRef = useRef<Room | null>(null);
  const [phase, setPhase] = useState("idle");
  const [roomId, setRoomId] = useState("");
  const [players, setPlayers] = useState<{ id: string; name: string }[]>([]);
  const [chainReady, setChainReady] = useState(false);
  const [question, setQuestion] = useState<{ index: number; prompt: string; options: string[]; durationMs: number } | null>(null);
  const [answeredCount, setAnsweredCount] = useState(0);
  const [endsAt, setEndsAt] = useState(0);
  const [now, setNow] = useState(0);
  const [correct, setCorrect] = useState<number | null>(null);
  const [board, setBoard] = useState<LB[]>([]);
  const [settlement, setSettlement] = useState<Settlement | null>(null);
  const [anchors, setAnchors] = useState<Anchor[]>([]);
  const [potHint, setPotHint] = useState("5");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const anchorId = useRef(0);

  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 80);
    return () => clearInterval(t);
  }, []);

  // countdown ticks (last 5s) — audible tension
  const secondsLeft = Math.max(0, Math.ceil((endsAt - now) / 1000));
  const lastTick = useRef(-1);
  useEffect(() => {
    if (phase === "question" && secondsLeft <= 5 && secondsLeft > 0 && secondsLeft !== lastTick.current) {
      lastTick.current = secondsLeft;
      sfx.tick(secondsLeft <= 3);
    }
  }, [secondsLeft, phase]);

  function pushAnchor(name: string, questionIndex: number, ms: number) {
    const id = ++anchorId.current;
    setAnchors((a) => [...a, { id, name, questionIndex, ms }].slice(-6));
    sfx.anchor();
    setTimeout(() => setAnchors((a) => a.filter((x) => x.id !== id)), 4200);
  }

  async function createGame() {
    unlock();
    setBusy(true);
    setError("");
    try {
      const client = new Client(wsUrl());
      const room = await client.create("quivo", { host: true, name: "HOST", potAmount: String(Number(potHint) * 1_000_000) });
      roomRef.current = room;
      setRoomId(room.roomId);
      setPhase("lobby");

      room.onStateChange((s: any) => {
        setPhase((p) => (s.phase === "lobby" && p === "idle" ? "lobby" : s.phase));
        const list: { id: string; name: string }[] = [];
        let answered = 0;
        s.players?.forEach((p: any, id: string) => {
          list.push({ id, name: p.name });
          if (p.hasAnswered) answered++;
        });
        setPlayers((prev) => {
          if (list.length > prev.length) sfx.join();
          return list;
        });
        setAnsweredCount(answered);
      });
      room.onMessage("chainReady", () => setChainReady(true));
      room.onMessage("question", (m: any) => {
        setQuestion({ ...m.question });
        setEndsAt(m.endsAt);
        setCorrect(null);
        setAnsweredCount(0);
        sfx.question();
      });
      room.onMessage("reveal", (m: any) => {
        setCorrect(m.correctChoice);
        setBoard(m.leaderboard);
        sfx.correct();
      });
      room.onMessage("podium", (m: any) => {
        setBoard(m.leaderboard);
        sfx.fanfare();
      });
      room.onMessage("settled", (m: any) => {
        setSettlement(m.settlement);
        sfx.coin();
      });
      room.onMessage("anchored", (m: any) => pushAnchor(m.name, m.questionIndex, m.ms));
      room.onMessage("error", (m: any) => setError(m.message));
    } catch (e: any) {
      setError(String(e?.message ?? e));
      setPhase("idle");
    } finally {
      setBusy(false);
    }
  }

  function start() {
    unlock();
    roomRef.current?.send("host:start");
  }

  const joinUrl = typeof window !== "undefined" && roomId ? `${window.location.origin}/play?c=${roomId}` : "";

  return (
    <main style={{ minHeight: "100vh", padding: "clamp(20px,3vw,48px)", position: "relative", overflow: "hidden" }}>
      <Ticker anchors={anchors} />
      <Header />

      <AnimatePresence mode="wait">
        {phase === "idle" && <Idle key="idle" busy={busy} pot={potHint} setPot={setPotHint} onCreate={createGame} />}
        {phase === "lobby" && (
          <Lobby key="lobby" joinUrl={joinUrl} code={roomId} players={players} chainReady={chainReady} pot={potHint} onStart={start} />
        )}
        {(phase === "question" || phase === "reveal") && question && (
          <QuestionView
            key="q"
            q={question}
            phase={phase}
            secondsLeft={secondsLeft}
            frac={Math.max(0, Math.min(1, (endsAt - now) / (question.durationMs || 20000)))}
            correct={correct}
            answered={answeredCount}
            players={players.length}
            board={board}
          />
        )}
        {(phase === "settling" || phase === "complete") && (
          <Podium key="podium" board={board} settlement={settlement} />
        )}
      </AnimatePresence>

      {error && <Toast msg={error} />}
    </main>
  );
}

/* ─────────────── pieces ─────────────── */

function Header() {
  return (
    <div style={{ textAlign: "center", marginBottom: 8 }}>
      <span style={{ fontWeight: 900, fontSize: "clamp(26px,3vw,40px)", color: T.ink, letterSpacing: -0.5 }}>QUIVO</span>
      <span style={{ fontWeight: 800, fontSize: 14, color: "#6b6a86", marginLeft: 12 }}>
        live game show · real prizes · devnet
      </span>
    </div>
  );
}

function Idle({ busy, pot, setPot, onCreate }: { busy: boolean; pot: string; setPot: (v: string) => void; onCreate: () => void }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0 }}
      style={{ maxWidth: 620, margin: "10vh auto 0", textAlign: "center" }}
    >
      <Card style={{ padding: 40 }}>
        <div style={{ fontSize: 26, fontWeight: 900, color: T.ink }}>Host a live game show</div>
        <p style={{ color: T.muted, fontWeight: 700, fontSize: 16, margin: "10px 0 26px" }}>
          The room joins on their phones. Answer fast. Winners are paid on-chain, instantly.
        </p>
        <div style={{ display: "flex", alignItems: "center", gap: 10, justifyContent: "center", marginBottom: 22 }}>
          <Coin size={30} />
          <span style={{ fontWeight: 800, color: T.body }}>Prize pool</span>
          <input
            value={pot}
            onChange={(e) => setPot(e.target.value.replace(/[^0-9.]/g, ""))}
            style={{ width: 70, textAlign: "center", fontWeight: 900, fontSize: 20, color: T.ink, border: `2px solid #d3e1fb`, borderRadius: 14, padding: "8px 6px", background: "#fff" }}
          />
          <span style={{ fontWeight: 800, color: T.muted }}>test-USDC</span>
        </div>
        <PillButton onClick={onCreate} disabled={busy} big>
          {busy ? "Creating + escrowing pot…" : "▶  Create game"}
        </PillButton>
      </Card>
    </motion.div>
  );
}

function Lobby({ joinUrl, code, players, chainReady, pot, onStart }: any) {
  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} style={{ maxWidth: 1100, margin: "2vh auto 0" }}>
      <div style={{ display: "grid", gridTemplateColumns: "auto 1fr", gap: 28, alignItems: "start" }}>
        <Card style={{ padding: 28, textAlign: "center" }}>
          <div style={{ fontWeight: 900, fontSize: 22, color: T.ink, marginBottom: 14 }}>Scan to join</div>
          <div style={{ background: "#fff", padding: 14, borderRadius: 20, display: "inline-block", boxShadow: T.shadowCard }}>
            {joinUrl && <QRCodeSVG value={joinUrl} size={230} bgColor="#ffffff" fgColor={T.ink} />}
          </div>
          <div style={{ marginTop: 16, fontWeight: 800, color: T.muted, fontSize: 13 }}>or enter code</div>
          <div style={{ fontWeight: 900, fontSize: 40, letterSpacing: 4, color: T.primaryText }}>{code}</div>
          <div style={{ marginTop: 14, display: "inline-flex", alignItems: "center", gap: 8, fontWeight: 800, fontSize: 13, color: chainReady ? T.winLime : "#c58a1e" }}>
            <span style={{ width: 9, height: 9, borderRadius: 9, background: chainReady ? T.winLime : "#e8b04a", boxShadow: `0 0 0 4px ${chainReady ? "rgba(130,177,29,.18)" : "rgba(232,176,74,.2)"}` }} />
            {chainReady ? `${pot} USDC escrowed on-chain` : "escrowing prize pool…"}
          </div>
        </Card>

        <div>
          <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between", marginBottom: 14 }}>
            <div style={{ fontWeight: 900, fontSize: 26, color: T.ink }}>
              {players.length} player{players.length === 1 ? "" : "s"} in
            </div>
            <PillButton onClick={onStart} disabled={players.length === 0} color="130,177,29">
              ▶ Start
            </PillButton>
          </div>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 12, minHeight: 120, alignContent: "flex-start" }}>
            <AnimatePresence>
              {players.map((p: any) => (
                <motion.div
                  key={p.id}
                  layout
                  initial={{ scale: 0.4, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  exit={{ scale: 0.4, opacity: 0 }}
                  transition={{ type: "spring", stiffness: 500, damping: 20 }}
                >
                  <PlayerChip name={p.name} />
                </motion.div>
              ))}
            </AnimatePresence>
            {players.length === 0 && (
              <div style={{ color: "#7b7a93", fontWeight: 800, fontSize: 16, padding: "36px 4px" }}>waiting for players to scan…</div>
            )}
          </div>
        </div>
      </div>
    </motion.div>
  );
}

function QuestionView({ q, phase, secondsLeft, frac, correct, answered, players, board }: any) {
  return (
    <motion.div key={q.index} initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -20 }} style={{ maxWidth: 1200, margin: "1vh auto 0" }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 8 }}>
        <span style={{ fontWeight: 800, color: "#5b5a78", fontSize: 18 }}>Question {q.index + 1}</span>
        <span style={{ fontWeight: 800, color: T.primaryText, fontSize: 18 }}>
          {phase === "question" ? `${answered}/${players} answered` : "answers locked"}
        </span>
      </div>

      <Card style={{ padding: "clamp(24px,3vw,44px)", position: "relative", overflow: "visible" }}>
        <Ring frac={frac} seconds={secondsLeft} hidden={phase !== "question"} />
        <div style={{ fontWeight: 900, color: T.ink, fontSize: "clamp(28px,4vw,56px)", lineHeight: 1.12, textAlign: "center", textWrap: "balance", padding: "10px 40px 6px" } as any}>
          {q.prompt}
        </div>
      </Card>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginTop: 18 }}>
        {q.options.map((opt: string, i: number) => {
          const a = ANSWERS[i % 4];
          const dim = correct !== null && correct !== i;
          const win = correct === i;
          return (
            <motion.div
              key={i}
              animate={{ opacity: dim ? 0.25 : 1, scale: win ? 1.04 : 1 }}
              transition={springy}
              style={{
                background: a.grad,
                borderRadius: 22,
                padding: "clamp(18px,2.4vw,30px)",
                display: "flex",
                alignItems: "center",
                gap: 18,
                boxShadow: win ? `0 0 0 6px #fff, ${T.shadowBtn(a.rgb)}` : T.shadowBtn(a.rgb),
                minHeight: 92,
              }}
            >
              <span style={{ fontSize: "clamp(24px,3vw,40px)", color: "#fff", opacity: 0.9 }}>{a.glyph}</span>
              <span style={{ fontWeight: 900, color: "#fff", fontSize: "clamp(20px,2.4vw,34px)", textShadow: "0 2px 6px rgba(0,0,0,.18)" }}>{opt}</span>
              {win && <span style={{ marginLeft: "auto", fontSize: 34 }}>✓</span>}
            </motion.div>
          );
        })}
      </div>

      {phase === "reveal" && <MiniBoard board={board} />}
    </motion.div>
  );
}

function MiniBoard({ board }: { board: LB[] }) {
  return (
    <div style={{ marginTop: 18, display: "flex", flexDirection: "column", gap: 8, maxWidth: 620, marginInline: "auto" }}>
      {board.slice(0, 5).map((r) => (
        <motion.div key={r.sessionId} layout transition={springy} style={rowStyle(r.rank === 1)}>
          <span style={{ display: "flex", alignItems: "center", gap: 12, fontWeight: 800, color: T.ink, fontSize: 20 }}>
            <Medal rank={r.rank} /> {r.name}
          </span>
          <span style={{ fontWeight: 900, color: T.ink, fontSize: 22 }}>
            <AnimatePresence>
              {r.delta > 0 && (
                <motion.span key={r.score} initial={{ y: 10, opacity: 0 }} animate={{ y: 0, opacity: 1 }} style={{ color: T.winLime, marginRight: 10, fontSize: 16 }}>
                  +{r.delta}
                </motion.span>
              )}
            </AnimatePresence>
            {r.score}
          </span>
        </motion.div>
      ))}
    </div>
  );
}

function Podium({ board, settlement }: { board: LB[]; settlement: Settlement | null }) {
  const top = board.slice(0, 3);
  const order = [1, 0, 2]; // 2nd, 1st, 3rd for pedestal
  const heights = [150, 210, 120];
  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} style={{ maxWidth: 900, margin: "1vh auto 0", textAlign: "center" }}>
      <div style={{ fontWeight: 900, fontSize: 34, color: T.ink }}>🏆 Podium</div>
      <div style={{ display: "flex", alignItems: "flex-end", justifyContent: "center", gap: 18, margin: "24px 0 8px", minHeight: 240 }}>
        {order.map((idx, slot) => {
          const p = top[idx];
          if (!p) return <div key={slot} style={{ width: 200 }} />;
          const rank = idx + 1;
          return (
            <motion.div key={p.sessionId} initial={{ y: 60, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ delay: slot * 0.15, ...springy }} style={{ width: 200 }}>
              <div style={{ marginBottom: 10 }}>
                <div style={{ width: 66, height: 66, margin: "0 auto 8px", borderRadius: "50%", background: playerHue(p.wallet || p.name), boxShadow: T.shadowCard }} />
                <div style={{ fontWeight: 900, color: T.ink, fontSize: 20 }}>{p.name}</div>
                <div style={{ fontWeight: 900, color: T.primaryText, fontSize: 22 }}>{p.score}</div>
              </div>
              <div style={{ height: heights[idx], background: idx === 0 ? T.winPurple : "#fff", borderRadius: "18px 18px 0 0", boxShadow: T.shadowCard, display: "flex", alignItems: "flex-start", justifyContent: "center", paddingTop: 12 }}>
                <span style={{ fontWeight: 900, fontSize: 30, color: idx === 0 ? "#fff" : T.muted }}>{rank}</span>
              </div>
            </motion.div>
          );
        })}
      </div>

      <AnimatePresence mode="wait">
        {!settlement ? (
          <motion.div key="paying" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
            <Card style={{ padding: 22, maxWidth: 480, margin: "16px auto 0" }}>
              <div style={{ display: "flex", alignItems: "center", gap: 12, justifyContent: "center", fontWeight: 800, color: "#c58a1e", fontSize: 18 }}>
                <Coin size={26} spin /> Paying winners on-chain…
              </div>
            </Card>
          </motion.div>
        ) : (
          <motion.div key="paid" initial={{ scale: 0.85, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} transition={{ type: "spring", stiffness: 300, damping: 18 }}>
            <Card style={{ padding: 26, maxWidth: 520, margin: "16px auto 0", background: "linear-gradient(180deg,#f0fbf2,#e6f7ea)" }}>
              <div style={{ fontWeight: 900, fontSize: 24, color: "#2f9e44", display: "flex", alignItems: "center", gap: 10, justifyContent: "center" }}>
                <Coin size={28} /> Winners paid on-chain
              </div>
              <div style={{ margin: "14px 0", display: "flex", flexDirection: "column", gap: 8 }}>
                {settlement.winners.map((w) => (
                  <div key={w.rank} style={{ display: "flex", justifyContent: "space-between", fontWeight: 800, color: T.ink, fontFamily: "ui-monospace, monospace", fontSize: 15, background: "#fff", borderRadius: 12, padding: "10px 14px" }}>
                    <span><Medal rank={w.rank} /> {w.wallet.slice(0, 4)}…{w.wallet.slice(-4)}</span>
                    <span style={{ color: "#2f9e44" }}>+{Number(w.amount) / 1e6} USDC</span>
                  </div>
                ))}
              </div>
              {settlement.txSig !== "stub-signature" ? (
                <a href={`https://explorer.solana.com/tx/${settlement.txSig}?cluster=devnet`} target="_blank" style={{ color: T.primaryText, fontWeight: 800 }}>
                  view the settlement transaction ↗
                </a>
              ) : (
                <span style={{ color: T.muted, fontSize: 13, fontWeight: 700 }}>(stub mode — no relayer key set)</span>
              )}
            </Card>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}

function Ticker({ anchors }: { anchors: Anchor[] }) {
  return (
    <div style={{ position: "fixed", top: 16, right: 16, width: 300, display: "flex", flexDirection: "column", gap: 8, zIndex: 50, pointerEvents: "none" }}>
      <AnimatePresence>
        {anchors.map((a) => (
          <motion.div
            key={a.id}
            initial={{ x: 320, opacity: 0 }}
            animate={{ x: 0, opacity: 1 }}
            exit={{ opacity: 0, scale: 0.9 }}
            transition={{ type: "spring", stiffness: 400, damping: 28 }}
            style={{ background: T.primaryGrad, color: "#fff", borderRadius: 14, padding: "9px 13px", boxShadow: T.shadowBtn(), fontWeight: 800, fontSize: 13, display: "flex", alignItems: "center", gap: 8 }}
          >
            <span style={{ fontSize: 15 }}>⚡</span>
            <span style={{ flex: 1, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
              {a.name} · answer anchored
            </span>
            <span style={{ fontFamily: "ui-monospace, monospace", opacity: 0.85, fontSize: 11 }}>q{a.questionIndex + 1}</span>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}

/* ─────────────── atoms ─────────────── */

function Card({ children, style }: { children: any; style?: React.CSSProperties }) {
  return <div style={{ background: T.card, borderRadius: T.rBig, boxShadow: T.shadowFloat, ...style }}>{children}</div>;
}

function PillButton({ children, onClick, disabled, big, color = "47,125,246" }: any) {
  return (
    <motion.button
      whileTap={{ scale: 0.94 }}
      onClick={onClick}
      disabled={disabled}
      style={{
        border: "none",
        borderRadius: 999,
        padding: big ? "18px 44px" : "12px 28px",
        fontWeight: 900,
        fontSize: big ? 22 : 18,
        color: "#fff",
        background: disabled ? "#b9bccb" : `linear-gradient(90deg, rgb(${color}), rgb(${color}))`,
        boxShadow: disabled ? "none" : `0 6px 14px rgba(${color},.4)`,
        cursor: disabled ? "not-allowed" : "pointer",
        fontFamily: "inherit",
      }}
    >
      {children}
    </motion.button>
  );
}

function PlayerChip({ name }: { name: string }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 9, background: "#fff", borderRadius: 999, padding: "8px 16px 8px 8px", boxShadow: T.shadowCard }}>
      <div style={{ width: 30, height: 30, borderRadius: "50%", background: playerHue(name) }} />
      <span style={{ fontWeight: 800, color: T.ink, fontSize: 16 }}>{name}</span>
    </div>
  );
}

function Ring({ frac, seconds, hidden }: { frac: number; seconds: number; hidden: boolean }) {
  const R = 34;
  const C = 2 * Math.PI * R;
  const urgent = seconds <= 3;
  return (
    <div style={{ position: "absolute", top: -34, left: "50%", transform: "translateX(-50%)", opacity: hidden ? 0 : 1, transition: "opacity .3s" }}>
      <motion.div animate={{ scale: urgent ? [1, 1.12, 1] : 1 }} transition={{ duration: 0.5, repeat: urgent ? Infinity : 0 }} style={{ position: "relative", width: 84, height: 84 }}>
        <svg width="84" height="84" style={{ transform: "rotate(-90deg)" }}>
          <circle cx="42" cy="42" r={R} fill="#fff" stroke="#eef0f7" strokeWidth="8" />
          <circle cx="42" cy="42" r={R} fill="none" stroke={urgent ? "#e5484d" : T.primary} strokeWidth="8" strokeLinecap="round" strokeDasharray={C} strokeDashoffset={C * (1 - frac)} />
        </svg>
        <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", fontWeight: 900, fontSize: 30, color: urgent ? "#e5484d" : T.ink, fontVariantNumeric: "tabular-nums" }}>{seconds}</div>
      </motion.div>
    </div>
  );
}

function Coin({ size = 26, spin }: { size?: number; spin?: boolean }) {
  return (
    <motion.div
      animate={spin ? { rotateY: 360 } : {}}
      transition={spin ? { duration: 1.4, repeat: Infinity, ease: "linear" } : {}}
      style={{ width: size, height: size, borderRadius: "50%", background: T.coin, boxShadow: T.coinShadow, flex: "none", display: "grid", placeItems: "center" }}
    >
      <div style={{ width: size * 0.42, height: size * 0.42, borderRadius: "50%", background: "radial-gradient(circle at 35% 30%,#ffe0a8,#f0a835)" }} />
    </motion.div>
  );
}

function Medal({ rank }: { rank: number }) {
  return <span>{rank === 1 ? "🥇" : rank === 2 ? "🥈" : rank === 3 ? "🥉" : `${rank}.`}</span>;
}

function Toast({ msg }: { msg: string }) {
  return (
    <div style={{ position: "fixed", bottom: 20, left: "50%", transform: "translateX(-50%)", background: "#e5484d", color: "#fff", fontWeight: 800, padding: "12px 20px", borderRadius: 14, boxShadow: T.shadowCard, zIndex: 60 }}>
      ⚠ {msg}
    </div>
  );
}

function rowStyle(first: boolean): React.CSSProperties {
  return {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    padding: "12px 18px",
    borderRadius: 16,
    background: first ? "#fff" : T.cardTint,
    boxShadow: first ? T.shadowCard : "none",
  };
}
