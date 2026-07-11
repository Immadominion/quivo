# @quivo/mobile — the player app (Flutter)

The player experience: **scan the QR → you're in (no signup) → answer live → get paid on-chain.**

## Flow
1. **Scan** the host's QR (`mobile_scanner`) → deep-links into a game by join code.
2. **Identity** — mint an ephemeral Solana keypair on first open (`flutter_secure_storage`); the
   server's relayer sponsors gas and a session key signs answers with no popup. (Optional: link a real
   wallet via Mobile Wallet Adapter later.)
3. **Play** — lobby → questions (tap an option, big and fast) → per-question reveal → live leaderboard.
4. **Win** — podium; the prize lands in *your* wallet on-chain, with a receipt. That's the moment.

## Open decision — realtime transport
Colyseus (the game server) doesn't speak plain JSON on the wire. Two clean options:
- **A. JSON-over-WS gateway (leaning this):** `services/realtime` exposes a thin player gateway that
  forwards `join`/`answer` to the room and streams room events as JSON. Dart uses `web_socket_channel`
  directly — dead simple, rock-solid for the demo.
- **B. Colyseus Dart client:** speak the Colyseus protocol from Dart (community client or a thin impl).
  More "native" to Colyseus, more risk.

Both keep the message shapes from [`@quivo/protocol`](../../packages/protocol/src/index.ts).

## Scaffold
Platform folders (`android/`, `ios/`) aren't committed yet. Generate them in place:
```bash
cd apps/mobile
flutter create . --project-name quivo --org fun.quivo --platforms=android,ios
flutter pub get
flutter run
```
