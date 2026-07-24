# User Stories — ConnectLocal

## 1. Introduction
This document captures ConnectLocal's functionality as a prioritized set of user stories, written from the perspective of each system actor. User stories form the primary unit of work for sprint planning and link directly to the Product Backlog and Functional Requirements.

## 2. Purpose
To translate functional requirements into small, testable, independently deliverable units of value that can be estimated, scheduled into sprints, and verified against acceptance criteria.

## 3. Scope
Covers all Customer, Provider, and Administrator stories for the current project scope (see Scope-Statement.md). Story format follows: *As a [role], I want [capability], so that [benefit]*, with INVEST-aligned acceptance criteria.

## 4. Detailed Content

### 4.1 Customer Stories

**US-01 (Must Have)** — As a customer, I want to register using my email or Google account, so that I can quickly create a profile without friction.
*Acceptance Criteria:* Registration form validates email format; Google OAuth completes in ≤2 taps; verification email sent within 30s.

**US-02 (Must Have)** — As a customer, I want to search for service providers near my location, so that I can find help close to me.
*Acceptance Criteria:* Results sorted by distance by default; map view and list view both available; radius is adjustable.

**US-03 (Must Have)** — As a customer, I want to view a provider's profile, services, and reviews before booking, so that I can make an informed decision.
*Acceptance Criteria:* Profile shows verification badge, average rating, service list with prices, and at least the 5 most recent reviews.

**US-04 (Must Have)** — As a customer, I want to book a specific service at a chosen date and time, so that I can secure the provider's availability.
*Acceptance Criteria:* Only available time slots are selectable; booking enters `pending` status; confirmation notification sent on acceptance.

**US-05 (Must Have)** — As a customer, I want to message a provider about my booking, so that I can clarify details before the appointment.
*Acceptance Criteria:* Messages delivered in near real-time; conversation history persists across sessions.

**US-06 (Should Have)** — As a customer, I want to pay for my booking in-app, so that I don't need to handle cash or arrange payment separately.
*Acceptance Criteria:* Redirect to PayFast completes within 3 taps; payment status reflected in booking within 60s of confirmation.

**US-07 (Should Have)** — As a customer, I want to leave a rating and review after a completed booking, so that I can share my experience with other users.
*Acceptance Criteria:* Review prompt appears only after `completed` status; rating required, written review optional (max 500 chars).

**US-08 (Could Have)** — As a customer, I want to receive push notifications for booking updates, so that I stay informed without checking the app constantly.

### 4.2 Provider Stories

**US-09 (Must Have)** — As a provider, I want to register a business profile with my service category and area, so that customers can discover me.
*Acceptance Criteria:* Profile requires business name, category, description, and at least one service area coordinate.

**US-10 (Must Have)** — As a provider, I want to submit verification documents, so that I earn a "Verified" badge that builds customer trust.
*Acceptance Criteria:* Document upload supports PDF/JPG/PNG up to 10MB; status visible as `pending`, `approved`, or `rejected`.

**US-11 (Must Have)** — As a provider, I want to create and manage service listings, so that customers know what I offer and at what price.

**US-12 (Must Have)** — As a provider, I want to accept or decline booking requests, so that I retain control over my schedule.
*Acceptance Criteria:* Decline requires an optional reason; accept locks the time slot against further requests.

**US-13 (Should Have)** — As a provider, I want to set my working hours and blackout dates, so that customers can't book me when I'm unavailable.

**US-14 (Should Have)** — As a provider, I want to see my payment history and pending payouts, so that I can track my earnings.

**US-15 (Could Have)** — As a provider, I want to respond publicly to customer reviews, so that I can address feedback professionally.

### 4.3 Administrator Stories

**US-16 (Must Have)** — As an administrator, I want to review and approve/reject provider verification submissions, so that only legitimate businesses are listed.

**US-17 (Must Have)** — As an administrator, I want to suspend user or provider accounts that violate platform policy, so that I can maintain trust and safety.

**US-18 (Should Have)** — As an administrator, I want to view platform analytics (bookings, revenue, active users), so that I can monitor platform health.

**US-19 (Should Have)** — As an administrator, I want to moderate reviews flagged as inappropriate, so that the review system remains fair and useful.

**US-20 (Could Have)** — As an administrator, I want to manage disputes raised between customers and providers, so that conflicts are resolved fairly and transparently.

## 5. Assumptions
- MoSCoW prioritization (Must/Should/Could/Won't) reflects the current sprint horizon and may be re-prioritized at each sprint planning session.
- Story point estimation is performed collaboratively by the development team using a Fibonacci-based scale during backlog refinement.

## 6. Constraints
- Stories are scoped to fit a single-semester academic delivery timeline; "Won't Have" items are explicitly deferred (see Future Enhancements).

## 7. Future Enhancements
- Multi-provider "job" bookings requiring more than one specialist.
- Group/family account stories.
- Provider team management (multiple staff under one business profile).
