/**
 * Quivo realtime server — Colyseus authoritative game server.
 *
 * Hosts the `quivo` game room (see rooms/GameRoom.ts). When REDIS_URL is set it uses the Redis
 * driver + presence so rooms can scale across multiple nodes (Railway can run N replicas); without
 * it, it runs single-node (fine for local dev and a demo).
 */
import { Server } from "colyseus";
import { RedisDriver } from "@colyseus/redis-driver";
import { RedisPresence } from "@colyseus/redis-presence";
import { GameRoom } from "./rooms/GameRoom";
import { makeChainWorker } from "./chain/worker";
import { startMobileGateway } from "./gateway";

const port = Number(process.env.PORT ?? 2567);
const mobilePort = Number(process.env.MOBILE_GATEWAY_PORT ?? port + 1);
const redisUrl = process.env.REDIS_URL;

if (process.env.QUIVO_SERVICE === "mobile-gateway") {
  const colyseusEndpoint = process.env.COLYSEUS_ENDPOINT ?? "ws://localhost:2567";
  startMobileGateway({ port, colyseusEndpoint });
  console.log(`[quivo] native gateway listening on :${port} → ${colyseusEndpoint}`);
} else {
  const server = new Server(
    redisUrl
      ? { driver: new RedisDriver(redisUrl), presence: new RedisPresence(redisUrl) }
      : {},
  );

  // One shared chain worker (holds the relayer key; drives escrow + settlement) injected into rooms.
  const chain = makeChainWorker();
  server.define("quivo", GameRoom, { chain });

  server
    .listen(port)
    .then(() => {
      console.log(`[quivo] realtime listening on :${port}${redisUrl ? " (redis-scaled)" : " (single-node)"}`);
      startMobileGateway({ port: mobilePort, colyseusEndpoint: `ws://localhost:${port}` });
    })
    .catch((err) => {
      console.error("[quivo] failed to start:", err);
      process.exit(1);
    });
}
