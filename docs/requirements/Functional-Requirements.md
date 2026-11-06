# Functional Requirements Specification — ConnectLocal

## 1. Introduction
This document defines the functional requirements of ConnectLocal, a location-based service marketplace connecting customers with local service providers. It forms part of the Requirements Analysis phase of the project and is intended to guide system design, development, and acceptance testing.

## 2. Purpose
The purpose of this document is to specify, in unambiguous and testable terms, what the ConnectLocal system must do from the perspective of its three primary actors: **Customer**, **Provider**, and **Administrator**. Each requirement is uniquely identified for traceability to design artifacts, test cases, and sprint backlogs.

## 3. Scope
This specification covers all customer-facing, provider-facing, and administrative functionality delivered through the Flutter mobile/web client and the Node.js/Express backend. It excludes third-party system internals (e.g., PayFast's internal settlement logic) which are treated as external dependencies.

## 4. Detailed Content

### 4.1 Authentication Module
| ID | Requirement |
|---|---|
| FR-AUTH-01 | The system shall allow users to register using email and password. |
| FR-AUTH-02 | The system shall allow users to register/login using Google OAuth via Supabase Auth. |
| FR-AUTH-03 | The system shall send a verification email upon email/password registration and restrict full access until verified. |
| FR-AUTH-04 | The system shall allow phone number verification via a one-time-passcode (OTP) SMS. |
| FR-AUTH-05 | The system shall allow authenticated users to log out, invalidating their refresh token. |
| FR-AUTH-06 | The system shall support access token refresh without requiring re-authentication, up to the refresh token's validity period. |
| FR-AUTH-07 | The system shall allow users to reset a forgotten password via email link. |
| FR-AUTH-08 | The system shall enforce role-based access control for Customer, Provider, and Admin roles. |

### 4.2 User & Provider Profile Module
| ID | Requirement |
|---|---|
| FR-PROF-01 | The system shall allow customers to create and edit a profile (name, photo, contact details, address). |
| FR-PROF-02 | The system shall allow providers to register a business profile (business name, category, description, logo, service area). |
| FR-PROF-03 | The system shall require providers to submit identity/business verification documents before being listed publicly. |
| FR-PROF-04 | The system shall allow administrators to approve or reject provider verification submissions. |
| FR-PROF-05 | The system shall display a provider's verification status on their public profile. |

### 4.3 Location & Search Module
| ID | Requirement |
|---|---|
| FR-LOC-01 | The system shall capture and store the geographic coordinates of registered providers. |
| FR-LOC-02 | The system shall allow customers to search for providers within a configurable radius of their current or selected coordinates, using PostGIS. |
| FR-LOC-03 | The system shall allow customers to filter search results by service category, price range, and rating. |
| FR-LOC-04 | The system shall display provider locations as markers on an interactive map. |
| FR-LOC-05 | The system shall display the straight-line distance returned by the API between the customer and provider. |

### 4.4 Service Management Module
| ID | Requirement |
|---|---|
| FR-SVC-01 | The system shall allow providers to create, edit, and deactivate service listings with a title, description, category, price, and duration. |
| FR-SVC-02 | The system shall allow providers to define their available working hours and blackout dates. |
| FR-SVC-03 | The system shall allow customers to browse all active services offered by a given provider. |

### 4.5 Booking Module
| ID | Requirement |
|---|---|
| FR-BK-01 | The system shall allow customers to request a booking for a specific service, date, and time slot. |
| FR-BK-02 | The system shall allow providers to accept, decline, or propose an alternative time for a booking request. |
| FR-BK-03 | The system shall prevent double-booking of a provider's time slot. |
| FR-BK-04 | The system shall allow customers and providers to cancel a booking, subject to a configurable cancellation policy. |
| FR-BK-05 | The system shall allow customers to reschedule a pending or confirmed booking. |
| FR-BK-06 | The system shall maintain a booking status lifecycle: `pending → confirmed → in_progress → completed`, with `cancelled` and `declined` as terminal states. |

### 4.6 Messaging Module
| ID | Requirement |
|---|---|
| FR-MSG-01 | The system shall allow a customer and provider to exchange text messages within the context of a booking or general inquiry. |
| FR-MSG-02 | The system shall deliver messages in near real-time using WebSocket/Realtime channels. |
| FR-MSG-03 | The system shall persist full message history per conversation. |
| FR-MSG-04 | The system shall display message read/delivered status. |

### 4.7 Review & Rating Module
| ID | Requirement |
|---|---|
| FR-REV-01 | The system shall allow customers to submit a star rating (1–5) and written review after a booking is marked `completed`. |
| FR-REV-02 | The system shall calculate and display a provider's average rating based on all submitted reviews. |
| FR-REV-03 | The system shall allow providers to publicly respond to a review. |
| FR-REV-04 | The system shall allow administrators to moderate (hide/remove) reviews that violate platform policy. |

### 4.8 Payment Module
| ID | Requirement |
|---|---|
| FR-PAY-01 | The system shall allow customers to pay for a confirmed booking via PayFast. |
| FR-PAY-02 | The system shall record payment status (`pending`, `paid`, `failed`, `refunded`) against each booking. |
| FR-PAY-03 | The system shall process PayFast Instant Transaction Notifications (ITN) to confirm payment status server-side. |
| FR-PAY-04 | The system shall generate a payment receipt viewable by both customer and provider. |

### 4.9 Notification Module
| ID | Requirement |
|---|---|
| FR-NOT-01 | The system shall send push notifications for booking status changes, new messages, and payment events. |
| FR-NOT-02 | The system shall maintain an in-app notification center listing recent notifications. |
| FR-NOT-03 | The system shall allow users to configure notification preferences per category. |

### 4.10 Admin Dashboard Module
| ID | Requirement |
|---|---|
| FR-ADM-01 | The system shall allow administrators to view, search, and suspend user and provider accounts. |
| FR-ADM-02 | The system shall allow administrators to review and act on provider verification submissions. |
| FR-ADM-03 | The system shall allow administrators to view platform analytics (active users, bookings, revenue, top categories). |
| FR-ADM-04 | The system shall allow administrators to manage dispute cases raised between customers and providers. |
| FR-ADM-05 | The system shall allow administrators to configure platform-wide settings (commission rate, supported categories, cancellation windows). |

## 5. Assumptions
- All users have internet access and a supported device (Android 8+, iOS 13+, or a modern browser).
- Providers operate within jurisdictions supported by PayFast.
- The Flutter client can obtain or accept latitude/longitude coordinates for map search.

## 6. Constraints
- The system must operate within Supabase's free/Pro tier resource limits for the duration of the academic project.
- Payment functionality is limited to PayFast's supported payment methods and currencies (primarily ZAR).
- Development timeline is constrained to a single academic semester (approx. 12–14 weeks).

## 7. Future Enhancements
- Multi-language and multi-currency support.
- AI-based provider recommendation engine.
- In-app video consultations for applicable service categories.
- Subscription-based provider membership tiers.
- Loyalty and referral programs.
