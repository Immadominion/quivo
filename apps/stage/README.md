# @quivo/stage — host / big-screen presenter + web player

Next.js app deployed on **Vercel** at `app.usequivo.fun`. Two jobs:

1. **Stage / presenter** (`/`) — what the projector shows during a game: the join QR + code, the
   current question, the countdown, the live leaderboard, and the **payout reveal** (winners
   credited on-chain).
2. **Player** (`/play`) — the phone view for anyone joining without the Flutter app: an ephemeral
   Solana wallet minted silently, answer tiles, the payout money-moment.

The marketing landing page lives separately in [`@quivo/landing`](../landing) at `usequivo.fun`.

Talks to the realtime server (Railway) with the **Colyseus JS client** (`colyseus.js`), consuming the
same message shapes as [`@quivo/protocol`](../../packages/protocol/src/index.ts).

### To scaffold
```bash
cd apps/stage
pnpm create next-app@latest . --ts --app --tailwind --eslint --no-src-dir --import-alias "@/*"
pnpm add colyseus.js @quivo/protocol qrcode.react
```
Then set `NEXT_PUBLIC_REALTIME_URL` and build the presenter route + the join QR.

### Deploy (Vercel)
Root Directory = `apps/stage`. `vercel.json` pins the framework. `NEXT_PUBLIC_*` env only.
