/**
 * Quivo "Floodlight" design tokens - see docs/DESIGN.md.
 * One primary color (violet), no gradients as brand decisions, no shadows, squircle corners.
 * Single source of truth for both pages (stage + player-web).
 */
import type { CSSProperties } from "react";

export const T = {
  ink: "#17122a",
  body: "#2a2140",
  muted: "#938da8",
  ground: "linear-gradient(180deg,#ffffff 0%,#f6f1fe 100%)",
  card: "#ffffff",
  cardTint: "#f3eeff",
  cardWash: "linear-gradient(180deg,#faf7ff 0%,#f3eeff 100%)",

  // the dark "ink" surface - host cards, verdict cards, wallet balance, sticky nav
  night: "#120f1c",
  nightGrad: "#120f1c",

  // THE one primary color. A second (magenta) exists for sparing, single-color accent use only
  // (e.g. one trait chip) - never paired with primary as a gradient.
  primary: "#7c3aed",
  primaryText: "#7c3aed",
  primaryDeep: "#7c3aed",
  magenta: "#e93d82",
  primaryGrad: "#7c3aed",

  winPurple: "#7c3aed",
  winLime: "#22c55e",
  winLimeGrad: "#22c55e",
  coin: "#f2951f",
  coinShadow: "none",

  danger: "#f43f5e",
  amber: "#f59e0b",
  amberPale: "#fef3c7",
  info: "#3b82f6",
  infoPale: "#dbeafe",

  // No shadows anywhere - kept as no-ops so existing call sites don't need touching.
  shadowCard: "none",
  shadowFloat: "none",
  shadowFrame: "none",
  shadowBtn: (_rgb = "124,58,237") => "none",

  rCard: 24,
  rBig: 28,
  rPill: 999,
} as const;

/** No-op - the old glow-blob effect (a radial-gradient "shadow") is retired along with shadows and
 * gradients. Kept so call sites can stay as-is; it resolves to a transparent fill. */
export function glowBlob(_hex: string, _alpha = 0.32): string {
  return "transparent";
}

/** Superellipse ("squircle") corners via the CSS `corner-shape` property - Chromium 139+, and a
 * pure progressive enhancement: unsupported browsers just see the plain `border-radius` underneath,
 * never a broken shape. See docs/DESIGN.md. Spread into any inline style object. */
export function squircle(radius: number): CSSProperties {
  return { borderRadius: radius, ["cornerShape" as never]: "squircle" } as CSSProperties;
}

/** The four answer colors - the shared vocabulary between stage and phones (Kahoot grammar). Each
 * is ONE solid color; `.grad` degenerates to the same color at both stops for old call sites. */
export const ANSWERS = [
  { key: "A", glyph: "▲", solid: "#f43f5e", grad: "#f43f5e", rgb: "244,63,94" },
  { key: "B", glyph: "◆", solid: "#3b82f6", grad: "#3b82f6", rgb: "59,130,246" },
  { key: "C", glyph: "●", solid: "#f59e0b", grad: "#f59e0b", rgb: "245,158,11" },
  { key: "D", glyph: "■", solid: "#22c55e", grad: "#22c55e", rgb: "34,197,94" },
] as const;

/** Deterministic identicon color for a wallet/name (avatars, player chips) - per-user color
 * variety is a data-visualization technique, not a brand gradient decision, so this intentionally
 * stays hue-varied rather than collapsing to the single primary color. */
export function playerHue(seed: string): string {
  let h = 0;
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) % 360;
  return `hsl(${h} 85% 55%)`;
}

export const springy = { type: "spring", stiffness: 380, damping: 26 } as const;
