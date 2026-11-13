# Astro App — Development Kickoff Prompt & Architecture Wiring Doc

> **How to use this file:** This is written to be pasted directly as a prompt/brief into an AI coding agent (Antigravity or similar) to begin actual development. It assumes two other docs already exist in project root and must be read first by the agent:
> - `astro-app-system-design.md` — full system design: user flow, expert flow, payment gateway flow, backend services, build-vs-buy breakdown, and the detailed 1:1 session/billing engine spec
> - `astro-app-project-phases.md` — phase-by-phase project roadmap with timeline
>
> This doc does **not** repeat those — it tells the agent how to connect the pieces (backend ↔ DB ↔ Flutter ↔ auth ↔ cloud), what the repo structure should look like, and the concrete prerequisite steps to get a working dev environment running against the existing GitHub repo.
>
> **Important constraint for whoever runs this prompt:** the agent should treat the two referenced MD files as the single source of truth for feature scope, billing rules, and tech stack choices. It should not invent new third-party vendors, new monetization mechanics, or change the session state machine already defined in the system design doc — it should implement against what's already decided, and only ask clarifying questions for things genuinely left open (e.g. exact DB field names, folder structure details) rather than re-deciding settled architecture questions.

---

## 1. Project Context (for the agent to read first)

- **Project:** Astrology consultation marketplace app (Astrotalk-style) — two mobile apps (User + Expert) built in Flutter for Android and iOS, one admin web panel in React/Next.js, one shared NestJS backend.
- **Repository:** `https://github.com/Aryan010N/Astro-main.git` — this is the existing repo. The agent must clone/work inside this repo, not create a new one. If the repo is currently empty or only partially scaffolded, the agent should check its current structure first (`git clone`, inspect root) before creating any new folders, to avoid duplicating or conflicting with whatever already exists there.
- **Core monetization:** per-minute billed chat/call/video sessions between users and astrologers, wallet-based prepaid model, commission split, e-commerce add-on, as detailed in the system design doc.
- **Stack already decided** (do not re-decide, just implement):
  - Frontend (User + Expert apps): **Flutter**
  - Admin panel: **React + Next.js + Ant Design**
  - Backend: **Node.js + NestJS**
  - Real-time: **Socket.io + Redis**
  - Primary DB: **PostgreSQL**
  - Calling: **Agora.io or Twilio Video** (pick one during setup, document the choice)
  - Payments: **Razorpay/Cashfree (India) or Stripe (global)**
  - Push notifications: **Firebase Cloud Messaging**
  - Storage: **AWS S3**
  - Hosting: **AWS or GCP**

---

## 2. Repository Structure to Set Up

Recommended as a **monorepo** (single repo, multiple apps) since the project is small-to-mid team size and the apps share types/contracts heavily. Confirm this fits what's already in `Astro-main` before restructuring.

```
Astro-main/
├── apps/
│   ├── user-app/              # Flutter — user-facing app
│   ├── expert-app/            # Flutter — expert-facing app (can share a core package with user-app)
│   ├── admin-panel/           # React + Next.js
│   └── backend/               # NestJS — single backend serving all three
├── packages/
│   ├── flutter-shared/        # Shared Flutter widgets/theme/models between user-app and expert-app
│   └── api-contracts/         # Shared TypeScript types/DTOs + OpenAPI spec, consumed by backend + admin-panel
├── infra/
│   ├── docker/                # Dockerfiles, docker-compose for local dev
│   └── ci-cd/                 # Pipeline configs
├── docs/
│   ├── astro-app-system-design.md
│   ├── astro-app-project-phases.md
│   └── astro-app-antigravity-dev-kickoff.md   (this file)
└── README.md
```

**Agent's first task:** inspect the current state of `Astro-main` and report back what already exists vs. what needs scaffolding, rather than assuming an empty repo.

---

## 3. How the Pieces Connect — Overall Architecture

```
┌─────────────┐     ┌─────────────┐     ┌──────────────┐
│  User App   │     │ Expert App  │     │ Admin Panel  │
│  (Flutter)  │     │  (Flutter)  │     │ (Next.js)    │
└──────┬──────┘     └──────┬──────┘     └──────┬───────┘
       │  REST (HTTPS)      │  REST (HTTPS)     │  REST (HTTPS)
       │  + WebSocket        │  + WebSocket      │  (admin routes only)
       └─────────┬───────────┴───────────┬───────┘
                  │                       │
                  ▼                       ▼
          ┌───────────────────────────────────┐
          │      NestJS Backend (API + WS)     │
          │  Auth | Wallet | Session | Expert  │
          │  Admin | Notification | Billing    │
          └───────────┬───────────┬────────────┘
                       │           │
            ┌──────────┘           └──────────┐
            ▼                                 ▼
    ┌───────────────┐                 ┌───────────────┐
    │  PostgreSQL   │                 │     Redis     │
    │ (source of    │                 │ (presence,    │
    │  truth: users,│                 │  session locks,│
    │  wallet ledger,│                 │  pub/sub,     │
    │  transactions)│                 │  rate limits) │
    └───────────────┘                 └───────────────┘
                       │
         ┌─────────────┼──────────────┬───────────────┐
         ▼             ▼              ▼               ▼
   ┌──────────┐  ┌───────────┐  ┌───────────┐  ┌─────────────┐
   │ Agora /  │  │ Razorpay/ │  │ Firebase  │  │   AWS S3    │
   │ Twilio   │  │ Stripe    │  │   FCM     │  │  (storage)  │
   │ (calls)  │  │ (payments)│  │ (push)    │  │             │
   └──────────┘  └───────────┘  └───────────┘  └─────────────┘
```

**Key connection principles the agent must follow:**
1. **All three frontends talk to one backend.** The admin panel does NOT get its own separate API — it hits the same NestJS backend, on routes protected by role-based guards (`@Roles('admin')` decorators in NestJS).
2. **Flutter apps use REST for CRUD, WebSocket (Socket.io client) for real-time** — session requests, presence updates, live chat messages, and billing ticks must come over the socket connection, not polled over REST.
3. **PostgreSQL is the single source of truth for money** — wallet balance, transactions, session billing records. Redis is never the source of truth for anything involving money; it's for speed (presence, locks, pub/sub) and can be rebuilt from Postgres if lost.
4. **Agora/Twilio never talk to your database directly** — they only handle media. Your backend subscribes to their server-side webhooks/callbacks and is the only thing writing billing data to Postgres, per the state machine already defined in the system design doc (Section 7A).
5. **The admin panel is just another API consumer** — it should use the same `api-contracts` package (shared types) as the Flutter apps, generated from the backend's OpenAPI/Swagger spec, so a field rename in the backend immediately surfaces as a type error in the frontend instead of a silent runtime bug.

---

## 4. Authentication — How It's Connected End to End

1. **OTP-based signup/login** (phone number) is the primary auth for both User and Expert apps.
   - Flutter app calls `POST /auth/otp/request` with phone number → backend calls Firebase Auth (or MSG91) to send OTP → backend returns a `requestId`
   - User enters OTP → Flutter calls `POST /auth/otp/verify` with `requestId` + OTP → backend verifies with the provider → on success, backend issues **its own JWT** (access token + refresh token) — don't just trust Firebase's client SDK token alone, always verify server-side and issue your own session token so you control expiry/revocation
2. **JWT strategy:**
   - Access token: short-lived (e.g., 15–30 min), sent in `Authorization: Bearer <token>` header on every REST call and attached to the Socket.io handshake (`auth: { token }`) for WebSocket auth
   - Refresh token: longer-lived (e.g., 30 days), stored securely on-device (Flutter `flutter_secure_storage`, not plain SharedPreferences), used to silently mint new access tokens
3. **Role differentiation:** the JWT payload includes a `role` claim (`user`, `expert`, `admin`, `support_agent`, etc.) — NestJS guards check this role on every protected route, this is how the same backend serves three different frontends safely
4. **Admin panel auth is separate in practice, same mechanism underneath:** admin users log in via email/password (not OTP) through a dedicated `/auth/admin/login` endpoint, but still get the same JWT structure with `role: admin`, so the rest of the guard/middleware logic doesn't need a separate code path
5. **Social login (optional, Phase 2):** if adding Google/Apple sign-in later — remember Apple Sign-In becomes *mandatory* the moment Google Sign-In is offered on iOS (App Store policy), so don't add Google-only social login on iOS
6. **Socket.io auth handshake:** every socket connection must validate the JWT on connect (`io.use((socket, next) => {...})` middleware in NestJS's Socket.io gateway) — an unauthenticated socket should never be allowed to subscribe to presence or session events

**Agent's task:** implement this exact flow first, before any other feature — auth is the dependency every other module needs (wallet, sessions, admin all require a valid authenticated user/expert/admin).

---

## 5. UI Design — How to Approach It

1. **Design tokens first, screens second.** Before building any screen, the agent should set up a Flutter theme file (`AppTheme` / `ThemeData`) with:
   - Font pairing: a distinctive heading font (e.g., **Fraunces** or **Lora** — geometric serif, mystical-but-modern) + clean sans-serif body font (**Inter**, **Manrope**, or **Plus Jakarta Sans**) — load via `google_fonts` package or bundle as assets
   - Color palette: avoid the generic red/orange zodiac-wheel look most competitor apps use — deep indigo/midnight + gold accent for premium feel, or soft pastel for a calmer/Gen-Z feel (pick one direction, don't mix)
   - Spacing scale (4/8/16/24/32px grid), border radius standard (16–20px for cards feels current), elevation/shadow standards
2. **Component library before full screens:** build reusable widgets first — `ExpertCard`, `WalletBalanceChip`, `OnlineStatusDot`, `SessionTimerBadge`, `PrimaryButton` — then compose screens from these, not the reverse. This keeps the User app and Expert app visually consistent since they'll share the `flutter-shared` package.
3. **State management:** use **Riverpod** or **Bloc** (pick one, stay consistent across both Flutter apps) — avoid plain `setState` for anything beyond trivial local UI state, since session/wallet state needs to be globally accessible and reactive to socket events arriving asynchronously.
4. **Custom icon set:** replace stock zodiac emoji/clipart with a custom illustrated icon set (can be built as SVGs converted to Flutter icon fonts, or `flutter_svg` package) — this is a cheap way to make the app feel non-templated, as already noted in the system design doc.
5. **Admin panel UI:** Ant Design components directly (`Table`, `Form`, `Statistic`, `Tabs`) — don't custom-build data tables/charts, Ant Design's admin-oriented components exist specifically so you don't have to.
6. **Design handoff reality check:** if no Figma file exists yet, the agent should NOT invent pixel-perfect designs from scratch for every screen — instead build functional screens against the theme/component system above, and treat visual polish as an iterative pass once core flows work. Functional-first, polish-second, for an MVP timeline.

---

## 6. Prerequisites & How to Fulfill Each One

This expands Section 9 ("Full Requisites List") from `astro-app-system-design.md` into **concrete setup steps** the agent (or dev team) should execute in order.

### Step 1 — Accounts & Credentials (must be done by a human, not the agent)
| Prerequisite | Action | Blocks |
|---|---|---|
| Firebase project | Create at console.firebase.google.com, enable Auth (Phone), FCM, Crashlytics | Auth module, push notifications |
| Payment gateway | Register Razorpay/Cashfree merchant account, get test + live API keys | Wallet/payment module |
| Agora or Twilio account | Sign up, create a project, get App ID/API keys | Calling module |
| AWS or GCP account | Create account, set up billing | Hosting, S3/storage, RDS, ElastiCache |
| Domain name | Purchase, point DNS to hosting once backend is deployed | Production API URL |
| Apple Developer account | $99/year, needed to build/sign/submit iOS app | iOS builds and TestFlight |
| Google Play Developer account | $25 one-time | Android builds and Play Console |

**The agent cannot create these accounts** — it should generate a checklist/`.env.example` file listing every credential needed, and pause/ask the human to supply real keys before proceeding to the modules that depend on them.

### Step 2 — Local Dev Environment Setup
1. Clone the repo: `git clone https://github.com/Aryan010N/Astro-main.git`
2. Install Flutter SDK (stable channel), verify with `flutter doctor` — resolve any missing Android/iOS toolchain issues before writing app code
3. Install Node.js (LTS version) + pnpm or yarn (pick one package manager, stay consistent across `backend` and `admin-panel`)
4. Install Docker Desktop (see Section 7 — yes, Docker is needed, explained below)
5. Set up PostgreSQL and Redis **locally via Docker Compose** (not installed natively) for consistent dev environments across the team
6. Create `.env` files (from `.env.example` templates) in `backend/`, populate with the real or sandbox/test keys from Step 1

### Step 3 — Backend Bootstrapping
1. Scaffold NestJS project in `apps/backend` (if not already present in repo) — `nest new backend`
2. Set up TypeORM or Prisma (pick one) connected to the Dockerized PostgreSQL
3. Implement Auth module first (per Section 4 above) — this unblocks everything else
4. Set up Swagger/OpenAPI auto-generation from day one, so `packages/api-contracts` can be generated from it rather than hand-written

### Step 4 — Flutter App Bootstrapping
1. Scaffold `user-app` and `expert-app` Flutter projects (if not already present)
2. Set up the shared `flutter-shared` package with the theme system (Section 5)
3. Wire up API client (e.g., `dio` package) pointed at the local backend URL during dev
4. Implement OTP login screen first, connected to the real Auth module from Step 3 — this is the first true end-to-end slice (Flutter → Backend → Firebase → Backend → Flutter) and validates the whole connection works before building anything else

### Step 5 — Admin Panel Bootstrapping
1. Scaffold Next.js project in `apps/admin-panel` (if not already present)
2. Install Ant Design, set up the admin login flow (email/password → same JWT backend endpoint)
3. Build the Expert Approval screen first — it's the simplest full-stack slice to validate the admin ↔ backend ↔ Postgres connection works

---

## 7. Docker — Is It Required?

**Yes, Docker is required**, for these specific reasons (not just "best practice" generically):

1. **Local dev parity with production** — PostgreSQL and Redis must behave identically on every developer's machine and in production; Docker Compose gives every team member the exact same DB/Redis version without "works on my machine" drift
2. **The backend itself should be containerized** for deployment — this is what makes it portable between AWS/GCP, and what most CI/CD pipelines (Section 8) expect as the deployment artifact
3. **Does NOT apply to Flutter apps** — Flutter apps are compiled to native binaries (APK/IPA) and are never Dockerized; Docker here is purely for backend + its dependent services (Postgres, Redis) + admin panel (Next.js can be containerized too, or deployed to Vercel if preferred — both are reasonable, Docker gives more hosting flexibility)

**Local dev setup:** `infra/docker/docker-compose.yml` should define:
```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: astro_dev
      POSTGRES_USER: astro
      POSTGRES_PASSWORD: devpassword
    ports: ["5432:5432"]
    volumes: ["pgdata:/var/lib/postgresql/data"]

  redis:
    image: redis:7
    ports: ["6379:6379"]

  backend:
    build: ../../apps/backend
    depends_on: [postgres, redis]
    env_file: ../../apps/backend/.env
    ports: ["3000:3000"]

volumes:
  pgdata:
```

**Production:** the same `backend` Dockerfile gets built and pushed to a container registry (AWS ECR or GCP Artifact Registry), then deployed to ECS/Fargate (AWS) or Cloud Run (GCP) — both let you run containers without managing raw VMs, which is the right level of complexity for a team this size (not Kubernetes yet — that's over-engineering for pre-launch).

---

## 8. CI/CD Pipeline — Recommended Setup

Yes, set this up early — it's cheap to do now and expensive to retrofit once multiple people are committing.

**Tool: GitHub Actions** (since the repo is already on GitHub — no reason to introduce a separate CI tool like Jenkins/CircleCI).

### Pipeline structure (`infra/ci-cd/` + `.github/workflows/`)

**1. `backend-ci.yml`** — triggers on PR to `main`/`develop` touching `apps/backend/**`
- Install dependencies
- Lint (ESLint)
- Run unit tests
- Run integration tests against a throwaway Postgres/Redis (via `services:` in GitHub Actions, or docker-compose in CI)
- Build Docker image (don't push yet, just verify it builds)

**2. `backend-cd.yml`** — triggers on merge to `main`
- Build Docker image, tag with git SHA
- Push to AWS ECR / GCP Artifact Registry
- Deploy to staging environment automatically
- Deploy to production — **manual approval gate** (GitHub Environments with required reviewers), never auto-deploy to prod for an app handling real money without a human sign-off

**3. `admin-panel-ci.yml` / `admin-panel-cd.yml`** — same pattern (lint, test, build, deploy to Vercel or containerized deploy), triggers on changes to `apps/admin-panel/**`

**4. `flutter-ci.yml`** — triggers on PR touching `apps/user-app/**` or `apps/expert-app/**`
- `flutter analyze` (lint)
- `flutter test` (unit/widget tests)
- Build a debug APK as a PR artifact (so reviewers can install and test the actual build)

**5. `flutter-release.yml`** — triggers on version tag push (e.g., `v1.0.0`)
- Build signed release APK/AAB (Android) and IPA (iOS) — requires signing secrets stored in GitHub Secrets (keystore, provisioning profiles)
- Upload to Play Console internal testing track / TestFlight automatically (via `fastlane`, which is the standard tool for this — don't hand-roll store upload scripts)

**Standards to follow:**
- Use **path-based triggers** (`paths:` filter in workflow YAML) so a Flutter-only change doesn't trigger a backend deploy and vice versa — this matters because it's a monorepo
- Store all secrets (API keys, signing certs, DB passwords) in **GitHub Secrets / Environments**, never committed, never in plain `.env` files in the repo
- Require **status checks to pass before merge** (branch protection rule on `main`) — lint + tests must be green
- Separate **staging and production environments** with separate credentials for everything (payment gateway test vs. live keys, separate Postgres instances) — this was already flagged in the system design doc's engineering setup checklist, this is where it's enforced

---

## 9. Cloud Data Processing — How Data Actually Flows

1. **Write path (e.g., a chat session ends):**
   - Flutter app sends final "end session" event over WebSocket → NestJS gateway receives it → backend writes the final billing ledger entry to PostgreSQL (RDS/Cloud SQL) → backend publishes an event to Redis pub/sub → any other backend instance (if horizontally scaled) picks up the event to update in-memory presence state → backend emits a WebSocket event back to both Flutter clients confirming session summary

2. **Read path (e.g., loading the expert list):**
   - Flutter app calls `GET /experts?filters=...` → NestJS queries PostgreSQL (with proper indexing on filter columns — expertise, language, rating) → for online/offline status specifically, backend checks Redis (fast, in-memory) rather than Postgres, since presence changes constantly and shouldn't hit the relational DB on every read

3. **Media/file data (profile photos, KYC docs, chat images):**
   - Flutter app requests a **pre-signed upload URL** from the backend (`POST /uploads/presign`) → backend generates a short-lived S3 pre-signed URL → Flutter app uploads directly to S3 (not through your backend server, to avoid your API server handling large binary payloads) → backend only stores the resulting S3 URL/key in Postgres

4. **Backups & data retention:**
   - PostgreSQL: automated daily snapshots (RDS/Cloud SQL built-in feature), retained per your compliance needs (financial transaction data often needs 5+ year retention in India depending on applicable regulations — confirm with the legal/compliance step from the system design doc)
   - Session billing ledger specifically: never hard-delete, only soft-delete/archive, since it's the audit trail for financial disputes (as already specified in Section 7A.6 of the system design doc — 90-day minimum retrieval window, but full historical archive should persist indefinitely in cold storage)

5. **Scaling consideration (not needed at launch, but the agent should not architect against it):**
   - Keep the backend **stateless** (no in-memory session data that isn't also in Redis) so it can run as multiple instances behind a load balancer later without a rewrite
   - Redis pub/sub is what allows multiple backend instances to stay in sync on presence/socket events — this is why Redis was chosen over in-memory-only state from the start

---

## 10. Build Order for the Agent (Concrete First Slice)

Don't start broad — build one vertical, fully-connected slice first to prove the architecture works, then expand. Recommended first slice:

1. Docker Compose running Postgres + Redis locally
2. NestJS backend: Auth module only (OTP request/verify, JWT issue) — connected to real Firebase Auth
3. User-app Flutter: phone number entry → OTP screen → successful login → lands on a placeholder home screen showing "Logged in as [phone number]"
4. This proves: Flutter ↔ Backend ↔ Firebase ↔ Postgres (user record created) ↔ JWT returned ↔ Flutter stores token securely

**Only once this slice works end-to-end** should the agent move to the next module (expert listing, then wallet, then sessions — following the phase order already defined in `astro-app-project-phases.md`).

---

## 11. Explicit Instructions to the Agent

- Read `astro-app-system-design.md` and `astro-app-project-phases.md` fully before writing any code.
- Do not introduce new vendors, payment providers, or architectural patterns not already named in those docs or this one — if a genuine gap exists, flag it as a question rather than silently deciding.
- Inspect the actual current state of `https://github.com/Aryan010N/Astro-main.git` before scaffolding anything, and report what already exists.
- Build the first vertical slice (Section 10) before touching any other feature.
- Ask for real API credentials where needed (Section 6, Step 1) rather than hardcoding placeholder keys that silently fail later.
- Flag, rather than guess, any detail not already specified in the three docs (e.g., exact Postgres column names, exact Redis key naming conventions) — propose a convention and confirm before applying it repo-wide.
