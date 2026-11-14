import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/widgets/wallet_balance_chip.dart';

class PlaceholderHomeScreen extends ConsumerWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final phoneNumber = user?.phoneNumber ?? authState.phoneNumber ?? 'Unknown';

    return Scaffold(
      backgroundColor: AppTheme.midnightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.midnightSurface,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppTheme.goldAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              'Astro App',
              style: GoogleFonts.lora(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          const WalletBalanceChip(),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout, color: AppTheme.textSecondary),
            onPressed: () async {
              await ref.read(authStateProvider.notifier).signOut();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Verification Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Slice 1 Verified End-to-End',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.success,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Flutter ↔ NestJS ↔ Firebase ↔ Postgres ↔ Redis',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // User Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: AppTheme.midnightSurface,
                                child: const Icon(Icons.person, color: AppTheme.goldAccent, size: 30),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Logged in as',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppTheme.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      phoneNumber,
                                      style: GoogleFonts.lora(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.goldAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  user?.role ?? 'USER',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.goldAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32, color: AppTheme.midnightBorder),

                          _buildDetailRow(
                            icon: Icons.fingerprint,
                            label: 'User ID',
                            value: user?.id ?? '—',
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Wallet Balance',
                            value: user?.wallet != null
                                ? '₹${(int.tryParse(user!.wallet!.balanceInPaise) ?? 0) / 100} (${user.wallet!.balanceInPaise} paise)'
                                : '₹0.00',
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            icon: Icons.security,
                            label: 'Session Auth',
                            value: 'JWT Verified (Bearer token in secure storage)',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Next Phase Roadmap Card
                  Card(
                    color: AppTheme.midnightSurface,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.rocket_launch_outlined, color: AppTheme.goldAccent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Next Up: Phase 2 & 3',
                                style: GoogleFonts.lora(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '• User profile onboarding (DOB, Time & Place of birth)\n'
                            '• Expert listing & presence system (Redis + WebSocket)\n'
                            '• Wallet recharge ledger & payment gateway (Razorpay/Cashfree)',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  ElevatedButton.icon(
                    onPressed: () async {
                      await ref.read(authStateProvider.notifier).signOut();
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Log Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.midnightCard,
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.midnightBorder),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

