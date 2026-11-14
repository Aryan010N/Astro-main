import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../models/session_model.dart';

class SessionSummaryDialog extends StatelessWidget {
  final SessionSummary summary;
  final VoidCallback onDismiss;

  const SessionSummaryDialog({
    super.key,
    required this.summary,
    required this.onDismiss,
  });

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.midnightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.goldAccent, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.goldAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: AppTheme.goldAccent,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Consultation Summary',
              textAlign: TextAlign.center,
              style: GoogleFonts.lora(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Session completed successfully',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.midnightBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.midnightBorder),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    label: 'Duration',
                    value: _formatDuration(summary.durationSeconds),
                    icon: Icons.timer_outlined,
                  ),
                  const Divider(height: 20, color: AppTheme.midnightBorder),
                  _buildSummaryRow(
                    label: 'Rate',
                    value: '₹${summary.ratePerMinuteRupees.toStringAsFixed(2)}/min',
                    icon: Icons.speed,
                  ),
                  const Divider(height: 20, color: AppTheme.midnightBorder),
                  _buildSummaryRow(
                    label: 'Total Deducted',
                    value: '₹${summary.totalBilledRupees.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet,
                    valueColor: AppTheme.goldAccent,
                    isBold: true,
                  ),
                  const Divider(height: 20, color: AppTheme.midnightBorder),
                  _buildSummaryRow(
                    label: 'Status',
                    value: summary.endReason.replaceAll('_', ' '),
                    icon: Icons.check_circle_outline,
                    valueColor: AppTheme.success,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.goldAccent,
                foregroundColor: AppTheme.midnightBackground,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onDismiss,
              child: Text(
                'Done',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
