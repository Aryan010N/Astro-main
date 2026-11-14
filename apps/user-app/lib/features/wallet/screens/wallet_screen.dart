import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../models/wallet_order_model.dart';
import '../models/wallet_transaction_model.dart';
import '../providers/wallet_provider.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final TextEditingController _amountController = TextEditingController(text: '500');
  int _selectedPreset = 500;

  final List<int> _presetAmounts = [100, 250, 500, 1000, 2000, 5000];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onPresetSelected(int amount) {
    setState(() {
      _selectedPreset = amount;
      _amountController.text = amount.toString();
    });
  }

  void _initiateRecharge() async {
    final amountRupees = int.tryParse(_amountController.text.trim());
    if (amountRupees == null || amountRupees < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum recharge amount is ₹50'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final amountInPaise = amountRupees * 100;
    final order = await ref
        .read(walletStateProvider.notifier)
        .createRechargeOrder(amountInPaise);

    if (order != null && mounted) {
      _showRazorpayCheckoutStub(order);
    }
  }

  // =========================================================================
  // RAZORPAY CHECKOUT SDK STUB
  // =========================================================================
  // TODO: Replace this simulation dialog with the official Razorpay Flutter SDK:
  //
  // import 'package:razorpay_flutter/razorpay_flutter.dart';
  //
  // void _openRazorpayCheckout(RechargeOrderModel order) {
  //   final razorpay = Razorpay();
  //   razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
  //   razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
  //   razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  //
  //   final options = {
  //     'key': order.keyId,
  //     'amount': order.amountInPaise,
  //     'name': 'Astro Consultation',
  //     'description': 'Wallet Balance Recharge',
  //     'order_id': order.orderId,
  //     'prefill': {'contact': userPhone},
  //     'theme': {'color': '#F5A623'}
  //   };
  //   razorpay.open(options);
  // }
  // =========================================================================
  void _showRazorpayCheckoutStub(RechargeOrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.midnightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final walletState = ref.watch(walletStateProvider);

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.midnightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.goldAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.payment,
                      color: AppTheme.goldAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Razorpay Payment Gateway (Stub)',
                          style: GoogleFonts.lora(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Test Mode / Offline Simulation',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.goldLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.midnightCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.midnightBorder),
                ),
                child: Column(
                  children: [
                    _buildModalRow('Order ID', order.orderId),
                    const Divider(color: AppTheme.midnightBorder, height: 16),
                    _buildModalRow(
                      'Recharge Amount',
                      '₹${order.amountInRupees.toStringAsFixed(2)}',
                      isHighlight: true,
                    ),
                    const Divider(color: AppTheme.midnightBorder, height: 16),
                    _buildModalRow('Gateway Key', order.keyId),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'NOTICE: Real Razorpay account credentials will be swapped in before launch. Use the simulation buttons below to test the ledger credit and failure paths.',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: walletState.isProcessingPayment
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);
                        final ok = await ref
                            .read(walletStateProvider.notifier)
                            .simulatePayment(
                              orderId: order.orderId,
                              isSuccess: true,
                            );
                        nav.pop();
                        if (ok) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '₹${order.amountInRupees.toStringAsFixed(2)} credited to your wallet!',
                              ),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      },
                icon: walletState.isProcessingPayment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.midnightBackground,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('Simulate Successful Payment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: walletState.isProcessingPayment
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);
                        await ref
                            .read(walletStateProvider.notifier)
                            .simulatePayment(
                              orderId: order.orderId,
                              isSuccess: false,
                            );
                        nav.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Payment failed (simulated). Wallet balance unchanged.'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      },
                icon: const Icon(Icons.cancel_outlined, size: 20),
                label: const Text('Simulate Failed Payment'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 13),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: isHighlight ? AppTheme.goldLight : AppTheme.textPrimary,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            fontSize: isHighlight ? 16 : 13,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.midnightBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.midnightSurface,
        elevation: 0,
        title: Text(
          'My Wallet',
          style: GoogleFonts.lora(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Ledger',
            icon: const Icon(Icons.refresh, color: AppTheme.goldAccent, size: 22),
            onPressed: () => ref.read(walletStateProvider.notifier).refreshWallet(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Balance Summary Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.midnightCard, AppTheme.midnightSurface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.goldAccent.withValues(alpha: 0.35),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.goldAccent.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'AVAILABLE BALANCE',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹ ${wallet.balanceInRupees.toStringAsFixed(2)}',
                      style: GoogleFonts.lora(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.goldLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Stored in integer paise (${wallet.balanceInPaise} paise) • Append-only ledger',
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 2. Recharge Section
              Text(
                'Add Money to Wallet',
                style: GoogleFonts.lora(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Preset Slabs Grid
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _presetAmounts.map((amt) {
                  final isSelected = _selectedPreset == amt;
                  final isPopular = amt == 500;

                  return InkWell(
                    onTap: () => _onPresetSelected(amt),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: (MediaQuery.of(context).size.width - 60) / 3,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.goldAccent.withValues(alpha: 0.2) : AppTheme.midnightSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppTheme.goldAccent : AppTheme.midnightBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (isPopular)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.goldAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'POPULAR',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.midnightBackground,
                                ),
                              ),
                            ),
                          Text(
                            '₹ $amt',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? AppTheme.goldLight : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Custom Amount Input
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '₹  ',
                  prefixStyle: GoogleFonts.inter(
                    color: AppTheme.goldAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  hintText: 'Enter custom amount',
                  labelText: 'Recharge Amount',
                ),
                onChanged: (val) {
                  final num = int.tryParse(val);
                  setState(() {
                    _selectedPreset = num ?? 0;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Recharge Action Button
              ElevatedButton(
                onPressed: wallet.isCreatingOrder ? null : _initiateRecharge,
                child: wallet.isCreatingOrder
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.midnightBackground,
                        ),
                      )
                    : Text(
                        'Recharge Wallet',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.midnightBackground,
                        ),
                      ),
              ),
              const SizedBox(height: 36),

              // 3. Append-Only Transaction Ledger History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaction History',
                    style: GoogleFonts.lora(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${wallet.transactions.length} records',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (wallet.isLoading && wallet.transactions.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: AppTheme.goldAccent),
                  ),
                )
              else if (wallet.transactions.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppTheme.midnightSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.midnightBorder),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 40,
                          color: AppTheme.textMuted.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No transactions yet',
                          style: GoogleFonts.inter(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: wallet.transactions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tx = wallet.transactions[index];
                    return _buildTransactionCard(tx);
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(WalletTransactionModel tx) {
    final isCredit = tx.isCredit;
    final color = isCredit ? AppTheme.success : AppTheme.error;
    final sign = isCredit ? '+' : '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.midnightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.midnightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description ?? (isCredit ? 'Recharge' : 'Session Charge'),
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year} • Ref: ${tx.referenceId ?? 'N/A'}',
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Balance after: ₹${tx.runningBalanceInRupees.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign ₹${tx.amountInRupees.toStringAsFixed(2)}',
                style: GoogleFonts.inter(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tx.isSuccess
                      ? AppTheme.success.withValues(alpha: 0.2)
                      : AppTheme.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tx.status,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: tx.isSuccess ? AppTheme.success : AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
