class WalletTransactionModel {
  final String id;
  final String walletId;
  final int amountInPaise;
  final double amountInRupees;
  final String type; // RECHARGE, SESSION_CHARGE, SESSION_REFUND, etc.
  final String status; // SUCCESS, PENDING, FAILED, REVERSED
  final int runningBalanceSnapshot;
  final double runningBalanceInRupees;
  final String? referenceId;
  final String? description;
  final DateTime createdAt;

  WalletTransactionModel({
    required this.id,
    required this.walletId,
    required this.amountInPaise,
    required this.amountInRupees,
    required this.type,
    required this.status,
    required this.runningBalanceSnapshot,
    required this.runningBalanceInRupees,
    this.referenceId,
    this.description,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as String,
      walletId: json['walletId'] as String? ?? '',
      amountInPaise: int.tryParse(json['amountInPaise']?.toString() ?? '0') ?? 0,
      amountInRupees: (json['amountInRupees'] as num?)?.toDouble() ?? 0.0,
      type: (json['type'] as String?) ?? 'RECHARGE',
      status: (json['status'] as String?) ?? 'SUCCESS',
      runningBalanceSnapshot:
          int.tryParse(json['runningBalanceSnapshot']?.toString() ?? '0') ?? 0,
      runningBalanceInRupees:
          (json['runningBalanceInRupees'] as num?)?.toDouble() ?? 0.0,
      referenceId: json['referenceId'] as String?,
      description: json['description'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isCredit => type == 'RECHARGE' || type == 'SESSION_REFUND' || type == 'COMMISSION_EARNING';
  bool get isSuccess => status == 'SUCCESS';
}
