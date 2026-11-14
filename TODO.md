# Astro — Pending Integrations & Launch Checklist (TODO)

This document tracks all external vendor stubs, placeholder test credentials, and mock flows that must be swapped for real production/test keys prior to public deployment.

---

## 1. Razorpay Payment Gateway & Webhook (Phase 3)

Currently, the payment gateway integration is implemented against Razorpay's documented API specifications with mock fallbacks and HMAC SHA256 cryptographic verification. To transition to real Razorpay test or live accounts, complete the following items:

### A. Environment Variables (`apps/backend/.env`)

| Variable | Current Placeholder Value | Real Production/Test Value Needed | Description |
|:---|:---|:---|:---|
| `RAZORPAY_KEY_ID` | `rzp_test_placeholder_key_id` | `rzp_test_...` or `rzp_live_...` | Razorpay Merchant Key ID |
| `RAZORPAY_KEY_SECRET` | `placeholder_secret_key` | Generated in Razorpay Dashboard | Razorpay API Secret Key |
| `RAZORPAY_WEBHOOK_SECRET` | `placeholder_webhook_secret` | Configured in Razorpay Webhooks | Webhook secret for HMAC SHA256 signature verification |

### B. Backend Orders API Swap (`apps/backend/src/wallet/razorpay.service.ts`)

- **Current State:** In `RazorpayService.createOrder()`, if `isMockMode` is active, a structured Razorpay order response is created locally.
- **Required Action:**
  1. Install Razorpay Node SDK: `pnpm add razorpay` (in `apps/backend`).
  2. In `apps/backend/src/wallet/razorpay.service.ts`:
     ```typescript
     import Razorpay from 'razorpay';
     
     const instance = new Razorpay({
       key_id: this.keyId,
       key_secret: this.keySecret,
     });
     
     return await instance.orders.create({
       amount: options.amount,
       currency: options.currency || 'INR',
       receipt: options.receipt,
       notes: options.notes,
     });
     ```
  3. The webhook verification logic in `RazorpayService.verifyWebhookSignature()` already uses standard HMAC SHA256 and will automatically validate real Razorpay callbacks once `RAZORPAY_WEBHOOK_SECRET` is set.

### C. Razorpay Webhook Configuration in Merchant Dashboard

- **Webhook URL:** `https://api.yourdomain.com/webhooks/payment`
- **Secret:** Enter matching `RAZORPAY_WEBHOOK_SECRET`.
- **Active Events to Select:**
  - `payment.captured`
  - `order.paid`
  - `payment.failed`

### D. Flutter User App Razorpay Checkout (`apps/user-app`)

- **File:** `apps/user-app/lib/features/wallet/screens/wallet_screen.dart`
- **Current State:** `_showRazorpayCheckoutStub()` presents an interactive simulation modal allowing testing of success (`payment.captured`) and failure (`payment.failed`) scenarios.
- **Required Action:**
  1. Add `razorpay_flutter` package to `apps/user-app/pubspec.yaml`:
     ```yaml
     dependencies:
       razorpay_flutter: ^1.3.7
     ```
  2. Implement `Razorpay` event listeners:
     ```dart
     import 'package:razorpay_flutter/razorpay_flutter.dart';

     void _openRazorpayCheckout(RechargeOrderModel order) {
       final razorpay = Razorpay();
       razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
       razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
       razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

       final options = {
         'key': order.keyId,
         'amount': order.amountInPaise,
         'name': 'Astro Consultation',
         'description': 'Wallet Balance Recharge',
         'order_id': order.orderId,
         'prefill': {'contact': userPhone},
         'theme': {'color': '#F5A623'}
       };
       razorpay.open(options);
     }
     ```

---

## 2. Real-Time Calling & WebRTC (Phase 6)

- **Agora / Twilio App ID & Certificate:** To be configured during Phase 6 calling engine build.
