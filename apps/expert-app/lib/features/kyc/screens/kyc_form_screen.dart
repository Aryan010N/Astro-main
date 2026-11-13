import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_shared/flutter_shared.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/kyc_provider.dart';
import '../models/expert_profile_model.dart';

class KycFormScreen extends ConsumerStatefulWidget {
  final ExpertProfileModel? existingProfile;

  const KycFormScreen({super.key, this.existingProfile});

  @override
  ConsumerState<KycFormScreen> createState() => _KycFormScreenState();
}

class _KycFormScreenState extends ConsumerState<KycFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  late TextEditingController _expController;
  late TextEditingController _idNumberController;
  late TextEditingController _upiController;
  late TextEditingController _chatRateController;
  late TextEditingController _callRateController;
  late TextEditingController _videoRateController;

  String _selectedIdType = 'Aadhaar Card';
  final List<String> _selectedLanguages = ['Hindi', 'English'];
  final List<String> _selectedExpertise = ['Vedic Astrology', 'Kundli Matching'];

  final List<String> _availableLanguages = [
    'Hindi',
    'English',
    'Sanskrit',
    'Bengali',
    'Tamil',
    'Telugu',
    'Marathi',
    'Gujarati',
    'Kannada',
    'Punjabi',
  ];

  final List<String> _availableExpertise = [
    'Vedic Astrology',
    'Kundli Matching',
    'Numerology',
    'Tarot Reading',
    'Vastu Shastra',
    'Palmistry',
    'Prashna Kundli',
    'Gemology',
    'Lal Kitab',
    'Western Astrology',
  ];

  final List<String> _idProofTypes = [
    'Aadhaar Card',
    'PAN Card',
    'Passport',
    'Voter ID',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existingProfile;
    _nameController = TextEditingController(text: p?.name ?? '');
    _emailController = TextEditingController(text: p?.email ?? '');
    _bioController = TextEditingController(text: p?.bio ?? '');
    _expController = TextEditingController(
      text: p != null ? p.experienceYears.toString() : '5',
    );
    _idNumberController = TextEditingController(text: p?.idProofNumber ?? '');
    _upiController = TextEditingController(text: p?.payoutUpiId ?? '');
    _chatRateController = TextEditingController(
      text: p != null ? (p.chatRateInPaise ~/ 100).toString() : '25',
    );
    _callRateController = TextEditingController(
      text: p != null ? (p.callRateInPaise ~/ 100).toString() : '30',
    );
    _videoRateController = TextEditingController(
      text: p != null ? (p.videoRateInPaise ~/ 100).toString() : '50',
    );

    if (p != null) {
      if (p.idProofType.isNotEmpty) _selectedIdType = p.idProofType;
      if (p.languages.isNotEmpty) {
        _selectedLanguages.clear();
        _selectedLanguages.addAll(p.languages);
      }
      if (p.expertise.isNotEmpty) {
        _selectedExpertise.clear();
        _selectedExpertise.addAll(p.expertise);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _expController.dispose();
    _idNumberController.dispose();
    _upiController.dispose();
    _chatRateController.dispose();
    _callRateController.dispose();
    _videoRateController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one language'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (_selectedExpertise.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one astrological expertise'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final chatRateInRupees = int.tryParse(_chatRateController.text.trim()) ?? 0;
    final callRateInRupees = int.tryParse(_callRateController.text.trim()) ?? 0;
    final videoRateInRupees = int.tryParse(_videoRateController.text.trim()) ?? 0;

    final success = await ref.read(kycStateProvider.notifier).submitKyc(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          bio: _bioController.text.trim(),
          experienceYears: int.tryParse(_expController.text.trim()) ?? 0,
          languages: _selectedLanguages,
          expertise: _selectedExpertise,
          idProofType: _selectedIdType,
          idProofNumber: _idNumberController.text.trim(),
          payoutUpiId: _upiController.text.trim(),
          chatRateInPaise: chatRateInRupees * 100,
          callRateInPaise: callRateInRupees * 100,
          videoRateInPaise: videoRateInRupees * 100,
        );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('KYC Application Submitted Successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kycState = ref.watch(kycStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.midnightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.midnightSurface,
        elevation: 0,
        title: Text(
          'Expert KYC Verification',
          style: GoogleFonts.lora(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontSize: 18,
          ),
        ),
        actions: [
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner Notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.goldAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.goldAccent.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            color: AppTheme.goldAccent,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Astro Partner Onboarding',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.goldLight,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Please provide accurate legal details and credentials. All submissions undergo manual review by the compliance team before activation.',
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section 1: Personal Details
                    _buildSectionHeader('1. Personal & Professional Profile'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Legal Name *',
                      hint: 'e.g. Acharya Rajesh Sharma',
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'e.g. rajesh@astrology.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _expController,
                      label: 'Experience (Years) *',
                      hint: 'e.g. 10',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Experience is required';
                        final num = int.tryParse(val);
                        if (num == null || num < 0) return 'Enter valid years';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _bioController,
                      label: 'Professional Bio',
                      hint: 'Describe your lineage, background, and specializations...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 28),

                    // Section 2: Languages
                    _buildSectionHeader('2. Consultation Languages *'),
                    const SizedBox(height: 8),
                    Text(
                      'Select all languages in which you can consult seekers fluently:',
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableLanguages.map((lang) {
                        final isSelected = _selectedLanguages.contains(lang);
                        return FilterChip(
                          label: Text(lang),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedLanguages.add(lang);
                              } else {
                                _selectedLanguages.remove(lang);
                              }
                            });
                          },
                          backgroundColor: AppTheme.midnightSurface,
                          selectedColor: AppTheme.goldAccent.withValues(alpha: 0.25),
                          checkmarkColor: AppTheme.goldAccent,
                          labelStyle: GoogleFonts.inter(
                            color: isSelected ? AppTheme.goldLight : AppTheme.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppTheme.goldAccent : AppTheme.midnightBorder,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // Section 3: Astrological Expertise
                    _buildSectionHeader('3. Primary Areas of Expertise *'),
                    const SizedBox(height: 8),
                    Text(
                      'Select the domains you specialize in:',
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableExpertise.map((exp) {
                        final isSelected = _selectedExpertise.contains(exp);
                        return FilterChip(
                          label: Text(exp),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedExpertise.add(exp);
                              } else {
                                _selectedExpertise.remove(exp);
                              }
                            });
                          },
                          backgroundColor: AppTheme.midnightSurface,
                          selectedColor: AppTheme.goldAccent.withValues(alpha: 0.25),
                          checkmarkColor: AppTheme.goldAccent,
                          labelStyle: GoogleFonts.inter(
                            color: isSelected ? AppTheme.goldLight : AppTheme.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppTheme.goldAccent : AppTheme.midnightBorder,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // Section 4: Government Identity
                    _buildSectionHeader('4. Government ID Verification *'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.midnightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.midnightBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedIdType,
                          isExpanded: true,
                          dropdownColor: AppTheme.midnightSurface,
                          style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 15),
                          items: _idProofTypes.map((type) {
                            return DropdownMenuItem(value: type, child: Text(type));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedIdType = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _idNumberController,
                      label: 'ID Document Number *',
                      hint: 'e.g. 5642 9871 2341 or ABCD1234E',
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'ID Number is required' : null,
                    ),
                    const SizedBox(height: 28),

                    // Section 5: Payout & Rates
                    _buildSectionHeader('5. Payout Details & Consultation Rates *'),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _upiController,
                      label: 'Payout UPI ID (VPA) *',
                      hint: 'e.g. sharma@okaxis or astrologer@upi',
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'UPI ID is required';
                        if (!val.contains('@')) return 'Enter valid UPI ID (must contain @)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _chatRateController,
                            label: 'Chat (₹/min)',
                            hint: '25',
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            prefixText: '₹ ',
                            validator: (val) {
                              final rate = int.tryParse(val ?? '');
                              if (rate == null || rate < 5) return 'Min ₹5';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _callRateController,
                            label: 'Call (₹/min)',
                            hint: '30',
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            prefixText: '₹ ',
                            validator: (val) {
                              final rate = int.tryParse(val ?? '');
                              if (rate == null || rate < 5) return 'Min ₹5';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _videoRateController,
                            label: 'Video (₹/min)',
                            hint: '50',
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            prefixText: '₹ ',
                            validator: (val) {
                              final rate = int.tryParse(val ?? '');
                              if (rate == null || rate < 5) return 'Min ₹5';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rates are stored in integer paise on backend (e.g. ₹25/min = 2,500 paise).',
                      style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
                    ),

                    if (kycState.errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          kycState.errorMessage!,
                          style: GoogleFonts.inter(color: AppTheme.error, fontSize: 13),
                        ),
                      ),
                    ],

                    const SizedBox(height: 36),
                    ElevatedButton(
                      onPressed: kycState.isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: kycState.isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.midnightBackground,
                              ),
                            )
                          : Text(
                              'Submit Application for Review',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.midnightBackground,
                              ),
                            ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.lora(
        color: AppTheme.goldLight,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? prefixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
          style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            prefixStyle: GoogleFonts.inter(
              color: AppTheme.goldAccent,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}
