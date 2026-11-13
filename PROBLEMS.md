# ConnectLocal problem history

This is a historical record of problems found and their status, assembled from the
`delevop` commit history through `ec747cf` (7 November 2026), the earlier project
chat context, and [`TEST_REPORT.md`](./TEST_REPORT.md). “Fixed” means the fix is
recorded in a commit or was marked fixed in the earlier project notes; it is not a
claim that every item has been re-tested against the live system today.

## Fixed

| Problem | Resolution and evidence |
|---|---|
| Codespaces could not reliably connect using Supabase's IPv6-only direct database host; the legacy pool also had a short timeout. | Project notes mark this fixed. The database push workflow uses the Supabase Session pooler with TLS; see `103a2ce` and `backend/scripts/db-push.mjs`. |
| Missing `SUPABASE_SERVICE_ROLE_KEY` silently fell back to the anon key, causing backend queries to run under RLS and fail unexpectedly. | Project notes mark the configuration as fail-fast instead of silently falling back. |
| Admin/provider repositories queried columns that do not exist in the schema. | Project notes mark the column mismatches corrected, including provider rating and activation fields. |
| CommonJS duplicates could crash if imported into the ES-module backend. | Project notes mark the unused duplicate modules converted or removed. |
| The schema lacked data required for packages, booking fees and balances, booking PINs, phone codes, and payouts. | Added Supabase migrations for booking/pricing/payout/OTP support; see `103a2ce`. |
| RLS had duplicate policies and unsafe or outdated policy definitions. | The migration work reduced policies from 127 to 35 and hardened sign-up/RLS; see `103a2ce`. |
| The old migration runner was a stub, leaving schema changes without a dependable deployment path. | Replaced it with Supabase CLI migrations and a pooler-aware push script; obsolete stubs were removed in `bb75479`. |
| The Flutter app had no complete API-backed data path and still contained device-only/demo behavior. | The app and admin site were wired to the API, and local/demo data paths were removed; see `3417994`. |
| Sign-up returned an unhelpful 401 when Supabase email delivery failed. | Supabase email errors now map to useful client messages; optional test-only auto-confirm was added. See `25a7098`, `9e41d1b`, and `4dc2f34`. |
| Map tiles failed because CARTO required a key and the volunteer OSM tile service blocked the web app. | Switched to Esri tiles with optional MapTiler configuration and documented key handling; see `36db396`, `0ec4339`, and `dcd3984`. |
| Customers could not see service photos, and provider profiles could select the wrong business photo. | Search and provider profiles now include service photos and all business photos, newest first; see `a6b171d`. |
| A repeated payment attempt could charge twice; booking/payment races and inconsistent validation also needed hardening. | Added idempotent payment handling, duplicate-booking reuse, slot rechecks, and race/ownership safeguards; see `7b6f474` and `bb75479`. |
| Provider registration and service forms had validation and price-entry errors, including decimal prices being saved incorrectly. | Shared client/server validation, field-level errors, safer upload retry, and decimal-price handling were added in `7b6f474`; business-name checks were added in `c860a28` and `f2d61b7`. |
| CI used incorrect project assumptions and failed on pushes. | CI was updated for the actual backend and Flutter folders, supported Node versions, lint, tests, and web builds; see `ec747cf`. |

The first eight entries correspond to the earlier project chat context's
“Known problems found in the code (Nov 2026; items 1–8 are fixed).” The remaining
entries are supported by the commit descriptions and the November 7 test report.

## Still open in the 7 November 2026 test report

These were listed as follow-ups in [`TEST_REPORT.md`](./TEST_REPORT.md). The commits
reviewed through `ec747cf` do not establish that they were subsequently resolved.

| Ref. | Problem / follow-up |
|---|---|
| O1 | Production dependency audit reported a high-severity issue in the installed Zod version; upgrading to Zod 4 was deferred as a breaking change. |
| O2 | `CORS_ORIGINS` still needed the real Netlify origin, and the MapTiler key needed the deployed origin allow-listed. |
| O3 | Two customers can request the same slot concurrently. Payment-time checks prevent both from keeping the slot, but a database exclusion constraint would reject the conflict earlier. |
| O4 | The proposed category-tree migration was waiting for approval. |
| O5 | Privacy/POPIA work remained: privacy page, cookie banner, consent, age requirement, data export/deletion, and admin audit log. |
| O6 | Four legacy `@connectlocal.test` seed accounts and related data were repaired but not deleted. |
| O7 | A real PayFast sandbox checkout still needed a browser-driven test. |
| O8 | Demo email delivery used a personal Gmail account; production should use a transactional provider and rotate the password previously shared in chat. |
| O9 | Supabase password policy still needed confirmation against the app's password rules. |
| O10 | The report noted publicly callable `is_admin()` / `my_provider_id()` functions and a public `GET /users/:id` profile endpoint for review. |
| O11 | Rate limits were in memory and suitable only for a single server instance. |
| O12 | The Android application ID was still `com.example.connect_local`, and release builds still used a debug signing key. |

## Verification recorded

The November 7 report recorded passing lint, 243 unit and 8 integration tests,
Flutter analysis, 57 Flutter tests, both web builds, and a live-database smoke test
with 35 of 35 steps passing. Those results are historical; repeat the checks before
deployment. See [`TEST_REPORT.md`](./TEST_REPORT.md) for the full results and
limitations.
