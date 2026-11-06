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
- **Query Parameters:** `role`, `status`, `page`, `limit`

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "users": [
      { "id": "8b1b6f2e-...", "full_name": "Jane Doe", "email": "jane.doe@example.com", "role": "customer", "is_active": true, "deleted_at": null, "created_at": "2026-02-10T08:15:00Z" }
    ],
    "page": 1, "limit": 20, "total": 512, "pages": 26
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

### 4.2 Update a User Account
- **URL:** `/api/v1/admin/users/:id`
- **Method:** `PUT`
- **Auth Required:** Yes (role: `admin`)

**Request Body**
```json
{ "status": "suspended" }
```

**Response Body (200 OK)**
```json
{ "success": true, "data": { "user": { "id": "8b1b6f2e-...", "role": "customer", "status": "suspended", "is_active": false } } }
```

Allowed statuses are `active`, `suspended`, and `deactivated`. A deactivated account is soft-deleted; suspended accounts remain undeleted but inactive.

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Status updated |
| 404 | User not found |

---

### 4.3 List Pending Provider Verifications
- **URL:** `/api/v1/admin/providers/pending`
- **Method:** `GET`
- **Auth Required:** Yes (role: `admin`)
- **Query Parameters:** `page`, `limit` (verification status is always `pending`)

Each result includes its provider documents from `provider_documents`, including document type, URL, approval status, and upload time.

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "providers": [
      { "id": "c3e1a9f0-...", "business_name": "Mokoena Plumbing Services", "documents": [{ "document_type": "registration", "document_url": "https://storage.connectlocal.dev/verification/c3e1a9f0-doc1.pdf", "approval_status": "pending" }] }
    ],
    "page": 1, "total": 8, "pages": 1
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
- **URL:** `/api/v1/admin/providers/:id/verify` or `/api/v1/admin/providers/:id/reject`
- **Method:** `POST`
- **Auth Required:** Yes (role: `admin`)

The verify and reject routes take no request body. Provider verification status is stored as `verified` or `rejected`.

**Response Body (200 OK)**
```json
{ "success": true, "message": "Provider verified successfully", "data": { "provider": { "id": "c3e1a9f0-...", "verification_status": "verified" } } }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Decision recorded |

---

### 4.5 List / Manage Disputes
- **URL:** `/api/v1/admin/disputes`
- **Method:** `GET`
- **Auth Required:** Yes (role: `admin`)
- **Query Parameters:** `status` (`open`, `under_review`, `resolved`, `rejected`), `page`, `limit`

Without a `status` filter, only active disputes (`open` and `under_review`) are returned.

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "disputes": [
      { "id": "disp-221", "booking_id": "bk-2026-00892", "raised_by": "user-1", "status": "open", "created_at": "2026-08-06T09:00:00Z" }
    ],
    "total": 1, "page": 1, "pages": 1
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Disputes returned |

- **URL:** `/api/v1/admin/disputes/:id`
- **Method:** `PUT`
- **Auth Required:** Yes (role: `admin`)

**Request Body**
```json
{ "status": "resolved", "resolutionNotes": "Full refund issued after review." }
```

**Response Body (200 OK)**
```json
{ "success": true, "message": "Dispute resolved", "data": { "id": "disp-221", "status": "resolved" } }
```

Allowed update statuses are `under_review`, `resolved`, and `rejected`. Terminal decisions require a non-empty `resolutionNotes` value (maximum 5000 characters). Only disputes in `open` or `under_review` can be updated.

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Dispute resolved |
| 409 | Dispute is missing or no longer active |

---

### 4.6 Platform Analytics
- **URL:** `/api/v1/admin/analytics`
- **Method:** `GET`
- **Auth Required:** Yes (role: `admin`)

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "totalUsers": 1204,
    "totalProviders": 187,
    "totalBookings": 3421,
    "totalRevenue": 512340.00,
    "averageRating": 4.7
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Analytics returned |

---

### 4.7 Review Moderation
- `GET /api/v1/admin/reviews` lists reviews with optional `status=visible|hidden`, `page`, and `limit`.
- `POST /api/v1/admin/reviews/:id/hide` flags a review as hidden and refreshes the provider rating.

## 5. Assumptions
- Admin accounts are provisioned manually by the project team (no public admin self-registration).

## 6. Constraints
- Analytics endpoint performs live aggregation in the current scope; may require materialized views as data volume grows (see Database-Architecture.md Future Enhancements).

## 7. Future Enhancements
- Exportable analytics reports (CSV/PDF).
- Audit log endpoint exposing all admin actions for accountability.
