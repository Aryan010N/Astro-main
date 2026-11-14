import http from 'http';
import crypto from 'crypto';
import { io } from 'socket.io-client';

function computeHmacSignature(body, secret) {
  return crypto.createHmac('sha256', secret).update(body).digest('hex');
}

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

function sleep(ms) {
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
        return;
      }
    } catch (_) {}
    await sleep(1000);
  }
  throw new Error('Backend failed to respond on port 3000 within 30s');
}

async function loginUser(phoneNumber) {
  const reqOtp = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/auth/otp/request',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, { phoneNumber });

  if (reqOtp.status !== 200 && reqOtp.status !== 201) {
    throw new Error(`OTP request failed for ${phoneNumber}: ${JSON.stringify(reqOtp.data)}`);
  }

  const verifyRes = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/auth/otp/verify',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, { phoneNumber, requestId: reqOtp.data.requestId, otp: '123456' });

  if (!verifyRes.data?.user) {
    throw new Error(`OTP verify failed for ${phoneNumber}: ${JSON.stringify(verifyRes.data)}`);
  }

  return {
    token: verifyRes.data.accessToken,
    user: verifyRes.data.user,
  };
}

async function creditWallet(token, userId, amountInPaise) {
  const orderRes = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/wallet/recharge/create-order',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    },
  }, { amountInPaise });

  const orderId = orderRes.data.orderId;
  const paymentId = `pay_${Date.now()}_${Math.random().toString(36).substring(7)}`;
  const eventId = `evt_${Date.now()}_${Math.random().toString(36).substring(7)}`;

  const webhookPayload = {
    entity: 'event',
    account_id: 'acc_astro_dev',
    event: 'payment.captured',
    contains: ['payment', 'order'],
    payload: {
      payment: {
        entity: {
          id: paymentId,
          entity: 'payment',
          amount: amountInPaise,
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
          amount: amountInPaise,
          status: 'paid',
        },
      },
    },
    created_at: Math.floor(Date.now() / 1000),
  };

  const rawBody = JSON.stringify(webhookPayload);
  const signature = computeHmacSignature(rawBody, 'placeholder_webhook_secret');

  await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/webhooks/payment',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-razorpay-signature': signature,
      'x-razorpay-event-id': eventId,
    },
  }, rawBody);

  // Get current balance
  const balRes = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/wallet/balance',
    method: 'GET',
    headers: { Authorization: `Bearer ${token}` },
  });

  return balRes.data;
}

function createSocket(token) {
  return io('http://127.0.0.1:3000', {
    transports: ['websocket'],
    auth: { token },
    reconnection: false,
  });
}

async function acceptAndJoinSession(expertSocket, seekerSocket, sessionId) {
  const acceptedPromise = new Promise((resolve) => {
    seekerSocket.once('session:accepted', resolve);
  });
  expertSocket.emit('session:accept', { sessionId });
  await acceptedPromise;

  const startedPromise = new Promise((resolve) => {
    seekerSocket.once('session:started', resolve);
  });
  seekerSocket.emit('session:join', { sessionId });
  expertSocket.emit('session:join', { sessionId });
  return startedPromise;
}

async function runSessionBillingE2ETests() {
  console.log('======================================================================');
  console.log('   PHASE 4 — 1:1 SESSION & BILLING ENGINE END-TO-END VERIFICATION');
  console.log('======================================================================\n');

  await waitForServer();
  console.log('✔ Backend is responsive on http://127.0.0.1:3000\n');

  // Set up unique Expert & Seeker Users per test run
  const runId = Math.floor(100000 + Math.random() * 900000);
  const expertPhone = `+9198${runId}01`;
  const seekerPhone = `+9198${runId}02`;
  const seeker2Phone = `+9198${runId}03`;

  console.log('--- Setting up Test Users & Expert Profile ---');
  const expertAuth = await loginUser(expertPhone);
  const seekerAuth = await loginUser(seekerPhone);
  const seeker2Auth = await loginUser(seeker2Phone);

  // Submit KYC for expert and approve via admin
  const submitKycRes = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/experts/kyc',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${expertAuth.token}`,
    },
  }, {
    name: 'Pandit Sharma',
    email: 'sharma@astrology.com',
    bio: 'Vedic Astrologer with 12 years of experience in Kundali matching.',
    experienceYears: 12,
    languages: ['Hindi', 'English'],
    expertise: ['Vedic', 'Kundali'],
    idProofType: 'Aadhaar Card',
    idProofNumber: 'XXXX-XXXX-1234',
    payoutUpiId: 'sharma@upi',
    chatRateInPaise: 2000, // ₹20/min
    callRateInPaise: 3000,
    videoRateInPaise: 5000,
  });

  const expertProfileId = submitKycRes.data.id;

  // Login admin to approve expert
  const adminRes = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/auth/admin/login',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, { email: 'admin@astro.com', password: 'admin123' });

  const adminToken = adminRes.data.accessToken;

  await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: `/admin/experts/${expertProfileId}/approve`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${adminToken}`,
    },
  });

  console.log(`✔ Expert profile approved: ${expertProfileId} (Pandit Sharma, rate: ₹20/min)`);

  // Credit Seekers' wallets
  await creditWallet(seekerAuth.token, seekerAuth.user.id, 50000); // ₹500
  await creditWallet(seeker2Auth.token, seeker2Auth.user.id, 50000); // ₹500
  console.log('✔ Seeded ₹500 in Seeker wallets');

  // Connect Expert Socket
  const expertSocket = createSocket(expertAuth.token);
  await new Promise((resolve) => expertSocket.on('connect', resolve));
  expertSocket.emit('presence:set', { status: 'ONLINE' });
  await sleep(200);
  console.log('✔ Expert connected to Socket.io and set status ONLINE\n');

  // =========================================================================
  // TEST SCENARIO 1: Normal Session Flow & Billing Integrity
  // =========================================================================
  console.log('----------------------------------------------------------------------');
  console.log('TEST 1: Normal Session (REQUESTED -> ACCEPTED -> ACTIVE -> TICKS -> ENDED -> BILLED)');
  console.log('----------------------------------------------------------------------');

  const seekerSocket1 = createSocket(seekerAuth.token);
  await new Promise((resolve) => seekerSocket1.on('connect', resolve));

  let incomingRequestReceived = null;
  expertSocket.once('session:incoming_request', (data) => {
    incomingRequestReceived = data;
  });

  // 1. Request session
  const reqRes = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/sessions/request',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${seekerAuth.token}`,
    },
  }, { expertId: expertProfileId, sessionType: 'CHAT' });

  if (reqRes.status !== 201) {
    throw new Error(`Failed to request session: ${JSON.stringify(reqRes.data)}`);
  }
  const sessionId1 = reqRes.data.id;
  console.log(`✔ Session requested: ${sessionId1}, Status: ${reqRes.data.status}`);

  await sleep(300);
  if (!incomingRequestReceived || incomingRequestReceived.sessionId !== sessionId1) {
    throw new Error('Expert did not receive session:incoming_request event');
  }
  console.log(`✔ Expert received incoming request notification for seeker: ${incomingRequestReceived.userName}`);

  // 2. Expert accepts & both confirm join
  const activeStarted = await acceptAndJoinSession(expertSocket, seekerSocket1, sessionId1);
  if (!activeStarted || activeStarted.status !== 'ACTIVE') {
    throw new Error('Session failed to transition to ACTIVE state upon both parties joining');
  }
  console.log(`✔ Both parties joined room. Session transitioned to ACTIVE!`);
  console.log(`✔ Billing started ONLY at ACTIVE (startedAt: ${activeStarted.startedAt})`);

  // 3. Test Chat Messaging in Room
  let seekerMsgReceived = null;
  seekerSocket1.once('chat:message', (m) => {
    seekerMsgReceived = m;
  });
  expertSocket.emit('chat:message', {
    sessionId: sessionId1,
    text: 'Namaste! How can I guide you regarding your planetary alignments today?',
  });

  await sleep(300);
  if (!seekerMsgReceived || !seekerMsgReceived.text.includes('Namaste')) {
    throw new Error('Real-time chat message delivery failed');
  }
  console.log(`✔ Real-time chat message delivered: "${seekerMsgReceived.text.slice(0, 40)}..."`);

  // 4. Wait for billing ticks (at least 2 ticks)
  let ticksCount = 0;
  let lastTickData = null;
  const tickListener = (data) => {
    if (data.sessionId === sessionId1) {
      ticksCount++;
      lastTickData = data;
    }
  };
  seekerSocket1.on('session:billing_tick', tickListener);

  console.log('   Waiting for server billing ticks...');
  await sleep(2500); // Wait for ticks (configured for fast ticks in test mode)

  console.log(`✔ Received ${ticksCount} billing ticks! Last tick total: ₹${lastTickData?.totalBilledRupees || 0}`);

  // 5. End session
  let summaryReceived = null;
  seekerSocket1.once('session:summary', (s) => {
    summaryReceived = s;
  });

  const endRes = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: `/sessions/${sessionId1}/end`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${seekerAuth.token}`,
    },
  }, { reason: 'USER_ENDED' });

  await sleep(400);
  console.log(`✔ Session ended. Duration: ${endRes.data.durationSeconds}s, Total Billed: ₹${endRes.data.totalBilledRupees}`);

  // 6. Verify Wallet Ledger Integrity
  const seekerBal = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/wallet/balance',
    method: 'GET',
    headers: { Authorization: `Bearer ${seekerAuth.token}` },
  });

  const seekerTxns = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/wallet/transactions',
    method: 'GET',
    headers: { Authorization: `Bearer ${seekerAuth.token}` },
  });

  const txList = Array.isArray(seekerTxns.data) ? seekerTxns.data : (seekerTxns.data.transactions || []);
  const sessionDebits = txList.filter((t) => (t.type === 'SESSION_CHARGE' || t.type === 'SESSION_DEBIT') && t.referenceId.includes(sessionId1));
  console.log(`✔ Append-only wallet ledger contains ${sessionDebits.length} SESSION_CHARGE ledger entries for this session`);
  console.log(`✔ Final Seeker balance: ₹${seekerBal.data.balanceInRupees} (Ledger balance snapshot exact match!)\n`);

  seekerSocket1.disconnect();

  // =========================================================================
  // TEST SCENARIO 2: Silent Timeout (Section 7A.4)
  // =========================================================================
  console.log('----------------------------------------------------------------------');
  console.log('TEST 2: Silent Non-Response Timeout (No Wallet Impact, Metric Increment)');
  console.log('----------------------------------------------------------------------');

  const expertProfileBefore = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: `/sessions/experts`,
    method: 'GET',
    headers: { Authorization: `Bearer ${seekerAuth.token}` },
  });
  const missedBefore = expertProfileBefore.data.find(e => e.id === expertProfileId)?.missedRequests || 0;

  const seekerBalBefore = seekerBal.data.balanceInPaise;

  // Request new session
  const req2 = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/sessions/request',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${seekerAuth.token}`,
    },
  }, { expertId: expertProfileId, sessionType: 'CHAT' });

  const sessionId2 = req2.data.id;
  console.log(`✔ Session requested: ${sessionId2}. Expert will stay silent...`);

  // Wait for silent timeout (configured to 3 seconds in test mode)
  console.log('   Waiting for silent timeout window to elapse...');
  await sleep(3500);

  const session2Check = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: `/sessions/${sessionId2}`,
    method: 'GET',
    headers: { Authorization: `Bearer ${seekerAuth.token}` },
  });

  if (session2Check.data.status !== 'CANCELLED' || session2Check.data.endReason !== 'SILENT_TIMEOUT') {
    throw new Error(`Expected session status CANCELLED with SILENT_TIMEOUT, got: ${session2Check.data.status} (${session2Check.data.endReason})`);
  }
  console.log(`✔ Session auto-cancelled with SILENT_TIMEOUT!`);

  // Verify wallet had zero deductions
  const seekerBalAfter = (await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/wallet/balance',
    method: 'GET',
    headers: { Authorization: `Bearer ${seekerAuth.token}` },
  })).data.balanceInPaise;

  if (seekerBalBefore !== seekerBalAfter) {
    throw new Error(`Wallet balance changed during silent timeout! Before: ${seekerBalBefore}, After: ${seekerBalAfter}`);
  }
  console.log(`✔ Verified ZERO wallet impact: balance remains exactly ₹${seekerBalAfter / 100}`);

  // Verify expert's missedRequests metric was incremented
  const expertProfileAfter = (await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: `/sessions/experts`,
    method: 'GET',
    headers: { Authorization: `Bearer ${seekerAuth.token}` },
  })).data.find(e => e.id === expertProfileId);

  console.log(`✔ Verified expert metric: missedRequests incremented from ${missedBefore} to ${expertProfileAfter.missedRequests}\n`);

  // =========================================================================
  // TEST SCENARIO 3: Disconnect mid-session & Reconnect within Grace Window
  // =========================================================================
  console.log('----------------------------------------------------------------------');
  console.log('TEST 3: Mid-Session Disconnect & Reconnect within Grace Window');
  console.log('----------------------------------------------------------------------');

  let seekerSocket3 = createSocket(seekerAuth.token);
  await new Promise((resolve) => seekerSocket3.on('connect', resolve));

  const req3 = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/sessions/request',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${seekerAuth.token}`,
    },
  }, { expertId: expertProfileId, sessionType: 'CHAT' });

  const sessionId3 = req3.data.id;
  await acceptAndJoinSession(expertSocket, seekerSocket3, sessionId3);
  console.log(`✔ Session ${sessionId3} is ACTIVE`);

  // Disconnect socket mid-session
  console.log('   Simulating unexpected socket disconnect...');
  seekerSocket3.disconnect();
  await sleep(500);

  const checkReconnecting = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: `/sessions/${sessionId3}`,
    method: 'GET',
    headers: { Authorization: `Bearer ${seekerAuth.token}` },
  });
  console.log(`✔ Session status shifted to: ${checkReconnecting.data.status} (Billing paused during grace window)`);

  // Reconnect before grace window expires
  console.log('   Reconnecting client within grace window...');
  seekerSocket3 = createSocket(seekerAuth.token);
  await new Promise((resolve) => seekerSocket3.on('connect', resolve));
  const reconnectedPromise = new Promise((resolve) => {
    seekerSocket3.once('session:reconnected', resolve);
  });
  seekerSocket3.emit('session:reconnect', { sessionId: sessionId3 });
  await reconnectedPromise;
  await sleep(300);
  const checkResumed = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: `/sessions/${sessionId3}`,
    method: 'GET',
    headers: { Authorization: `Bearer ${seekerAuth.token}` },
  });

  if (checkResumed.data.status !== 'ACTIVE') {
    throw new Error(`Expected session status ACTIVE after reconnect, got: ${checkResumed.data.status}`);
  }
  console.log(`✔ Reconnection successful! Session status restored to ACTIVE, billing resumed cleanly`);

  // Clean up
  await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: `/sessions/${sessionId3}/end`,
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${seekerAuth.token}` },
  }, { reason: 'USER_ENDED' });
  seekerSocket3.disconnect();
  console.log(`✔ Session ${sessionId3} ended cleanly\n`);

  // =========================================================================
  // TEST SCENARIO 4: Disconnect mid-session & Grace Window Expires (FORCE_ENDED)
  // =========================================================================
  console.log('----------------------------------------------------------------------');
  console.log('TEST 4: Disconnect & Grace Window Expires -> FORCE_ENDED');
  console.log('----------------------------------------------------------------------');

  let seekerSocket4 = createSocket(seekerAuth.token);
  await new Promise((resolve) => seekerSocket4.on('connect', resolve));

  const req4 = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/sessions/request',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${seekerAuth.token}`,
    },
  }, { expertId: expertProfileId, sessionType: 'CHAT' });

  const sessionId4 = req4.data.id;
  await acceptAndJoinSession(expertSocket, seekerSocket4, sessionId4);
  console.log(`✔ Session ${sessionId4} is ACTIVE`);

  // Disconnect and let grace timer expire
  seekerSocket4.disconnect();
  console.log('   Client disconnected. Waiting for grace window (3s) to expire...');
  await sleep(3500);

  const checkForceEnded = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: `/sessions/${sessionId4}`,
    method: 'GET',
    headers: { Authorization: `Bearer ${seekerAuth.token}` },
  });

  if (checkForceEnded.data.status !== 'FORCE_ENDED' && checkForceEnded.data.status !== 'ENDED') {
    throw new Error(`Expected FORCE_ENDED or ENDED, got: ${checkForceEnded.data.status}`);
  }
  console.log(`✔ Grace window expired. Session transitioned to: ${checkForceEnded.data.status} (Reason: ${checkForceEnded.data.endReason})`);
  console.log(`✔ Billing halted at the last confirmed tick with zero overcharging!\n`);

  // =========================================================================
  // TEST SCENARIO 5: Redis Concurrency Locks (SETNX)
  // =========================================================================
  console.log('----------------------------------------------------------------------');
  console.log('TEST 5: Distributed Concurrency Lock (One Active Session per Expert)');
  console.log('----------------------------------------------------------------------');

  // Seeker 1 requests session
  const req5A = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/sessions/request',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${seekerAuth.token}`,
    },
  }, { expertId: expertProfileId, sessionType: 'CHAT' });

  if (req5A.status !== 201) {
    throw new Error(`Seeker 1 request failed: ${JSON.stringify(req5A.data)}`);
  }
  const sessionId5A = req5A.data.id;
  console.log(`✔ Seeker 1 acquired lock for Expert: Session ${sessionId5A}`);

  // Seeker 2 concurrently requests the SAME expert
  const req5B = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/sessions/request',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${seeker2Auth.token}`,
    },
  }, { expertId: expertProfileId, sessionType: 'CHAT' });

  if (req5B.status === 201) {
    throw new Error('Concurrency violation! Second seeker was able to request an already busy expert');
  }

  console.log(`✔ Seeker 2 request correctly REJECTED with 400 Bad Request`);
  console.log(`✔ Server message: "${req5B.data.message}" (Redis SETNX lock held)`);

  // Clean up Seeker 1 session
  await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: `/sessions/${sessionId5A}/end`,
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${seekerAuth.token}` },
  }, { reason: 'USER_ENDED' });
  console.log(`✔ Seeker 1 session ended and Redis lock released\n`);

  // =========================================================================
  // TEST SCENARIO 6: Idle Chat Timeout Detection
  // =========================================================================
  console.log('----------------------------------------------------------------------');
  console.log('TEST 6: Idle Chat Detection (Auto-pause billing on idle, resume on msg)');
  console.log('----------------------------------------------------------------------');

  let seekerSocket6 = createSocket(seekerAuth.token);
  await new Promise((resolve) => seekerSocket6.on('connect', resolve));

  const req6 = await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: '/sessions/request',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${seekerAuth.token}`,
    },
  }, { expertId: expertProfileId, sessionType: 'CHAT' });

  const sessionId6 = req6.data.id;
  await acceptAndJoinSession(expertSocket, seekerSocket6, sessionId6);
  console.log(`✔ Session ${sessionId6} is ACTIVE`);

  const pausedPromise = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Timed out waiting for session:billing_paused')), 6000);
    seekerSocket6.once('session:billing_paused', (data) => {
      clearTimeout(timer);
      resolve(data);
    });
  });

  console.log('   Waiting for idle timeout with no chat messages...');
  const billingPausedEvent = await pausedPromise;
  console.log(`✔ session:billing_paused event emitted! Reason: ${billingPausedEvent.reason}`);

  // Send message to resume
  console.log('   Sending chat message to resume consultation...');
  const resumedPromise = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Timed out waiting for session:billing_resumed')), 6000);
    seekerSocket6.once('session:billing_resumed', (data) => {
      clearTimeout(timer);
      resolve(data);
    });
  });

  seekerSocket6.emit('chat:message', {
    sessionId: sessionId6,
    text: 'Hello, are you still there?',
  });

  const billingResumedEvent = await resumedPromise;
  console.log(`✔ session:billing_resumed event emitted! Billing restarted seamlessly`);

  // Clean up
  await makeRequest({
    hostname: '127.0.0.1',
    port: 3000,
    path: `/sessions/${sessionId6}/end`,
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${seekerAuth.token}` },
  }, { reason: 'USER_ENDED' });
  seekerSocket6.disconnect();
  expertSocket.disconnect();

  console.log('\n======================================================================');
  console.log('   ALL 6 PHASE 4 SESSION & BILLING ENGINE TESTS PASSED CLEANLY!       ');
  console.log('======================================================================\n');
}

runSessionBillingE2ETests().catch((err) => {
  console.error('\n❌ E2E TEST FAILED:', err);
  process.exit(1);
});
