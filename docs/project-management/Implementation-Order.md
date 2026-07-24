# Recommended Implementation Order — ConnectLocal

## 1. Introduction
This document translates the Work Breakdown Structure and Product Backlog into a concrete, dependency-aware build sequence for the development team, mapping each phase to GitHub Issues and sprint assignments.

## 2. Purpose
To ensure development proceeds in an order that respects technical dependencies (e.g., the database must exist before the backend can query it) while maximizing parallel work between the backend and frontend developers.

## 3. Scope
Covers the full build sequence from database through deployment, referencing the Sprint Plans, Product Backlog, and GitHub Labels/Milestones defined elsewhere in this documentation set.

## 4. Detailed Content

### 4.1 Phase Sequence & Rationale

| Phase | Order | Rationale |
|---|---|---|
| 1. Database | First | All other layers depend on a stable schema; late schema changes are the most expensive to absorb |
| 2. Backend Core (Auth) | Second | Every feature module requires authenticated, authorized requests |
| 3. Backend APIs (feature modules) | Third | Business logic and endpoints built against the stable schema and auth foundation |
| 4. Frontend | Fourth (overlapping from Phase 2 onward) | UI development can begin against mocked/contracted APIs as soon as API specs are frozen, then integrate as real endpoints land |
| 5. Testing | Continuous, intensifying | Unit tests written alongside each module; integration/system/UAT testing intensifies once modules are integrated |
| 6. Deployment | Final, with early staging setup | Staging environment stood up early (Sprint 1) so every subsequent sprint deploys incrementally, avoiding a risky "big bang" release |

### 4.2 Detailed Build Sequence with GitHub Issues & Sprint Mapping

#### Step 1 — Database (Sprint 1)
- `CL-104` Implement core database migrations: users, providers, services, bookings
- `CL-1041` (follow-up) Implement payments, messages, conversations, reviews, notifications migrations
- `CL-1042` Configure Row-Level Security policies per table
- `CL-1043` Enable PostGIS extension and create geospatial indexes
- **Milestone:** M1 — Foundations

#### Step 2 — Backend: Authentication (Sprint 1–2)
- `CL-105` `/auth/register`, `/auth/login`, `/auth/logout`
- `CL-106` Email verification flow
- `CL-111` Phone OTP flow
- `CL-112` Google OAuth login
- **Milestone:** M1 — Foundations

#### Step 3 — Backend: Core APIs (Sprint 2–6)
- `CL-113`–`CL-115` Provider profile & verification (Sprint 2)
- Search & Location API (Sprint 3) — `module:search`
- Service Management API (Sprint 3) — `module:profiles`
- Booking API (Sprint 4–5) — `module:bookings`
- Messaging API (Sprint 5) — `module:messaging`
- Notification API (Sprint 5–6) — `module:notifications`
- Review API (Sprint 6) — `module:reviews`
- Payment API (Sprint 7) — `module:payments`
- Admin API (Sprint 7–8) — `module:admin`
- **Milestones:** M2 (Core Marketplace), M3 (Transactions), M4 (Trust & Payments)

#### Step 4 — Frontend (Sprint 1–8, parallel/trailing each backend module by roughly half a sprint)
- Auth screens (Sprint 1–2)
- Provider onboarding screens (Sprint 2)
- Search & map UI (Sprint 3)
- Service listing & provider profile UI (Sprint 3–4)
- Booking flow UI (Sprint 4–5)
- Messaging UI (Sprint 5)
- Notification center UI (Sprint 5–6)
- Review UI (Sprint 6)
- Payment UI (Sprint 7)
- Admin dashboard (Web-focused) (Sprint 7–8)
- **Milestones:** M2, M3, M4

#### Step 5 — Testing (Continuous, Sprint 1–10; dedicated hardening in Sprint 9–10)
- Unit tests written within the same sprint as each feature (Definition of Done requirement)
- Integration test suites expanded per module as it lands
- System testing scenarios executed from Sprint 4 onward, once core flows are integrated end-to-end
- UAT sessions scheduled at the end of M2, M3, and M4
- Sprint 9–10 dedicated to regression testing, defect triage, and NFR verification (performance sampling, security spot-checks)
- **Milestone:** M5 — Hardening

#### Step 6 — Deployment (Sprint 1 setup, continuous thereafter, final push Sprint 11)
- Staging environment (Render + Supabase) stood up in Sprint 1 alongside CI/CD
- Every merge to `main` auto-deploys to staging from Sprint 1 onward (continuous deployment, not a single "deployment phase")
- Sprint 11: final deployment verification, demo environment freeze, and Deployment Guide finalization for the academic report
- **Milestone:** M6 — Release

### 4.3 Sprint-to-Milestone Summary
| Sprint | Primary Focus | Milestone |
|---|---|---|
| 1 | Database core tables, Auth, CI/CD, staging setup | M1 |
| 2 | Auth completion, Provider onboarding & verification | M1 |
| 3 | Search/Location, Service Management | M2 |
| 4 | Booking API + UI (part 1) | M2 → M3 |
| 5 | Booking completion, Messaging, Notifications | M3 |
| 6 | Reviews, Notification polish | M3 → M4 |
| 7 | Payments (PayFast integration) | M4 |
| 8 | Admin Dashboard | M4 |
| 9 | Testing & hardening (part 1), defect triage | M5 |
| 10 | Testing & hardening (part 2), NFR verification | M5 |
| 11 | Final deployment, demo prep, report compilation | M6 |

## 5. Assumptions
- Frontend development can begin as soon as an API's specification (in `docs/api-specs/`) is finalized, even before the backend implementation is complete, using a mocked API layer — reducing idle time for the frontend developer.

## 6. Constraints
- The sequence assumes the single-team, non-parallelized capacity described in the Work Breakdown Structure; a larger team could compress phases 3–4 further through greater parallelization.

## 7. Future Enhancements
- Introduce feature flags to allow trailing frontend work to merge to `develop` ahead of full backend readiness without breaking the staging build.
