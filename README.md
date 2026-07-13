# Quivo

**A live game show for crypto events.** The host runs it from a big screen; the room joins on their
phones by scanning a QR; everyone answers in real time; the winners are paid a real crypto prize
**on-chain, instantly, in front of the room** — provably fair.

Not "trivia with a token." The thing web2 tools (Kahoot) can't do: the prize is real, it settles to
the winners' wallets the second the game ends, and anyone can verify it wasn't rigged — powered by
Solana + MagicBlock's real-time Ephemeral Rollups.

> Built for **Solana Blitz v6** (MagicBlock · Solana Mobile). See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
> for the full system design — the on-chain/off-chain seam is the whole game.

**Live on devnet:** program [`BgUU6i94wtZrx215bGBRZePEDXTYC4snNrbDEymVcCVG`](https://explorer.solana.com/address/BgUU6i94wtZrx215bGBRZePEDXTYC4snNrbDEymVcCVG?cluster=devnet) — escrow · question commit-reveal · ER delegate/commit settle.

**Try it:** [usequivo.fun](https://usequivo.fun) (landing) · [app.usequivo.fun](https://app.usequivo.fun)
(host/stage view + web player, real devnet payouts) · **Watch it:** [demo video](https://youtu.be/oTDprAI4UXk)

## Monorepo layout

```
apps/
  mobile/      Flutter — the PLAYER app (scan → join → answer → get paid)
  landing/     Next.js — marketing landing page                          → Vercel (usequivo.fun)
  stage/       Next.js — the HOST big-screen presenter + web player      → Vercel (app.usequivo.fun)
services/
  realtime/    Node + Colyseus — authoritative game server + chain worker → Railway
onchain/
  programs/quivo/  Anchor + ephemeral-rollups-sdk — escrow · VRF · settle → Solana devnet
packages/
  protocol/    Shared TS — WS message schema, game state, scoring, constants
docs/
  ARCHITECTURE.md
```

## Prerequisites (all present on this machine)

`node 24` · `pnpm 10` · `anchor-cli 1.0.2` · `solana 3.1.10` · `rust 1.95` · `flutter 3.44` ·
`railway` · `vercel` · `gh`

## Quickstart

```bash
# JS/TS workspace (protocol, realtime, stage)
pnpm install
pnpm dev            # runs realtime server + stage in parallel (turbo)

# On-chain program
cd onchain && anchor build && anchor deploy --provider.cluster devnet

# Mobile player app
cd apps/mobile && flutter run
```

Copy `.env.example` → `.env` and fill it before running the realtime service.

## Deploy topology

| Package | Platform | Notes |
|---|---|---|
| `apps/landing` | **Vercel** (`quivo-landing`) | Root Directory = `apps/landing`, aliased to `usequivo.fun` |
| `apps/stage` | **Vercel** (`quivo-stage`) | Root Directory = `apps/stage`, aliased to `app.usequivo.fun` |
| `services/realtime` | **Railway** | long-running WS service; single-node (Redis optional for multi-instance) |
| `onchain` | **Solana devnet** | `anchor deploy`; MagicBlock ER resolved at runtime |
| `apps/mobile` | APK / TestFlight | Solana Mobile dApp Store-ready (stretch) |

Railway (not Vercel) hosts the game server because WebSocket rooms need a persistent process.
