# Build context is the MONOREPO ROOT (so the workspace + @quivo/protocol resolve).
# In Railway: set the service's Dockerfile path to services/realtime/Dockerfile and root to repo root.
FROM node:24-slim

RUN corepack enable
WORKDIR /app

# Install with the workspace graph so @quivo/protocol links.
COPY pnpm-workspace.yaml package.json turbo.json ./
COPY pnpm-lock.yaml* ./
COPY packages/protocol/package.json packages/protocol/package.json
COPY services/realtime/package.json services/realtime/package.json
RUN pnpm install --frozen-lockfile || pnpm install

# Source
COPY packages/protocol packages/protocol
COPY services/realtime services/realtime

ENV NODE_ENV=production
EXPOSE 2567
# Runtime is tsx (transpile-on-run) — no separate build step, protocol is consumed as source.
CMD ["pnpm", "--filter", "@quivo/realtime", "start"]
