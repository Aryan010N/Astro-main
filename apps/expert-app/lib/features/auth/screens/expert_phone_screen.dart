import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_shared/flutter_shared.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import 'expert_otp_screen.dart';

class ExpertPhoneScreen extends ConsumerStatefulWidget {
  const ExpertPhoneScreen({super.key});

  @override
  ConsumerState<ExpertPhoneScreen> createState() => _ExpertPhoneScreenState();
}

class _ExpertPhoneScreenState extends ConsumerState<ExpertPhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final String _countryCode = '+91';

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() async {
    final rawNumber = _phoneController.text.trim();
    if (rawNumber.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final fullNumber = '$_countryCode$rawNumber';
    final success =
        await ref.read(expertAuthStateProvider.notifier).requestOtp(fullNumber);

    if (mounted && success) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ExpertOtpScreen(phoneNumber: fullNumber),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(expertAuthStateProvider);
    final is10Digits = _phoneController.text.trim().length == 10;

    return Scaffold(
      backgroundColor: AppTheme.midnightBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Emblem
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppTheme.goldAccent, AppTheme.goldLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.goldAccent.withValues(alpha: 0.35),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 44,
                        color: AppTheme.midnightBackground,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Header
                  Text(
                    'Astrologer Partner Portal',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join India\'s premier consultation network and guide thousands of seekers daily.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // Input Card
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
                          'Registered Mobile Number',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Phone Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.midnightCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.midnightBorder),
                              ),
                              child: Row(
                                children: [
                                  const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Text(
                                    _countryCode,
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '9876543210',
                                  counterText: '',
                                ),
                                onSubmitted: (_) => is10Digits ? _submit() : null,
                              ),
                            ),
                          ],
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

                        // Action Button
                        ElevatedButton(
                          onPressed: is10Digits && !authState.isLoading ? _submit : null,
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
                                  'Send OTP',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: is10Digits
                                        ? AppTheme.midnightBackground
                                        : AppTheme.textMuted,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 15,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Secure Astrologer Verification & Payout System',
                          style: GoogleFonts.inter(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
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
