# Work Breakdown Structure — ConnectLocal

## 1. Introduction
Decomposes the ConnectLocal project into manageable work packages aligned to the system's major modules and SDLC phases.

## 2. Purpose
To provide the basis for sprint planning, effort estimation, and progress tracking against the Project Charter's milestones.

## 3. Scope
Covers all work packages from requirements analysis through deployment, mapped to GitHub Issues and Labels for execution tracking.

## 4. Detailed Content

### 4.1 WBS Hierarchy

```
1. Project Initiation & Planning
   1.1 Project Charter & Scope Statement
   1.2 Stakeholder & Risk Register
   1.3 Requirements Gathering (Functional, Non-Functional, User Stories, Use Cases)

2. System & Database Design
   2.1 System Architecture
   2.2 Database Schema & ERD
   2.3 API Specification
   2.4 UI/UX Wireframes & Mockups

3. Foundation Development
   3.1 Repository & CI/CD Setup
   3.2 Database Schema Implementation (Migrations)
   3.3 Authentication Module (Supabase Auth integration)

4. Core Marketplace Development
   4.1 User & Provider Profile Module
   4.2 Location & Search Module (PostGIS API search and client-rendered Flutter maps)
   4.3 Service Management Module

5. Transaction Development
   5.1 Booking Module
   5.2 Messaging Module
   5.3 Notification Module

6. Trust & Monetization Development
   6.1 Review & Rating Module
   6.2 Payment Module (PayFast integration)
   6.3 Admin Dashboard Module

7. Quality Assurance
   7.1 Unit Testing
   7.2 Integration Testing
   7.3 System & UAT Testing
   7.4 Performance & Security Review

8. Deployment & Release
   8.1 Staging Environment Setup
   8.2 Production-style Deployment (Render + Supabase)
   8.3 Demo Preparation

9. Documentation & Reporting
   9.1 Technical Documentation Maintenance
   9.2 Final Academic Report Compilation
```

### 4.2 GitHub Label Mapping
Each WBS leaf item maps to a `module:` label used on GitHub Issues (see GitHub Labels list below), enabling traceability between this WBS and the issue tracker.

### 4.3 GitHub Labels
| Label | Purpose |
|---|---|
| `type:feature` / `type:bug` / `type:documentation` / `type:chore` | Nature of the work |
| `priority:critical` / `priority:high` / `priority:medium` / `priority:low` | Urgency |
| `module:auth` / `module:profiles` / `module:search` / `module:bookings` / `module:messaging` / `module:reviews` / `module:payments` / `module:notifications` / `module:admin` | Feature area (aligned to WBS Sections 3–6) |
| `status:blocked` | Flags work that cannot proceed |
| `good-first-issue` | Onboarding-friendly tasks |

### 4.4 GitHub Milestones
| Milestone | Aligned WBS Sections |
|---|---|
| M1 — Foundations | 1, 2, 3 |
| M2 — Core Marketplace | 4 |
| M3 — Transactions | 5 |
| M4 — Trust & Payments | 6 |
| M5 — Hardening | 7 |
| M6 — Release | 8, 9 |

## 5. Assumptions
- Work packages are sized to fit within a two-week sprint cadence; larger packages are further decomposed at sprint planning time.

## 6. Constraints
- WBS reflects a single-team, non-parallelized delivery model appropriate to the team size described in the README.

## 7. Future Enhancements
- Introduction of story-point-weighted WBS tracking (e.g., via GitHub Projects custom fields) for velocity forecasting.
