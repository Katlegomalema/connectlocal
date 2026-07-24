# Sprint 2 Plan — ConnectLocal

## 1. Introduction
Sprint 2 builds on the authentication and database foundation from Sprint 1, extending into provider onboarding and phone verification.

## 2. Purpose
To deliver a functioning provider registration and verification workflow, and complete the authentication module with phone OTP support.

## 3. Scope
Two-week sprint. Sprint Goal: **"A provider can register a business profile, submit verification documents, and an admin can approve them; phone verification is fully functional."**

## 4. Detailed Content

### 4.1 Sprint Backlog
| Issue | Title | Assignee | Estimate (SP) | Module |
|---|---|---|---|---|
| CL-111 | Implement phone OTP request/verify endpoints | Backend Dev | 5 | auth |
| CL-112 | Implement Google OAuth login endpoint | Backend Dev | 5 | auth |
| CL-113 | Implement provider profile creation & update endpoints | Backend Dev | 5 | profiles |
| CL-114 | Implement provider verification document submission | Backend Dev | 5 | profiles |
| CL-115 | Implement admin verification approval endpoint | Backend Dev | 3 | admin |
| CL-116 | Build provider onboarding screens (Flutter) | Frontend Dev | 8 | frontend |
| CL-117 | Build phone verification screen (Flutter) | Frontend Dev | 5 | frontend |
| CL-118 | Integrate Supabase Storage for document uploads | Backend Dev | 3 | profiles |
| CL-119 | Write integration tests: registration → verification → approval | QA Engineer | 5 | testing |
| CL-120 | Update ERD and Provider-API documentation | Backend Dev | 2 | documentation |

**Total:** 46 story points

### 4.2 Sprint Timeline
| Day | Activity |
|---|---|
| Day 1 | Sprint Planning, backlog refinement carry-over from Sprint 1 retro |
| Day 2–7 | Development |
| Day 8–9 | Integration testing, admin approval flow end-to-end verification |
| Day 10 | Sprint Review demo + Retrospective |

## 5. Assumptions
- Sprint 1's authentication endpoints are stable and merged to `develop` before Sprint 2 begins.

## 6. Constraints
- Admin dashboard UI is not built in this sprint; verification approval is tested via API/Postman until the Admin Dashboard module (Sprint 8) delivers a UI.

## 7. Future Enhancements
- Bulk document review UI for admins, deferred to the Admin Dashboard sprint.
