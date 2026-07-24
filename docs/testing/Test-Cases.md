# Sample Test Cases — ConnectLocal

## 1. Introduction
Provides a representative set of detailed test cases covering critical-path functionality, derived from the Use Cases and Functional Requirements.

## 2. Purpose
To demonstrate the traceability from requirements through to executable test cases, and to serve as a template for the full test case suite maintained in the project's test management (or this document, extended, for the academic submission).

## 3. Scope
Covers a representative sample across Authentication, Booking, Payment, and Review modules. The full test suite extends this pattern to all functional requirements.

## 4. Detailed Content

### TC-01: Successful Customer Registration
| Field | Value |
|---|---|
| Requirement | FR-AUTH-01 |
| Preconditions | Email not previously registered |
| Steps | 1. Open app → Sign Up. 2. Enter valid email, strong password, full name. 3. Tap Register. |
| Expected Result | Account created; verification email sent; user redirected to "check your email" screen. |
| Priority | Critical |

### TC-02: Registration with Already-Used Email
| Field | Value |
|---|---|
| Requirement | FR-AUTH-01 |
| Preconditions | Email already registered |
| Steps | 1. Attempt registration with an existing email. |
| Expected Result | System returns 409 error; UI displays "Email already in use" with a link to reset password. |
| Priority | High |

### TC-03: Prevent Double-Booking of the Same Slot
| Field | Value |
|---|---|
| Requirement | FR-BK-03 |
| Preconditions | Provider has a confirmed booking at 2026-08-05 09:00–10:00 |
| Steps | 1. A second customer attempts to book the same provider for the same time slot. |
| Expected Result | API returns 409; UI shows "This slot is no longer available" and refreshes availability. |
| Priority | Critical |

### TC-04: Booking Status Transitions Correctly on Provider Accept
| Field | Value |
|---|---|
| Requirement | FR-BK-02, FR-BK-06 |
| Preconditions | Booking exists in `pending` status |
| Steps | 1. Provider opens booking request. 2. Provider taps Accept. |
| Expected Result | Booking status becomes `confirmed`; customer receives a notification; slot is locked against further requests. |
| Priority | Critical |

### TC-05: Payment Confirmation via PayFast ITN
| Field | Value |
|---|---|
| Requirement | FR-PAY-03 |
| Preconditions | Booking is `confirmed`; payment initiated, status `pending` |
| Steps | 1. Simulate a valid PayFast ITN POST with `payment_status=COMPLETE` and correct signature. |
| Expected Result | Payment status updates to `paid`; booking's `paymentStatus` reflects `paid`; both parties notified. |
| Priority | Critical |

### TC-06: Reject Tampered PayFast ITN
| Field | Value |
|---|---|
| Requirement | NFR-SEC-06 |
| Preconditions | Same as TC-05 |
| Steps | 1. Send an ITN POST with an incorrect signature. |
| Expected Result | Payment status remains unchanged; request logged as a security event; response still returns 200 "OK" to PayFast per protocol without revealing validation details. |
| Priority | Critical |

### TC-07: Review Submission Restricted to Completed Bookings
| Field | Value |
|---|---|
| Requirement | FR-REV-01 |
| Preconditions | Booking exists in `confirmed` (not yet `completed`) status |
| Steps | 1. Customer attempts to submit a review for the booking. |
| Expected Result | API returns 403; UI does not display the review option until status is `completed`. |
| Priority | High |

### TC-08: Provider Search Returns Results Within Radius, Sorted by Distance
| Field | Value |
|---|---|
| Requirement | FR-LOC-02 |
| Preconditions | At least 3 approved providers exist within 10km of test coordinates |
| Steps | 1. Search with `lat`, `lng`, `radiusKm=10`, no category filter. |
| Expected Result | All 3 providers returned, ordered by ascending distance; providers beyond 10km excluded. |
| Priority | High |

## 5. Assumptions
- Test cases assume a seeded test dataset with known providers, services, and bookings, provisioned via factory functions (see Integration-Testing.md).

## 6. Constraints
- This document presents a representative sample; the full test case suite (100+ cases across all modules) is maintained incrementally in the project's issue tracker/test management artifacts as development proceeds.

## 7. Future Enhancements
- Migrate test cases into a dedicated test management tool (e.g., TestRail or a GitHub Projects-based test board) for richer status tracking as the suite grows.
