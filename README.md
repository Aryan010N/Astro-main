# Astro — Astrology Consultation Platform

> High-throughput, real-time consultation marketplace connecting seekers with verified astrologers for 1:1 live chat, audio, and video consultations. Built as a scalable monorepo with production-grade financial ledger mechanics and low-latency infrastructure.

[![CI Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()
[![Monorepo](https://img.shields.io/badge/pnpm-workspace-blue.svg)](https://pnpm.io/)
[![Flutter](https://img.shields.io/badge/Flutter-3.50.0-02569B.svg)](https://flutter.dev/)
[![NestJS](https://img.shields.io/badge/NestJS-10.x-E0234E.svg)](https://nestjs.com/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791.svg)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D.svg)](https://redis.io/)

---

## 1. Overview & Key Capabilities

Astro is an end-to-end consultation ecosystem inspired by high-concurrency consultation platforms like Astrotalk. It orchestrates real-time presence, per-minute billing state machines, strict append-only financial ledgers, and seamless live communications.

### Core Ecosystem Highlights

- **User Mobile App (`apps/user-app`):** High-conversion Flutter application featuring strict phone-number OTP authentication, real-time astrologer directory, instant recharge wallet flow, and 1:1 consultation interfaces.
- **Astrologer Partner App (`apps/expert-app`):** Dedicated Flutter application for verified astrologers to onboard through multi-step KYC verification, manage live consultation statuses (Online/Offline), set per-minute rates (Chat/Call/Video), and monitor payout earnings.
- **Admin & Compliance Portal (`apps/admin-panel`):** Next.js 14 & Ant Design dashboard for back-office operations, KYC dossier verification, astrologer approval/rejection workflows, financial monitoring, and session dispute resolution.
- **Backend API & Real-Time Engine (`apps/backend`):** NestJS modular monolith backed by PostgreSQL 16 (Prisma ORM) and Redis 7 for sub-second presence, session state machines, and distributed locking.
- **Shared Monorepo Packages (`packages/*`):** Single source of truth for cross-platform design tokens (`packages/flutter-shared`) and type-safe API contracts (`packages/api-contracts`).

---

## 2. Architecture & System Topology

```mermaid
flowchart TD
    subgraph Clients["Client Layer"]
        UA["User Flutter App\n(Android / iOS)"]
        EA["Expert Flutter App\n(Android / iOS)"]
        AP["Admin Panel\n(Next.js 14 + AntD)"]
    end

    subgraph Gateway["Edge & Gateway"]
        LB["Reverse Proxy / Ingress\n(HTTPS / WSS)"]
    end

    subgraph Backend["NestJS Modular Backend"]
        AUTH["Auth Module\n(Firebase Admin + JWT)"]
        EXP["Experts & KYC Module"]
        ADM["Admin Review Module"]
        WAL["Wallet & Ledger Module\n(Paise-precise)"]
        SES["1:1 Session Engine\n(State Machine)"]
    end

    subgraph Data["Persistence & Caching"]
        PG[("PostgreSQL 16\n(Prisma ORM)")]
        RD[("Redis 7\n(Sessions & Presence)")]
    end

    subgraph External["External Services"]
        FB["Firebase Auth\n(OTP / Identity)"]
        PGW["Payment Gateway\n(Razorpay / Cashfree)"]
        RTC["Live RTC Engine\n(Agora / Twilio)"]
    end

    UA -->|HTTPS / WSS| LB
    EA -->|HTTPS / WSS| LB
    AP -->|HTTPS / WSS| LB

    LB --> AUTH
    LB --> EXP
    LB --> ADM
    LB --> WAL
    LB --> SES

    AUTH <--> FB
    AUTH <--> RD
    AUTH <--> PG

    EXP <--> PG
    ADM <--> PG

    WAL <--> PGW
    WAL <--> PG
    WAL <--> RD

    SES <--> RTC
    SES <--> RD
    SES <--> PG
```

---

## 3. Monorepo Repository Structure

The monorepo is managed using `pnpm` workspaces for web/backend services and Flutter package dependencies for mobile clients:

```
Astro-main/
├── apps/
│   ├── backend/               # NestJS 10 modular backend service
│   │   ├── prisma/            # Prisma schema, migrations, and seeds
│   │   └── src/
│   │       ├── auth/          # OTP request/verify, Firebase, JWT strategy
│   │       ├── experts/       # Expert KYC submission and profile retrieval
│   │       ├── admin/         # Pending KYC queue, approval/rejection APIs
│   │       ├── prisma/        # Database access service
│   │       └── redis/         # Redis connection and cache service
│   ├── user-app/              # Flutter app for seekers (Android / iOS / Web)
│   ├── expert-app/            # Flutter app for astrologers (Android / iOS / Web)
│   └── admin-panel/           # Next.js 14 + Ant Design 5 administration dashboard
├── packages/
│   ├── api-contracts/         # Shared TypeScript DTOs and API interfaces
│   └── flutter-shared/        # Shared Flutter theme, color tokens, and components
├── infra/
│   └── docker/                # Local development Docker Compose manifests
├── docs/                      # Architectural specifications & system design
├── pnpm-workspace.yaml        # Workspace configuration
└── package.json               # Root monorepo scripts
```

---

## 4. Key Design & Technical Decisions

1. **Integer-Paise Money Storage:** All financial quantities, balances, and per-minute rates are stored strictly as 64-bit integers (`bigint`) in paise (e.g., ₹25.00/min is stored as `2500`). Floating-point arithmetic is strictly prohibited across the entire stack to eliminate rounding errors.
2. **Unified Authentication Architecture:** All roles (`USER`, `EXPERT`, `ADMIN`, `SUPPORT_AGENT`) authenticate through the core Auth module. Users and Astrologers authenticate via mobile OTP; Admins authenticate via secure email/password credentials.
3. **Optimistic KYC Workflow:** Astrologers enter the platform as standard users and submit a KYC application. Upon review and approval by an administrator via the Admin Panel, their database role is elevated to `EXPERT` and their profile is set live.
4. **Resilient Rate Limiting & Sliding Windows:** OTP requests and verifications are throttled using Redis sliding-window keys to mitigate abuse and SMS carrier exhaustion.

---

## 5. Prerequisites & Environment Setup

### Required Toolchain

- **Node.js:** `>= 20.0.0`
- **pnpm:** `>= 9.0.0`
- **Flutter SDK:** `>= 3.29.0` (Dart SDK `>= 3.7.0`)
- **Java JDK:** OpenJDK 17
- **Docker Desktop:** With Compose v2 enabled

### Local Environment Configuration

Copy the example environment file for the backend:

```bash
cd apps/backend
cp .env.example .env
```

Ensure `.env` contains:

```env
DATABASE_URL="postgresql://astro:devpassword@localhost:5432/astro_dev?schema=public"
REDIS_URL="redis://localhost:6379"
JWT_SECRET="dev-jwt-secret-key-change-in-production-min-32-chars"
JWT_EXPIRATION="15m"
JWT_REFRESH_SECRET="dev-jwt-refresh-secret-key-change-in-production"
JWT_REFRESH_EXPIRATION="7d"
FIREBASE_SERVICE_ACCOUNT_PATH="firebase-service-account.json"
PORT=3000
```

---

## 6. Quickstart Guide

### Step 1: Start Infrastructure (PostgreSQL & Redis)

```bash
# From repository root
cd infra/docker
docker compose up -d

# Verify containers are healthy
docker compose ps
```

### Step 2: Install Node Dependencies & Generate Prisma Client

```bash
# From repository root
pnpm install

# Run database migrations and generate Prisma client
cd apps/backend
npx prisma db push
```

### Step 3: Run the Backend Service

```bash
cd apps/backend
pnpm run start:dev
```
- API Base URL: `http://localhost:3000`
- Swagger API Documentation: `http://localhost:3000/api/docs`

### Step 4: Run the Admin Panel

```bash
cd apps/admin-panel
pnpm run dev
```
- Access Admin Portal: `http://localhost:3001`
- Default Super Admin Credentials: `admin@astro.com` / `admin123`

### Step 5: Run the Flutter Apps

```bash
# Run User App (Web or Connected Device)
cd apps/user-app
flutter run -d chrome

# Run Expert Partner App (Web or Connected Device)
cd apps/expert-app
flutter run -d chrome
```

---

## 7. End-to-End Verification & Testing

### Running Tests Across Workspace

```bash
# Test backend build
cd apps/backend && pnpm run build

# Test user app Flutter unit/widget tests
cd apps/user-app && flutter test

# Test expert app Flutter unit/widget tests
cd apps/expert-app && flutter test

# Test admin panel Next.js production build
cd apps/admin-panel && pnpm run build
```

---

## 8. Development Roadmap

Following `astro-app-project-phases.md`:

| Phase | Description | Status |
|:---|:---|:---:|
| **Phase 0** | Planning, tech stack selection & architecture specification | Completed |
| **Phase 1** | Design system tokens (`packages/flutter-shared`) & information architecture | Completed |
| **Phase 2** | Monorepo scaffolding, Auth service, Expert KYC & Admin approval workflows | Completed |
| **Phase 3** | Wallet ledger, recharge slabs, Razorpay API integration & webhooks | Completed |
| **Phase 4** | Redis presence tracking, heartbeat system, and 1:1 session/billing engine | Up Next |
| **Phase 5** | 1:1 Consultation engine (Chat MVP, per-minute billing state machine) | Planned |
| **Phase 6** | Audio & Video calling infrastructure (Agora integration) | Planned |
| **Phase 7** | Ratings, reviews, sorting algorithms & search discovery | Planned |
| **Phase 8** | Fraud prevention, call drop compensation & dispute handling | Planned |
| **Phase 9** | Advanced Admin tools, payout settlement batches & analytics | Planned |
| **Phase 10** | Production security hardening, load testing & store submissions | Planned |

---

## 9. Payment Gateway & Wallet Ledger Mechanics (Phase 3)

The financial infrastructure is engineered according to strict transactional consistency rules:
- **Append-Only Ledger (`wallet_ledger`):** No direct balance mutation occurs outside of an atomic ledger entry. Every credit or debit records `amount_in_paise`, transaction `type`, `reference_id`, and a `running_balance_snapshot`.
- **HMAC SHA256 Webhook Verification:** The `/webhooks/payment` endpoint verifies incoming payloads against the `RAZORPAY_WEBHOOK_SECRET` using timing-safe comparisons.
- **Webhook Idempotency:** The gateway's event ID (`x-razorpay-event-id`) is stored with a unique constraint in `payment_webhook_events`. Redelivered events return HTTP 200 immediately without double-crediting.
- **Concurrency & Overdraft Prevention:** Deductions lock the target wallet row using `SELECT ... FOR UPDATE` inside a database transaction, guaranteeing that concurrent session charges never over-draft the balance below zero.
- **Pending Integrations Checklist:** See [`TODO.md`](file:///c:/Astro-l/TODO.md) for the exact environment variables and SDK calls to swap once live Razorpay merchant credentials are provided.

---

## 10. License

Proprietary — All Rights Reserved.  
Unauthorized copying, modification, distribution, or public display of this codebase is strictly prohibited.

