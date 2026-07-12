import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';

/// App router. Screens are added per iteration (onboarding, join, play, results, wallet, …);
/// a ShellRoute bottom-nav shell (Home/Wallet/History/Profile) lands in It5.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
  ],
);
