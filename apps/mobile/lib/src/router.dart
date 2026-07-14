import 'package:go_router/go_router.dart';
import 'screens/splash_gate.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/join_screen.dart';
import 'screens/play_screen.dart';
import 'screens/preview_screen.dart';
import 'screens/shell/app_shell.dart';
import 'screens/tabs/wallet_screen.dart';
import 'screens/tabs/history_screen.dart';
import 'screens/tabs/profile_screen.dart';

/// App router. Three primary tabs live behind a StatefulShellRoute (Home / Wallet / History);
/// profile is a full-screen route pushed from the home avatar, and the live session (/play), join,
/// onboarding, splash and the debug preview are full-screen routes above the shell too.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (c, s) => const SplashGate()),
    GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
    GoRoute(path: '/join', builder: (c, s) => const JoinScreen()),
    GoRoute(path: '/play', builder: (c, s) => const PlayScreen()),
    GoRoute(path: '/preview', builder: (c, s) => const PreviewScreen()),
    GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
    StatefulShellRoute.indexedStack(
      builder: (c, s, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (c, s) => const HomeScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/wallet', builder: (c, s) => const WalletScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/history', builder: (c, s) => const HistoryScreen())]),
      ],
    ),
  ],
);
