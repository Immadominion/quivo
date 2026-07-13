import Marquee from "@/components/ui/marquee";

const ITEMS = [
  "REAL PRIZES ✦",
  "PAID ON-CHAIN ✦",
  "PROVABLY FAIR ✦",
  "MAGICBLOCK EPHEMERAL ROLLUPS ✦",
  "NO WALLET NEEDED ✦",
  "SOLANA DEVNET LIVE ✦",
];

export function Ticker() {
  return <Marquee items={ITEMS} />;
}
