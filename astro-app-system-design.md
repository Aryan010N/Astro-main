# Astrology Consultation App — System Design

## 1. High-Level System Overview

Three apps/panels sit on top of one shared backend:

| App | Platform | Purpose |
|---|---|---|
| User App | Flutter (Android + iOS) | Browse experts, chat/call, recharge wallet, free tools |
| Expert App | Flutter (Android + iOS) | Accept sessions, manage availability, view earnings, withdraw |
| Admin Panel | Web (React/Next.js) | Manage users, experts, payments, disputes, content |

All three talk to the same backend via REST + WebSocket APIs.

```
[User App] ---\
               \
[Expert App] ---+---> [API Gateway] ---> [Backend Services] ---> [DB / Redis / Storage]
               /
[Admin Panel]-/
```

---

## 2. USER SIDE — Full Flow

### 2.1 Onboarding
1. Open app → Splash → Language selection (optional)
2. Sign up via Phone Number → OTP verification (Firebase Auth / MSG91 / Twilio Verify)
3. Basic profile: Name, DOB, Time of Birth, Place of Birth (needed for kundli/chart generation), Gender
4. Optional: Google/Apple sign-in for faster onboarding (Apple Sign-In is **mandatory** if you offer Google Sign-In on iOS, per App Store rules)

### 2.2 Home Screen
- Banner carousel (offers, festivals, free recharge promos)
- Categories: Chat, Call, Video Call, Live sessions, Free Kundli, Horoscope, Match-making
- Astrologer list — filterable by: Expertise (Vedic/Tarot/Numerology/Vastu), Language, Price, Rating, Online status
- "Top Astrologers" / "New Astrologers" / "Offer Astrologers" rails

### 2.3 Expert Profile Page
- Photo, name, experience, languages, expertise tags
- Price per minute (chat/call/video may differ)
- Rating + reviews
- Online / Busy / Offline status (real-time)
- CTA: Chat Now / Call Now / Video Call (disabled if offline, or shows "Notify when online")

### 2.4 Wallet & Recharge (critical path — must be solid)
1. User taps Chat/Call → system checks wallet balance
2. If balance < minimum threshold (e.g., enough for 3 minutes) → forced recharge screen
3. Recharge options: ₹100 / ₹500 / ₹1000 / Custom amount
4. Payment Gateway screen (see Section 4)
5. On success → wallet credited → ledger entry created → user redirected back to session

### 2.5 Session Flow (Chat / Call / Video)
1. User taps "Chat Now" → request sent to expert (push notification + in-app socket event)
2. Expert accepts within timeout window (e.g., 30s) → session starts
   - If expert doesn't respond → auto-cancel, suggest alternate expert
3. **Billing engine starts a per-second/per-minute timer** the moment both parties connect
4. Every tick (e.g., every 10–15 sec), backend deducts proportional amount from user wallet in real time
5. If wallet hits zero → grace warning ("30 seconds left, recharge now") → auto-end session if not recharged
6. Either party can end session manually
7. Session summary shown: duration, amount charged, option to recharge & continue

### 2.6 Post-Session
- Rate & review expert (1–5 stars + comment)
- Option to re-chat / follow-up
- Order remedies (gemstones, rudraksha, pooja items) — e-commerce flow with cart + checkout
- Push notification follow-ups ("Your astrologer is online now")

### 2.7 Free Tools (acquisition funnel — no wallet needed)
- Free daily horoscope
- Free kundli/birth chart generation (via astrology calculation library/API)
- Compatibility/match-making calculator
- These screens always end with a CTA nudging toward a paid chat session

### 2.8 Other User-Side Screens
- Wallet history / transaction statements
- Order history (remedies)
- Chat history with past experts
- Referral program (refer & earn wallet credit)
- Support / Help center (chatbot + ticket system)
- Settings: notifications, language, delete account (mandatory for both app stores)

---

## 3. EXPERT (ASTROLOGER) SIDE — Full Flow

### 3.1 Onboarding & Verification (gatekept — not instant like user signup)
1. Sign up with phone/email
2. Submit KYC: ID proof, experience certificates/credentials, bank/UPI details for payout
3. Profile setup: bio, expertise tags, languages, sample consultation (optional video intro)
4. **Manual admin approval step** before the expert goes live — quality control is core to trust in this business
5. Once approved → profile goes live in user-facing listing

### 3.2 Availability & Status Management
- Toggle: Online / Busy / Offline / On Break
- Set working hours / auto-offline schedule
- Set per-minute rates for chat, call, video (within admin-defined min/max band)

### 3.3 Incoming Session Handling
1. Push notification + in-app alert on new chat/call request
2. Accept / Reject / Auto-timeout
3. If busy — request goes to a queue or gets routed to next available expert
4. Session UI mirrors the user side (same billing timer, chat/call interface)

### 3.4 Earnings & Payouts
- Live earnings dashboard: today / this week / this month
- Per-session breakdown (gross amount, platform commission, net earning)
- Minimum payout threshold (e.g., ₹500)
- Payout request → Admin/automated approval → Bank transfer / UPI payout (via Razorpay Payouts, Cashfree Payouts, etc.)
- TDS/tax deduction handling if applicable (relevant for Indian market)

### 3.5 Performance & Growth Tools
- Rating & review dashboard
- Analytics: session count, repeat clients, avg session duration, response time
- "Featured Astrologer" paid promotion option
- Badges: Verified, Top Rated, Fast Responder (gamification to improve engagement)

### 3.6 Other Expert-Side Screens
- Chat/call history
- Client notes (private notes on repeat clients — useful, sticky feature)
- Support for expert-specific issues (payout delays, technical issues)

---

## 4. Payment Gateway Flow (shared backend logic)

```
User initiates recharge
        │
        ▼
App calls Backend: "create order" (amount, userId)
        │
        ▼
Backend calls Payment Gateway API (Razorpay/Stripe/Cashfree) → gets order_id
        │
        ▼
App opens Gateway SDK checkout (card/UPI/netbanking/wallet)
        │
        ▼
User completes payment
        │
        ▼
Gateway sends webhook to Backend (payment success/failure)
        │
        ▼
Backend verifies signature → credits wallet → writes ledger entry
        │
        ▼
Push confirmation to app (via socket or FCM) → UI updates instantly
```

**Important implementation details:**
- Always confirm payment via **server-side webhook**, never trust only the client-side SDK success callback (client callback can be spoofed/interrupted)
- Maintain an immutable **wallet ledger** (append-only transaction log), not just a single balance field — needed for audits, disputes, refunds
- Support UPI (India), cards, net banking, and possibly Apple Pay/Google Pay for smoother iOS/Android checkout
- Handle refunds for failed/disconnected sessions (partial session = partial refund logic)

---

## 5. Money Flow Summary (who earns what)

| Revenue Stream | Mechanism |
|---|---|
| Session commission | Platform takes a % cut of every chat/call/video minute billed |
| Wallet float/breakage | Prepaid wallet cash held upfront; some balance never used |
| E-commerce | Margin on gemstones/remedies sold in-app |
| Featured listing fees | Experts pay/accept lower commission for better visibility |
| Subscriptions (optional) | Bundled free minutes / priority access plans |

---

## 5A. Backend & Infra Stack (Final)

| Layer | Technology | Notes |
|---|---|---|
| User/Expert App | Flutter (Android + iOS) | One codebase |
| Admin Panel | **React + Next.js + Ant Design** | Data-heavy UI (tables, filters, charts) suits React better than Flutter Web |
| API Backend | Node.js + NestJS | Same backend serves user app, expert app, AND admin panel (RBAC-protected admin routes) |
| Real-time | Socket.io + Redis | Chat, presence, call signaling |
| Primary DB | PostgreSQL | Users, experts, wallet ledger, transactions, sessions, reviews |
| Ephemeral/fast state | Redis | Online status, active session timers, rate limiting |
| Calling | Agora.io / Twilio Video | WebRTC infra, Flutter SDKs available |
| Payments | Razorpay / Cashfree (India) or Stripe (global) | Webhook-verified, server-owned wallet ledger |
| Storage | AWS S3 | Profile photos, chat images, KYC docs |
| Push notifications | Firebase Cloud Messaging | Android + iOS |
| Hosting | AWS / GCP | EC2/Compute + managed Postgres (RDS) + managed Redis (ElastiCache) + load balancer |
| Error/crash monitoring | Sentry + Firebase Crashlytics | Separate from admin panel — for the engineering team |
| Infra monitoring | Grafana + Prometheus, or CloudWatch | Server health, API latency, socket connection count |
| Log aggregation | Datadog / ELK stack | Optional, useful once you scale |
| Live streaming / group sessions | Agora/Twilio broadcast mode or 100ms.live | Separate from 1:1 call infra — needed if adding Live Sessions feature |
| Birth chart/ephemeris calculation | Prokerala API / AstrologyAPI / Swiss Ephemeris (self-hosted) | Buy/license — see Section 8A |
| AI chat tier (optional) | OpenAI/Anthropic/Gemini API | If adding an "AI Astrologer" free/low-cost tier |
| Image moderation (optional) | AWS Rekognition / Google Cloud Vision | Needed only if supporting palm/face-reading photo uploads |

## 5B. Admin Panel — Functional Scope

1. **Expert Management** — KYC review/approve/reject, suspend/ban, commission rate overrides, featured placement
2. **User Management** — search/view profiles & session history, manual wallet adjustment (with mandatory audit log), ban/flag users
3. **Session & Billing Monitoring** — live view of active sessions, full billing audit trail per session, dispute resolution tool (chat/call log + billing breakdown)
4. **Financial Dashboard** — revenue breakdown (commission / e-commerce / featured listings), payout approval queue, gateway reconciliation (DB totals vs gateway reports)
5. **Content & Growth** — push notification campaign sender (segment targeting), banner/offer management, blog/content management (optional)
6. **Analytics** — DAU/MAU, session completion rate, avg session value, expert response time, cohort retention (free-tool → paid conversion)
7. **System Health** — error/crash log viewer pulled from Sentry/Crashlytics (actual infra dashboards like Grafana stay separate, for engineers only)

**Access control:** role-based (`super_admin`, `support_agent`, `finance`, etc.) enforced at the API level, not just hidden in the UI.

## 6. Core Backend Services Needed

| Service | Responsibility |
|---|---|
| Auth Service | OTP, JWT sessions, social login |
| User/Expert Profile Service | CRUD profiles, KYC status |
| Presence Service | Real-time online/offline/busy status (Redis + WebSocket) |
| Session/Call Service | Session lifecycle, Agora/Twilio token generation |
| Billing Engine | Real-time per-minute wallet deduction, ledger writes |
| Wallet Service | Balance, recharge, refunds, payout requests |
| Payment Service | Gateway integration, webhook verification |
| Notification Service | FCM push, in-app alerts |
| Astrology Calculation Service | Kundli/horoscope generation (own engine or 3rd-party API) |
| Admin Service | Approvals, commission config, dispute resolution, content management, RBAC |
| Analytics Service | Event tracking, cohort/retention computation, dashboard aggregation |
| Astrology Calculation Service | Kundli/horoscope generation (own engine or 3rd-party API) |

---

## 7. Suggested Build Order (MVP → Full Product)

1. Auth + profiles (user & expert) + admin approval flow
2. Wallet + payment gateway + ledger (get this bulletproof first)
3. Expert listing + presence (online/offline)
4. Chat module + real-time billing engine
5. Reviews/ratings + post-session flow
6. Free tools (horoscope/kundli) for acquisition
7. Audio call → Video call (via Agora/Twilio)
8. Expert payouts
9. E-commerce (remedies)
10. Admin dashboard enhancements, analytics, featured listings

---

## 7A. 1:1 Session & Call Engine — Detailed Spec (Critical Path)

This is the single most failure-prone part of the whole system — it's where money, real-time infra, and UX all collide. Treat this section as the spec the backend team builds against.

### 7A.1 Session State Machine

```
REQUESTED ──(expert accepts, within timeout)──► ACCEPTED
   │                                                │
   │(timeout / expert rejects)                      │(media negotiation)
   ▼                                                 ▼
CANCELLED (no billing)                          CONNECTING
                                                      │
                                      (media flowing, both sides confirmed)
                                                      │
                                                      ▼
                                                 ACTIVE ◄──┐
                                                 │   │     │ (reconnect within grace window)
                          (either ends, or wallet=0)│   │(network drop)
                                                 │   ▼     │
                                                 │  RECONNECTING ──┘
                                                 ▼
                                             ENDED ──► BILLED ──► SUMMARY_SHOWN
                                                 │
                                   (reconnect grace window expires)
                                                 ▼
                                          FORCE_ENDED (server timeout)
```

**Critical rule: billing only runs during `ACTIVE`.** Never during `REQUESTED`, `ACCEPTED`, or `CONNECTING` — these are "accept" and "handshake" states, not "service delivered" states. Conflating "accepted" with "billing starts" is the single most common overbilling bug in this type of app.

### 7A.2 Who Owns What (Agora/Twilio vs. Your Backend)
- Agora/Twilio: media transport only (audio/video/screen packets, ICE/STUN/TURN relay). They fire **connection state callbacks** (user joined channel, user left channel, connection quality) — your backend subscribes to these.
- Your backend: generates session tokens, listens to the SDK's server-side webhooks/callbacks to know exact connect/disconnect timestamps, and runs the billing timer **independently** using those timestamps — never trust client-reported "I connected" events alone, always reconcile against server-side callbacks, since a compromised/modified client app could fake a "connected late" event to under-report billable time.

### 7A.3 Billing Mechanics — Decisions to Lock Before Coding
| Decision | Recommended default | Why |
|---|---|---|
| Granularity | Per-second, rounded up to nearest second | Fairer to users than per-minute rounding; matches what current competitor apps do |
| Billing trigger | Starts at `ACTIVE` (media confirmed both sides), not at `ACCEPTED` | Prevents charging for connection/handshake lag |
| Tick interval | Deduct from wallet every 5–10 seconds (not every single second) | Reduces DB write load; still feels "live" to the user |
| Time source | **Server clock only**, never client device time | Client clocks can be wrong/manipulated; server timestamp is the only source of truth for the ledger |
| Idle/inactivity (chat only) | Auto-pause billing after 3–5 min of no message from either side, resume on next message | Prevents silently draining wallet on an abandoned chat window |
| Rounding on session end | Round down to the last fully-elapsed second at `ENDED` timestamp | Avoid overcharging the final partial second |

### 7A.4 Failure & Edge-Case Handling
- **Call connects but no media flows** (ICE negotiation fails): must emit a distinct `CONNECT_FAILED` state, auto-refund any pre-auth hold, do not touch wallet balance
- **Network drop mid-session**: enter `RECONNECTING`, pause billing, give a grace window (e.g. 15–20 sec); if reconnect succeeds, resume billing from pause point; if grace window expires, `FORCE_ENDED` and bill only up to the last confirmed `ACTIVE` tick
- **Expert app crash/force-close without ending**: server-side heartbeat — if no keep-alive signal from expert's client within X seconds during `ACTIVE`, auto-`FORCE_ENDED`, stop billing, flag session for review
- **Double-accept / race condition**: lock each expert to one `ACTIVE`/`ACCEPTED` session at a time at the **database level** (not just UI-disabled) — use a unique constraint or distributed lock (Redis `SETNX`), because two simultaneous requests hitting the accept endpoint in the same millisecond is a real scenario at scale
- **User opens two session requests with two different experts simultaneously**: decide if this is allowed (probably yes, since they're paying) — but each must deduct from the **same wallet** correctly, meaning wallet deduction itself must be atomic/locked per-user to prevent two concurrent sessions over-drafting the balance below zero
- **Mid-session chat→call upgrade**: close the chat session cleanly (bill what's used), start a **new** call session with its own ledger entries — never blend two rate types into one entry, it breaks auditability
- **Video quality degrades → downgrade to audio-only**: allow mid-session, but treat as a **rate change event** — log the exact second the rate changed so the ledger entry splits into "video portion" + "audio portion," each billed correctly
- **Silent reject (expert never responds)**: hard timeout at 30–45 sec → auto-`CANCELLED`, zero wallet impact, but **log it against the expert's response-time metric** (feeds into their discovery ranking — repeated silent-rejects should push them down in search)

### 7A.5 Fraud & Abuse Prevention (often overlooked)
- **Fake "connected" spoofing**: a modified client could claim it connected earlier than it did to make a session look longer (benefits a dishonest expert) — always reconcile against Agora/Twilio's own server-side event logs, never trust only what either client reports
- **Self-dealing**: an expert using a second account to "consult themselves" and drain wallet-to-wallet (money laundering/promo abuse pattern) — needs device fingerprinting + flagging same-device user+expert account pairs
- **Promo/free-minute abuse**: if you offer "first 3 minutes free," prevent a user from creating multiple accounts (same phone/device) to repeatedly claim it — tie free-minute eligibility to verified phone number + device ID, not just account ID
- **Session recording & consent**: if you record calls for dispute resolution/QA (recommended), you are legally required in most jurisdictions (including India) to **notify both parties and get consent** before recording starts — build this as an explicit in-call banner/consent step, not a silent background feature

### 7A.6 Dispute & Refund Window
- Keep the **full billing ledger per session** (every tick, every second billed) retrievable for at least 90 days — this is your evidence when a user disputes a charge
- Define a concrete refund policy window (e.g., user can raise a dispute within 24–48 hours of session end) and whether disputes are auto-resolved (e.g., auto-refund if session duration < 10 seconds, likely a connection failure) vs. requiring manual admin review

### 7A.7 Multi-Device / Session Integrity
- Prevent a user from running the **same active session on two devices** simultaneously (e.g., logged in on phone + tablet) — enforce single active session per user account, force-logout older session or block the new one
- Session tokens (for Agora/Twilio) must be **short-lived and single-use** per session — don't issue a long-lived token that could be replayed to rejoin a call after it's ended

---

## 8. What's Still Missing / Not Yet Covered

### 8.1 Feature gaps vs. a real Astrotalk-style app
Based on what current live apps in this category actually ship, these weren't in the earlier docs and should be scoped in:

- **Panchang** — daily auspicious timings (Rahu Kaal, Shubh Muhurat, Tithi, Nakshatra) — a free daily-use screen, strong retention driver
- **Transit alerts** — push notifications when a planet changes sign (Saturn/Jupiter transit etc.) — notification-only feature, cheap to build, high engagement
- **Live Group Sessions / Live Streaming** — astrologers host live audio/video sessions many users can join at once (like a webinar), with in-session paid gifting/questions — this is a **separate feature from 1:1 chat/call** and needs its own streaming infra (not just Agora 1:1 calls — needs Agora/Twilio's live-streaming/broadcast mode or a dedicated service like 100ms)
- **AI Astrologer Chat** — an AI-powered chat tier (unlimited, cheaper than live experts) that answers using birth details — increasingly standard in 2026 apps as a free/low-cost funnel before upselling to a real expert
- **Palm reading / face reading (via photo upload)** — niche but present in several competitor apps — needs image upload + either expert review or AI analysis
- **Synastry / relationship compatibility reports** (beyond basic match-making) — full compatibility charts between two people's birth data
- **Multiple chart systems** (Vedic vs Western, Placidus vs Whole Sign house systems) — decide which systems you support; affects the calculation engine choice
- **Astro Mall / Shop** — covered already as "e-commerce," but worth explicitly noting competitors sell **pooja booking** (temple rituals performed on your behalf) as a service, not just physical products
- **Written/PDF reports** — paid detailed reports (career, marriage, health) generated and delivered as downloadable PDFs, not just live sessions — a separate revenue line with its own fulfillment flow (some are automated, some need an expert to manually write/review)

### 8.2 Process/infra gaps (carried over, still valid)
- **Astrology calculation engine itself** — kundli/birth chart math is a real sub-project (planetary positions, dasha calculations, chart rendering). Decide: build in-house (needs an astrology-domain developer) vs license an existing API/library
- **Multi-language support** — decide scope (English-only MVP vs multi-language from day 1 — affects both UI and expert filtering)
- **Session queueing logic** — exact rules for what happens when an expert is busy
- **Dispute/refund policy** — concrete rules needed before the billing engine's edge cases can be coded
- **Content moderation** — chat message moderation (profanity filter, reported message review in admin panel)
- **Tax/compliance** — GST handling on commission (India), TDS deduction on expert payouts, invoice generation
- **Data privacy for birth data** — DOB/time/place of birth is sensitive; needs a clear privacy policy and secure storage approach
- **Scaling plan for Socket servers** — plan for horizontal scaling (Redis pub/sub across instances) before launch marketing kicks in
- **Customer support flow** — in-app chatbot vs ticket system vs live agent
- **App Store/Play Store compliance specifics** — Apple Sign-In requirement, Account Deletion flow, Data Safety form

## 8A. Build vs. Buy — What to Outsource to Third-Party Services vs Build In-House

This is the real leverage point for moving fast without reinventing solved problems.

### Buy / Use a Third-Party Service For:
| Capability | Use This Instead of Building | Why |
|---|---|---|
| OTP/Auth | Firebase Auth / MSG91 | Solved problem, security-sensitive, not worth owning |
| 1:1 Audio/Video calling (WebRTC) | Agora.io / Twilio Video / ZegoCloud | WebRTC infra is genuinely hard (NAT traversal, codec handling, global relay servers) — nobody builds this from scratch anymore |
| Live streaming / group sessions | Agora/Twilio broadcast mode, or 100ms.live | Different infra from 1:1 calls — needs CDN-backed broadcast, don't build |
| Payment processing | Razorpay / Cashfree / Stripe | PCI-DSS compliance alone makes building this yourself a non-starter |
| Payouts to experts | Razorpay Payouts / Cashfree Payouts | Bank transfer rails, compliance, KYC verification all handled |
| Push notifications | Firebase Cloud Messaging | Free, reliable, no reason to build |
| Birth chart / planetary calculations | Prokerala API / AstrologyAPI / FreeAstrologyAPI, or Swiss Ephemeris (open-source library, self-hosted) | The astronomical math (ephemeris data) is decades of accumulated precision — license it or wrap the open-source Swiss Ephemeris library rather than computing planetary positions yourself |
| Crash/error monitoring | Sentry + Firebase Crashlytics | Standard tooling, not a differentiator |
| Infra monitoring | Grafana + Prometheus / CloudWatch | Same — operational tooling, not product |
| Email/SMS transactional | Twilio SendGrid / MSG91 | Delivery infrastructure is a solved commodity problem |
| AI chat (if adding AI astrologer tier) | OpenAI/Anthropic/Gemini API, prompted with astrology context | Don't train your own model — prompt engineering on top of an existing LLM API is the entire feature |
| Image/content moderation (if needed for photo uploads — palm reading etc.) | AWS Rekognition / Google Cloud Vision moderation API | Don't build a moderation classifier yourself |

### Build In-House (this is your actual product/IP):
| Capability | Why It's Yours to Build |
|---|---|
| **Wallet ledger + per-minute billing engine** | This is your core business logic — money math, session-to-charge mapping, refund rules. No vendor can own this; it's the product's financial integrity |
| **Expert matching/discovery (filters, search, ranking)** | Your differentiation — how users find the right expert is a product decision, not infra |
| **Presence system (online/offline/busy) + session request/accept/queue flow** | Business-logic heavy, tightly coupled to your billing and UX — build on top of Redis, but the logic is yours |
| **Admin panel (approvals, dispute tools, analytics, RBAC)** | Operationally specific to how *you* run the platform |
| **Review/rating system** | Simple but core to trust — tightly tied to your session data model |
| **Expert earnings/commission calculation logic** | Your business rules (commission tiers, bonuses) — don't outsource |
| **Overall UI/UX, design system, Flutter app** | This is the actual product experience — your differentiation from every other Astrotalk clone |
| **Astrology content curation** (horoscope copy, Panchang data presentation) — *if* going beyond raw calculation API output | Optional, but what makes horoscope text feel non-generic is editorial/product work, not infra |

**Rule of thumb:** if a vendor already does it at scale for thousands of other apps (auth, payments, calling, push, monitoring, ephemeris math) — buy it. If it's the specific logic that makes your marketplace run and makes money correctly — build it yourself, because owning the billing/matching/admin layer is what actually makes this a defensible product rather than a reskinned template.

---

## 9. Full Requisites List

### A. Legal & Business
- [ ] Company registration
- [ ] Payment gateway merchant account (approval can take 1–3 weeks — start early)
- [ ] Payout gateway merchant account (Razorpay Payouts / Cashfree Payouts)
- [ ] Privacy Policy (must cover birth data, payment data, KYC docs)
- [ ] Terms of Service
- [ ] Expert agreement/contract template (commission terms, conduct policy)
- [ ] GST/tax registration (if applicable) + invoicing setup
- [ ] Apple Developer account ($99/year) + Google Play Developer account ($25 one-time)

### B. Design Assets
- [ ] Figma file: wireframes → high-fidelity mockups (User app, Expert app, Admin panel)
- [ ] Design system: color palette, font pairing (heading + body), spacing/radius rules
- [ ] Custom icon set (zodiac signs, categories — avoid generic stock)
- [ ] App icon + splash screen (Android + iOS specs differ — need both sizes)
- [ ] Store listing assets: screenshots, feature graphic, preview video (optional)

### C. Third-Party Accounts/API Keys Needed
- [ ] Firebase project (Auth, FCM, Crashlytics, Storage if used)
- [ ] Payment gateway account (Razorpay/Cashfree/Stripe) + API keys
- [ ] Payout gateway account + API keys
- [ ] Agora.io or Twilio account + API keys (calling)
- [ ] Astrology calculation API account (if licensing instead of building in-house)
- [ ] AWS or GCP account (hosting, S3/Storage, RDS, ElastiCache)
- [ ] Sentry account (error monitoring)
- [ ] Domain name + SSL certificate

### D. Engineering Setup
- [ ] Git repos (separate: user app, expert app, admin panel, backend — or monorepo if team prefers)
- [ ] CI/CD pipeline (GitHub Actions / Bitbucket Pipelines / GitLab CI)
- [ ] Staging + Production environments (separate DBs, separate gateway test/live keys)
- [ ] API documentation tool (Swagger/Postman collection, kept in sync with backend)
- [ ] Code review process / branching strategy (e.g., trunk-based or GitFlow)

### E. Team Roles Needed
- [ ] Flutter developer(s) — user + expert app
- [ ] React/Next.js developer — admin panel
- [ ] Backend developer(s) — NestJS, real-time, billing engine
- [ ] DevOps/infra (can be part-time or outsourced initially)
- [ ] UI/UX designer
- [ ] QA/testing (manual at minimum, automation later)
- [ ] Product/project manager (even part-time, to track the phase checklist)
- [ ] Legal/compliance advisor (for Terms, Privacy Policy, payment compliance)

### F. Pre-Launch Checklist
- [ ] Wallet/billing tested under failure conditions (network drop, double payment, webhook delay)
- [ ] Load test on Socket server with simulated concurrent sessions
- [ ] App Store + Play Store compliance items complete (Account Deletion, Apple Sign-In if needed, Data Safety form)
- [ ] Crash-free rate monitored in a closed beta before public launch
- [ ] Support channel live (even a simple ticket system) before go-live
- [ ] At least a minimum pool of verified, approved experts onboarded before opening to users (empty marketplace = bad first impression)

---

*Next possible deep-dives: wallet ledger schema design, Agora/Twilio per-minute billing integration, or Flutter state-management architecture for the real-time session screen.*
