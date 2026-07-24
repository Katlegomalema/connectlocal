# Booking API — ConnectLocal

## 1. Introduction
Specifies endpoints governing the booking lifecycle: creation, provider response, rescheduling, cancellation, and completion. All endpoints are prefixed `/api/v1/bookings`.

## 2. Purpose
To define a precise, state-machine-aligned contract for booking operations used by both customer and provider clients.

## 3. Scope
Covers booking CRUD and status transitions. Payment-specific endpoints are documented separately in `Payment-API.md`.

## 4. Detailed Content

### 4.1 Booking Status Lifecycle
```
pending → confirmed → in_progress → completed
   |            |
   v            v
declined    cancelled
```

### 4.2 Create Booking
- **URL:** `/api/v1/bookings`
- **Method:** `POST`
- **Auth Required:** Yes (role: `customer`)

**Request Body**
```json
{
  "providerId": "c3e1a9f0-...",
  "serviceId": "svc-001",
  "scheduledStart": "2026-08-05T09:00:00Z",
  "notes": "Kitchen sink is blocked, please bring drain snake."
}
```

**Response Body (201 Created)**
```json
{
  "success": true,
  "data": {
    "bookingId": "bk-2026-00892",
    "status": "pending",
    "scheduledStart": "2026-08-05T09:00:00Z",
    "totalPrice": 450.00
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 201 | Booking created in `pending` status |
| 400 | Validation error |
| 409 | Time slot no longer available |

---

### 4.3 List My Bookings
- **URL:** `/api/v1/bookings`
- **Method:** `GET`
- **Auth Required:** Yes
- **Query Parameters:** `status`, `page`, `pageSize`

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "results": [
      { "bookingId": "bk-2026-00892", "providerName": "Mokoena Plumbing Services", "status": "confirmed", "scheduledStart": "2026-08-05T09:00:00Z" }
    ],
    "page": 1, "pageSize": 20, "totalResults": 6
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Bookings returned |
| 401 | Not authenticated |

---

### 4.4 Get Booking Detail
- **URL:** `/api/v1/bookings/:bookingId`
- **Method:** `GET`
- **Auth Required:** Yes (customer or provider party to the booking; admin)

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "bookingId": "bk-2026-00892",
    "customer": { "id": "8b1b6f2e-...", "fullName": "Jane Doe" },
    "provider": { "id": "c3e1a9f0-...", "businessName": "Mokoena Plumbing Services" },
    "service": { "id": "svc-001", "title": "Blocked Drain Clearing", "price": 450.00 },
    "status": "confirmed",
    "scheduledStart": "2026-08-05T09:00:00Z",
    "paymentStatus": "pending"
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Booking detail returned |
| 403 | Not a party to this booking |
| 404 | Booking not found |

---

### 4.5 Respond to Booking Request (Accept/Decline)
- **URL:** `/api/v1/bookings/:bookingId/respond`
- **Method:** `PATCH`
- **Auth Required:** Yes (role: `provider`, owner of the booking)

**Request Body**
```json
{ "action": "accept" }
```
or
```json
{ "action": "decline", "reason": "Fully booked on this date" }
```

**Response Body (200 OK)**
```json
{ "success": true, "data": { "bookingId": "bk-2026-00892", "status": "confirmed" }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Status updated |
| 400 | Invalid action |
| 403 | Not the assigned provider |
| 409 | Booking is not in `pending` status |

---

### 4.6 Reschedule Booking
- **URL:** `/api/v1/bookings/:bookingId/reschedule`
- **Method:** `PATCH`
- **Auth Required:** Yes (customer, owner of the booking)

**Request Body**
```json
{ "newScheduledStart": "2026-08-06T10:00:00Z" }
```

**Response Body (200 OK)**
```json
{ "success": true, "data": { "bookingId": "bk-2026-00892", "scheduledStart": "2026-08-06T10:00:00Z", "status": "pending" }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Rescheduled (reverts to `pending` for re-confirmation) |
| 409 | New slot unavailable |

---

### 4.7 Cancel Booking
- **URL:** `/api/v1/bookings/:bookingId/cancel`
- **Method:** `PATCH`
- **Auth Required:** Yes (customer or provider, party to the booking)

**Request Body**
```json
{ "reason": "Customer no longer requires the service" }
```

**Response Body (200 OK)**
```json
{ "success": true, "data": { "bookingId": "bk-2026-00892", "status": "cancelled" }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Booking cancelled |
| 409 | Booking already completed/cancelled |

---

### 4.8 Mark Booking Complete
- **URL:** `/api/v1/bookings/:bookingId/complete`
- **Method:** `PATCH`
- **Auth Required:** Yes (role: `provider`, owner)

**Response Body (200 OK)**
```json
{ "success": true, "data": { "bookingId": "bk-2026-00892", "status": "completed" }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Marked complete, eligible for review |
| 409 | Booking not in `in_progress`/`confirmed` status |

## 5. Assumptions
- Booking total price is calculated server-side from the service's current price at time of booking.

## 6. Constraints
- Cancellation policy (e.g., minimum notice period) is enforced server-side based on admin-configured platform settings.

## 7. Future Enhancements
- Recurring/repeat booking support.
- Provider-initiated rescheduling with customer counter-approval.
