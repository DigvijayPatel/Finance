import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/env.dart';
import 'core/providers.dart';
import 'features/auth/auth_screen.dart';
import 'features/shell/home_shell.dart';

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2563eb)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff5b8def),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Env.isConfigured ? const _AuthGate() : const _SetupScreen(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateProvider);
    final user = ref.watch(currentUserProvider);
    return user == null ? const AuthScreen() : const HomeShell();
  }
}

class _SetupScreen extends StatelessWidget {
  const _SetupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Supabase is not configured.\n\n'
            'Run the app with:\n'
            'flutter run \\\n'
            '  --dart-define=SUPABASE_URL=... \\\n'
            '  --dart-define=SUPABASE_ANON_KEY=...',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
