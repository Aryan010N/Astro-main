# Astrology App — Full Project Roadmap (Phase by Phase)

This covers everything from idea to post-launch, across Product, Design, Engineering (User App + Expert App + Admin + Backend), and Business/Legal.

---

## PHASE 0 — Planning & Foundations (Week 1–2)

**Goal:** Lock down scope before writing code.

- [ ] Define MVP scope (recommend: Chat only first, no calls/video yet)
- [ ] Finalize monetization model (commission %, wallet recharge slabs)
- [ ] Choose tech stack (Flutter + Node/NestJS + PostgreSQL + Redis + Firebase for push/presence)
- [ ] Choose 3rd-party vendors:
  - Chat/call infra: Agora / Twilio / ZegoCloud
  - Payment gateway: Razorpay / Cashfree / Stripe
  - OTP: Firebase Auth / MSG91
  - Payouts: Razorpay Payouts / Cashfree Payouts
- [ ] Company/legal setup: business registration, payment gateway merchant account approval (can take 1–3 weeks — start early)
- [ ] Domain, cloud account (AWS/GCP), basic DevOps setup (CI/CD skeleton)

**Output:** Scope doc, tech stack doc, vendor accounts created.

---

## PHASE 1 — Design (Week 2–4, overlaps with Phase 0 tail end)

- [ ] Information architecture / user flow diagrams (User app, Expert app, Admin)
- [ ] Wireframes — all core screens
- [ ] UI design system: colors, typography (heading + body font pairing), spacing, component library
- [ ] High-fidelity mockups: Home, Expert listing, Expert profile, Chat screen, Wallet/Recharge, Call screen, Expert dashboard
- [ ] Design handoff (Figma) with exportable assets/icons

**Output:** Complete Figma file, design system ready for dev.

---

## PHASE 2 — Backend Foundation (Week 3–6)

- [ ] Database schema design: Users, Experts, Sessions, Wallet Ledger, Transactions, Reviews
- [ ] Auth service (OTP + JWT)
- [ ] User profile CRUD APIs
- [ ] Expert profile CRUD + KYC submission APIs
- [ ] Admin approval workflow (expert onboarding)
- [ ] Basic admin panel (even a simple internal tool) to approve/reject experts
- [ ] API documentation (Swagger/Postman)

**Output:** Auth + profile system fully working, testable via Postman.

---

## PHASE 3 — Wallet & Payment Gateway (Week 5–7) [COMPLETED]

**This phase is non-negotiable to get right before anything else — treat it like its own mini-project.**

- [x] Payment gateway integration (Razorpay Orders API shape, stubbed SDK with mock fallback)
- [x] Webhook handling + HMAC SHA256 signature verification + event idempotency
- [x] Wallet ledger design (append-only transaction log table `wallet_ledger`, running balance snapshots)
- [x] Atomic overdraft prevention (`SELECT ... FOR UPDATE` row-level locks)
- [x] Recharge flow end-to-end (Flutter app → create-order → simulation/webhook → wallet credit)
- [x] Transaction history API (`GET /wallet/transactions` & `GET /wallet/balance`)
- [x] End-to-end automated test suite covering credits, duplicate webhooks, failed payments, and concurrent race conditions

**Output:** A user can recharge a wallet and see balance update reliably, with full audit trail. Verified with 100% test pass rate.

---

## PHASE 4 — Presence, 1:1 Consultation & Billing Engine (Section 7A) [COMPLETED]

**Implemented against Section 7A of astro-app-system-design.md:**

- [x] Exact state machine implemented: `REQUESTED` → `ACCEPTED` → `CONNECTING` → `ACTIVE` → `ENDED` → `BILLED` → `SUMMARY_SHOWN`, plus `RECONNECTING` and `FORCE_ENDED` paths
- [x] Redis-backed real-time presence system (`ONLINE`, `OFFLINE`, `BUSY`) with sub-second WebSocket broadcasts
- [x] 30–45s silent request timeout with zero wallet impact and expert response metric logging (`missedRequests`)
- [x] Per-second billing granularity starting strictly at `ACTIVE` (never at `ACCEPTED`) using server timestamp only
- [x] 5–10s periodic billing ticks reusing Phase 3 atomic wallet deduction (`SESSION_CHARGE`)
- [x] Chat idle detection (auto-pauses billing after idle timeout, resumes immediately upon next message)
- [x] 15–20s reconnection grace window (`RECONNECTING`), pause billing, resume on reconnect, auto `FORCE_ENDED` if window expires (billing stopped at last confirmed tick)
- [x] Redis distributed concurrency locks (`SETNX`) enforcing one active/accepted session per expert
- [x] Full Flutter UI in `apps/user-app` (live presence indicators, start consultation, chat screen with mirrored billing timer, summary modal)
- [x] Full Flutter UI in `apps/expert-app` (30s incoming request countdown dialog, accept/reject, live consultation screen)
- [x] Automated end-to-end test suite (`tests/session-billing-e2e.mjs`) verifying all 6 mandatory test scenarios with 100% pass rate

**Output:** Robust, fraud-resilient 1:1 consultation and per-second billing engine verified end-to-end against containerized PostgreSQL and Redis.

---

## PHASE 5 — Chat Module + Billing Engine (Week 7–10)

- [ ] Chat UI (user + expert side) — text, images, read receipts
- [ ] Session request → accept/reject/timeout flow
- [ ] **Per-minute billing engine**: live deduction every N seconds while session is active
- [ ] Low-balance warning + auto-end-session logic
- [ ] Session summary screen (duration, amount charged)
- [ ] Chat history storage & retrieval

**Output:** A user can chat with an expert and get billed correctly in real time — this is your MVP core.

---

## PHASE 6 — Reviews, Profiles & Discovery (Week 9–11)

- [ ] Expert listing with filters (expertise, language, price, rating)
- [ ] Expert profile page (full detail + reviews)
- [ ] Rating & review submission flow
- [ ] Search functionality
- [ ] "Top Astrologer" / "New" / "Offer" sorting logic

**Output:** Full discovery experience — users can find and evaluate experts easily.

---

## PHASE 7 — Free Tools (Acquisition Funnel) (Week 10–12, can run parallel to Phase 6)

- [ ] Astrology calculation engine integration (kundli/birth chart — build in-house or license a library/API)
- [ ] Free daily horoscope screen
- [ ] Free kundli generation flow
- [ ] Compatibility/match-making calculator
- [ ] CTA nudges from free tools → paid chat

**Output:** Free, no-login-required (or light-login) tools that drive installs.

---

## PHASE 8 — Audio & Video Calling (Week 12–15)

- [ ] Agora/Twilio SDK integration (both platforms)
- [ ] Call UI (incoming/outgoing, mute, speaker, end call)
- [ ] Call-specific billing (same engine as chat, different rate)
- [ ] Video call UI + camera permissions handling
- [ ] Call quality fallback handling (auto-reconnect, poor network UX)

**Output:** Full chat + audio + video session suite live.

---

## PHASE 9 — Expert App Completion (Week 13–16, runs parallel with Phase 8)

- [ ] Expert earnings dashboard (session breakdown, commission split shown transparently)
- [ ] Payout request flow + integration with payout gateway
- [ ] Expert analytics (session count, repeat clients, response time)
- [ ] Client notes feature
- [ ] Badges/gamification (Verified, Top Rated, Fast Responder)

**Output:** Experts can fully manage their business from the app.

---

## PHASE 10 — E-Commerce Add-on (Week 15–17, optional for v1, common for v2)

- [ ] Product catalog (gemstones, rudraksha, pooja items)
- [ ] Cart + checkout (reuses payment gateway from Phase 3)
- [ ] Order tracking
- [ ] Inventory/admin management for products

**Output:** Secondary revenue stream live.

---

## PHASE 11 — Admin Panel Full Build (Week 10–18, continuous)

- [ ] Expert approval/rejection with document review
- [ ] Commission rate configuration (global + per-expert override)
- [ ] Dispute resolution tools (refunds, session replay/logs)
- [ ] Content management (banners, offers, push campaign triggers)
- [ ] Analytics dashboard (DAU, revenue, session volume, top experts)

**Output:** Operations team can run the platform without engineering involvement for routine tasks.

---

## PHASE 12 — QA & Hardening (Week 16–19)

- [ ] Full regression testing (manual + automated where feasible)
- [ ] Load testing on billing engine and socket server (simulate concurrent sessions)
- [ ] Payment edge-case testing (double charge, webhook failure, network drop mid-session)
- [ ] Security review (API auth, wallet tampering prevention, rate limiting)
- [ ] Accessibility pass
- [ ] Crash reporting setup (Firebase Crashlytics/Sentry)

**Output:** App is stable under real-world failure conditions, not just the happy path.

---

## PHASE 13 — Store Submission & Compliance (Week 18–20)

- [ ] App Store (iOS) requirements: Apple Sign-In if Google Sign-In offered, Account Deletion flow, Privacy Nutrition Labels, App Tracking Transparency if applicable
- [ ] Google Play requirements: Data Safety form, target API level compliance
- [ ] Privacy Policy + Terms of Service (especially important given payments + personal birth data)
- [ ] Payment gateway compliance (PCI-DSS handled by gateway, but verify your flow doesn't store card data)
- [ ] Submit to both stores, handle review feedback/rejections

**Output:** App live on both App Store and Google Play.

---

## PHASE 14 — Launch & Growth (Week 20+, ongoing)

- [ ] Soft launch to limited audience, monitor billing accuracy closely
- [ ] Referral program activation
- [ ] Marketing funnel: free tools → app install → first paid session incentive (e.g., "first 3 minutes free")
- [ ] Expert acquisition drive (more experts = better availability = better retention)
- [ ] Monitor key metrics: session completion rate, wallet recharge rate, expert response time, churn

**Output:** Live, monetizing product with a feedback loop for v2 features.

---

## Rough Timeline Summary

| Phase | Duration | Can Run Parallel With |
|---|---|---|
| 0. Planning | 2 weeks | — |
| 1. Design | 2–3 weeks | Phase 0 tail |
| 2. Backend Foundation | 3–4 weeks | Phase 1 |
| 3. Wallet & Payments | 2–3 weeks | Phase 2 tail |
| 4. Real-time Infra | 2 weeks | Phase 3 |
| 5. Chat + Billing | 3–4 weeks | — |
| 6. Discovery/Reviews | 2–3 weeks | Phase 7 |
| 7. Free Tools | 2–3 weeks | Phase 6 |
| 8. Calling | 3–4 weeks | Phase 9 |
| 9. Expert App completion | 3–4 weeks | Phase 8 |
| 10. E-commerce | 2–3 weeks (optional v1) | Phase 11 |
| 11. Admin Panel | Continuous through above | — |
| 12. QA & Hardening | 3 weeks | — |
| 13. Store Submission | 2 weeks | — |
| 14. Launch | Ongoing | — |

**Realistic total for a lean team (3–5 engineers) to reach store-live MVP (Phases 0–7 + minimal 11–13): ~4–5 months.**
**Full-featured version with calls, e-commerce, polished expert tools: ~7–9 months.**

---

*Next: want a one-page MVP-only version of this (cutting straight to Phases 0, 1, 2, 3, 5, 12, 13 for the fastest path to a working chat-only app)?*
