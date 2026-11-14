import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    // Android emulator loops back to host via 10.0.2.2
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    // iOS simulator, desktop, etc.
    return 'http://localhost:3000';
  }

  static const String requestOtp = '/auth/otp/request';
  static const String verifyOtp = '/auth/otp/verify';
  static const String firebaseLogin = '/auth/firebase-login';
  static const String refreshToken = '/auth/refresh';
  static const String getMe = '/auth/me';

  // Wallet Endpoints (Phase 3)
  static const String walletBalance = '/wallet/balance';
  static const String walletTransactions = '/wallet/transactions';
  static const String walletCreateOrder = '/wallet/recharge/create-order';
  static const String walletSimulatePayment = '/wallet/simulate-payment';
}

