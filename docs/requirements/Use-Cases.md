# Use Case Specification — ConnectLocal

## 1. Introduction
This document provides detailed use case descriptions for ConnectLocal's core interactions, expanding on the user stories with structured pre/post-conditions and flows suitable for system analysis and design.

## 2. Purpose
To formally describe actor–system interactions in sufficient detail to drive sequence diagram construction, API design, and test case derivation.

## 3. Scope
Covers the primary use cases for Customer, Provider, and Administrator actors. A companion Mermaid use case diagram is provided in `diagrams/use-cases/Use-Case-Diagram.md`.

## 4. Detailed Content

### UC-01: Register Account
- **Actor:** Customer, Provider
- **Preconditions:** User is not authenticated.
- **Main Flow:**
  1. User selects "Sign Up".
  2. User chooses Email/Password or Google OAuth.
  3. System validates input and creates an account via Supabase Auth.
  4. System sends a verification email/OTP.
  5. User verifies their account.
- **Alternate Flow:** Email already registered → system displays error and offers password reset.
- **Postconditions:** A new user record exists with `is_verified = false` until step 5 completes.

### UC-02: Search for Nearby Providers
- **Actor:** Customer
- **Preconditions:** Customer has granted location permission or entered a manual location.
- **Main Flow:**
  1. Customer opens the Search screen.
  2. System requests current location or uses last known/manual location.
  3. Customer optionally applies filters (category, price, rating).
  4. System queries providers within the selected radius, ordered by distance.
  5. System displays results on map and list views.
- **Alternate Flow:** No providers found within radius → system suggests expanding the search radius.
- **Postconditions:** None (read-only operation).

### UC-03: Create a Booking
- **Actor:** Customer
- **Preconditions:** Customer is authenticated and verified; provider has at least one active service with availability.
- **Main Flow:**
  1. Customer selects a service from a provider's profile.
  2. Customer selects an available date/time slot.
  3. Customer confirms booking details.
  4. System creates a booking record with status `pending`.
  5. System notifies the provider of the new request.
- **Alternate Flow:** Selected slot becomes unavailable before confirmation → system displays a conflict error and refreshes availability.
- **Postconditions:** A booking record exists in `pending` status.

### UC-04: Accept/Decline a Booking
- **Actor:** Provider
- **Preconditions:** A booking exists in `pending` status assigned to the provider.
- **Main Flow:**
  1. Provider views pending booking requests.
  2. Provider selects Accept or Decline.
  3. If Accept: system sets status to `confirmed` and locks the time slot.
  4. If Decline: system sets status to `declined` and prompts for an optional reason.
  5. System notifies the customer of the outcome.
- **Postconditions:** Booking status updated; customer notified.

### UC-05: Make a Payment
- **Actor:** Customer
- **Preconditions:** Booking exists in `confirmed` status.
- **Main Flow:**
  1. Customer selects "Pay Now" on a confirmed booking.
  2. System generates a PayFast payment request and redirects the customer.
  3. Customer completes payment on PayFast's hosted page.
  4. PayFast sends an Instant Transaction Notification (ITN) to the backend.
  5. System verifies the ITN signature and updates payment status to `paid`.
  6. System notifies both customer and provider.
- **Alternate Flow:** Payment fails/cancelled → status remains `pending`; customer may retry.
- **Postconditions:** Payment record created and linked to the booking.

### UC-06: Submit a Review
- **Actor:** Customer
- **Preconditions:** Booking status is `completed`; no existing review for this booking.
- **Main Flow:**
  1. System prompts the customer to rate the completed booking.
  2. Customer submits a star rating and optional written review.
  3. System stores the review and recalculates the provider's average rating.
- **Postconditions:** Review is visible on the provider's profile (unless later moderated).

### UC-07: Verify a Provider
- **Actor:** Administrator, Provider
- **Preconditions:** Provider has submitted verification documents.
- **Main Flow:**
  1. Provider uploads business/identity documents.
  2. Administrator reviews the submission in the Admin Dashboard.
  3. Administrator approves or rejects, with an optional comment on rejection.
  4. System updates the provider's verification status and notifies them.
- **Postconditions:** Provider profile displays updated verification badge.

### UC-08: Exchange Messages
- **Actor:** Customer, Provider
- **Preconditions:** Both parties are authenticated; a conversation context exists (booking or general inquiry).
- **Main Flow:**
  1. User opens a conversation thread.
  2. User composes and sends a message.
  3. System persists the message and pushes it to the recipient in real time.
  4. Recipient's client marks the message as delivered/read.
- **Postconditions:** Message persisted in `messages` table.

### UC-09: Resolve a Dispute
- **Actor:** Administrator
- **Preconditions:** A dispute has been raised by a customer or provider against a booking.
- **Main Flow:**
  1. Administrator reviews dispute details, booking history, and messages.
  2. Administrator contacts relevant parties if needed.
  3. Administrator records a resolution (e.g., refund, booking reinstatement, warning issued).
  4. System updates the dispute status to `resolved`.
- **Postconditions:** Dispute closed with an auditable resolution record.

## 5. Assumptions
- All use cases assume a stable network connection unless explicitly stated as an offline/degraded scenario.
- Use cases describing payment assume a sandbox PayFast environment during development and testing.

## 6. Constraints
- Use cases are limited to functionality within the current project scope; multi-actor concurrent booking conflicts are handled via database-level locking, not covered in UI-level use cases.

## 7. Future Enhancements
- Use case for provider-initiated rescheduling with customer counter-proposal.
- Use case for automated dispute triage using rule-based flagging.
