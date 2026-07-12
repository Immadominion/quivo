# Quivo — mobile app (Flutter)

The player-side companion to Quivo: join a live game show in the room by QR/code, answer timed
trivia on your phone, and get paid real crypto on Solana the instant the game settles.

Built with the 2026-recommended Flutter stack and verified end-to-end on an iOS simulator against
the live realtime server.

## What's in it

A complete, ship-ready product — not an MVP loop:

- **Onboarding** — 3 value slides, silent embedded wallet (no signup), name + avatar.
- **Home / Play** — greeting, wallet chip, big Join CTA, "how it works" strip.
- **Join** — big game-code entry (QR camera path is the next pass).
- **Live game** (`/play`, one socket for the whole session, sub-views by phase):
  - **Lobby** — code, live player grid, "waiting for host".
  - **Question** — countdown ring, four Kahoot-grammar candy tiles, haptics, "locked in".
  - **Reveal** — correct/wrong verdict, points delta, live leaderboard with your row pinned.
  - **Settling** — "paying out winners…" coin spinner.
  - **Results (money moment)** — podium, coin count-up of your USDC, confetti, **on-chain receipt**
    (tap → Solana Explorer), share card.
  - **Error / reconnect** — friendly offline card + auto-reconnect banner.
- **Wallet** — devnet SOL balance (live RPC), lifetime winnings, receive address QR + copy, faucet.
- **History** — every finished game (persisted), rank/score/winnings, tx link; empty state.
- **Profile / Settings** — avatar, editable name, stats, sound + haptics toggles, about.
- **Store readiness** — branded adaptive app icon + seamless native splash, a11y (Semantics,
  ≥48px targets), reduced-motion support.

## Architecture

MVVM + repository, matching the official Flutter app-architecture guidance.

```
UI (screens/, widgets/)  ──watch──▶  Riverpod providers
                                       │
   data/game_controller.dart  ◀── ViewModel: Notifier<GameState>; maps every relayed
                                       │   message to immutable state; owns reconnect
   services/gateway_service.dart  ◀── transport: web_socket_channel over the JSON gateway
                                       │
   data/ (wallet, prefs, history, balance, models)  ◀── repositories / stores
```

- **State**: Riverpod 2 (`Notifier`/`AsyncNotifier`). **Nav**: go_router with a `StatefulShellRoute`
  bottom-nav shell. **Motion**: flutter_animate. **Wallet**: `solana` (throtl-proven) + secure storage.
- **Transport**: the app never speaks Colyseus. `services/realtime/src/gateway.ts` bridges each phone
  to the authoritative room as plain JSON over WS (port 2568). `data/models.dart` mirrors that wire
  contract exactly.
- The game account is never delegated to the ER, so payout is never hostage to rollup timing.

## Run

```bash
flutter pub get
flutter run                       # iOS simulator shares the Mac's network → localhost gateway works
```

Physical device (point at your Mac's LAN IP):

```bash
flutter run --dart-define=QUIVO_GATEWAY=ws://192.168.x.x:2568
```

## Live end-to-end demo

```bash
# terminal 1 — realtime server (+ JSON gateway on :2568). No keypair ⇒ stub chain = instant settle.
cd services/realtime && PORT=2567 pnpm start
# for real devnet payouts instead: QUIVO_KEYPAIR=/path/to/id.json PORT=2567 pnpm start

# terminal 2 — a host that seats 3 bots, prints ROOM_CODE, waits for the phone, then starts
pnpm --filter @quivo/realtime demo-host        # → ROOM_CODE=XXXX

# phone/sim — enter the code on the Join screen, or auto-join for testing:
cd apps/mobile && flutter run --dart-define=QUIVO_JOIN=XXXX
```

## Debug boot shortcuts (kDebugMode only, compile-time)

| define | effect |
|---|---|
| `QUIVO_PREVIEW=win\|lobby\|question\|correct\|…` | boot straight into a fabricated game phase (design QA) |
| `QUIVO_ROUTE=/wallet\|/history\|/profile` | boot straight to a tab (bypasses onboarding) |
| `QUIVO_SEED=true` | seed sample match history for the Wallet/History/Profile tabs |
| `QUIVO_JOIN=CODE` | auto-join a real room on boot (live testing) |

The interactive phase harness is also reachable in debug builds by long-pressing the home avatar.
