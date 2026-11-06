# Authentication Implementation Guide

## Overview

ConnectLocal uses **Supabase Auth** for user authentication with JWT tokens and role-based access control (RBAC). The auth system is implemented with a layered architecture:

```
Routes (API endpoints)
    ↓
Middleware (validation, token verification)
    ↓
Services (Supabase auth operations)
    ↓
Supabase Auth
```

---

## ✅ Completed Auth Components

### 1. Middleware Layer (`src/middleware/auth.js`)

**`verifyToken(req, res, next)`**
- Extracts JWT from `Authorization: Bearer <token>` header
- Verifies token with Supabase Auth
- Attaches `req.user` with id, email, role
- Throws `AuthenticationError` if invalid

**`requireRole(...roles)(req, res, next)`**
- Checks if user has one of the required roles
- Throws `AuthorizationError` if insufficient permissions
- Usage: `router.get('/', requireRole('admin', 'provider'), handler)`

**`optionalToken(req, res, next)`**
- Attempts to verify token but doesn't fail if missing
- Used for public endpoints that may accept authenticated users
- Populates `req.user` if token is valid

**`requireOwnership(paramName)(req, res, next)`**
- Verifies user owns the resource (or is admin)
- Compares user ID with resource ID from route params
- Prevents users from accessing others' data

### 2. Service Layer (`src/services/authService.js`)

**Registration**
```javascript
await authService.registerUser(email, password, userData)
// Creates Supabase auth user
// User receives verification email
// Returns: auth user object
```

**Login**
```javascript
const { user, session } = await authService.loginUser(email, password)
// Returns user + session with access_token and refresh_token
```

**Token Refresh**
```javascript
const { user, session } = await authService.refreshSession(refreshToken)
// Returns new access token using refresh token
```

**Email Verification**
```javascript
await authService.verifyUserEmail(tokenHash)
// Verifies OTP token from email link
```

**Password Reset**
```javascript
await authService.sendPasswordResetEmail(email)
// Sends reset link via email

await authService.updatePasswordWithToken(password, token)
// Resets password with reset token
```

**Phone Verification**
```javascript
await authService.verifyPhoneWithOtp(phone, otp)
// Verifies SMS OTP
```

**Logout**
```javascript
await authService.logoutUser(userId)
// Invalidates session
```

### 3. Route Layer (`src/routes/auth.js`)

All endpoints with request validation:

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/auth/register` | POST | ❌ | Register new user |
| `/auth/login` | POST | ❌ | Login and get token |
| `/auth/refresh` | POST | ❌ | Refresh access token |
| `/auth/logout` | POST | ✅ | Logout user |
| `/auth/password-reset` | POST | ❌ | Request password reset |
| `/auth/reset-password` | POST | ❌ | Reset password with token |
| `/auth/verify-email` | POST | ❌ | Verify email with token |
| `/auth/verify-phone` | POST | ❌ | Verify phone with OTP |
| `/auth/me` | GET | ✅ | Get current user |

---

## 🔄 Auth Flow Examples

### Registration Flow
```
1. POST /auth/register
   Body: { email, password, firstName, lastName, role, phone? }
   ↓
2. Validate input with Zod schema
   ↓
3. Call authService.registerUser()
   ↓
4. Supabase creates auth user
   ↓
5. Supabase sends verification email
   ↓
6. Response: { success: true, user: {...} }
   ↓
7. User clicks email link → /auth/verify-email?token=xxx
   ↓
8. POST /auth/verify-email { token }
   ↓
9. Account is verified and ready
```

### Login Flow
```
1. POST /auth/login
   Body: { email, password }
   ↓
2. Validate credentials
   ↓
3. Call authService.loginUser()
   ↓
4. Supabase verifies password
   ↓
5. Returns session with:
   - access_token (JWT)
   - refresh_token
   - expires_in
   ↓
6. Client stores tokens (secure storage)
   ↓
7. Client adds to headers: Authorization: Bearer <access_token>
```

### Protected Endpoint Flow
```
1. GET /api/v1/users/:id
   Headers: Authorization: Bearer <token>
   ↓
2. Middleware: verifyToken() extracts token
   ↓
3. Call supabase.auth.getUser(token)
   ↓
4. Supabase verifies JWT signature
   ↓
5. Attaches req.user with decoded claims
   ↓
6. Handler receives authenticated user
```

### Role-Based Access Control (RBAC)
```
1. User logs in, Supabase stores role in user_metadata
   ↓
2. JWT token includes role in claims
   ↓
3. Middleware verifyToken() extracts role:
   req.user.role = 'provider' (or 'customer', 'admin')
   ↓
4. Route uses requireRole('provider', 'admin')
   ↓
5. Middleware checks: if (!allowedRoles.includes(req.user.role))
   ↓
6. If not allowed: throw AuthorizationError (403)
```

---

## 🔑 User Roles

Three roles are defined and enforced:

| Role | Permissions | Can Do |
|------|-------------|--------|
| `customer` | Basic user | Search, book, pay, review |
| `provider` | Service provider | Manage services, accept bookings, receive payments |
| `admin` | System administrator | Manage all users, verify providers, moderate content |

### Setting User Role

During registration, user selects role. It's stored in:
```javascript
// Supabase auth user_metadata
user.user_metadata = {
  firstName: "John",
  lastName: "Doe",
  role: "customer", // or "provider"
  phone: "+27123456789"
}
```

Middleware extracts from token:
```javascript
req.user.role = data.user.user_metadata?.role || 'customer'
```

---

## 📋 Still To Implement

### 1. User Profile Creation
After `registerUser()`, create profile in `users` table:
```javascript
// In authService.registerUser() after line 23:
await createUserProfile(data.user.id, {
  first_name: userData.firstName,
  last_name: userData.lastName,
  email: email,
  phone: userData.phone,
  role: userData.role,
  status: 'pending_verification',
  created_at: new Date()
});
```

**Location**: `src/services/authService.js` line ~23

### 2. Email Verification Flow
Complete email template integration:
```javascript
// Send verification email with HTML template
import { sendVerificationEmail } from '../integrations/sendgrid.js';

await sendVerificationEmail(email, `${API_URL}/auth/verify-email?token=${token}`);
```

**Location**: `src/services/authService.js` after line 32

### 3. Database Migrations
Create database schema:
```sql
-- users table
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email VARCHAR UNIQUE NOT NULL,
  first_name VARCHAR,
  last_name VARCHAR,
  phone VARCHAR,
  role VARCHAR, -- customer, provider, admin
  status VARCHAR, -- active, suspended, deleted
  avatar_url VARCHAR,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- providers table
CREATE TABLE providers (
  id UUID PRIMARY KEY REFERENCES users(id),
  business_name VARCHAR NOT NULL,
  category VARCHAR NOT NULL,
  description TEXT,
  latitude DECIMAL,
  longitude DECIMAL,
  average_rating DECIMAL(3,2),
  total_reviews INT DEFAULT 0,
  verification_status VARCHAR, -- pending, verified, rejected
  created_at TIMESTAMP DEFAULT NOW()
);
```

**Location**: `migrations/` folder - create new migration files

### 4. Phone OTP Verification
Implement Twilio OTP:
```javascript
// Send OTP
import { sendOtpSms } from '../integrations/twilio.js';
await sendOtpSms(phone, generateOtp(), 10); // 10 minutes

// Verify OTP
const isValid = await verifyOtpWithTwilio(phone, otp);
if (!isValid) throw new ValidationError('Invalid OTP');
```

**Location**: `src/services/authService.js` - add `requestPhoneOtp()` function

### 5. Provider Verification Workflow
After provider registration:
```javascript
// Create provider verification record
await supabase.from('provider_verifications').insert({
  provider_id: user.id,
  status: 'pending',
  documents: [], // proof of business
  submitted_at: new Date()
});

// Admin reviews and approves
// Update provider status to 'verified'
```

**Location**: New service `src/services/providerService.js`

### 6. Test Implementation
Complete auth test suite:
```javascript
// tests/integration/authApi.test.js
describe('Auth API', () => {
  test('should register new user', async () => {
    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'test@example.com',
        password: 'SecurePass123!',
        firstName: 'John',
        lastName: 'Doe',
        role: 'customer'
      });

    expect(response.status).toBe(201);
    expect(response.body.data.user.email).toBe('test@example.com');
  });

  test('should login user', async () => {
    // Register first
    await registerTestUser();

    const response = await request(app)
      .post('/api/v1/auth/login')
      .send({
        email: 'test@example.com',
        password: 'SecurePass123!'
      });

    expect(response.status).toBe(200);
    expect(response.body.data.token).toBeDefined();
  });
});
```

**Location**: `tests/integration/authApi.test.js` - expand existing tests

---

## 🔐 Security Considerations

### Token Storage
```javascript
// ❌ DON'T store in localStorage (XSS vulnerable)
localStorage.setItem('token', accessToken);

// ✅ DO store in httpOnly cookie (XSS/CSRF protected)
// Set via Set-Cookie header from server

// Or use secure in-memory storage in Flutter
// Or device keystore (Flutter Secure Storage)
```

### CORS Configuration
```javascript
// src/app.js
app.use(cors({
  origin: [
    process.env.FRONTEND_URL,  // Flutter web
    process.env.ADMIN_URL      // Admin dashboard
  ],
  credentials: true,  // Allow cookies
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

### Rate Limiting
```javascript
// Implement rate limiting on auth endpoints
// GET /auth/register - 5 per hour per IP
// GET /auth/login - 10 per hour per IP
// GET /auth/password-reset - 3 per hour per email

// Use express-rate-limit package
import rateLimit from 'express-rate-limit';

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5 // 5 requests per windowMs
});

router.post('/register', authLimiter, ...);
```

### Password Requirements
```javascript
// Already defined in src/utils/validators.js
const passwordSchema = z.string()
  .min(8, 'At least 8 characters')
  .regex(/[A-Z]/, 'One uppercase')
  .regex(/[a-z]/, 'One lowercase')
  .regex(/[0-9]/, 'One number')
  .regex(/[^A-Za-z0-9]/, 'One special character');
```

---

## 📝 Implementation Checklist

- [ ] Configure `.env` with Supabase credentials
- [ ] Test auth routes with Postman/Insomnia
- [ ] Implement user profile creation after signup
- [ ] Create database migrations
- [ ] Add email verification template
- [ ] Implement phone OTP (Twilio)
- [ ] Add rate limiting to auth endpoints
- [ ] Write integration tests
- [ ] Add provider verification flow
- [ ] Setup role-based dashboard access
- [ ] Document for frontend team
- [ ] Security audit (OWASP)

---

## 📚 API Documentation

See [docs/api-specs/Authentication-API.md](../../docs/api-specs/Authentication-API.md) for detailed endpoint documentation.

## 🔗 Related Files

- Middleware: [src/middleware/auth.js](src/middleware/auth.js)
- Service: [src/services/authService.js](src/services/authService.js)
- Routes: [src/routes/auth.js](src/routes/auth.js)
- Validators: [src/utils/validators.js](src/utils/validators.js)
- Error Handling: [src/utils/errors.js](src/utils/errors.js)
- Email Integration: [src/integrations/sendgrid.js](src/integrations/sendgrid.js)
- SMS Integration: [src/integrations/twilio.js](src/integrations/twilio.js)

---

## 🚀 Next Steps

1. **Setup Supabase Project**
   - Create project at supabase.com
   - Get API credentials
   - Enable email verification

2. **Configure Backend**
   - Add Supabase URL/keys to `.env`
   - Setup email templates in Supabase
   - Configure CORS for frontend URLs

3. **Implement Remaining Features**
   - Create user profiles table
   - Implement provider verification
   - Add rate limiting
   - Complete tests

4. **Frontend Integration**
   - Share API endpoint documentation
   - Provide auth token flow guide
   - Setup error handling
   - Implement token refresh logic
