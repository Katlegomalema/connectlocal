# ConnectLocal: full check before merging to main

Date: 6 November 2026. Branch: `delevop` (main already has PR #2 up to `93150b6`; this round is the next PR). Checked against the live Supabase project (dev) from Codespaces.

**Summary.** The code checks are green: lint, 242 backend tests, 53 Flutter tests, `flutter analyze`, and both
web builds. The live smoke test passes every step it can reach. It stops at the booking fee for two reasons
that need someone with dashboard/database access:

- the payment migration is not applied yet;
- Supabase's built-in email sender limits sign-ups per hour.

**Do not merge to main until items 1–3 under "Must do before the demo" are done and the smoke test passes.**

---

## 1. What passed

| Check | Result |
|---|---|
| Code review of all changes since `main` | 10 findings. All fixed (list in section 4). |
| Backend `npm run lint` | 0 errors, 0 warnings |
| Backend `npm test` | 234 unit tests (26 suites) + 8 integration tests: all pass |
| `flutter analyze` | No issues found |
| `flutter test` | 53 pass. 3 are skipped on purpose: real-upload tests that only run with `--tags e2e` against a running API. |
| `flutter build web` (`lib/main.dart`) | Builds (`build/web`, 3.5 MB `main.dart.js`) |
| `flutter build web` (`lib/main_admin.dart`) | Builds (`build/web-admin`, 2.8 MB `main.dart.js`) |
| Smoke test `backend/scripts/smoke-test.sh` | 18 steps pass (details below). Cleanup leaves 0 test users. |

**What the smoke test proved on the live database:**

- A name with digits is refused at sign-up.
- Login works.
- The phone code (demo code, no paid SMS) verifies.
- The provider creates a business, and the documents (PDF and photo) upload straight to Storage through signed URLs and are attached.
- The application is submitted.
- A customer gets 403 on provider routes and on "approve".
- The admin approves the business.
- Bank details are saved (encrypted).
- A service is added.
- A booking is requested (R450, fee R67.50) for a weekday at 10:00 SAST.

## 2. What failed

| # | Failure | Cause | Fix |
|---|---|---|---|
| F1 | `POST /payments/intent` returns 500: "column payments.idempotency_key does not exist" | Migration `20261106120000_payment_idempotency.sql` (never charge twice) is not applied. My attempt to apply it was blocked. | Run `cd backend && npm run db:push -- --yes`, restart the API, run the smoke test again. |
| F2 | 13 smoke-test steps skipped: fee paid, accept, PIN shown to the customer only, PIN on arrival, complete, cash balance, review, HTML in a review refused, delete someone else's account (403), delete own account, signed out afterwards | They all need the fee payment from F1. | Same as F1. |
| F3 | Sign-up returns 429 after 1–2 accounts in an hour | Supabase's built-in email sender allows only a few emails per hour. At the campus demo the 3rd person to sign up would fail. | Set up custom SMTP in Supabase (SendGrid; a key is already in `.env`) and raise the email rate limit (SETUP.md section 7). The API now says "We cannot send more confirmation emails right now…" instead of a generic error. When this happens, the smoke test marks the step FAIL, creates the account the same way sign-up does, and carries on. |
| F4 | Sign-up with `Longpass11` returns 400 from Supabase: "Password should contain … !@#$…" | The Supabase Auth password policy still requires a symbol. The agreed rule (app + API) is 8+ characters with a capital, a small letter and a number. | Supabase → Authentication → Email → Password requirements: "Lowercase, uppercase letters and digits". Until then the API says "Choose a stronger password: add a symbol". |

## 3. Security pass

| Check | Result |
|---|---|
| Secrets in the code | None. `backend/.env` is git-ignored. `.env.example` has placeholders only. `.env.test` has only the public Supabase local-demo keys. |
| Secrets in git history | None found in any commit (searched for JWTs, service-role and PayFast values, `postgres://user:pass@`). |
| Service-role key only on the server | Read only in `backend/src/config/supabase.js`. Not in Flutter code. Not in either web build (searched `main.dart.js` for `service_role`, `eyJ…` tokens, passphrase). |
| Every route checks role/ownership | Reviewed every router. Public routes are intended: health, categories, search, provider profile/services/schedule, reviews of a provider, PayFast ITN (validated by signature, source IP, amount and a server-side query), and payment return/cancel pages. Everything else uses `verifyToken`, plus `requireRole` or ownership checks in the services. The smoke test confirmed the 403s it reached. |
| Rate limiting | Added (`middleware/rateLimit.js`): login 10 per 15 min per IP+email, register 10/h per IP, password reset 5/h, phone-code checks 10 per 15 min per user (on top of 5 tries per code), payment start 20 per 10 min per user. |
| RLS on every table | On for all 28 tables in `public`. |

## 4. Code-review findings (all fixed)

1. Two quick PIN guesses could both be checked before the try was counted. Now the try is reserved first.
2. The same race existed for phone codes. Same fix.
3. A provider could accept two bookings at the same time. Accept now refuses when another booking is already accepted or in progress at that time.
4. A double tap on "Book" made two pending bookings. The same request now returns the first booking.
5. Paying the fee for a slot that someone else's paid booking took meanwhile. Now refused before checkout.
6. Cash for the balance while a card checkout was open: the card payment is closed. If PayFast still completes it, it is refunded automatically.
7. PayFast retries were answered "200 OK" even when the server failed, so no retry came. Now 500 (PayFast retries). A wrong amount still gets 200 and is ignored.
8. Messages: the app could post into someone else's conversation by sending its id. Now checked.
9. "Report review" hid the review immediately. Now it notifies the admins, who decide.
10. Booking times were sent as the phone's local time. Now always South African time (UTC+2).

## 5. Still open

| # | Item | Why it is open / what to do |
|---|---|---|
| O1 | Apply the payment migration (F1) | Needs `npm run db:push -- --yes` (the tool blocked me). |
| O2 | Custom SMTP + password policy (F3, F4) | Supabase dashboard settings. |
| O3 | Two customers booking the same slot at the same instant | The check is in code, so two requests arriving within milliseconds can both pass. Only the first one to pay the fee is kept (the second is refused at payment), so nobody pays twice. A real fix is a DB exclusion constraint (migration; SQL to be shown first). |
| O4 | Categories proposal (`docs/proposals/category_tree.sql`: 16 main categories + 61 subcategories) | Waiting for your OK. Then: migration, the app loads categories from the API (remove `kCategories`), update CLAUDE.md. |
| O5 | Privacy / POPIA task | Not started: privacy pages, cookie banner, consents table (SQL first), 18+, data export/deletion, admin deletion list, `admin_logs`. |
| O6 | `is_admin()` and `my_provider_id()` are SECURITY DEFINER and callable by anon | Low risk: they only answer about the caller. Could move to a private schema. |
| O7 | `GET /users/:id` is public (name, picture, role) | Intended for profile pages. Make it signed-in only if that is not wanted. |
| O8 | `CORS_ORIGINS` in `.env` is still the placeholder `https://<your-site>.netlify.app` | Set the real Netlify addresses before the demo (SETUP.md 5.3). |
| O9 | Rate limits are kept in memory | Fine for one server. With several servers they would need Redis or the database. |
| O10 | The real PayFast sandbox payment was not clicked through this round | Run `PAY=real bash scripts/smoke-test.sh` after O1 and pay with the sandbox card. |

## 6. Repo cleanup in this round

Removed (all still in git history; restore with `git checkout 7b6f474 -- <path>`):
- `connect-local-v39.zip`, `connect-local-v42.zip`: the app now lives in `frontend/connect-local`.
- `startapp.md`: personal run notes (in SETUP.md now).
- `database/README.md`: said migrations go there; they are in `supabase/migrations/`.
- `backend/migrations/` (stub `run.js` + 2 SQL files already folded into `20261104230000_…`), and the `npm run migrate` script.
- `backend/QUICKSTART.js`, `backend/SETUP_COMPLETE.md`, `backend/BACKEND_STRUCTURE.md`: scaffold notes describing files that don't exist (e.g. `authController.js`).

Moved: `wire.pdf` → `assets/wireframes/wire.pdf`.

Updated: README (structure, how to run, env vars, tests), SETUP.md (email sender, password rule, smoke test),
TEST_ACCOUNTS.md (password rule).

## How to repeat this check

```bash
cd backend && npm run lint && npm test
PORT=3005 node server.js &  API=http://localhost:3005 bash scripts/smoke-test.sh;  kill %1
cd ../frontend/connect-local && flutter analyze && flutter test
flutter build web -t lib/main.dart --dart-define=API_BASE_URL=https://<api>
flutter build web -t lib/main_admin.dart --dart-define=API_BASE_URL=https://<api> --output build/web-admin
```
