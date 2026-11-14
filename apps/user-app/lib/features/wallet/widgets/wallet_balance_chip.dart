import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/wallet_provider.dart';
import '../screens/wallet_screen.dart';

class WalletBalanceChip extends ConsumerWidget {
  const WalletBalanceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletStateProvider);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const WalletScreen()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.midnightCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.goldAccent.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 16,
              color: AppTheme.goldAccent,
            ),
            const SizedBox(width: 6),
            Text(
              '₹${wallet.balanceInRupees.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                color: AppTheme.goldLight,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.add_circle,
              size: 14,
              color: AppTheme.goldAccent,
            ),
          ],
        ),
      ),
    );
  }
}
