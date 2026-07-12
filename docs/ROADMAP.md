# Quivo: Top-Submission Roadmap

> Everything a *winning* weekend-hackathon submission needs, beyond "it works." Synthesized from
> deep research (Kahoot/Jackbox/HQ Trivia patterns, CC0 audio sources, Colosseum judging guidance,
> WebSocket reconnection best-practice) + our architecture. Checklist-first; sources cited inline.
>
> Status legend: ✅ done · 🔨 in progress · ⬜ todo

---

## 0. The one-line thesis (say it everywhere)
**"Kahoot where the prize is real, escrowed before the game, every answer recorded on-chain live
through MagicBlock's Ephemeral Rollup, winners paid the instant it ends. Don't trust us, read the
accounts."** This is the hook for the README, the pitch, and the 15-second demo opener.

---

## 1. Product / gameplay feel (make it electric)

The research on what makes live trivia land, mapped to Quivo:

- **Countdown tension is a *whole-body* thing.** HQ Trivia vibrated the phone once per remaining
  second so time pressure was *felt*, not just seen [bighuman.com/work/hq-trivia]. → Quivo player
  phones: `navigator.vibrate` a short pulse each of the last ~5 seconds; stage countdown ring pulses
  + shifts toward red. 🔨
- **Sudden-death / escalating stakes** drove HQ's drama (12 questions, one miss = out, survivors
  split the pot) [same]. → Quivo keeps everyone in (more fun for a room) but escalates points per
  question and shows the *pot* growing tension; a "final question, double points" beat is the cheap
  win. ⬜
- **The four answer colors are the grammar.** Stage and phone share red/blue/gold/green + shape
  glyphs (▲◆●■ for colorblind). Player taps a color; stage reveals the same color. ✅ (tokens)
- **Reveal choreography:** wrong options desaturate + shrink to ~25%; correct springs up +6% with a
  white ring; `+NNN` deltas fly up; leaderboard FLIP-reorders. 🔨
- **Podium ceremony:** 3-2-1 pedestal, winner scale-in, then the money beat, coin burst on
  "PAID ON-CHAIN ✓" with the tx link. This is the screenshot that travels. 🔨
- **Big-screen (projector) rules:** ink-on-white only for critical text, question ≥ 56px, timer
  ≥ 80px, answer labels ≥ 32px, tabular numerals, high contrast (candy colors are ~AA on white with
  the white 900-weight labels carrying the text). ✅ (DESIGN.md)
- **Phone thumb-ergonomics:** answer tiles in the bottom 60% of the screen, ≥ 110px tall, 2×2, no
  precise targets, single-tap lock. ✅

---

## 2. Audio (the multiplier most hackathon apps skip)

Sound is the cheapest way to make a demo feel finished. Moments that matter, in order of impact:
lobby loop → question swoosh → countdown tick (last 5s) + rising tension bed → answer-lock click →
correct/wrong stinger → leaderboard whoosh → **podium fanfare** → **coin/payout chime**.

- **Our choice: 100% procedural Web Audio** (`app/sound.ts`): zero asset files, zero licensing,
  works offline at a venue, no autoplay-of-a-media-file issues. ✅
- **Autoplay policy** (universal): browsers block audio until a user gesture; arm the engine on the
  *first tap*, host: Create/Start; player: Join [howler.js README pattern; same rule for raw Web
  Audio via `AudioContext.resume()`]. ✅ (`unlock()` on first interaction)
- **If we ever want richer samples** (fallback, not needed): CC0/free sources vetted in research:
  Kenney *Interface Sounds* (100 CC0 files) + *Music Jingles* (85 CC0) [kenney.nl/assets/category:Audio];
  Mixkit game-show category (37 free SFX incl. countdown timers, correct/wrong stingers)
  [mixkit.co/free-sound-effects/game-show]. Keep as `public/sfx/` swap-in if judges want polish.
- **Haptics** pair with audio on the phone (lock, correct, payout). ✅ (`buzz()`)

---

## 3. Onboarding (a room of strangers, in seconds)

- **QR → deep-link with the code pre-filled**, ephemeral wallet minted silently in `localStorage`,
  no signup, name optional. ✅ (verified in browser)
- **Join must never hard-fail on flaky venue wifi.** Research-backed reconnection contract: ⬜
  - Colyseus already reconnects its own socket; we keep the player's seat during an active game. ✅
  - Add exponential backoff **500ms base, ×2, cap 30s, jittered 50–100%** to avoid a whole room
    thundering-herd reconnecting after an AP hiccup [websocket.org/guides/reconnection]. ⬜
  - On rejoin, **full-state resync**: the server re-sends current phase/question/timer/score so a
    returning phone lands on the live screen, never a stale one [same; Socket.IO CSR `recovered===false`
    fallback pattern]. ⬜
- **Error copy** is human: "Couldn't reach the game, retrying…" not a raw stack. ⬜
- **Empty/edge states:** lobby with 0 players (host sees "waiting for players…"), a player who joins
  mid-question (lands in the current question or a "next question starting…" hold). ⬜

---

## 4. What judges actually reward (Colosseum-style)

From Colosseum's own guidance [blog.colosseum.com/how-to-win-a-colosseum-hackathon,
/perfecting-your-hackathon-submission]:

- **Pitch video < 3 minutes**, narrative clarity **over** production polish; "flashy visuals with
  little substance" is an explicit anti-pattern. ⬜
- **Two videos:** a pitch (the *why*) and a **separate technical demo** walking core features, stack,
  and the reasoning behind the on-chain design. ⬜
- **Six pitch beats:** team · product · why you started · market opportunity · how you get first
  usage/traction · live demo. ⬜
- **Judges favor teams who'll keep building** and products with a **viable business model**, not
  just a clever weekend demo. → Quivo's "run it at every crypto meetup / conference / token launch"
  angle + a real fee model (host pays / sponsor-funded pots, small rake) belongs in the pitch. ⬜
- **README anatomy** (below). ⬜

### Demo video script (2 min, our cut)
1. **0:00–0:15 Hook:** "This is Kahoot, but the prize is real crypto, and it's escrowed on-chain
   before anyone plays." Big screen + phones in frame.
2. **0:15–0:35 Join:** scan QR → on the phone → in. "No app, no signup, no seed phrase, a wallet
   was just minted on their phone."
3. **0:35–1:10 Play:** questions, countdown, the **live on-chain ticker**: "every answer is landing
   on the MagicBlock rollup *right now*, gasless." Show the ticker.
4. **1:10–1:35 Settle:** podium → "Winners paid, on-chain, this second" → click the explorer link
   live. Show a winner phone: "💸 You got paid."
5. **1:35–2:00 Proof + ask:** "Read the accounts, the answers are on Solana, the payout is on
   Solana." One line on the business ("runs at any event; host or sponsor funds the pot").

### Live-demo risk management
- **Pre-record the happy path** as backup video in case venue wifi dies. ⬜
- **Single-device fallback** already exists (one phone hot-swaps seats). ✅ (sim)
- **Self-minted test-USDC + relayer-sponsored gas** so no faucet dependency mid-demo. ✅
- **Tier-2 degrades to Tier-1**: if the ER hiccups, the payout still happens. ✅ (architecture)
- **RPC flakiness** handled by transient-retry wrapper. ✅

---

## 5. Polish details that separate winners

- **Micro-interactions:** spring everything (stiff ~380, damp ~26), never linear fades; button press
  scale-down; player-chip pop-in with overshoot; rolling number counters (score, pot, payout). 🔨
- **Haptics on mobile web** at lock / correct / payout. ✅ helper
- **Latency masking:** optimistic UI, the phone shows "locked in ✓" *immediately* on tap; the
  on-chain anchor happens in the background and only surfaces as a subtle ticker item. ✅ (fire-and-forget)
- **Reconnection** (see §3). ⬜
- **Loading/skeleton** states while the escrow funds in the lobby ("prize pool loading…"). 🔨
- **Accessibility:** shape glyphs on answers, ≥ AA contrast, `prefers-reduced-motion` respected. ⬜

---

## 6. Submission deliverables checklist

- ⬜ **README.md** (public): thesis line → 30-sec "what it is" → the on-chain proof (program id,
  explorer links to a real settle + a real answer-anchor tx) → architecture diagram → "run it in 60s"
  → honest scope (devnet, Tier-1/Tier-2) → roadmap → team.
- ⬜ **Pitch video** (< 3 min) + **technical demo video** (2–3 min).
- ⬜ **Live deploys:** stage on Vercel, realtime on Railway, program on devnet (done), GitHub public.
- ✅ **On-chain evidence** captured (settle tx, answer-anchor tx, decoded Player accounts).
- 🔨 **Screenshots / GIF** of the money moment for the README + social.
- ⬜ **One-liner + 6-beat pitch** written down.

---

## 7. Build order from here (this session)
1. ✅ Design system + tokens + procedural audio engine + ER ticker plumbing
2. 🔨 Stage UI rebuild (lobby energy · countdown · reveal choreography · podium · on-chain ticker · sound)
3. ⬜ Player UI rebuild (candy tiles · locked/reveal · payout moment · haptics · sound)
4. ⬜ Reconnection + resync + empty states
5. ⬜ Browser verification + README + screenshots
6. ⬜ Deploy (Railway + Vercel + GitHub)
