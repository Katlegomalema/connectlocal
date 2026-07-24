# Sequence Diagram: Authentication Flow — ConnectLocal

## 1. Introduction
Depicts the message sequence for user registration and login, including email verification, across the Flutter client, Express API, and Supabase Auth.

## 2. Purpose
To clarify the exact order of calls and responsibilities between components during authentication, supporting both implementation and test-case design.

## 3. Scope
Covers registration, email verification, and login. Token refresh is a simplified sub-flow of Login and is described narratively.

## 4. Diagram

```mermaid
sequenceDiagram
    actor U as User
    participant App as Flutter App
    participant API as Express API
    participant SB as Supabase Auth
    participant DB as PostgreSQL

    U->>App: Enter registration details
    App->>API: POST /auth/register
    API->>SB: createUser(email, password)
    SB-->>API: userId, unverified
    API->>DB: INSERT INTO users (id, email, role, is_email_verified=false)
    DB-->>API: OK
    SB-->>U: Verification email sent
    API-->>App: 201 Created {userId, isVerified: false}
    App-->>U: "Check your email to verify your account"

    U->>App: Clicks verification link
    App->>API: POST /auth/verify-email {token}
    API->>SB: verifyEmailToken(token)
    SB-->>API: verified = true
    API->>DB: UPDATE users SET is_email_verified = true
    API-->>App: 200 OK {isVerified: true}

    U->>App: Enter login credentials
    App->>API: POST /auth/login
    API->>SB: signInWithPassword(email, password)
    SB-->>API: accessToken, refreshToken
    API-->>App: 200 OK {accessToken, refreshToken, user}
    App->>App: Store tokens in Secure Storage
    App-->>U: Navigate to Home screen
```

## 5. Assumptions
- Email verification token delivery and validation is fully handled by Supabase Auth's built-in flow.

## 6. Constraints
- Diagram omits error paths (e.g., invalid credentials, expired token) for clarity; these are covered in `Authentication-API.md` status code tables.

## 7. Future Enhancements
- Extend diagram to include Google OAuth's redirect-based flow once implemented on Web.
