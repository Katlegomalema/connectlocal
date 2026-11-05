# Integration Testing Strategy — ConnectLocal

## 1. Introduction
Details the approach to integration testing, verifying that ConnectLocal's components — API routes, service layer, repositories, and the real (test) database — work correctly together.

## 2. Purpose
To catch defects at component boundaries that unit tests (which mock dependencies) cannot detect, such as incorrect SQL, misconfigured RLS policies, or malformed API contracts.

## 3. Scope
Covers backend API-to-database integration tests run against a dedicated Supabase test project, and selected frontend-to-backend contract tests.

## 4. Detailed Content

### 4.1 Backend Integration Testing
- **Framework:** Jest + Supertest, run against a running Express instance in a test environment.
- **Database:** A dedicated, disposable Supabase test project (or local Supabase CLI instance) migrated fresh before each test run and truncated between test suites.
- **What is integration tested:**
  - Full HTTP request/response cycle for each documented endpoint in `docs/api-specs/`.
  - Authentication middleware correctly rejecting missing/invalid/expired tokens.
  - Row-Level Security policies correctly restricting cross-user data access.
  - Booking conflict prevention under concurrent request scenarios.
  - PayFast ITN webhook handling with valid and invalid (tampered) signatures.

**Example test scenario (illustrative):**
```javascript
describe('POST /api/v1/bookings', () => {
  it('returns 409 when the requested time slot is already confirmed for the provider', async () => {
    await createTestBooking({ providerId, status: 'confirmed', scheduledStart: '2026-08-05T09:00:00Z' });
    const res = await request(app)
      .post('/api/v1/bookings')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ providerId, serviceId, scheduledStart: '2026-08-05T09:00:00Z' });
    expect(res.status).toBe(409);
  });
});
```

### 4.2 External Service Integration Testing
- **Nearby search:** Integration tests use deterministic provider coordinates in the test database to verify PostGIS radius boundaries and returned distances. No external map API is called.
- **PayFast:** All integration tests run exclusively against PayFast's sandbox environment; production credentials are never used in automated tests.
- **Supabase Realtime:** Messaging delivery is integration-tested by asserting the message row is persisted and a Realtime event is emitted, using a test subscriber client.

### 4.3 Test Data Management
- Seed/fixture data is generated per-test via factory functions (e.g., `createTestUser()`, `createTestProvider()`) rather than a shared static fixture file, to avoid test interdependency.
- The test database is fully reset between test suite runs via migration re-application in CI.

## 5. Assumptions
- CI runners have network access to the sandbox Supabase and PayFast environments (secrets provisioned via GitHub Actions secrets).

## 6. Constraints
- Map rendering is tested in the Flutter client; backend location tests do not depend on map tiles.

## 7. Future Enhancements
- Contract testing (e.g., Pact) between the Flutter client and backend API to catch breaking changes automatically.
