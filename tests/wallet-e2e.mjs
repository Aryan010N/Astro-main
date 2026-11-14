import http from 'http';
import crypto from 'crypto';

function makeRequest(options, postData) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, data: parsed, headers: res.headers });
        } catch {
          resolve({ status: res.statusCode, raw: data, headers: res.headers });
        }
      });
    });
    req.on('error', (err) => reject(err));
    if (postData) {
      if (typeof postData === 'string') {
        req.write(postData);
      } else {
        req.write(JSON.stringify(postData));
      }
    }
    req.end();
  });
}

async function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function waitForServer() {
  for (let i = 0; i < 30; i++) {
    try {
      const res = await makeRequest({
        hostname: '127.0.0.1',
        port: 3000,
        path: '/auth/otp/request',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      }, { phoneNumber: '+919999999999' });
      if (res.status === 200 || res.status === 400 || res.status === 429) {
        console.log('Backend is up and responsive on port 3000!');
        return;
      }
    } catch (_) {}
    await sleep(1000);
  }
  throw new Error('Backend failed to respond on port 3000 within 30s');
}

function computeHmacSignature(body, secret) {
  return crypto.createHmac('sha256', secret).update(body).digest('hex');
}

async function runPhase3Tests() {
  console.log('===============================================================');
  console.log('   PHASE 3 — WALLET & PAYMENT GATEWAY END-TO-END VERIFICATION');
  console.log('===============================================================');

  await waitForServer();
  const webhookSecret = 'placeholder_webhook_secret';

  // 1. Authenticate test user
  console.log('\n--- Step 1: User Login via Mobile OTP ---');
  const userPhone = '+919988776655';
  const reqOtp = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/auth/otp/request',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, { phoneNumber: userPhone });

  const verifyRes = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/auth/otp/verify',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, { phoneNumber: userPhone, requestId: reqOtp.data.requestId, otp: '123456' });

  const token = verifyRes.data.accessToken;
  const userId = verifyRes.data.user.id;
  console.log(`User authenticated: ${userId} (${userPhone})`);

  // Verify initial balance
  const initialBalance = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/wallet/balance',
    method: 'GET',
    headers: { Authorization: `Bearer ${token}` },
  });
  console.log('Initial Wallet Balance:', initialBalance.data);

  // 2. Test Case 1: Successful mock recharge crediting the wallet via ledger
  console.log('\n--- Test Case 1: Create Order & Successful Recharge via Webhook ---');
  const orderRes = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/wallet/recharge/create-order',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
  }, { amountInPaise: 50000 }); // ₹500
  console.log('Order created:', orderRes.data);
  const orderId = orderRes.data.orderId;

  const paymentId1 = `pay_${Date.now()}_test1`;
  const eventId1 = `evt_${Date.now()}_test1`;
  const webhookPayload1 = {
    entity: 'event',
    account_id: 'acc_astro_dev',
    event: 'payment.captured',
    contains: ['payment', 'order'],
    payload: {
      payment: {
        entity: {
          id: paymentId1,
          entity: 'payment',
          amount: 50000,
          currency: 'INR',
          status: 'captured',
          order_id: orderId,
          method: 'upi',
          notes: { userId },
        },
      },
      order: {
        entity: {
          id: orderId,
          entity: 'order',
          amount: 50000,
          status: 'paid',
        },
      },
    },
    created_at: Math.floor(Date.now() / 1000),
  };

  const rawBody1 = JSON.stringify(webhookPayload1);
  const signature1 = computeHmacSignature(rawBody1, webhookSecret);

  // Fire webhook with valid HMAC SHA256 signature
  const webhookRes1 = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/webhooks/payment',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-razorpay-signature': signature1,
      'x-razorpay-event-id': eventId1,
    },
  }, rawBody1);
  console.log('Webhook Response:', webhookRes1.data);

  // Check balance after credit
  const balanceAfterRecharge = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/wallet/balance',
    method: 'GET',
    headers: { Authorization: `Bearer ${token}` },
  });
  console.log('Balance after recharge:', balanceAfterRecharge.data);

  if (balanceAfterRecharge.data.balanceInPaise !== '50000') {
    throw new Error(`Expected balance 50000 paise, got: ${balanceAfterRecharge.data.balanceInPaise}`);
  }
  console.log('✔ Test Case 1 PASSED: Wallet successfully credited ₹500 (50,000 paise)!');

  // 3. Test Case 2: Duplicate webhook event firing twice does NOT double-credit
  console.log('\n--- Test Case 2: Webhook Idempotency (Duplicate Event Delivery) ---');
  const duplicateWebhookRes = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/webhooks/payment',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-razorpay-signature': signature1,
      'x-razorpay-event-id': eventId1, // Same event ID!
    },
  }, rawBody1);
  console.log('Duplicate Webhook Response:', duplicateWebhookRes.data);

  const balanceAfterDuplicate = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/wallet/balance',
    method: 'GET',
    headers: { Authorization: `Bearer ${token}` },
  });
  console.log('Balance after duplicate webhook:', balanceAfterDuplicate.data);

  if (balanceAfterDuplicate.data.balanceInPaise !== '50000') {
    throw new Error(
      `FATAL: Duplicate webhook double-credited the wallet! Expected 50000, got ${balanceAfterDuplicate.data.balanceInPaise}`,
    );
  }
  console.log('✔ Test Case 2 PASSED: Duplicate webhook safely ignored, balance remains strictly ₹500 (50,000 paise)!');

  // 4. Test Case 3: Simulated failed payment does NOT credit wallet
  console.log('\n--- Test Case 3: Simulated Failed Payment Handling ---');
  const orderRes2 = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/wallet/recharge/create-order',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
  }, { amountInPaise: 100000 }); // ₹1,000
  const orderId2 = orderRes2.data.orderId;

  const paymentIdFailed = `pay_${Date.now()}_failed`;
  const eventIdFailed = `evt_${Date.now()}_failed`;
  const webhookPayloadFailed = {
    entity: 'event',
    account_id: 'acc_astro_dev',
    event: 'payment.failed',
    contains: ['payment', 'order'],
    payload: {
      payment: {
        entity: {
          id: paymentIdFailed,
          entity: 'payment',
          amount: 100000,
          currency: 'INR',
          status: 'failed',
          order_id: orderId2,
          error_code: 'BAD_REQUEST_ERROR',
          error_description: 'Payment was cancelled by user',
        },
      },
      order: {
        entity: {
          id: orderId2,
          entity: 'order',
          amount: 100000,
          status: 'attempted',
        },
      },
    },
    created_at: Math.floor(Date.now() / 1000),
  };

  const rawBodyFailed = JSON.stringify(webhookPayloadFailed);
  const sigFailed = computeHmacSignature(rawBodyFailed, webhookSecret);

  const webhookResFailed = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/webhooks/payment',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-razorpay-signature': sigFailed,
      'x-razorpay-event-id': eventIdFailed,
    },
  }, rawBodyFailed);
  console.log('Failed Payment Webhook Response:', webhookResFailed.data);

  const balanceAfterFailed = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/wallet/balance',
    method: 'GET',
    headers: { Authorization: `Bearer ${token}` },
  });
  console.log('Balance after failed payment attempt:', balanceAfterFailed.data);

  if (balanceAfterFailed.data.balanceInPaise !== '50000') {
    throw new Error(`Failed payment unexpectedly altered balance to: ${balanceAfterFailed.data.balanceInPaise}`);
  }
  console.log('✔ Test Case 3 PASSED: Failed payment recorded cleanly without crediting wallet!');

  // 5. Test Case 4: Concurrent deduction attempts do NOT allow balance to go negative
  console.log('\n--- Test Case 4: Concurrent Atomic Deductions & Overdraft Prevention ---');
  console.log('Current balance: ₹500 (50,000 paise).');
  console.log('Firing 5 simultaneous concurrent deduction requests of ₹200 (20,000 paise) each...');

  const concurrentRequests = Array.from({ length: 5 }, (_, i) =>
    makeRequest({
      hostname: '127.0.0.1',
      port: 3000,
      path: '/wallet/deduct',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
    }, {
      amountInPaise: 20000, // ₹200
      referenceId: `concurrent_session_${i + 1}`,
      description: `Concurrent session test #${i + 1}`,
    }),
  );

  const results = await Promise.all(concurrentRequests);
  const successCount = results.filter((r) => r.status === 200 || r.status === 201).length;
  const rejectedCount = results.filter((r) => r.status === 400).length;

  console.log(`Concurrent results: ${successCount} Succeeded (HTTP 200), ${rejectedCount} Rejected (HTTP 400 Insufficient Balance)`);

  const finalBalance = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/wallet/balance',
    method: 'GET',
    headers: { Authorization: `Bearer ${token}` },
  });
  console.log('Final Wallet Balance:', finalBalance.data);

  if (successCount !== 2 || rejectedCount !== 3) {
    throw new Error(
      `Concurrency race condition detected! Expected exactly 2 successes and 3 rejections, got ${successCount} and ${rejectedCount}`,
    );
  }

  if (finalBalance.data.balanceInPaise !== '10000') {
    throw new Error(
      `Final balance expected 10,000 paise (₹100), but found: ${finalBalance.data.balanceInPaise}`,
    );
  }
  console.log('✔ Test Case 4 PASSED: Database row-level locks strictly prevented negative balance and race conditions!');

  // 6. Verify Transaction History & Auditability
  console.log('\n--- Step 6: Verify Append-Only Transaction Ledger History ---');
  const txHistory = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/wallet/transactions',
    method: 'GET',
    headers: { Authorization: `Bearer ${token}` },
  });

  console.log(`Total ledger entries: ${txHistory.data.transactions.length}`);
  txHistory.data.transactions.forEach((tx, idx) => {
    console.log(
      `  #${idx + 1}: [${tx.type}] ₹${tx.amountInRupees} (${tx.status}) -> Snapshot: ₹${tx.runningBalanceInRupees} | Ref: ${tx.referenceId}`,
    );
  });

  console.log('\n===============================================================');
  console.log('   ALL 4 PHASE 3 TEST SCENARIOS PASSED WITH 100% SUCCESS!');
  console.log('===============================================================\n');
}

runPhase3Tests().catch((err) => {
  console.error('\n❌ Phase 3 Tests Failed with error:\n', err);
  process.exit(1);
});
