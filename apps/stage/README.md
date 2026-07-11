# @quivo/stage — host / big-screen presenter (+ landing)

Next.js app deployed on **Vercel**. Two jobs:

1. **Stage / presenter** — what the projector shows during a game: the join QR + code, the current
   question, the countdown, the live leaderboard, and the **payout reveal** (winners credited on-chain).
2. **Landing** — the marketing page ("run a live game show at your event, winners paid on-chain").

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
