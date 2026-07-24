# Authentication API — ConnectLocal

## 1. Introduction
Specifies the REST endpoints for user registration, login, verification, token management, and logout. Authentication is backed by Supabase Auth; the Express API acts as a thin, validating proxy that also manages ConnectLocal-specific profile creation.

## 2. Purpose
To give frontend and backend developers a precise, versioned contract for all authentication-related interactions.

## 3. Scope
Covers email/password auth, Google OAuth handoff, email verification, phone OTP verification, token refresh, and logout. All endpoints are prefixed `/api/v1/auth`.

## 4. Detailed Content

### 4.1 Register (Email/Password)
- **URL:** `/api/v1/auth/register`
- **Method:** `POST`
- **Auth Required:** No

**Request Body**
```json
{
  "email": "jane.doe@example.com",
  "password": "S3cureP@ss!",
  "fullName": "Jane Doe",
  "role": "customer"
}
```

**Response Body (201 Created)**
```json
{
  "success": true,
  "data": {
    "userId": "8b1b6f2e-2c1a-4b2a-9a0a-3f9c9e6a1234",
    "email": "jane.doe@example.com",
    "role": "customer",
    "isVerified": false
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 201 | Account created, verification email sent |
| 400 | Validation error (invalid email/weak password) |
| 409 | Email already registered |

---

### 4.2 Login (Email/Password)
- **URL:** `/api/v1/auth/login`
- **Method:** `POST`
- **Auth Required:** No

**Request Body**
```json
{
  "email": "jane.doe@example.com",
  "password": "S3cureP@ss!"
}
```

**Response Body (200 OK)**
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "v1.MRQ...opaque-token",
    "expiresIn": 3600,
    "user": { "id": "8b1b6f2e-...", "role": "customer", "isVerified": true }
  },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Login successful |
| 401 | Invalid credentials |
| 403 | Account suspended |

---

### 4.3 Google OAuth Login
- **URL:** `/api/v1/auth/google`
- **Method:** `POST`
- **Auth Required:** No
- **Description:** Client obtains a Google ID token via Flutter's Google Sign-In SDK and exchanges it here.

**Request Body**
```json
{ "idToken": "google-issued-id-token" }
```

**Response Body (200 OK)** — same shape as Login above.

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Login/registration successful |
| 401 | Invalid Google token |

---

### 4.4 Verify Email
- **URL:** `/api/v1/auth/verify-email`
- **Method:** `POST`
- **Auth Required:** No (uses one-time token from email link)

**Request Body**
```json
{ "token": "email-verification-token" }
```

**Response (200 OK)**
```json
{ "success": true, "data": { "isVerified": true }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Email verified |
| 400 | Token invalid or expired |

---

### 4.5 Request Phone OTP
- **URL:** `/api/v1/auth/phone/request-otp`
- **Method:** `POST`
- **Auth Required:** Yes

**Request Body**
```json
{ "phoneNumber": "+27821234567" }
```

**Response (200 OK)**
```json
{ "success": true, "data": { "otpSent": true, "expiresInSeconds": 300 }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | OTP dispatched |
| 429 | Too many OTP requests, rate limited |

---

### 4.6 Verify Phone OTP
- **URL:** `/api/v1/auth/phone/verify-otp`
- **Method:** `POST`
- **Auth Required:** Yes

**Request Body**
```json
{ "phoneNumber": "+27821234567", "otp": "482913" }
```

**Response (200 OK)**
```json
{ "success": true, "data": { "phoneVerified": true }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Phone verified |
| 400 | Incorrect or expired OTP |

---

### 4.7 Refresh Token
- **URL:** `/api/v1/auth/refresh`
- **Method:** `POST`
- **Auth Required:** No (uses refresh token)

**Request Body**
```json
{ "refreshToken": "v1.MRQ...opaque-token" }
```

**Response (200 OK)**
```json
{
  "success": true,
  "data": { "accessToken": "new-jwt", "expiresIn": 3600 },
  "error": null
}
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | New access token issued |
| 401 | Refresh token invalid or expired |

---

### 4.8 Logout
- **URL:** `/api/v1/auth/logout`
- **Method:** `POST`
- **Auth Required:** Yes

**Request Body:** *(none)*

**Response (200 OK)**
```json
{ "success": true, "data": { "loggedOut": true }, "error": null }
```

**Status Codes**
| Code | Meaning |
|---|---|
| 200 | Session/refresh token invalidated |
| 401 | Not authenticated |

## 5. Assumptions
- The Flutter client integrates the Supabase Flutter SDK for Google Sign-In token acquisition prior to calling `/auth/google`.

## 6. Constraints
- OTP delivery depends on Supabase Auth's SMS provider integration and its associated rate/cost limits.

## 7. Future Enhancements
- Support for Apple Sign-In.
- Multi-factor authentication (TOTP) for provider/admin roles.
