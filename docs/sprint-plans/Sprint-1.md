# Sprint 1 Plan — ConnectLocal

## 1. Introduction
Sprint 1 initiates development following the completion of the Requirements Analysis and System Design phases, focused on foundational infrastructure.

## 2. Purpose
To establish the technical foundation (repository, CI/CD, database schema, authentication) upon which all subsequent feature work depends.

## 3. Scope
Two-week sprint. Sprint Goal: **"A developer can register, log in, and receive a verified JWT session against a fully migrated database, with CI passing on every push."**

## 4. Detailed Content

### 4.1 Sprint Backlog
| Issue | Title | Assignee | Estimate (SP) | Module |
|---|---|---|---|---|
| CL-101 | Initialize repository structure, `.gitignore`, README, CONTRIBUTING | Project Lead | 2 | chore |
| CL-102 | Set up backend-ci.yml and frontend-ci.yml GitHub Actions | Backend Dev | 3 | chore |
| CL-103 | Provision Supabase project (Auth, DB, Storage) | Backend Dev | 2 | infra |
| CL-104 | Implement core database migrations: users, providers, services, bookings | Backend Dev | 8 | database |
| CL-105 | Implement `/auth/register`, `/auth/login`, `/auth/logout` endpoints | Backend Dev | 8 | auth |
| CL-106 | Implement email verification flow | Backend Dev | 5 | auth |
| CL-107 | Scaffold Flutter app structure (feature-first folders, routing) | Frontend Dev | 5 | frontend |
| CL-108 | Build registration & login screens | Frontend Dev | 8 | frontend |
| CL-109 | Write unit tests for Auth service layer | QA Engineer | 5 | testing |
| CL-110 | Document Authentication API in `docs/api-specs/Authentication-API.md` | Backend Dev | 2 | documentation |

**Total:** 48 story points

### 4.2 Sprint Timeline
| Day | Activity |
|---|---|
| Day 1 | Sprint Planning, environment provisioning |
| Day 2–7 | Development (parallel: backend auth + DB, frontend scaffolding) |
| Day 8–9 | Integration of frontend auth screens with backend endpoints |
| Day 10 | Testing, bug fixes, documentation finalization |
| Day 10 (PM) | Sprint Review demo + Retrospective |

## 5. Assumptions
- Supabase and Google/PayFast sandbox accounts are provisioned before Day 1.

## 6. Constraints
- Frontend and backend auth work proceeds in parallel against the agreed API contract (`Authentication-API.md`) to avoid blocking.

## 7. Future Enhancements
- Phone OTP verification is deferred to Sprint 2 to keep Sprint 1 scope achievable.
