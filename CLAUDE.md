# Connect Local – project context for Claude Code

School project: a local-services marketplace (South Africa). Customers book local service
providers; an admin verifies businesses. Goal right now: **get the app working end to end**:
Flutter app → Express backend API → Supabase Postgres.

## Repo layout
- `backend/`: Node 18+/20, Express, ES modules (`"type": "module"`), `@supabase/supabase-js`, zod, jest.
  - `server.js` → `src/app.js` mounts routes at `/api/v1/{auth,users,providers,search,bookings,messages,reviews,payments,admin,notifications}` + `/health`.
  - Layers: `routes/` → `services/` → `repositories/` (all DB access) → `config/supabase.js`.
  - Repositories use `supabaseAdmin` (service-role key, **bypasses RLS**). So the backend itself must
    check who may read/write what (ownership + role) in services/middleware.
  - `middleware/auth.js`: `verifyToken` checks the Supabase access token, then loads the `public.users` row (role, is_active).
- `frontend/connect-local/`: the Flutter app (imported from the frontend team's v42 zip; the zips were removed from the tree in Nov 2026, still in git history). See SETUP.md to run it.
  - Entry points: `lib/main.dart` (customer + provider app), `lib/main_admin.dart` (separate admin web app).
  - All data comes from the API: `lib/core/api_client.dart` (tokens, refresh, errors) + `lib/core/connect_local_repository.dart`
    (every endpoint) feed `lib/features/community/state/app_state.dart`. Only the sign-in tokens are kept on the device;
    there is no offline / device-only mode (`app_state_storage.dart`, `LocalAuthService`, `DemoPayFastService`, DEV_TOOLS
    were removed). A build without `--dart-define=API_BASE_URL=...` shows a "not connected" page.
  - Slots/working hours: `lib/features/community/models/schedule.dart` (same rules as `backend/src/utils/schedule.js`).
- `docs/api-specs/*.md`: intended API contracts.

## Environment
- Dev happens in **GitHub Codespaces (IPv4 only)**. A teammate also runs the Flutter app in Android Studio; the
  web build is hosted on Netlify (QR code for a campus demo), so the API must work over HTTPS from a browser (CORS).
- **Supabase direct DB host `db.<ref>.supabase.co:5432` is IPv6-only → it fails from Codespaces.**
  Any direct Postgres connection (pg, psql, `supabase db` commands, migrations) must use the **Session pooler**:
  `postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres`
  (note the username is `postgres.<ref>`). Copy the exact string from Dashboard → Connect → Session pooler.
  The supabase-js client (HTTPS) is not affected.
- Secrets live only in `backend/.env` (git-ignored). Never print, commit or hard-code keys, the DB password or the
  service-role key. Never put the service-role key, PayFast merchant key or passphrase in the Flutter app.

## Business rules (must hold in API + DB)
- Sign-up asks "I need a service" (customer) / "I offer a service" (provider). No demo/seed accounts; only the admin is built in.
- Customers need verified email + phone before booking. Phone code: app/back end generates a 6-digit code (no paid SMS),
  expires after 5 min, 5 tries, single use.
- Providers: registration number (format `YYYY/NNNNNN/TT`) + documents; admin approves → `verification_status = verified`.
  Providers need bank details before accepting bookings; store account numbers encrypted, never return them in full.
- Pricing: per hour, fixed price, or packages (`service_packages`: service_id, name, price, description).
- Categories: exactly 10, in this order: Beauty & Health, Healthcare, Plumbing, Cleaning Services, Education & Tutoring,
  Automotive Services, Electrical Services, Events & Photography, Home Maintenance, Other (DB migration
  `20261105200000_connectlocal_categories.sql` = `AppState.kCategories`).
- Booking type: "Visit the business" (`bookings.at_business = true`, needs `providers.offers_visit` + a business address)
  or "House call" (`offers_house_call`, needs the customer's address). A provider offers at least one.
- Time slots: provider working hours (`provider_availability`, standard Mon–Fri 8–17, Sat 9–13 until set) and slot length
  (`providers.slot_minutes`: 30/60/120/240/480). A booking holds one slot (per-hour services: the hours booked) and keeps
  **30 minutes free** before/after other bookings. Times are SAST. The API checks this in createBooking/reschedule;
  `GET /providers/:id/schedule` gives the app the hours + taken times (no customer details).
- Booking flow: customer requests and pays a **15% booking fee by card** (it is a deposit that counts toward the price) →
  provider accepts → 4-digit **PIN** shown to the customer → provider enters the PIN **on arrival** (job starts,
  `in_progress`) → provider completes → customer pays the **balance** (price − fee) by card or cash →
  review allowed after payment. Fee refunded if the provider declines or the customer cancels while pending.
- ConnectLocal keeps a **10% commission** from the provider payout; payouts are automatic (admin does not mark paid).
- Payments via **PayFast** (sandbox while testing). Backend builds + signs the form, receives the ITN on `notify_url`,
  validates it, and records every transaction (`payments`, `receipts`).

## Team and branches (Nov 2026)
- We work on `delevop` (local `fix/round-2` is older). `origin/main` has PR #2 (delevop up to `93150b6`, 6 Nov 2026); later work goes to main by a new PR from `delevop`.
- Teammates push frontend work as branches built on older code: Shuan (`frontend-booking-updates`, Flutter screens),
  radzivhonikharendwe (`delevop`). Merge them into our branch and keep the server-only app state (no device storage).
- `origin/frontend` and `origin/separate-admin` are unrelated-history copies of the v39/v42 zips: do not merge them.

## Known problems found in the code (Nov 2026; items 1-8 are fixed, kept for history)
1. `src/config/database.js` defaults to the IPv6-only direct host and has `connectionTimeoutMillis: 2000`.
   Nothing imports this pool today; either delete it or make it read `DATABASE_URL` (Session pooler) only, with a longer timeout.
2. `src/config/supabase.js` silently falls back to the anon key when `SUPABASE_SERVICE_ROLE_KEY` is missing. Then every
   repository runs under RLS without a user → empty results / permission errors. Fail fast at startup instead.
3. Column names that don't exist in the schema:
   - `repositories/adminRepository.js`: `category`, `description`, `verification_document_url` (providers has
     `business_description`; documents are in `provider_documents`), `average_rating` → `rating_average`,
     `account_status` → `is_active`.
   - `repositories/providerRepository.js:152`: order by `average_rating` → `rating_average`.
4. CommonJS files in an ES-module project (never imported, would crash if used): `controllers/userController.js`,
   `controllers/mapsController.js`, `services/mapsService.js`, `repositories/mapsRepository.js`,
   `routes/userRoutes.js`, `routes/mapsRoutes.js`, `utils/distance.js`. Convert to ESM or remove duplicates.
5. Schema is missing what the app needs: `service_packages` table; `services.pricing_type`; on `bookings`:
   booking fee/deposit, balance, package name/quantity, PIN (store a hash) + tries + verified-at, payment method;
   payout records + commission; phone OTP storage. Add these with migrations.
6. RLS: many tables have duplicate policies from two rounds of setup; `provider_views` uses deprecated `auth.role()`;
   UPDATE policies have no `WITH CHECK`; `"Provider profiles are public" USING (true)` exposes unverified providers.
   Clean up (one policy per action), but remember the backend uses the service role.
7. `migrations/run.js` is a stub. Use the Supabase CLI migrations folder (`supabase/migrations/`) instead.
8. The Flutter app has no API client yet.

## How to work
- Work in small phases. At the end of each phase: run the checks, show me what changed, and **stop for me to test**.
- Ask before: deleting files, changing the database, or anything you can't undo. Show SQL before running it.
- Before any Supabase/DB work, use the installed `supabase` and `supabase-postgres-best-practices` skills; for errors use `debug`.
- Verify every fix (curl the endpoint, run the test, run `flutter analyze`). A fix without a check isn't done.
- Explain changes in simple English. Don't push to `main`; I push after testing.
