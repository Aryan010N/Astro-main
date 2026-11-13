import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/phone_entry_screen.dart';
import 'features/home/screens/placeholder_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: AstroUserApp(),
    ),
  );
}

class AstroUserApp extends ConsumerWidget {
  const AstroUserApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Astro User App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _buildHome(authState),
    );
  }

  Widget _buildHome(AuthState authState) {
    if (authState.isLoading && authState.phoneNumber == null) {
      return const Scaffold(
        backgroundColor: AppTheme.midnightBackground,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.goldAccent,
          ),
        ),
      );
    }

    if (authState.isAuthenticated) {
      return const PlaceholderHomeScreen();
    }

    return const PhoneEntryScreen();
  }
}
