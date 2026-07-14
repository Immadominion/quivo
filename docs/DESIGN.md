# Quivo Design System - "Floodlight"

> Derived from the user's claude.ai/design project `f12a62f7` ("Mature gamified app design") -
> specifically **The Touchline / The Gaffer** (a football-manager prediction app: `The Touchline.dc.html`,
> `The Touchline - Web.dc.html`, `The Gaffer App.dc.html`, `The Gaffer - Web App.dc.html`, `Landing.dc.html`).
> We take its **structural/gamification DNA** - persona-commentary cards, podium leaderboards,
> streak/form indicators, bias chips, memory timelines, verdict/share cards, mono-for-numbers
> typography, dark floating nav - and reskin it entirely: ONE flat primary color (no gradients, no
> shadows, squircle corners) instead of the reference's muted sage/forest palette and shadow-heavy
> depth, and content rebuilt for Quivo (a live trivia game show), not football betting. Nothing is
> copied word-for-word.

**v2 update:** the first pass of this system used a two-tone violet-to-magenta gradient, drop
shadows on every card/button, and a radial "glow blob" signature on dark cards. All three are
retired per direct feedback - see §5. The violet stays as the one primary color; everything that
used to be a gradient or a glow is now a flat fill, and depth comes from color/spacing alone.

## 0. The bridge: Touchline -> Floodlight

*Touchline* = the sideline you watch a match from. *Floodlight* = the stage lights of a live show.
Same sports-venue lineage, but ours points at Quivo's actual product: a crowd under stage lights,
answering fast, watched by a host who hypes (not roasts) them.

| Reference concept | Quivo equivalent |
|---|---|
| The Gaffer (AI manager, roasts you) | **Q**, the host persona - hypes, teases, never mean |
| Manager's Pot | The game's live prize pot (already exists) |
| Squad Ladder | Leaderboard (already exists) - restyled as a podium widget |
| Make a call (predict + stake) | Answer a question (already exists) - same visual grammar: badge overline, N-choice buttons, warning/hype callout, big CTA |
| The Verdict (share card) | Results share card (already exists) - restyled: dark flat card, stat trio |
| My Dossier (memory + bias chips + timeline) | Profile - derived client-side from match history already persisted, no new backend |
| Wallet | Wallet (already exists) - restyled: dark flat balance card, activity list |

## 1. Foundations

### Typography
- **Clash Display** 600/700 - headlines, section titles, big numbers-as-headline. Tight tracking
  (-0.02em on large sizes).
- **Satoshi** 400/500/700/900 - all UI/body/buttons. Sentence case, never uppercase paragraphs.
- **JetBrains Mono** 500/700 - **numbers only**: scores, timers, WAL/USDC amounts, wallet addresses,
  tx hashes, countdowns. Never use the display or body face for a number that updates or that the
  player compares at a glance - mono keeps digits from jittering in width.
- ALL-CAPS micro-labels (11-12px, 600-700 weight, +0.6-1.2px letter-spacing) for overlines and stat
  labels only - never for headlines or body copy.
- Fonts self-hosted (not CDN-linked at runtime): Clash Display + Satoshi `.woff2`/Flutter `.ttf`
  bundled locally (Fontshare license permits embedding); JetBrains Mono via `next/font/google` (web)
  / `google_fonts` (mobile).
- **No em dashes anywhere** - in copy, code comments, or docs. Use a comma, period, or a plain
  hyphen with spaces instead.

### Icons
- **Fluent System Icons** (`fluentui_system_icons` on pub.dev, Microsoft's official, verified-publisher
  Flutter port) - not Material Icons. Use the `_24_regular` weight by default, `_24_filled` for an
  active/selected state. Emoji stays fine as in-content flavor (a crown on #1, a coin), never as a
  UI chrome icon.
- Web keeps Phosphor Icons (already CDN-linked in the stage/player pages; unaffected by the mobile
  icon-pack change).

### Palette
One primary color. A second (magenta) exists only for sparing, single-element accent use (e.g. one
trait chip) - it is never paired with primary as a gradient, and no other two-color gradients exist
anywhere in the app.

| Token | Value | Use |
|---|---|---|
| `ink` (text) | `#17122A` | headings/body text on light |
| `night` (surface) | `#120F1C` | flat dark "host/money" surface (host card, nav, verdict card, wallet balance) - solid, no gradient partner |
| `ground` | `#FFFFFF -> #F6F1FE` | light canvas - bright, barely-violet-warm white |
| `card` | `#FFFFFF` | primary surface, no borders |
| `cardTint` | `#F3EEFF` | soft violet fill (highlighted rows, "you" row) |
| `line` | `#EBE6F5` | hairline dividers only |
| `primary` (the one color) | `#7C3AED` | CTAs, active nav, rating trend, links, focus rings - flat, never gradient |
| `magenta` (sparing secondary) | `#E93D82` | one-off accent only (e.g. a single trait chip) |
| `gold` (win/coin - kept from Quivo's existing coin motif) | `#F2951F` | pot, payouts, trophy, crown, #1 podium - flat, no gradient |
| `green` (correct/positive) | `#22C55E` / pale `#DCFCE7` | correct answers, wins, positive deltas |
| `red` (wrong/negative) | `#F43F5E` / pale `#FFE4E8` | wrong answers, losses |
| `amber` (pending/time) | `#F59E0B` / pale `#FEF3C7` | countdowns, "open" states |
| `blue` (locked/info) | `#3B82F6` / pale `#DBEAFE` | locked badges, info chips |

**Candy answer colors** (Kahoot grammar, kept, each a flat single fill - no gradient):
`▲` red `#F43F5E` . `◆` blue `#3B82F6` . `●` amber `#F59E0B` . `■` green `#22C55E`

**Exception - player identicons:** deterministic per-player avatar colors (derived from a hash of
wallet/name) intentionally stay hue-varied rather than collapsing to the one primary color. This is
a data-visualization technique for telling players apart at a glance, not a branding decision, so
it sits outside the "one primary color" rule.

### Shape & elevation
- **Squircle corners everywhere practical** - a true superellipse ("continuous corner") shape, not
  CSS/Flutter's default circular-arc rounded rect. Mobile: `figma_squircle`'s `SmoothRectangleBorder`
  / `SmoothBorderRadius` via `QC.squircle(radius)`, used as a `ShapeDecoration(shape: ...)` instead of
  `BoxDecoration(borderRadius: BorderRadius.circular(...))`. Web: the CSS `corner-shape: squircle`
  property (Chromium 139+) paired with the existing `border-radius` - pure progressive enhancement,
  degrades to a normal rounded rect on Safari/Firefox with zero risk. True circles (avatars, status
  dots) stay circles - squircle only applies to rounded-rect corners.
- Radii: cards 22-26px, hero/sheet cards 26-30px, tiles 16-18px, buttons/chips/avatars full pill
  (still circular at 999px - a pill has no "corner" for a squircle to smooth).
- **Neobrutalist border + hard shadow, everywhere** (v3, matches the `usequivo.fun` landing page) -
  every card, button, and floating surface gets a solid `ink`-colored 2px border plus a flat,
  no-blur offset shadow (`QC.shadowCard`/`shadowFloat`/`btnShadow` in `tokens.dart`; CSS
  `--shadow: Xpx Ypx 0px 0px var(--border)` on web). This replaces the old v2 "no shadows, no
  borders, depth from color alone" rule - kept deliberately restrained (one border weight, one
  shadow offset, no color/blur variation) rather than matching the landing's full halftone-dot /
  hard-tilt treatment, which stays landing-only.
- No radial "glow blob" effect (the v1 signature move) - retired along with gradients. Dark `night`
  cards are a flat solid fill.

## 2. Signature components (borrowed structure, Quivo content)

1. **Host card** - flat `night`-colored rounded (squircle) card, host avatar (placeholder slot, see
   §4) with a small live-status dot, `Q` label + "on Solana" trust chip, a hype line (short, punchy,
   never mean), pill CTA. Appears on Home and in the Lobby.
2. **Stat/rating card** - two-column headline stat (mono, with a trend arrow) + divider + streak row
   (last-5 results as colored squares, derived from local match history).
3. **Podium widget** - 3-column height-coded flat-color bars, crown on #1, avatar + name + score; the
   ranked list below highlights the player's own row with a flat `cardTint` fill.
4. **Section header + "See all"** - every list section gets a title + a small trailing link, never a
   title alone.
5. **Locked/countdown pill** - blue, lock glyph + remaining time, used anywhere a result is pending.
6. **Verdict/share card** - flat `night` card, big score, one-line host hype/consolation, 3-stat trio
   (RANK . PTS . STREAK), share + home actions.
7. **Bias/trait chips** - small pill tags summarizing a player's tendencies, computed client-side from
   history (e.g. "Fast fingers", "Comeback kid", "Category killer") - flavor, not new backend state.
8. **Memory timeline** - vertical dotted line, colored dot per entry, date + one-line note; used for a
   compact "recent form" feed on Profile, built from existing `HistoryEntry` data.
9. **Floating dark pill nav** (mobile) - flat `night`-colored bar; active item gets a flat `primary`
   pill fill. **Icon rail + avatar rail shell** (web) - left icon rail with a flat-primary active
   button, right "squad" rail of online player avatars.

## 3. Motion (choreography beats)
- Lobby: player chips pop in with spring scale (0.6->1, slight overshoot).
- Countdown: ring depletes; last 5s pulse scale + color shift toward `red`.
- Reveal: wrong tiles desaturate + shrink (opacity .4), correct tile springs with a white ring.
- Leaderboard: FLIP reorder, `+NNN` deltas fly up in `green`.
- Podium: pedestal rise 2-1-3 order, winner scale-in, coin burst / confetti on settlement.
- Springs throughout (stiffness ~350-400, damping ~26-30); no linear ease fades.

## 4. Asset placeholders - what to leave open for the user

The reference project ships real illustrated art (`gaffer.png`, cartoon avatars). Quivo doesn't have
its own host mascot yet, so every art slot below is built as a **procedural/CSS placeholder that
degrades gracefully and is trivially swappable** - never a hardcoded illustration:

- **Host avatar** (`HostAvatar` widget / component) - defaults to a flat-primary-colored disc with a
  simple mic/sound-wave glyph; accepts an optional image path/URL that replaces it entirely when the
  user supplies real host art.
- **Logo mark** - keeps the existing coin/Q mark already built for Quivo; no change needed.
- **Player avatars** - unchanged: deterministic solid-color discs with initials (already built,
  already good - see the identicon exception above).
- Any place a background photo/illustration would go (e.g. a landing-page hero) uses a flat
  primary-tinted wash instead, with a clearly named container the user can drop an image into later.

## 5. Anti-slop rules
1. The base canvas is bright and clean - never muted/grey/sage like the reference, never the old
   pastel-lavender field. Brightness lives in the `primary` accent, `gold`, and the candy colors -
   concentrated, not everywhere.
2. Numbers are always mono. If it updates or gets compared at a glance, it's `JetBrains Mono`.
3. **No gradients, anywhere, as a brand/UI decision.** One primary color; a second exists only for
   rare single-element accents. The only exception is per-player identicon color variety (data
   visualization, not branding).
4. **Every card/button/floating surface gets a 2px `ink` border + one flat, no-blur offset shadow**
   (v3, see §1) - one weight, one offset, no per-element variation.
5. (retired in v3 - see §1) cards now carry a border, matching the landing page.
6. **Squircle corners wherever a rounded rect appears** (see §1) - true circles stay circular.
7. Host commentary is short (1-2 sentences), hypes or teases - never actually mean, never emoji as a
   UI icon (Fluent icons for chrome; emoji is fine as in-content flavor, e.g. a crown on #1).
8. No new backend state for gamification flavor (bias chips, streak, timeline) - derive it from data
   already persisted (`HistoryEntry`, leaderboard rows) so this stays a design pass, not a feature
   buildout.
9. No em dashes, ever, in copy/comments/docs.
