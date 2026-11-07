# ConnectLocal: backend API (Node.js / Express)

REST API for the ConnectLocal app and admin website: `/api/v1/{auth, users, providers, search, bookings, messages,
reviews, payments, admin, notifications, uploads, geo}` plus `/health` and `/health/db`.

Needs **Node 22 or newer** (`@supabase/supabase-js` uses Node's built-in WebSocket).

## How it is built

```
routes/        HTTP: URLs, request validation (zod), status codes
  └─ services/       business rules: who may do what, booking flow, payments, payouts
       └─ repositories/  all database access (Supabase, service-role key)
middleware/    auth (Supabase token -> public.users row, role), validation, rate limits, errors
integrations/  PayFast, Supabase Storage (signed uploads), Nominatim (address search), email/push
utils/         validators.js (same rules as the app), schedule.js (time slots, SAST), secure codes
config/        Supabase clients, CORS, business constants (15% fee, 10% commission, ...)
```

The repositories use the **service-role key, which bypasses RLS**, so every service checks ownership and role
itself. The key lives only in `backend/.env` (git-ignored) and never goes to the app.

## Run

```bash
npm install
cp .env.example .env      # fill in the values
npm run db:push           # apply ../supabase/migrations (npm run db:push:dry shows what it would run)
npm start                 # http://localhost:3000, check /health/db
```

In Codespaces the database must be reached through the Supabase **Session pooler** (the direct host is IPv6-only).
Step-by-step: [SETUP.md](../SETUP.md) and [START.md](../START.md).

## Checks

```bash
npm run lint              # eslint (auto-fixes locally; CI runs it without --fix)
npm test                  # unit + integration tests (mocks and .env.test: no real database)
bash scripts/smoke-test.sh                       # whole flow with curl against a running API (real database)
node --env-file=.env scripts/e2e-booking-flow.mjs 3000   # the same, plus payment race checks
```

The two flow scripts create temporary users and delete them at the end.

## API contracts

[`docs/api-specs/`](../docs/api-specs/). Authentication details: [AUTH_IMPLEMENTATION.md](AUTH_IMPLEMENTATION.md).
