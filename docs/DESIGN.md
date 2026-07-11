# Quivo Design System — "Candy Arcade"

> Derived from the user's Gaming Dashboard reference (claude.ai/design project `ff829890`,
> `Gaming Dashboard.dc.html`). We inherit its language — chunky Nunito, candy gradients, pill
> geometry, coin motifs, soft colored shadows on white cards over lavender — and adapt it for a
> LIVE GAME SHOW: the player phone stays close to the reference; the stage (projector) keeps the
> same family but turns up size, contrast, and drama.

## 1. Foundations

### Typography
- **Nunito** — weights 700 / 800 / 900 (via `next/font/google`, self-hosted at build).
- Everything bold: body 700, labels 800, numbers/display 900. No thin weights anywhere.
- Numbers always `font-variant-numeric: tabular-nums` (timers, scores, money).
- Stage scale (projector at ~4-8m viewing): question 56-72px, options 32-40px, leaderboard 24-28px,
  timer 80px+. Phone scale: question 17px, options 18-20px, score 22px.

### Palette (from the reference, hex-exact)
| Token | Hex | Use |
|---|---|---|
| `ink` | `#161d33` (heads) / `#1b2237` (body) | text on light |
| `muted` | `#8b94ac` | secondary text |
| `ground` | `#aca5c6 → #9c94b8` gradient | page/stage backdrop (lavender) |
| `card` | `#ffffff` | primary surface |
| `card-tint` | `#e6effd` | soft blue fill (list rows, tiles) |
| `card-wash` | `#eef2fb → #e6ecf8` | grouped card gradient |
| `primary` | `#2f7df6` (btn) / `#2b6be4` (text/links) | actions, active states |
| `answer-red` | `#e74c3c` → ref `#f2588f` family | option A |
| `answer-blue` | `#3d9bd9`/`#4aa8f0 → #1f4fd6` | option B |
| `answer-gold` | `#f3b93c`/`#f8b64c → #e8681e` | option C |
| `answer-green` | `#8de06a → #2f9e44` | option D |
| `win-purple` | `#c25ff2 → #9430db` | podium / level accents |
| `win-lime` | `#b6db4e → #82b11d` | success / streaks |
| `coin` | radial `#ffcf7a → #f2951f` + inner shine | money moments |

### Shape & depth
- Radii: cards 22-34px, phones/frames 44px, buttons & chips 999px (full pill), icon tiles 13-16px.
- Shadows are **colored, soft, generous**: `0 8px 20px rgba(48,35,90,.10)` cards,
  `0 5px 12px rgba(47,125,246,.4)` on primary buttons (shadow matches fill), `0 30px 70px rgba(35,25,75,.38)` frames.
- Icon-in-circle chips: 24px pastel circle + 13px glyph + 800-weight label, white pill.
- Sunburst rays (`repeating-conic-gradient` white @ ~16% alpha) inside hero/gradient cards.
- Coin: radial gold gradient, inner ring highlight (`inset 0 0 0 2.5px rgba(255,255,255,.5)`),
  bottom inner shadow. Used for pot, payouts, currency.

## 2. Stage (projector) adaptations
- Same lavender ground + white cards, but content scaled 2-3× and contrast pushed:
  ink on white only (no muted-on-tint for critical info), thick timer ring, huge answer tiles
  in the four candy colors with white 900-weight labels + shape glyphs (▲ ◆ ● ■) for color-blind.
- The four answer colors are THE shared vocabulary between stage and phones (Kahoot grammar).
- Money moments (pot, payout) always use the coin motif + gold; on-chain proof chips use `primary`.
- Live "⚡ anchored on-chain" ticker: small pill toasts sliding in, primary blue, monospace tx tail.

## 3. Player (phone) adaptations
- Direct reference application: white card world, pill inputs, gradient-ring avatar (identicon from
  wallet), big four-color answer tiles (min 110px tall, thumb-first, bottom-half of screen),
  "locked in" state, +points pop in win-lime, payout card with the coin and explorer link.
- Haptics via `navigator.vibrate` where available on answer tap / result / payout.

## 4. Motion (choreography beats)
- Lobby: player chips pop in with spring scale (0.6→1, slight overshoot); joined counter rolls.
- Countdown: ring depletes; last 3s pulse scale + color shift toward `answer-red`.
- Reveal: wrong options desaturate + shrink (0.25 opacity), correct one springs +6% with white ring.
- Leaderboard: FLIP reorder (animate row Y positions), `+NNN` deltas fly up in win-lime.
- Podium: 3-2-1 pedestal rise, winner card scale-in, then coin burst on "PAID ON-CHAIN" confirm.
- Payout (phone): coin drops in with bounce, amount counts up, explorer chip fades in.
- Everything springs (stiff ~300-400, damping ~24-30), never `ease-in-out` linear fades.

## 5. Audio (moments — final asset list pending deep-research)
lobby loop (light, building) · join pop · countdown tick (last 5s) + rising tension bed during the
question · answer lock click · reveal sting (correct fanfare / wrong thud) · leaderboard whoosh ·
podium fanfare · coin/payment chime on settlement. Autoplay: audio unlocks on the host's first
click (create/start) and on the player's join tap.

## 6. Anti-slop rules
1. Never cool-grey; the ground is warm lavender, surfaces white, tints blue-warm.
2. Shadows always tinted (purple/blue family), never plain black.
3. One display family (Nunito) — weight does the hierarchy, not new fonts.
4. Emojis allowed as *game* glyphs (🔥👑💸) per the reference — but never as UI icons for
   navigation/settings (SVG there).
5. Buttons are pills with matched-color shadows; no rectangles, no outlines-only primaries.
