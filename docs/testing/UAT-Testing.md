# User Acceptance Testing (UAT) Strategy — ConnectLocal

## 1. Introduction
Describes how ConnectLocal's fitness for real-world use is validated by proxy end users representing customers and providers.

## 2. Purpose
To confirm the system meets user needs and expectations from a business/usability perspective, not merely technical correctness — the final gate before a milestone is considered complete.

## 3. Scope
Covers structured UAT sessions with proxy customers and proxy providers (fellow students, friends/family in relevant trades) against the staging environment.

## 4. Detailed Content

### 4.1 UAT Participants
- 3–5 proxy customers (varied technical familiarity).
- 2–3 proxy providers, ideally including at least one person with genuine experience in a relevant trade (e.g., tutoring, hairdressing).

### 4.2 UAT Scenarios (Scripted)
| Scenario | Role | Success Criteria |
|---|---|---|
| Find and book a nearby provider for a specific service | Customer | Completes booking within 5 minutes without assistance |
| Message a provider to ask a question before booking | Customer | Sends and receives a reply within the app |
| Register a business and submit verification documents | Provider | Completes onboarding without assistance |
| Accept a booking and mark it complete | Provider | Understands and correctly uses the booking status controls |
| Leave a review after a completed booking | Customer | Understands the rating scale and submits a review |

### 4.3 Feedback Collection
Each participant completes a short post-session questionnaire (System Usability Scale-style, 1–5 ratings) plus open-ended feedback, recorded in a shared spreadsheet referenced from `docs/testing/`.

### 4.4 Acceptance Threshold
A feature is considered UAT-accepted when at least 80% of participants complete the associated scenario without facilitator intervention, and no participant rates the experience below 3/5.

## 5. Assumptions
- Proxy users are willing and available for a single ~30-minute session per milestone.

## 6. Constraints
- UAT is conducted in a controlled setting (not a live public beta) given the academic project scope.

## 7. Future Enhancements
- Formal usability lab session with recorded screen/audio for deeper qualitative analysis, if resources permit post-academic.
