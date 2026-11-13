import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/expert_user_model.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage: storage);
});

class ExpertAuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? phoneNumber;
  final String? requestId;
  final ExpertUserModel? user;
  final String? errorMessage;

  const ExpertAuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.phoneNumber,
    this.requestId,
    this.user,
    this.errorMessage,
  });

  ExpertAuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? phoneNumber,
    String? requestId,
    ExpertUserModel? user,
    String? errorMessage,
  }) {
    return ExpertAuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      requestId: requestId ?? this.requestId,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class ExpertAuthNotifier extends Notifier<ExpertAuthState> {
  late final ApiClient _apiClient;
  late final SecureStorageService _storage;

  @override
  ExpertAuthState build() {
    _apiClient = ref.watch(apiClientProvider);
    _storage = ref.watch(secureStorageProvider);
    Future.microtask(() => checkInitialAuth());
    return const ExpertAuthState();
  }

  Future<void> checkInitialAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        final response = await _apiClient.dio.get(ApiConstants.getMe);
        final user = ExpertUserModel.fromJson(response.data);
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: user,
          phoneNumber: user.phoneNumber,
        );
        return;
      }
    } catch (_) {
      await _storage.clearAll();
    }
    state = state.copyWith(isLoading: false, isAuthenticated: false);
  }

  Future<bool> requestOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.requestOtp,
        data: {'phoneNumber': phoneNumber},
      );

      final requestId = response.data['requestId'] as String?;
      state = state.copyWith(
        isLoading: false,
        phoneNumber: phoneNumber,
        requestId: requestId,
      );
      return true;
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message ?? 'Failed to send OTP';
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMsg is List ? errorMsg.join(', ') : errorMsg.toString(),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred. Please try again.',
      );
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    if (state.phoneNumber == null || state.requestId == null) {
      state = state.copyWith(errorMessage: 'Session expired. Please request OTP again.');
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.verifyOtp,
        data: {
          'phoneNumber': state.phoneNumber,
          'requestId': state.requestId,
          'otp': otp,
        },
      );

      final accessToken = response.data['accessToken'] as String;
      final refreshToken = response.data['refreshToken'] as String;
      final userData = response.data['user'] as Map<String, dynamic>;
      final user = ExpertUserModel.fromJson(userData);

      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        phoneNumber: user.phoneNumber,
      );

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
        errorMessage: null,
      );
      return true;
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message ?? 'Invalid OTP';
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMsg is List ? errorMsg.join(', ') : errorMsg.toString(),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Verification failed. Please try again.',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _storage.clearAll();
    state = const ExpertAuthState(isAuthenticated: false);
  }
}

final expertAuthStateProvider =
    NotifierProvider<ExpertAuthNotifier, ExpertAuthState>(() {
  return ExpertAuthNotifier();
});
