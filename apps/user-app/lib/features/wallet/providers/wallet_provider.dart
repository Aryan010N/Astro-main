import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/wallet_transaction_model.dart';
import '../models/wallet_order_model.dart';

class WalletState {
  final double balanceInRupees;
  final int balanceInPaise;
  final String currency;
  final List<WalletTransactionModel> transactions;
  final bool isLoading;
  final bool isCreatingOrder;
  final bool isProcessingPayment;
  final String? errorMessage;

  const WalletState({
    this.balanceInRupees = 0.0,
    this.balanceInPaise = 0,
    this.currency = 'INR',
    this.transactions = const [],
    this.isLoading = false,
    this.isCreatingOrder = false,
    this.isProcessingPayment = false,
    this.errorMessage,
  });

  WalletState copyWith({
    double? balanceInRupees,
    int? balanceInPaise,
    String? currency,
    List<WalletTransactionModel>? transactions,
    bool? isLoading,
    bool? isCreatingOrder,
    bool? isProcessingPayment,
    String? errorMessage,
  }) {
    return WalletState(
      balanceInRupees: balanceInRupees ?? this.balanceInRupees,
      balanceInPaise: balanceInPaise ?? this.balanceInPaise,
      currency: currency ?? this.currency,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      isCreatingOrder: isCreatingOrder ?? this.isCreatingOrder,
      isProcessingPayment: isProcessingPayment ?? this.isProcessingPayment,
      errorMessage: errorMessage,
    );
  }
}

class WalletNotifier extends Notifier<WalletState> {
  @override
  WalletState build() {
    Future.microtask(() => refreshWallet());
    return const WalletState();
  }

  Future<void> refreshWallet() async {
    await Future.wait([
      fetchBalance(),
      fetchTransactions(),
    ]);
  }

  Future<void> fetchBalance() async {
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.dio.get(ApiConstants.walletBalance);
      final balanceInPaise = int.tryParse(res.data['balanceInPaise']?.toString() ?? '0') ?? 0;
      final balanceInRupees = (res.data['balanceInRupees'] as num?)?.toDouble() ?? (balanceInPaise / 100.0);
      state = state.copyWith(
        balanceInPaise: balanceInPaise,
        balanceInRupees: balanceInRupees,
        currency: res.data['currency'] as String? ?? 'INR',
      );
    } catch (_) {}
  }

  Future<void> fetchTransactions() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final apiClient = ref.read(apiClientProvider);
    try {
      final res = await apiClient.dio.get(ApiConstants.walletTransactions);
      final rawList = res.data['transactions'] as List<dynamic>? ?? [];
      final list = rawList.map((e) => WalletTransactionModel.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(
        isLoading: false,
        transactions: list,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.response?.data?['message']?.toString() ?? 'Failed to load transactions',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to connect to wallet ledger',
      );
    }
  }

  Future<RechargeOrderModel?> createRechargeOrder(int amountInPaise) async {
    state = state.copyWith(isCreatingOrder: true, errorMessage: null);
    final apiClient = ref.read(apiClientProvider);

    try {
      final res = await apiClient.dio.post(
        ApiConstants.walletCreateOrder,
        data: {'amountInPaise': amountInPaise},
      );
      state = state.copyWith(isCreatingOrder: false);
      return RechargeOrderModel.fromJson(res.data);
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message ?? 'Order creation failed';
      state = state.copyWith(
        isCreatingOrder: false,
        errorMessage: errorMsg is List ? errorMsg.join(', ') : errorMsg.toString(),
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        isCreatingOrder: false,
        errorMessage: 'Network error creating order',
      );
      return null;
    }
  }

  Future<bool> simulatePayment({
    required String orderId,
    required bool isSuccess,
  }) async {
    state = state.copyWith(isProcessingPayment: true, errorMessage: null);
    final apiClient = ref.read(apiClientProvider);

    try {
      await apiClient.dio.post(
        ApiConstants.walletSimulatePayment,
        data: {
          'orderId': orderId,
          'status': isSuccess ? 'captured' : 'failed',
        },
      );
      state = state.copyWith(isProcessingPayment: false);
      await refreshWallet();
      return true;
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['message'] ?? e.message ?? 'Payment simulation failed';
      state = state.copyWith(
        isProcessingPayment: false,
        errorMessage: errorMsg is List ? errorMsg.join(', ') : errorMsg.toString(),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isProcessingPayment: false,
        errorMessage: 'Network error executing mock payment',
      );
      return false;
    }
  }
}

final walletStateProvider = NotifierProvider<WalletNotifier, WalletState>(() {
  return WalletNotifier();
});
