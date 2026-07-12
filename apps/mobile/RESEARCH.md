# Quivo Mobile — Research Findings (validated deep-research, 2026)

Synthesis agent hit the API limit, but 105/106 agents completed. Verified, sourced findings that
directly shape the build:

## Architecture (official Flutter guidance)
- **MVVM + repository pattern.** Split into a **UI layer** (Views + ViewModels) and a **Data layer**
  (Repositories + Services); optional **Domain layer** only for complex logic. Views are "dumb" — no
  business logic, all render data comes from the ViewModel. [docs.flutter.dev/app-architecture]
- Our mapping: `screens/` = Views · Riverpod `Notifier`s = ViewModels · `data/` repositories
  (GameRepository over the WS gateway, WalletRepository, ChainRepository) · `services/` (WsService,
  SecureStore, SolanaRpc).

## Stack (all confirmed as 2026-recommended)
- **State: Riverpod** — "recommended default for new Flutter apps in 2026" (compile-safe, AsyncValue).
- **Nav: go_router** — Flutter Favorite, "preferred for 90% of apps"; **ShellRoute** for the bottom-nav
  shell (Home / Wallet / History / Profile as branches). [pub.dev/packages/go_router]
- **Animation: flutter_animate** — production-premium, 60-120fps chained (fadeIn/slideY/scale) for
  onboarding, list items, button feedback. **confetti 0.8.0** for the money moment. (Lottie/Rive
  optional; skip — no designer needed.)
- **Haptics: haptic_kit** (upgrade path) — semantic Haptics + custom Vibration + Core-Haptics patterns
  (intensity/sharpness 0–1) for celebration haptics, + ready widgets (HapticBounce, SlideToConfirm).
  We ship with built-in `HapticFeedback` + `vibration` now; haptic_kit is the It6 premium lift.

## Onboarding (top apps)
- **Sign-in-LESS** (we mint an ephemeral wallet silently — better than Cash App's phone auth).
- **Progressive disclosure** — Cash App collects across ~11 screens, not one form. Ask nothing up
  front; name is optional, permissions primed only when needed (camera at the QR step).

## Accessibility (hard numbers to hit)
- Tap targets **≥ 48×48 px** (our answer tiles ≫ that).
- Text/control contrast **≥ 4.5:1** vs background (except disabled).
- Must stay legible at large text-scale / display-scaling → respect `MediaQuery.textScaler`,
  and honor reduced-motion (`MediaQuery.disableAnimations`).

## Money moment / results (fintech + games)
- confetti burst + count-up amount + celebration haptics + a **share card** (screenshottable) — the
  Cash-App/Venmo "you got paid" pattern, adapted with our coin motif.
