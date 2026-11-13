import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_shared/flutter_shared.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../../kyc/providers/kyc_provider.dart';

class ExpertOtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const ExpertOtpScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<ExpertOtpScreen> createState() => _ExpertOtpScreenState();
}

class _ExpertOtpScreenState extends ConsumerState<ExpertOtpScreen> {
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the full verification code'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final success =
        await ref.read(expertAuthStateProvider.notifier).verifyOtp(otp);
    if (mounted && success) {
      // Trigger profile fetch for the logged-in user
      await ref.read(kycStateProvider.notifier).fetchProfile();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _resend() async {
    final success = await ref
        .read(expertAuthStateProvider.notifier)
        .requestOtp(widget.phoneNumber);
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code resent!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(expertAuthStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.midnightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppTheme.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.midnightSurface,
                        border: Border.all(
                          color: AppTheme.goldAccent.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 32,
                        color: AppTheme.goldAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Verify Identity',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the verification code sent to\n${widget.phoneNumber}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.midnightSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.midnightBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'One-Time Password (OTP)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          style: GoogleFonts.inter(
                            color: AppTheme.goldAccent,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 8,
                          ),
                          decoration: const InputDecoration(
                            hintText: '••••••',
                            hintStyle: TextStyle(
                              letterSpacing: 8,
                              color: AppTheme.textMuted,
                            ),
                            counterText: '',
                          ),
                          onChanged: (val) {
                            if (val.trim().length == 6) {
                              _verify();
                            }
                          },
                          onSubmitted: (_) => _verify(),
                        ),

                        if (authState.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppTheme.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    authState.errorMessage!,
                                    style: GoogleFonts.inter(
                                      color: AppTheme.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: authState.isLoading ? null : _verify,
                          child: authState.isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppTheme.midnightBackground,
                                  ),
                                )
                              : Text(
                                  'Verify & Continue',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.midnightBackground,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),

                        Center(
                          child: TextButton(
                            onPressed: authState.isLoading ? null : _resend,
                            child: Text(
                              'Didn\'t receive code? Resend OTP',
                              style: GoogleFonts.inter(
                                color: AppTheme.goldLight,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
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
}
