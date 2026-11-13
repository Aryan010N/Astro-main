import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_shared/flutter_shared.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/expert_phone_screen.dart';
import 'features/kyc/providers/kyc_provider.dart';
import 'features/kyc/screens/kyc_form_screen.dart';
import 'features/kyc/screens/kyc_status_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: AstroExpertApp(),
    ),
  );
}

class AstroExpertApp extends ConsumerWidget {
  const AstroExpertApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(expertAuthStateProvider);
    final kycState = ref.watch(kycStateProvider);

    return MaterialApp(
      title: 'Astro Expert App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _buildHome(ref, authState, kycState),
    );
  }

  Widget _buildHome(WidgetRef ref, ExpertAuthState authState, KycState kycState) {
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

    if (!authState.isAuthenticated) {
      return const ExpertPhoneScreen();
    }

    // User is authenticated. Fetch profile if not loaded yet
    if (kycState.profile == null && !kycState.isLoading && kycState.errorMessage == null) {
      Future.microtask(() {
        ref.read(kycStateProvider.notifier).fetchProfile();
      });
    }

    if (kycState.isLoading && kycState.profile == null) {
      return const Scaffold(
        backgroundColor: AppTheme.midnightBackground,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.goldAccent,
          ),
        ),
      );
    }

    if (kycState.profile != null) {
      return KycStatusScreen(profile: kycState.profile!);
    }

    // No profile created yet -> show KYC submission form
    return const KycFormScreen();
  }
}
