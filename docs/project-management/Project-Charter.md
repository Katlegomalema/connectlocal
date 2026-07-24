# Project Charter — ConnectLocal

## 1. Introduction
This charter formally authorizes the ConnectLocal project, defining its objectives, scope at a strategic level, stakeholders, and success criteria for the final-year BSc Information Technology software engineering project.

## 2. Purpose
To establish a shared understanding among the project team and academic supervisor of why the project exists, what it aims to achieve, and how success will be measured.

## 3. Scope
This charter covers the strategic framing of the project; detailed functional scope is defined in `docs/requirements/Scope-Statement.md`.

## 4. Detailed Content

### 4.1 Project Purpose & Justification
Finding trustworthy, available local service providers (plumbers, electricians, tutors, hairdressers, mechanics, cleaners) is a persistent, unstructured process typically reliant on word-of-mouth or unverified online listings. ConnectLocal addresses this by providing a structured, location-aware, trust-enabled marketplace that formalizes discovery, booking, communication, payment, and reputation for local services.

### 4.2 Objectives
1. Design and implement a functioning three-sided marketplace (customer, provider, admin) demonstrating full-stack software engineering competency.
2. Apply a complete SDLC — requirements analysis, system design, database design, implementation, testing, and deployment — to an original, non-trivial system.
3. Produce documentation of professional/industry standard suitable for academic assessment and portfolio use.
4. Deliver a working, demonstrable staging deployment by the end of the academic semester.

### 4.3 High-Level Requirements
See `docs/requirements/Functional-Requirements.md` and `Non-Functional-Requirements.md`.

### 4.4 Project Manager / Team Lead
Designated within the project team (see README.md Team Structure); reports to the academic supervisor.

### 4.5 Summary Milestones
| Milestone | Target Sprint |
|---|---|
| Requirements & Architecture Sign-off | Sprint 1 |
| Database & Authentication Complete | Sprint 2 |
| Core Marketplace (Search, Profiles, Services) | Sprint 4 |
| Bookings, Messaging, Notifications | Sprint 6 |
| Payments, Reviews, Admin Dashboard | Sprint 8 |
| Testing & Hardening | Sprint 10 |
| Final Deployment & Report Submission | Sprint 11 |

### 4.6 Budget
Zero/near-zero cash budget; reliant on free/trial tiers of Supabase, Render, Google Maps Platform, and PayFast sandbox. No paid staffing — team time is the primary resource.

### 4.7 Authorization
This project is authorized for execution as the capstone deliverable of the BSc Information Technology program, subject to ongoing academic supervisor review at each milestone.

## 5. Assumptions
- Team composition and academic calendar remain stable for the semester duration.
- Third-party service free tiers remain available and sufficient throughout the project.

## 6. Constraints
- Fixed academic deadline; no scope extension possible without formal supervisor approval.
- Team members balance this project alongside other academic coursework.

## 7. Future Enhancements
Post-academic commercialization path is noted as an aspiration but explicitly out of charter scope; see Scope-Statement.md Section 3.2.
