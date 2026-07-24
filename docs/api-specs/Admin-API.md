# Admin API — ConnectLocal

## 1. Introduction
Specifies endpoints used exclusively by the Administrator role for user/provider management, verification approval, dispute resolution, and platform analytics. All endpoints are prefixed `/api/v1/admin` and require the `admin` role claim.

## 2. Purpose
To define the administrative contract supporting platform governance, trust & safety, and operational oversight.

## 3. Scope
Covers user/provider management, verification review, dispute handling, and analytics retrieval. Review moderation is documented in `Review-API.md` (Section 4.4) but included here by reference as an admin-scoped operation.

## 4. Detailed Content

### 4.1 List Users
- **URL:** `/api/v1/admin/users`
- **Method:** `GET`
- **Auth Required:** Yes (role: `admin`)
- **Query Parameters:** `role`, `status`, `search`, `page`, `pageSize`

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "results": [
      { "id": "8b1b6f2e-...", "fullName": "Jane Doe", "email": "jane.doe@example.com", "role": "customer", "status": "active", "createdAt": "2026-02-10T08:15:00Z" }
    ],
    "page": 1, "pageSize": 20, "totalResults": 512
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Users returned |
| 403 | Not authorized |

---

### 4.2 Suspend / Reinstate User or Provider
- **URL:** `/api/v1/admin/users/:userId/status`
- **Method:** `PATCH`
- **Auth Required:** Yes (role: `admin`)

**Request Body**
```json
{ "status": "suspended", "reason": "Repeated policy violations reported by customers" }
```

**Response Body (200 OK)**
```json
{ "success": true, "data": { "id": "8b1b6f2e-...", "status": "suspended" }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Status updated |
| 404 | User not found |

---

### 4.3 List Pending Provider Verifications
- **URL:** `/api/v1/admin/providers/verifications`
- **Method:** `GET`
- **Auth Required:** Yes (role: `admin`)
- **Query Parameters:** `status` (default `pending`), `page`, `pageSize`

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "results": [
      { "providerId": "c3e1a9f0-...", "businessName": "Mokoena Plumbing Services", "documentUrl": "https://storage.connectlocal.dev/verification/c3e1a9f0-doc1.pdf", "submittedAt": "2026-07-20T10:00:00Z" }
    ],
    "page": 1, "pageSize": 20, "totalResults": 8
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Pending verifications returned |

---

### 4.4 Approve / Reject Provider Verification
- **URL:** `/api/v1/admin/providers/:providerId/verification`
- **Method:** `PATCH`
- **Auth Required:** Yes (role: `admin`)

**Request Body**
```json
{ "decision": "approved" }
```
or
```json
{ "decision": "rejected", "reason": "Business registration document illegible" }
```

**Response Body (200 OK)**
```json
{ "success": true, "data": { "providerId": "c3e1a9f0-...", "verificationStatus": "approved" }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Decision recorded, provider notified |
| 400 | Invalid decision value |

---

### 4.5 List / Manage Disputes
- **URL:** `/api/v1/admin/disputes`
- **Method:** `GET`
- **Auth Required:** Yes (role: `admin`)

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "results": [
      { "disputeId": "disp-221", "bookingId": "bk-2026-00892", "raisedBy": "customer", "status": "open", "createdAt": "2026-08-06T09:00:00Z" }
    ]
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Disputes returned |

- **URL:** `/api/v1/admin/disputes/:disputeId/resolve`
- **Method:** `PATCH`
- **Auth Required:** Yes (role: `admin`)

**Request Body**
```json
{ "resolution": "refund_issued", "notes": "Full refund processed per customer complaint of no-show." }
```

**Response Body (200 OK)**
```json
{ "success": true, "data": { "disputeId": "disp-221", "status": "resolved" }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Dispute resolved |
| 404 | Dispute not found |

---

### 4.6 Platform Analytics
- **URL:** `/api/v1/admin/analytics`
- **Method:** `GET`
- **Auth Required:** Yes (role: `admin`)
- **Query Parameters:** `from`, `to` (ISO date range)

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "activeUsers": 1204,
    "activeProviders": 187,
    "totalBookings": 3421,
    "completedBookings": 2988,
    "totalRevenue": 512340.00,
    "topCategories": [ { "category": "plumbing", "bookings": 812 }, { "category": "tutoring", "bookings": 654 } ]
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Analytics returned |

---

### 4.7 Update Platform Settings
- **URL:** `/api/v1/admin/settings`
- **Method:** `PATCH`
- **Auth Required:** Yes (role: `admin`)

**Request Body**
```json
{ "commissionRatePercent": 10, "cancellationWindowHours": 24 }
```

**Response Body (200 OK)**
```json
{ "success": true, "data": { "updated": true }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Settings updated |
| 400 | Invalid setting value |

## 5. Assumptions
- Admin accounts are provisioned manually by the project team (no public admin self-registration).

## 6. Constraints
- Analytics endpoint performs live aggregation in the current scope; may require materialized views as data volume grows (see Database-Architecture.md Future Enhancements).

## 7. Future Enhancements
- Exportable analytics reports (CSV/PDF).
- Audit log endpoint exposing all admin actions for accountability.
