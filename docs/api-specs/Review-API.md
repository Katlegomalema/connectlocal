# Review API — ConnectLocal

## 1. Introduction
Specifies endpoints for submitting, retrieving, responding to, and moderating provider reviews. All endpoints are prefixed `/api/v1/reviews`.

## 2. Purpose
To define the contract for the review and rating system that underpins trust on the platform.

## 3. Scope
Covers customer review submission, provider responses, public review listing, and admin moderation actions.

## 4. Detailed Content

### 4.1 Submit Review
- **URL:** `/api/v1/reviews`
- **Method:** `POST`
- **Auth Required:** Yes (role: `customer`)

**Request Body**
```json
{
  "bookingId": "bk-2026-00892",
  "rating": 5,
  "comment": "Arrived on time and fixed the blockage quickly. Highly recommend."
}
```

**Response Body (201 Created)**
```json
{
  "success": true,
  "data": { "reviewId": "rev-3301", "rating": 5, "createdAt": "2026-08-05T11:00:00Z" },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 201 | Review created |
| 400 | Rating out of range (must be 1–5) |
| 403 | Booking not eligible (not `completed`, or not owned by requester) |
| 409 | Review already exists for this booking |

---

### 4.2 List Reviews for a Provider
- **URL:** `/api/v1/providers/:providerId/reviews`
- **Method:** `GET`
- **Auth Required:** No
- **Query Parameters:** `page`, `pageSize`, `minRating`

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "results": [
      {
        "reviewId": "rev-3301",
        "customerName": "Jane D.",
        "rating": 5,
        "comment": "Arrived on time and fixed the blockage quickly.",
        "createdAt": "2026-08-05T11:00:00Z",
        "providerResponse": null
      }
    ],
    "averageRating": 4.7,
    "totalReviews": 132,
    "page": 1, "pageSize": 20
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Reviews returned |
| 404 | Provider not found |

---

### 4.3 Respond to a Review
- **URL:** `/api/v1/reviews/:reviewId/response`
- **Method:** `POST`
- **Auth Required:** Yes (role: `provider`, owner of the reviewed profile)

**Request Body**
```json
{ "response": "Thank you Jane, glad we could help so quickly!" }
```

**Response Body (201 Created)**
```json
{ "success": true, "data": { "reviewId": "rev-3301", "providerResponse": "Thank you Jane, glad we could help so quickly!" }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 201 | Response added |
| 403 | Not the reviewed provider |
| 409 | Response already submitted for this review |

---

### 4.4 Moderate Review (Admin)
- **URL:** `/api/v1/admin/reviews/:reviewId/moderate`
- **Method:** `PATCH`
- **Auth Required:** Yes (role: `admin`)

**Request Body**
```json
{ "action": "hide", "reason": "Contains personal contact information, violates platform policy" }
```

**Response Body (200 OK)**
```json
{ "success": true, "data": { "reviewId": "rev-3301", "status": "hidden" }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Moderation action applied |
| 403 | Not authorized (non-admin) |
| 404 | Review not found |

## 5. Assumptions
- One review per booking, enforced by a unique constraint on `reviews.booking_id`.

## 6. Constraints
- Review comments are capped at 500 characters; provider responses at 500 characters.

## 7. Future Enhancements
- Photo attachments on reviews.
- Verified "provider replied" badge and response-time metrics.
