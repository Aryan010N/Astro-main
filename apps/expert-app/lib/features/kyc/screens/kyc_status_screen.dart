import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_shared/flutter_shared.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/expert_profile_model.dart';
import '../providers/kyc_provider.dart';
import 'kyc_form_screen.dart';

class KycStatusScreen extends ConsumerStatefulWidget {
  final ExpertProfileModel profile;

  const KycStatusScreen({super.key, required this.profile});

  @override
  ConsumerState<KycStatusScreen> createState() => _KycStatusScreenState();
}

class _KycStatusScreenState extends ConsumerState<KycStatusScreen> {
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _isOnline = widget.profile.isLive;
  }

  @override
  Widget build(BuildContext context) {
    final kycState = ref.watch(kycStateProvider);
    final profile = kycState.profile ?? widget.profile;

    return Scaffold(
      backgroundColor: AppTheme.midnightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.midnightSurface,
        elevation: 0,
        title: Text(
          profile.isApproved
              ? 'Astrologer Dashboard'
              : 'Application Status',
          style: GoogleFonts.lora(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Status',
            icon: kycState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.goldAccent,
                    ),
                  )
                : const Icon(Icons.refresh, color: AppTheme.goldAccent, size: 22),
            onPressed: () => ref.read(kycStateProvider.notifier).fetchProfile(),
          ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout, color: AppTheme.textMuted, size: 20),
            onPressed: () => ref.read(expertAuthStateProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: profile.isApproved
                  ? _buildApprovedDashboard(context, profile)
                  : profile.isPending
                      ? _buildPendingView(context, profile)
                      : _buildRejectedView(context, profile),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. APPROVED / LIVE DASHBOARD
  // ==========================================
  Widget _buildApprovedDashboard(BuildContext context, ExpertProfileModel profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Verified Badge Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.midnightCard,
                AppTheme.midnightSurface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified,
                  color: AppTheme.success,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            style: GoogleFonts.lora(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'APPROVED',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.experienceYears} Years Exp • ${profile.languages.join(", ")}',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Live Toggle Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.midnightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.midnightBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isOnline ? AppTheme.success : AppTheme.textMuted,
                  boxShadow: _isOnline
                      ? [
                          BoxShadow(
                            color: AppTheme.success.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isOnline ? 'Online • Accepting Consultations' : 'Offline',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: _isOnline ? AppTheme.textPrimary : AppTheme.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _isOnline
                          ? 'Seekers can see you in search and request chats/calls'
                          : 'You will not receive incoming consultation requests',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isOnline,
                activeColor: AppTheme.goldAccent,
                activeTrackColor: AppTheme.goldAccent.withValues(alpha: 0.3),
                inactiveThumbColor: AppTheme.textMuted,
                inactiveTrackColor: AppTheme.midnightCard,
                onChanged: (val) {
                  setState(() => _isOnline = val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val ? 'You are now Online!' : 'You are now Offline',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Rates Breakdown Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.midnightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.midnightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active Consultation Rates',
                style: GoogleFonts.lora(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.goldLight,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildRateTile('Chat', '₹${profile.chatRateInRupees}/min', Icons.chat_bubble_outline),
                  const SizedBox(width: 12),
                  _buildRateTile('Audio Call', '₹${profile.callRateInRupees}/min', Icons.phone_outlined),
                  const SizedBox(width: 12),
                  _buildRateTile('Video Call', '₹${profile.videoRateInRupees}/min', Icons.videocam_outlined),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Payout Info Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.midnightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.midnightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payout & Verification Dossier',
                style: GoogleFonts.lora(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.goldLight,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow('UPI ID', profile.payoutUpiId),
              _buildInfoRow('ID Document', '${profile.idProofType} (${profile.idProofNumber})'),
              _buildInfoRow('Specialties', profile.expertise.join(', ')),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2. PENDING VIEW
  // ==========================================
  Widget _buildPendingView(BuildContext context, ExpertProfileModel profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.warning.withValues(alpha: 0.15),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: AppTheme.warning,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Application Under Review',
          style: GoogleFonts.lora(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Your KYC application for ${profile.name} has been received and is in the review queue.',
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        // Dossier Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.midnightSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.midnightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submitted Credentials',
                style: GoogleFonts.lora(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.goldLight,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow('Applicant Name', profile.name),
              _buildInfoRow('Experience', '${profile.experienceYears} Years'),
              _buildInfoRow('Languages', profile.languages.join(', ')),
              _buildInfoRow('Expertise', profile.expertise.join(', ')),
              _buildInfoRow('ID Type', profile.idProofType),
              _buildInfoRow('ID Number', profile.idProofNumber),
              _buildInfoRow('Payout UPI', profile.payoutUpiId),
              _buildInfoRow(
                'Proposed Rates',
                'Chat ₹${profile.chatRateInRupees}/min • Call ₹${profile.callRateInRupees}/min • Video ₹${profile.videoRateInRupees}/min',
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Action Buttons
        ElevatedButton.icon(
          onPressed: () => ref.read(kycStateProvider.notifier).fetchProfile(),
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text('Check Approval Status'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => KycFormScreen(existingProfile: profile),
              ),
            );
          },
          child: Text(
            'Edit Application Details',
            style: GoogleFonts.inter(
              color: AppTheme.goldLight,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. REJECTED VIEW
  // ==========================================
  Widget _buildRejectedView(BuildContext context, ExpertProfileModel profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.error.withValues(alpha: 0.15),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(
              Icons.cancel_outlined,
              color: AppTheme.error,
              size: 40,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Application Needs Revision',
          style: GoogleFonts.lora(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Reason box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feedback from Admin Review Team:',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.error,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                profile.rejectionReason ?? 'Credentials or documents could not be verified.',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => KycFormScreen(existingProfile: profile),
              ),
            );
          },
          icon: const Icon(Icons.edit_document, size: 20),
          label: const Text('Update & Re-submit KYC'),
        ),
      ],
    );
  }

  Widget _buildRateTile(String label, String rate, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.midnightCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.midnightBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.goldAccent, size: 20),
            const SizedBox(height: 8),
            Text(
              rate,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AppTheme.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
