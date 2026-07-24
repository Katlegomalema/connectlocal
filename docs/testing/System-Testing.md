# System Testing Strategy — ConnectLocal

## 1. Introduction
Describes the approach to testing ConnectLocal as a complete, integrated system deployed to the staging environment, verifying end-to-end business flows.

## 2. Purpose
To validate that the fully assembled system (Flutter clients + backend + database + third-party integrations) satisfies the Functional and Non-Functional Requirements when exercised as a whole.

## 3. Scope
Covers end-to-end scenario testing on the staging deployment, cross-platform verification (Android/iOS/Web), and non-functional spot-checks (performance, basic security).

## 4. Detailed Content

### 4.1 Approach
System testing is performed manually against the staging environment by the QA Engineer, supplemented by a Postman/Newman collection covering full end-to-end API sequences (e.g., register → verify → create provider → list service → book → pay → review).

### 4.2 Key End-to-End Scenarios
1. Customer registration through first successful booking and payment.
2. Provider registration through verification approval and first accepted booking.
3. Admin moderation of a flagged review.
4. Booking cancellation and its effect on provider availability.
5. Concurrent booking attempts on the same time slot (conflict handling).

### 4.3 Cross-Platform Verification
Each system test cycle is executed once on Android (emulator + physical device where available), once on iOS (simulator), and once on Flutter Web (Chrome), to catch platform-specific rendering or plugin issues (e.g., Google Maps plugin behavior differences).

### 4.4 Non-Functional Spot Checks
- Response time sampling against the NFR-PERF targets using Postman's response-time reporting.
- Basic security checks: attempting to access another user's booking/profile via direct ID manipulation (expect 403).

## 5. Assumptions
- Staging environment is representative of the eventual demo environment used for academic assessment.

## 6. Constraints
- System testing is manual/semi-automated only; full automated E2E UI testing is a future enhancement.

## 7. Future Enhancements
- Automated E2E testing using Flutter's `integration_test` package against the staging API.
