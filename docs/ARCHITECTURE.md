# Quivo: System Architecture

> **Quivo** is a live, in-the-room game show for crypto events. A host runs it from a big screen;
> the whole room joins on their phones by scanning a QR; everyone answers in real time; the winners
> are paid a real crypto prize **on-chain, instantly, in front of the room**, provably fair.
>
> This document is the source of truth for how the system is built. It is deliberately not a
> hackathon hack: the boundaries below (real-time authority vs. money/fairness authority) are the
> boundaries a production version would keep. We ship a scoped slice of it, not a different design.

---

## 1. The one hard problem

A live quiz has two requirements that pull in opposite directions:

1. **It must feel instant.** 40–300 people tapping answers at once, a leaderboard that snaps between
   questions, sub-150ms feedback. That is a *soft-real-time fan-out* problem, the domain of an
   authoritative game server, not a blockchain.
2. **The money and the fairness must be trustless.** The prize pot cannot be rug-pullable by the
   host; the questions cannot be swapped after bets are in; the payout must be verifiable and land in
   the winners' own wallets. That is a *settlement + verifiable-fairness* problem, the domain of a
   chain, and specifically of one fast enough to settle **while the room is still standing there.**

Quivo's architecture is the clean split of those two concerns, plus the seam that joins them.

```
        ┌──────────────────────────┐         ┌───────────────────────────┐
        │   GAMEPLAY AUTHORITY      │  seam   │   MONEY + FAIRNESS         │
        │   (off-chain, real-time)  │◄───────►│   AUTHORITY (on-chain)     │
        │                           │         │                           │
        │  Colyseus room server     │         │  Solana program + the      │
        │  · round lifecycle/timing │         │  MagicBlock Ephemeral      │
        │  · receives answers       │         │  Rollup                    │
        │  · live leaderboard       │         │  · pot escrow PDA          │
        │  · WS fan-out to phones   │         │  · question-set commitment │
        │  · holds SECRET questions │         │  · answer anchoring (ER)   │
        │                           │         │  · VRF tie-break           │
        │                           │         │  · settle = Magic Action   │
        └──────────────────────────┘         └───────────────────────────┘
```

Neither side is allowed to own the other's job. The server never custodies the pot; the chain never
holds a secret question in plaintext. That rule is what keeps this honest.

---

## 2. Components & the monorepo

```
quivo/
├── apps/
│   ├── mobile/        Flutter - the PLAYER app (scan → join → answer → get paid)
│   └── stage/         Next.js - the HOST "stage" (big-screen presenter) + landing page  → Vercel
├── services/
│   └── realtime/      Node + TypeScript + Colyseus - authoritative game server + chain worker → Railway
├── onchain/
│   └── programs/quivo/ Anchor + ephemeral-rollups-sdk - escrow, commitment, ER, settlement → Solana devnet
├── packages/
│   └── protocol/      Shared TS: WS message schema, game state types, scoring, constants
└── docs/
```

| Concern | Tech | Runs on | Why |
|---|---|---|---|
| Player client | Flutter 3.44 | phones (APK/TestFlight; Solana Mobile-ready) | one codebase, native feel, the audience is mobile |
| Host / big screen | Next.js | **Vercel** (edge/static) | the presenter view is a web page on a projector; landing lives here too |
| Real-time game server | Colyseus (Node/TS) | **Railway** (persistent process) | authoritative rooms, WS fan-out, reconnection, horizontal scale via Redis |
| Durable data | Postgres 15 | **Railway** plugin | games, question banks, results, hosts |
| Hot state / presence / rate-limit | Redis | **Railway** plugin | Colyseus presence + scale-out, idempotency, answer rate-limiting |
| Settlement + fairness | Anchor program | **Solana devnet** + MagicBlock ER | trustless pot, VRF, instant gasless payout |
| Chain worker (relayer/crank) | Node/TS | inside `services/realtime` on **Railway** | sponsors gas, drives delegate/commit/settle, watches chain |

**Why Colyseus and not "just WebSockets":** Colyseus is a purpose-built *authoritative* real-time
framework: rooms, patch-based state sync, client reconnection, and (critically) horizontal scale via
a Redis presence driver. It is the "proper scalable thing" for exactly this shape of app; hand-rolling
room state + reconnection + fan-out is where hackathon code rots.

---

## 3. The seam: on-chain vs off-chain authority

This is the most important design decision, so it is explicit.

**Off-chain is authoritative for the *experience*:**
- The round clock, question order, and "answer window open/closed" - the server's clock is truth,
  because latency and secrecy demand it.
- The **secret questions**: a public chain cannot hold the correct answer before the question is
  asked, or players read ahead. Questions live server-side and are revealed per-round.
- The **live leaderboard**: derived and broadcast by the server so 300 phones don't each poll chain.

**On-chain is authoritative for *trust and money*:**
- **Pot escrow**: a program-owned PDA holds the prize. The host funds it and *cannot* withdraw it;
  only the settlement instruction (signed by the vault PDA) can move it.
- **Question-set commitment**: at game start the host posts `hash(questions ‖ answers ‖ salt)`
  on-chain. At the end the set is revealed; anyone can verify the host didn't swap questions after
  money was staked. (Content fairness.)
- **Answer anchoring**: each player's `(answerChoice, latencyBucket)` per question is written to the
  MagicBlock **Ephemeral Rollup** via a gasless, session-key-signed transaction, so the score is
  reconstructible from on-chain data, not just the server's word. (Outcome fairness.)
- **VRF**: resolves ties deterministically and unforgeably at settlement.
- **Settlement**: a single **Magic Action** pays the top-N winners from escrow and commits state
  back to Solana base layer, atomically. Instant, in-room, on-chain, verifiable.

### Where MagicBlock is genuinely load-bearing (and where it isn't, stated honestly)

The Ephemeral Rollup is **not** doing the leaderboard fan-out; Colyseus is, because that's the right
tool. The ER earns its place on the two things a normal chain physically can't do live:

1. **Per-answer on-chain records at the speed of play**: hundreds of gasless, sub-100ms,
   session-key-signed answer writes during a 20-second window. On 400ms L1, with a fee and a wallet
   prompt per answer, this is impossible; the trust layer would have to be faked. The ER makes the
   *verifiable* version real-time.
2. **Instant multi-winner settlement in the room**: a gasless atomic payout to the top-N the moment
   the game ends, committed to base layer, while everyone watches. That's the money moment.

If a judge asks "why not settle once on L1 at the end?", you can, and that's the **Tier-1** fallback
below. The ER is what upgrades it from "trust the server's final scoreboard" to "the scoreboard was
on-chain the whole time." We build toward that, honestly, and we don't overclaim the parts Colyseus
owns.

### Trust tiers (a dial, not a corner cut)

The seam supports two trust levels with the *same* architecture, this is a deliberate scalability
dial, so we can ship the robust core first and turn up trust as time allows:

- **Tier 1: Escrow + committed results (MVP, ship first).** Gameplay + scoring in Colyseus. Server
  posts a signed **Merkle root of all answers** on-chain before settlement, plus the question reveal.
  On-chain: escrow, commitment, VRF, Magic-Action payout. Outcome is *auditable* (roots + reveal),
  money is *trustless*. Fully honest, fully shippable in the weekend.
- **Tier 2: Live answer anchoring (the differentiator).** Each answer is a gasless ER write in real
  time; scoring is reconstructible on-chain as it happens. This is the maximal MagicBlock-native
  version and the on-stage "watch the answers hit the chain live" beat.

We implement Tier 1 end-to-end, then lift the hot path to Tier 2. The account model (per-player state,
§5) is designed for Tier 2 from day one, so it is not a rewrite. It is turning the dial.

---

## 4. Lifecycle of one game (end-to-end)

```
HOST (stage/Vercel)                 SERVER (realtime/Railway)            CHAIN (Solana + ER)
──────────────────                  ─────────────────────────            ────────────────────
create game, set pot ───────────►   create Game room + DB row  ───────►  initialize_game
                                                                          + fund escrow PDA (host)
                                                                          + commit_questions(hash)
show QR + join code  ◄───────────   room ready, join code

PLAYERS (mobile)
scan QR ──────────────────────────► join_game (WS)  ─────────────────►   register Player PDA
   (ephemeral wallet minted,                                             + create session key
    gas sponsored)                  lobby state broadcast                  delegated to the ER

HOST: "Start" ────────────────────► round loop begins
                                     ├─ broadcast Question i (no answer)
PLAYERS tap answer ───────────────►  ├─ accept within window  ──────►    submit_answer → ER
                                     │    (score = correct × speed)         (gasless, session key)
                                     ├─ close window, reveal answer
                                     ├─ broadcast leaderboard
                                     └─ repeat for N questions
                                     compute final ranking  ──────────►   post answers Merkle root
                                                                          request VRF (tie-break)
                                     settle ─────────────────────────►    SETTLE (Magic Action):
                                                                          pay top-N from escrow,
                                                                          commit_and_undelegate → L1
podium + payout   ◄───────────────  broadcast Settled(txSig, winners) ◄─  winners' wallets credited
(everyone sees it land, on-chain)
```

Onboarding detail (from the validated pattern): players never touch a seed phrase or a wallet popup.
The mobile app mints an ephemeral keypair on first open (secure storage), a relayer/fee-payer in the
chain worker sponsors gas, and a **session key** scoped to this game signs every answer with no prompt.
A crypto-native player can optionally link a real wallet (Mobile Wallet Adapter), that's the upgrade
path, not the front door.

---

## 5. On-chain program (`onchain/programs/quivo`)

Anchor 1.0.2 + `ephemeral-rollups-sdk`. Deployed to devnet; the live `Game` account is **delegated**
to the Ephemeral Rollup for the duration of play, then **committed + undelegated** at settlement.

**Accounts**
- `Game`: `host`, `pot_mint`, `pot_vault` (PDA), `status`, `question_commitment: [u8;32]`,
  `num_questions`, `prize_split` (e.g. `[60,30,10]`), `players`, `answers_root: [u8;32]`, `seed`.
- `Player`: `game`, `wallet`, `score`, `answered_count`, `prized: bool`. (Per-player = no
  shared-account write contention when we lift to Tier-2 live anchoring.)
- `PotVault`: SPL token account owned by a PDA (`["vault", game]`). The escrow.

**Instructions**
- `initialize_game(num_questions, prize_split, seed)`: create `Game` + `PotVault`.
- `fund_pot(amount)`: host (or sponsor) transfers prize into the escrow.
- `commit_questions(commitment)`: store `hash(questions‖answers‖salt)` before any player joins.
- `join_game()`: create `Player`, register session key.
- `delegate_game()`: hand the `Game`/round accounts to the ER (`commit_frequency = never`; we commit
  once at the end, not per answer). *Reference: throtl `delegate_ride.rs`.*
- `submit_answer(q_index, choice, latency_bucket)`: **runs on the ER**, session-key-signed, gasless.
- `close_and_root(answers_root)`: post the Merkle root of answers (Tier-1 auditability).
- `settle(reveal, vrf_proof)`: verify reveal against `question_commitment`, resolve ties via VRF,
  pay `prize_split` to the top-N from `PotVault`, `commit_and_undelegate` to base layer. One Magic
  Action. *Reference: throtl `request_settle.rs`.*

**Honest anti-cheat (no spoofable sensor/claim):**
- Escrow is a PDA: the host has no withdraw path. Provable.
- `question_commitment` before joins: the host can't swap questions after money is in. Provable.
- `prized` flag: a wallet can't be paid twice.
- The server authenticates answer *timing* (it owns the clock); the chain authenticates *what was
  answered and who won*. We never claim the phone proves a human: the sensor/timing is UX, the money
  logic is the chain.

**Framework note:** we start in **Anchor** (fastest correct path in 48h, and the toolchain is already
`anchor-cli 1.0.2`). throtl's Pinocchio rewrite (`ephemeral-rollups-pinocchio 0.15.4`) is the
optimization path if rent/CU cost matters later, same wire contract, not a weekend concern.

---

## 6. Real-time server (`services/realtime`)

Node/TS + Colyseus. Two responsibilities, one process (split later if needed):

**A. Game rooms (`rooms/GameRoom.ts`)**: one Colyseus room per game. Holds authoritative state
(phase, questionIndex, endsAt, `players: Map<sessionId, PlayerState>`), the secret question set, the
round clock, and the scoring. Broadcasts patch-based state to all clients + the stage. Handles
reconnection (a dropped phone rejoins its seat).

**B. Chain worker**: the only holder of the fee-payer/relayer key. Sponsors gas, drives
`delegate_game` / `submit_answer` (Tier-2) / `close_and_root` / `settle`, and watches for the
settlement confirmation to broadcast the payout. Idempotent, retried, and the private keys live only
here (never in the client).

**State stores:** Postgres (durable: games, question banks, results, hosts) via a thin data layer;
Redis (hot: Colyseus presence for multi-node scale, answer idempotency keys, per-IP/per-wallet rate
limits).

**Scaling:** rooms are cheap and independent; a node holds many; Redis presence lets rooms spread
across nodes and lets the stage/players find their room by code. Answer submission is rate-limited and
idempotent (a double-tap or a retry can't double-score).

---

## 7. Deployment topology (Railway · Vercel · GitHub)

- **GitHub**: the `quivo` monorepo. Actions run typecheck + build on PR (`.github/workflows/ci.yml`).
- **Vercel**: `apps/stage`. Root Directory = `apps/stage`; deploys on push to `main`. Serves the
  presenter/big-screen app and the landing page. (Static/edge, no server state here.)
- **Railway**: `services/realtime` as a long-running service (Dockerfile), + **Postgres** plugin +
  **Redis** plugin. Railway is correct because WebSocket rooms need a *persistent* process; Vercel's
  serverless functions cannot hold a socket. Env: `DATABASE_URL`, `REDIS_URL`, `SOLANA_RPC`,
  `EPHEMERAL_RPC`, `RELAYER_SECRET`, `QUIVO_PROGRAM_ID`.
- **Solana devnet + MagicBlock ER**: `anchor deploy` to devnet; the ER endpoint is resolved at
  runtime from the router (`getDelegationStatus`), never hardcoded.
- **Flutter mobile**: built locally, distributed as APK/TestFlight for judges; Solana Mobile dApp
  Store-ready as a stretch.

```
GitHub (monorepo, CI)
   ├── apps/stage      ─► Vercel        (host screen + landing)
   ├── services/realtime ─► Railway     (Colyseus + Postgres + Redis + chain worker)
   ├── onchain         ─► Solana devnet (+ MagicBlock ER at runtime)
   └── apps/mobile     ─► APK / TestFlight (players)
```

---

## 8. What we build first (maps to the 48h plan)

1. **Vertical slice, no chrome:** one Colyseus `GameRoom` + a script "host" + a script "player" →
   prove: join → 3 questions → scoring → leaderboard, over WS. (Server correct before any UI.)
2. **Escrow + settle on devnet (Tier-1):** `initialize_game` / `fund_pot` / `commit_questions` /
   `close_and_root` / `settle` paying a hardcoded winner from the PDA. Prove money moves trustlessly.
3. **Wire the two:** chain worker settles the room's real final ranking; broadcast the tx.
4. **Stage app (Vercel):** QR + question + timer + leaderboard + the payout reveal.
5. **Mobile app (Flutter):** scan → ephemeral wallet → lobby → answer → "you won, it's in your wallet."
6. **Single-device demo insurance:** one phone can hot-swap seats into a room (never trust venue wifi).
7. **Tier-2 lift (if time):** answers as live ER writes.

Everything above is the real system, scoped. Nothing here is a throwaway we'd rip out for production.
We'd only turn the trust dial up and add question-authoring/host tooling around the same spine.
