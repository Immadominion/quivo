/**
 * Quivo "Candy Arcade" design tokens — see docs/DESIGN.md.
 * Derived from the Gaming Dashboard reference; single source of truth for both pages.
 */
export const T = {
  ink: "#161d33",
  body: "#1b2237",
  muted: "#8b94ac",
  ground: "linear-gradient(180deg,#aca5c6 0%,#9c94b8 100%)",
  card: "#ffffff",
  cardTint: "#e6effd",
  cardWash: "linear-gradient(180deg,#eef2fb 0%,#e6ecf8 100%)",
  primary: "#2f7df6",
  primaryText: "#2b6be4",
  primaryGrad: "linear-gradient(90deg,#2456d6,#2f7df6)",
  winPurple: "linear-gradient(155deg,#c25ff2 0%,#9430db 100%)",
  winLime: "#82b11d",
  winLimeGrad: "linear-gradient(155deg,#b6db4e 0%,#82b11d 100%)",
  coin: "radial-gradient(circle at 34% 28%,#ffcf7a,#f2951f 78%)",
  coinShadow:
    "inset 0 0 0 2.5px rgba(255,255,255,.5), inset 0 -2px 3px rgba(160,80,0,.4), 0 2px 4px rgba(200,110,10,.3)",

  shadowCard: "0 8px 20px rgba(48,35,90,.10)",
  shadowFloat: "0 16px 34px rgba(52,48,96,.12)",
  shadowFrame: "0 30px 70px rgba(35,25,75,.38)",
  shadowBtn: (rgb = "47,125,246") => `0 5px 12px rgba(${rgb},.4)`,

  rCard: 26,
  rBig: 34,
  rPill: 999,
} as const;

/** The four answer colors — the shared vocabulary between stage and phones (Kahoot grammar). */
export const ANSWERS = [
  { key: "A", glyph: "▲", solid: "#e5484d", grad: "linear-gradient(140deg,#f2588f,#d92d3f)", rgb: "229,72,77" },
  { key: "B", glyph: "◆", solid: "#2f7df6", grad: "linear-gradient(140deg,#4aa8f0,#1f4fd6)", rgb: "47,125,246" },
  { key: "C", glyph: "●", solid: "#eda13d", grad: "linear-gradient(140deg,#f8b64c,#e8681e)", rgb: "237,161,61" },
  { key: "D", glyph: "■", solid: "#3fa14e", grad: "linear-gradient(140deg,#8de06a,#2f9e44)", rgb: "63,161,78" },
] as const;

/** Deterministic candy gradient for a wallet/name (avatars, player chips). */
export function playerHue(seed: string): string {
  let h = 0;
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) % 360;
  return `linear-gradient(140deg, hsl(${h} 85% 62%), hsl(${(h + 40) % 360} 75% 45%))`;
}

export const springy = { type: "spring", stiffness: 380, damping: 26 } as const;
