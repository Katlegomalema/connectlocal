# Payment API — ConnectLocal

## 1. Introduction
Specifies endpoints for initiating and confirming payments processed via PayFast, and for retrieving payment history. All endpoints are prefixed `/api/v1/payments`.

## 2. Purpose
To define a secure, auditable contract for payment initiation, third-party callback handling, and receipt retrieval.

## 3. Scope
Covers PayFast payment initiation, the Instant Transaction Notification (ITN) webhook, and payment history/receipt endpoints. PCI-scope card capture occurs entirely on PayFast's hosted page and is out of scope for this API.

## 4. Detailed Content

### 4.1 Initiate Payment
- **URL:** `/api/v1/payments/initiate`
- **Method:** `POST`
- **Auth Required:** Yes (role: `customer`)

**Request Body**
```json
{ "bookingId": "bk-2026-00892" }
```

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "paymentId": "pay-7789",
    "redirectUrl": "https://sandbox.payfast.co.za/eng/process?merchant_id=...&signature=...",
    "amount": 450.00
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | PayFast redirect URL generated |
| 400 | Booking not eligible for payment (wrong status) |
| 409 | Payment already completed for this booking |

---

### 4.2 PayFast ITN Webhook (Server-to-Server)
- **URL:** `/api/v1/payments/payfast/itn`
- **Method:** `POST`
- **Auth Required:** No (validated via PayFast signature + source IP allow-list, not user JWT)
- **Description:** Called directly by PayFast servers upon payment completion/failure.

**Request Body (form-encoded, sent by PayFast)**
```
m_payment_id=pay-7789&pf_payment_id=1128841&payment_status=COMPLETE&amount_gross=450.00&signature=abc123...
```

**Response Body (200 OK)**
```
OK
```
*(PayFast requires a plain "OK" text response, not JSON, to acknowledge receipt.)*

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Notification processed (or intentionally ignored if signature invalid, to avoid leaking validation logic) |
| 400 | Malformed payload |

---

### 4.3 Get Payment Status
- **URL:** `/api/v1/payments/:paymentId`
- **Method:** `GET`
- **Auth Required:** Yes (customer or provider, party to the linked booking)

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "paymentId": "pay-7789",
    "bookingId": "bk-2026-00892",
    "amount": 450.00,
    "status": "paid",
    "paidAt": "2026-08-05T09:45:00Z",
    "method": "payfast"
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Payment status returned |
| 403 | Not authorized to view this payment |
| 404 | Payment not found |

---

### 4.4 List My Payment History
- **URL:** `/api/v1/payments`
- **Method:** `GET`
- **Auth Required:** Yes
- **Query Parameters:** `role` (`customer`/`provider` context), `page`, `pageSize`

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "results": [
      { "paymentId": "pay-7789", "bookingId": "bk-2026-00892", "amount": 450.00, "status": "paid", "paidAt": "2026-08-05T09:45:00Z" }
    ],
    "page": 1, "pageSize": 20, "totalResults": 14
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | History returned |
| 401 | Not authenticated |

---

### 4.5 Get Receipt
- **URL:** `/api/v1/payments/:paymentId/receipt`
- **Method:** `GET`
- **Auth Required:** Yes (customer or provider, party to the payment)

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "receiptNumber": "CL-RCPT-000451",
    "paymentId": "pay-7789",
    "amount": 450.00,
    "commission": 45.00,
    "netToProvider": 405.00,
    "issuedAt": "2026-08-05T09:46:00Z"
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Receipt returned |
| 404 | Receipt not yet generated (payment not confirmed) |

## 5. Assumptions
- Platform commission rate is configured centrally via admin settings and applied server-side at receipt generation.

## 6. Constraints
- All payments are processed in ZAR (South African Rand) via PayFast in the current scope.

## 7. Future Enhancements
- Support for additional payment gateways (Stripe, Ozow) for broader market reach.
- Automated provider payout scheduling.
