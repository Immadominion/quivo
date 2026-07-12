import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/router.dart';
import 'src/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
  );
  runApp(const ProviderScope(child: QuivoApp()));
}

class QuivoApp extends StatelessWidget {
  const QuivoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Quivo',
      debugShowCheckedModeBanner: false,
      theme: buildQuivoTheme(),
      routerConfig: appRouter,
    );
  }
}
