# Provider API — ConnectLocal

## 1. Introduction
Specifies endpoints for provider business profile management, service listings, availability, and provider search/discovery. All endpoints are prefixed `/api/v1/providers`.

## 2. Purpose
To define the contract for provider onboarding, profile management, and the public search/browse experience consumed by customers.

## 3. Scope
Covers provider profile CRUD, verification submission, service management, and location-based search. Booking-specific interactions are documented in `Booking-API.md`.

## 4. Detailed Content

### 4.1 Create Provider Profile
- **URL:** `/api/v1/providers`
- **Method:** `POST`
- **Auth Required:** Yes (role: `provider`)

**Request Body**
```json
{
  "businessName": "Mokoena Plumbing Services",
  "category": "plumbing",
  "description": "24/7 residential and commercial plumbing services in Johannesburg.",
  "serviceAreaRadiusKm": 15,
  "location": { "lat": -26.2041, "lng": 28.0473 }
}
```

`category` must match an active service-category name; callers may send `categoryId` instead. Address fields are optional. `location` is required. See [`Location-API.md`](./Location-API.md) for map search behavior.

**Response Body (201 Created)**
```json
{
  "success": true,
  "data": {
    "provider": {
      "id": "c3e1a9f0-...",
      "business_name": "Mokoena Plumbing Services",
      "verification_status": "pending"
    }
  },
  "message": "Provider profile created"
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 201 | Provider profile created, pending verification |
| 400 | Validation error |
| 409 | Provider profile already exists for this user |

---

### 4.2 Get Provider Profile (Public)
- **URL:** `/api/v1/providers/:providerId`
- **Method:** `GET`
- **Auth Required:** No

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "provider": {
      "id": "c3e1a9f0-...",
      "business_name": "Mokoena Plumbing Services",
      "business_description": "Residential and commercial plumbing services.",
      "rating_average": 4.7,
      "rating_count": 132,
      "verification_status": "verified",
      "location": { "latitude": -26.2041, "longitude": 28.0473 },
      "services": [
        { "id": "svc-001", "service_name": "Blocked Drain Clearing", "base_price": 450.00, "duration_minutes": 60 }
      ]
    }
  }
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Provider profile returned |
| 404 | Provider not found |

---

### 4.3 Update Provider Profile
- **URL:** `/api/v1/providers/me`
- **Method:** `PATCH`
- **Auth Required:** Yes (role: `provider`, owner only)

**Request Body**
```json
{ "description": "Updated business description.", "serviceAreaRadiusKm": 20 }
```

**Response Body (200 OK)**
```json
{ "success": true, "data": { "provider": { "id": "c3e1a9f0-..." } }, "message": "Profile updated successfully" }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Updated |
| 400 | Validation error |
| 403 | Not the profile owner |

---

### 4.4 Submit Verification Documents
- **URL:** `/api/v1/providers/me/verification`
- **Method:** `POST`
- **Auth Required:** Yes (role: `provider`)

**Request Body**
```json
{
  "documentType": "business_registration",
  "documentUrl": "https://storage.connectlocal.dev/verification/c3e1a9f0-doc1.pdf"
}
```

**Response Body (200 OK)**
```json
{ "success": true, "data": { "verificationStatus": "pending" }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Submission received, awaiting admin review |
| 400 | Invalid document type/format |

---

### 4.5 Search Providers (Location-Based)
- **URL:** `/api/v1/providers/search` (alias of `/api/v1/search/nearby` for coordinates)
- **Method:** `GET`
- **Auth Required:** No
- **Query Parameters:** `lat`, `lng`, `radiusKm` (default 10), `category`, `minRating`, `maxPrice`, `page`, `pageSize`

**Example:** `GET /api/v1/providers/search?lat=-26.2041&lng=28.0473&radiusKm=10&category=plumbing`

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "results": [
      {
        "providerId": "c3e1a9f0-...",
        "businessName": "Mokoena Plumbing Services",
        "category": "Plumbing",
        "distanceKm": 3.2,
        "averageRating": 4.7,
        "verificationStatus": "approved"
      }
    ],
    "page": 1,
    "pageSize": 20,
    "totalResults": 47
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Results returned (may be empty array) |
| 400 | Missing/invalid coordinates |

---

### 4.6 Create Service Listing
- **URL:** `/api/v1/providers/me/services`
- **Method:** `POST`
- **Auth Required:** Yes (role: `provider`)

**Request Body**
```json
{
  "title": "Geyser Installation",
  "description": "Supply and installation of standard electric geysers.",
  "category": "plumbing",
  "price": 1800.00,
  "durationMinutes": 120
}
```

**Response Body (201 Created)**
```json
{ "success": true, "data": { "serviceId": "svc-002", "title": "Geyser Installation" }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 201 | Service created |
| 400 | Validation error |
| 403 | Provider not verified — cannot list services |

---

### 4.7 Set Availability
- **URL:** `/api/v1/providers/me/availability`
- **Method:** `PUT`
- **Auth Required:** Yes (role: `provider`)

**Request Body**
```json
{
  "slots": [
    { "dayOfWeek": 1, "startTime": "08:00", "endTime": "17:00" },
    { "dayOfWeek": 2, "startTime": "08:00", "endTime": "17:00" }
  ]
}
```

**Response Body (200 OK)**
```json
{ "success": true, "data": { "updated": true }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Availability updated |
| 400 | Invalid schedule format |

## 5. Assumptions
- Providers cannot publish services until `verificationStatus = approved`.

## 6. Constraints
- Search radius is capped server-side at 50km to bound query cost.

## 7. Future Enhancements
- Bulk service import via CSV.
- Provider team/staff sub-accounts.
