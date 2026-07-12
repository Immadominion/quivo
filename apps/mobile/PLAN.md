# Quivo Mobile — Build Plan & Iteration Schedule

> A complete, ready-to-ship Flutter player app — not an MVP. Every screen a top game app ships with,
> the best-in-class UX, in our Candy Arcade design (docs/DESIGN.md), on the latest recommended stack.
> Informed by deep research (docs/MOBILE-RESEARCH.md) + throtl's proven Flutter+Solana patterns.

## Stack (latest recommended, cross-checked against throtl's proven choices)
| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter 3.44 (Dart 3.9) | installed, current |
| State | **Riverpod 2** (`flutter_riverpod` + `riverpod_annotation`) | the 2026 default; compile-safe, testable (throtl used `provider` — Riverpod is the modern successor) |
| Navigation | **go_router** | official Flutter recommendation, declarative, deep-link ready (QR → route) |
| Architecture | official Flutter layers: **UI → controllers (Riverpod) → repositories → services** | matches Flutter's app-architecture guide + throtl's `src/{screens,wallet,chain,...}` |
| Solana | **`solana ^0.32.0`** | throtl-proven: `Ed25519HDKeyPair.random()`, `RpcClient` balances, ATA derivation |
| Wallet | ephemeral `Ed25519HDKeyPair` in **`flutter_secure_storage`** | copy throtl `demo_wallet.dart`; phone = identity + payout address (no MWA needed for Tier-1) |
| Realtime | **`web_socket_channel`** → JSON-over-WS gateway on the realtime server | Colyseus isn't plain-JSON; a thin gateway keeps ONE server truth and a dead-simple Dart client |
| Animation | **`flutter_animate`** (choreography) + **`confetti`** (money moment) | declarative, spring-friendly; matches our motion beats |
| Audio | **`flutter_soloud`** (throtl-proven, low-latency) + bundled generated WAV SFX | self-contained, no licensing; procedural tones baked to `assets/sfx/` |
| Haptics | `HapticFeedback` (built-in) + **`vibration`** for custom patterns | countdown haptics (HQ-Trivia style), lock/correct/payout |
| Settings persist | `shared_preferences` | sound/haptics/theme toggles |
| QR | `mobile_scanner` | scan the stage QR |
| Store readiness | `flutter_launcher_icons` + `flutter_native_splash` | adaptive icon + branded splash |

## Server prerequisite
**JSON-over-WS gateway** (`services/realtime/src/gateway.ts`): a `ws` server that, per mobile
connection, joins the target Colyseus room as a `colyseus.js` client and relays JSON both ways
(`join`/`answer` up; `state`/`question`/`reveal`/`podium`/`settled`/`anchored` down). One source of
truth (the GameRoom); the phone speaks trivial JSON.

## Iteration schedule (each iteration = a shippable, verifiable slice)

**It 0 — Foundation** ✅ target
- JSON-over-WS gateway on the server (verify with a Dart/CLI smoke test)
- `flutter create` (org fun.quivo), add deps, analysis_options
- Candy Arcade design tokens in Dart (`theme/tokens.dart`), Nunito, ThemeData
- Riverpod `ProviderScope` + go_router shell + splash + adaptive icon
- App runs to a placeholder home on a device/simulator

**It 1 — Onboarding + identity**
- 3 welcome slides (value prop: "play live", "win real crypto", "no signup") w/ animated illustration
- silent ephemeral wallet mint on first run (secure storage) — no seed phrase shown, "advanced" reveal
- name entry, avatar auto-from-wallet, camera-permission priming screen
- first-run persistence (skip onboarding after)

**It 2 — Join + Lobby**
- home: big "Join game" + scan QR / enter code; recent games
- QR scanner screen (mobile_scanner) + code entry with the stage's format
- connect to gateway, join, lobby "you're in" w/ spring + player-count, error/offline states

**It 3 — Gameplay**
- question screen: candy tiles (bottom 60%, ≥110px), countdown ring + numeric, countdown haptics
- optimistic "locked in" on tap (+ lock haptic + sfx), disabled after
- reveal: wrong dim/shrink, correct spring + ring, my score/rank/+delta w/ correct/wrong haptic+sfx

**It 4 — Results + the money moment**
- results/podium (my placement, top 3)
- **payout screen**: coin drop, count-up amount, confetti burst, celebration haptics, "see on-chain",
  a **share card** (image the room screenshots) — the moment that travels
- "no payout" graceful state

**It 5 — Home, Profile, Wallet, History**
- home hub (join CTA, balance chip, recent results)
- profile (avatar, name edit, stats: games/wins/earned)
- wallet screen: balance (RpcClient), address (copy/QR to receive), "export key" (advanced), fund note
- match history (past games, placement, payout, tx link) w/ empty state

**It 6 — Settings + polish + a11y + store**
- settings: sound, haptics, notifications, theme, wallet export, about/version, licenses
- empty states, skeleton loaders, reconnection (backoff+resync), latency masking
- accessibility: dynamic type, reduced-motion, ≥AA contrast, semantic labels
- store readiness: adaptive icon, native splash, screenshots, app name/description

**It 7 — QA + device run + demo**
- run on real device (Android) + iOS sim; fix; capture screenshots/screen-recording for submission
- wire into README + demo video

## Design fidelity
Every screen follows docs/DESIGN.md: Nunito 700–900, lavender ground, white rounded cards, the four
candy answer colors (shared with the stage), coin motif for money, tinted shadows, full pills,
springy motion. The phone app is the reference-faithful surface (the Gaming Dashboard mock was a
phone).
