import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage: storage);
});

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? phoneNumber;
  final String? requestId;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.phoneNumber,
    this.requestId,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? phoneNumber,
    String? requestId,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      requestId: requestId ?? this.requestId,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final ApiClient _apiClient;
  late final SecureStorageService _storage;

  @override
  AuthState build() {
    _apiClient = ref.watch(apiClientProvider);
    _storage = ref.watch(secureStorageProvider);
    Future.microtask(() => checkInitialAuth());
    return const AuthState();
  }

  Future<void> checkInitialAuth() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        final response = await _apiClient.dio.get(ApiConstants.getMe);
        final user = UserModel.fromJson(response.data);
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
      final user = UserModel.fromJson(userData);

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
    state = const AuthState(isAuthenticated: false);
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
