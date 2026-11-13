import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/expert_profile_model.dart';

class KycState {
  final bool isLoading;
  final ExpertProfileModel? profile;
  final String? errorMessage;
  final bool isSubmitting;

  const KycState({
    this.isLoading = false,
    this.profile,
    this.errorMessage,
    this.isSubmitting = false,
  });

  KycState copyWith({
    bool? isLoading,
    ExpertProfileModel? profile,
    String? errorMessage,
    bool? isSubmitting,
    bool clearProfile = false,
  }) {
    return KycState(
      isLoading: isLoading ?? this.isLoading,
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class KycNotifier extends Notifier<KycState> {
  @override
  KycState build() {
    return const KycState();
  }

  Future<void> fetchProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final apiClient = ref.read(apiClientProvider);

    try {
      final response = await apiClient.dio.get(ApiConstants.getMyProfile);
      if (response.data != null && response.data is Map<String, dynamic>) {
        final profile = ExpertProfileModel.fromJson(response.data);
        state = state.copyWith(
          isLoading: false,
          profile: profile,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(isLoading: false, clearProfile: true);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        state = state.copyWith(isLoading: false, clearProfile: true);
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: e.response?.data?['message']?.toString() ?? 'Failed to load profile',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unexpected error loading profile',
      );
    }
  }

  Future<bool> submitKyc({
    required String name,
    String? email,
    String? bio,
    required int experienceYears,
    required List<String> languages,
    required List<String> expertise,
    required String idProofType,
    required String idProofNumber,
    required String payoutUpiId,
    required int chatRateInPaise,
    required int callRateInPaise,
    required int videoRateInPaise,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    final apiClient = ref.read(apiClientProvider);

    try {
      final response = await apiClient.dio.post(
        ApiConstants.submitKyc,
        data: {
          'name': name,
          if (email != null && email.isNotEmpty) 'email': email,
          if (bio != null && bio.isNotEmpty) 'bio': bio,
          'experienceYears': experienceYears,
          'languages': languages,
          'expertise': expertise,
          'idProofType': idProofType,
          'idProofNumber': idProofNumber,
          'payoutUpiId': payoutUpiId,
          'chatRateInPaise': chatRateInPaise,
          'callRateInPaise': callRateInPaise,
          'videoRateInPaise': videoRateInPaise,
        },
      );

      final profile = ExpertProfileModel.fromJson(response.data);
      state = state.copyWith(
        isSubmitting: false,
        profile: profile,
        errorMessage: null,
      );
      return true;
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message ?? 'KYC submission failed';
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: errorMsg is List ? errorMsg.join(', ') : errorMsg.toString(),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'An unexpected error occurred during submission.',
      );
      return false;
    }
  }
}

final kycStateProvider = NotifierProvider<KycNotifier, KycState>(() {
  return KycNotifier();
});
