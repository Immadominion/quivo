import 'package:go_router/go_router.dart';
import 'screens/splash_gate.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/join_screen.dart';
import 'screens/play_screen.dart';
import 'screens/preview_screen.dart';
import 'screens/shell/app_shell.dart';
import 'screens/tabs/history_screen.dart';
import 'screens/tabs/profile_screen.dart';

/// App router. The shell has two durable sections (Home, Profile) flanking the raised QR join
/// action. History is a pushed detail screen, and Receive is a contextual bottom sheet from Home.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (c, s) => const SplashGate()),
    GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
    GoRoute(path: '/join', builder: (c, s) => const JoinScreen()),
    GoRoute(path: '/play', builder: (c, s) => const PlayScreen()),
    GoRoute(path: '/preview', builder: (c, s) => const PreviewScreen()),
    GoRoute(path: '/history', builder: (c, s) => const HistoryScreen()),
    GoRoute(path: '/wallet', redirect: (c, s) => '/profile'),
    StatefulShellRoute.indexedStack(
      builder: (c, s, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
          ],
        ),
      ],
    ),
  ],
);
