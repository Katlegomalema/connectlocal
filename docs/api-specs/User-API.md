# User API — ConnectLocal

## 1. Introduction
Specifies endpoints for managing customer profile data. All endpoints are prefixed `/api/v1/users`.

## 2. Purpose
To define the contract for retrieving and updating a customer's own profile information.

## 3. Scope
Covers profile read/update and account deletion. Provider-specific profile endpoints are documented in `Provider-API.md`.

## 4. Detailed Content

### 4.1 Get Current User Profile
- **URL:** `/api/v1/users/me`
- **Method:** `GET`
- **Auth Required:** Yes (any authenticated role)

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "id": "8b1b6f2e-2c1a-4b2a-9a0a-3f9c9e6a1234",
    "fullName": "Jane Doe",
    "email": "jane.doe@example.com",
    "phoneNumber": "+27821234567",
    "profilePhotoUrl": "https://storage.connectlocal.dev/avatars/jane.jpg",
    "address": "12 Main Rd, Johannesburg",
    "role": "customer",
    "isVerified": true,
    "createdAt": "2026-02-10T08:15:00Z"
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Profile returned |
| 401 | Not authenticated |

---

### 4.2 Update Current User Profile
- **URL:** `/api/v1/users/me`
- **Method:** `PATCH`
- **Auth Required:** Yes

**Request Body**
```json
{
  "fullName": "Jane A. Doe",
  "address": "45 Oak Ave, Johannesburg",
  "profilePhotoUrl": "https://storage.connectlocal.dev/avatars/jane-new.jpg"
}
```

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": { "id": "8b1b6f2e-...", "fullName": "Jane A. Doe", "address": "45 Oak Ave, Johannesburg" },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Profile updated |
| 400 | Validation error |
| 401 | Not authenticated |

---

### 4.3 Get Public User Summary (for reviews/messaging display)
- **URL:** `/api/v1/users/:userId/summary`
- **Method:** `GET`
- **Auth Required:** Yes

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": { "id": "8b1b6f2e-...", "fullName": "Jane Doe", "profilePhotoUrl": "https://storage.connectlocal.dev/avatars/jane.jpg" },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Summary returned |
| 404 | User not found |

---

### 4.4 Deactivate Own Account
- **URL:** `/api/v1/users/me`
- **Method:** `DELETE`
- **Auth Required:** Yes

**Response Body (200 OK)**
```json
{ "success": true, "data": { "deactivated": true }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Account soft-deleted (deleted_at set) |
| 401 | Not authenticated |

## 5. Assumptions
- Profile photos are uploaded directly to Supabase Storage from the client; this API only stores the resulting URL.

## 6. Constraints
- Email address changes are handled via the Authentication API (requiring re-verification), not this endpoint.

## 7. Future Enhancements
- Granular privacy settings (e.g., hide address from public summary).
- Account data export endpoint (GDPR/POPIA-style data portability).
