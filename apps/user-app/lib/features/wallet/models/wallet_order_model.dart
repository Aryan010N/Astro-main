class RechargeOrderModel {
  final String orderId;
  final int amountInPaise;
  final double amountInRupees;
  final String currency;
  final String keyId;
  final String receipt;

  RechargeOrderModel({
    required this.orderId,
    required this.amountInPaise,
    required this.amountInRupees,
    required this.currency,
    required this.keyId,
    required this.receipt,
  });

  factory RechargeOrderModel.fromJson(Map<String, dynamic> json) {
    return RechargeOrderModel(
      orderId: json['orderId'] as String,
      amountInPaise: (json['amountInPaise'] as num).toInt(),
      amountInRupees: (json['amountInRupees'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      keyId: json['keyId'] as String? ?? '',
      receipt: json['receipt'] as String? ?? '',
    );
  }
}
