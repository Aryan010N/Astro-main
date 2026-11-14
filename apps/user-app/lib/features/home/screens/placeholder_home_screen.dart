import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallet/widgets/wallet_balance_chip.dart';
import '../../wallet/providers/wallet_provider.dart';
import '../../wallet/screens/wallet_screen.dart';
import '../../chat/providers/session_provider.dart';
import '../../chat/models/expert_presence_model.dart';
import '../../chat/screens/chat_screen.dart';

class PlaceholderHomeScreen extends ConsumerWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final sessionState = ref.watch(sessionProvider);
    final walletState = ref.watch(walletStateProvider);
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
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait<void>([
              ref.read(sessionProvider.notifier).fetchExperts(),
              ref.read(walletStateProvider.notifier).fetchBalance(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
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
                                'Phase 4: Real-time Consultations Live',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.success,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Redis Presence • Per-Second Billing Engine • Socket.io',
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
                  const SizedBox(height: 24),

                  // Astrologers Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Live Astrologers',
                        style: GoogleFonts.lora(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20, color: AppTheme.goldAccent),
                        onPressed: () {
                          ref.read(sessionProvider.notifier).fetchExperts();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (sessionState.isLoading && sessionState.experts.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: AppTheme.goldAccent),
                      ),
                    )
                  else if (sessionState.experts.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.midnightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.midnightBorder),
                      ),
                      child: Center(
                        child: Text(
                          'No approved astrologers currently online.\nCheck back soon!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: AppTheme.textMuted),
                        ),
                      ),
                    )
                  else
                    ...sessionState.experts.map((expert) => _buildExpertCard(context, ref, expert, walletState.balanceInRupees)),

                  const SizedBox(height: 24),

                  // User Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppTheme.midnightSurface,
                                child: const Icon(Icons.person, color: AppTheme.goldAccent, size: 26),
                              ),
                              const SizedBox(width: 14),
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
                                        fontSize: 18,
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
                          const Divider(height: 28, color: AppTheme.midnightBorder),

                          _buildDetailRow(
                            icon: Icons.fingerprint,
                            label: 'User ID',
                            value: user?.id ?? '—',
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Wallet Balance',
                            value: '₹${walletState.balanceInRupees.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 10),
                          _buildDetailRow(
                            icon: Icons.security,
                            label: 'Session Engine',
                            value: 'Secured via Redis Locks & Server Clock',
                          ),
                        ],
                      ),
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

  Widget _buildExpertCard(
    BuildContext context,
    WidgetRef ref,
    ExpertWithPresence expert,
    double userWalletRupees,
  ) {
    final isOnline = expert.presenceStatus == 'ONLINE';
    final isBusy = expert.presenceStatus == 'BUSY';
    final statusColor = isOnline
        ? AppTheme.success
        : (isBusy ? AppTheme.warning : AppTheme.textMuted);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.midnightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline ? AppTheme.goldAccent.withValues(alpha: 0.3) : AppTheme.midnightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppTheme.goldAccent.withValues(alpha: 0.15),
                      child: Text(
                        expert.name.isNotEmpty ? expert.name[0].toUpperCase() : 'A',
                        style: GoogleFonts.lora(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.goldAccent,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.midnightSurface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              expert.name,
                              style: GoogleFonts.lora(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.goldAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 12, color: AppTheme.goldAccent),
                                const SizedBox(width: 2),
                                Text(
                                  expert.rating.toStringAsFixed(1),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.goldAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${expert.experienceYears} yrs exp • ${expert.expertise.take(2).join(', ')}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.midnightBorder),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
                    ),
                    Text(
                      '₹${expert.chatRateInRupees.toStringAsFixed(2)}/min',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOnline ? AppTheme.goldAccent : AppTheme.midnightBackground,
                    foregroundColor: isOnline ? AppTheme.midnightBackground : AppTheme.textMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isOnline ? AppTheme.goldAccent : AppTheme.midnightBorder,
                      ),
                    ),
                  ),
                  icon: Icon(
                    isOnline ? Icons.chat : (isBusy ? Icons.hourglass_empty : Icons.do_not_disturb),
                    size: 16,
                  ),
                  label: Text(
                    isOnline ? 'Chat Now' : (isBusy ? 'Busy' : 'Offline'),
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: !isOnline
                      ? null
                      : () async {
                          // Check 1-minute minimum balance
                          if (userWalletRupees < expert.chatRateInRupees) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Minimum balance of ₹${expert.chatRateInRupees.toStringAsFixed(2)} required. Please recharge.',
                                ),
                                action: SnackBarAction(
                                  label: 'Recharge',
                                  textColor: AppTheme.goldAccent,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const WalletScreen()),
                                    );
                                  },
                                ),
                              ),
                            );
                            return;
                          }

                          // Request session
                          final success = await ref
                              .read(sessionProvider.notifier)
                              .requestSession(expert);

                          if (success && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(expertName: expert.name),
                              ),
                            );
                          }
                        },
                ),
              ],
            ),
          ],
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
