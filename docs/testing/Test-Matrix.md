# Test Traceability Matrix — ConnectLocal

## 1. Introduction
Maps functional requirements to their corresponding test cases and test levels, demonstrating requirement coverage across the test suite.

## 2. Purpose
To provide auditable evidence that every "Must Have" functional requirement has at least one associated test, supporting both quality assurance and academic assessment of test coverage rigor.

## 3. Scope
Covers the Must-Have functional requirements from `docs/requirements/Functional-Requirements.md`, mapped to representative test cases in `Test-Cases.md` and the corresponding test level.

## 4. Detailed Content

| Requirement ID | Description (short) | Test Case(s) | Test Level | Status |
|---|---|---|---|---|
| FR-AUTH-01 | Email/password registration | TC-01, TC-02 | Unit + Integration | Planned |
| FR-AUTH-04 | Phone OTP verification | Auth module test suite | Integration | Planned |
| FR-PROF-03 | Provider verification submission | Provider module test suite | Integration | Planned |
| FR-LOC-02 | Location-based search | TC-08 | Integration + System | Planned |
| FR-BK-01 | Create booking | Booking module test suite | Integration | Planned |
| FR-BK-02 | Accept/decline booking | TC-04 | Integration | Planned |
| FR-BK-03 | Prevent double-booking | TC-03 | Integration | Planned |
| FR-MSG-01 | Exchange messages | Messaging module test suite | Integration | Planned |
| FR-REV-01 | Submit review | TC-07 | Integration | Planned |
| FR-PAY-01 | Initiate payment | Payment module test suite | Integration | Planned |
| FR-PAY-03 | Process PayFast ITN | TC-05, TC-06 | Integration | Planned |
| FR-ADM-02 | Provider verification approval | Admin module test suite | Integration + System | Planned |
| FR-ADM-04 | Dispute management | Admin module test suite | System + UAT | Planned |

**Status Legend:** Planned → In Progress → Passing → Failing (updated as the test suite is implemented across sprints).

## 5. Assumptions
- This matrix is updated at the end of every sprint to reflect actual test implementation and execution status.

## 6. Constraints
- Matrix currently reflects Must-Have requirements only; Should/Could-Have requirement coverage is added incrementally as those features are implemented.

## 7. Future Enhancements
- Automated traceability matrix generation from test annotations (e.g., linking Jest `describe` blocks to requirement IDs via custom tooling).
