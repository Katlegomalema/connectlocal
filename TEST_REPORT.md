# ConnectLocal: test report

Date: 7 November 2026. Branch: `delevop` (to be merged into `main` by pull request). Checked against the live
Supabase project from GitHub Codespaces.

**Summary.** Everything we can test automatically passes. The full booking flow runs end to end on the real database
(35 of 35 steps). The repo has been cleaned up and CI has been fixed. Items still open are listed in section 4; none of them blocks the demo.

---

## 1. Results

| Check | Result |
|---|---|
| Backend lint (`npx eslint src/ --max-warnings=0`) | 0 errors, 0 warnings |
| Backend tests (`npm test`) | 243 unit + 8 integration tests pass. Also checked on a clean Node 22 machine without `.env`, the way CI runs them. |
| Flutter `flutter analyze` | No issues |
| Flutter `flutter test` | 57 pass. 3 real-upload tests skip themselves when no API is running. |
| Web build `lib/main.dart` (customer + provider app) | Builds |
| Web build `lib/main_admin.dart` (admin site) | Builds |
| Smoke test `backend/scripts/smoke-test.sh` on the live database | **35 passed, 0 failed, 0 skipped**; all test users deleted afterwards |
| Database migrations | Up to date (`npm run db:push:dry`: "Remote database is up to date") |

**What the smoke test walks through:**

1. **Sign-up and phone.** A customer and a provider sign up through the API; the confirmation emails go out through Gmail SMTP. A name containing digits is refused. Both log in, and the customer verifies a phone code.
2. **Provider application.** The provider creates a business and uploads a PDF and a photo straight to Storage. The application is submitted.
3. **Admin approval.** A customer is refused (403) on provider and admin routes. The admin approves the business.
4. **Setup.** The provider saves bank details (encrypted) and adds a service.
5. **Booking and fee.** The customer books a weekday at 10:00 SAST (R450, booking fee R67.50) and pays the fee through PayFast. A simulated payment notification (ITN) marks the fee paid. Starting the payment again with the same key returns the same payment, so nobody is charged twice.
6. **The job.** The provider accepts. Only the customer sees the PIN; the provider is refused it. The provider enters the PIN and the job starts, then completes the job.
7. **Balance and review.** The customer pays the R382.50 balance in cash and the provider confirms it. The customer leaves a review; a review containing HTML is refused.
8. **Delete account.** A user is refused (403) when deleting someone else's account. The customer deletes their own account, and the deleted account is signed out everywhere.

## 2. Fixed in this round

| Problem | Fix |
|---|---|
| New users could not register: Supabase answered 500 "Error sending confirmation email", which the API reported as 401 "Registration failed" | Custom SMTP (Gmail App Password) set up in Supabase. Supabase errors now map to clear messages, which the app shows. Merged with Shuan's `backend-signup-fix`, which adds the test-only `AUTH_AUTO_CONFIRM_SIGNUPS` setting (off). |
| Supabase Auth failed with "Database error finding users" | 4 old seed accounts (`@connectlocal.test`) had NULL values in `auth.users` columns. Repaired by setting them to empty text. |
| Maps showed "API KEY REQUIRED" (CARTO), then "Access blocked" (OpenStreetMap's volunteer servers) | MapTiler with a free browser key that only works from our addresses. The key file is git-ignored. Without a key the app falls back to Esri's street map. |
| Customers did not see the photos providers uploaded | Search and provider profiles now send every business photo (newest first; the newest is the profile picture) and each service's photos. Before, services had none, and only the oldest business photo was sent. |
| CI failed on every push (red badges on GitHub) | The workflows were rewritten for the real project. Backend: Node 22 and 24, lint, tests, production audit. Frontend: the right folder, current Flutter, analyze, tests, both web builds. |
| The backend needs Node 22+ (supabase-js uses Node's built-in WebSocket); the docs said Node 18 | `engines` set to `>=22`; README and CLAUDE.md updated. |
| Smoke test made up a registration year in the future (e.g. 2074), which the app rightly refuses | It now uses a year between 2000 and 2025. |

## 3. Security

| Check | Result |
|---|---|
| Secrets in code and git history | None. The whole history was searched for JWTs, SendGrid keys, the MapTiler key and the Gmail passwords from this week. `backend/.env` and `frontend/connect-local/.maptiler-key` are git-ignored. |
| Service-role key only on the server | Yes. Not in the app or either web build. |
| Every route checks role/ownership | Yes. The smoke test confirms the 403s above. |
| Rate limits | Login, sign-up, password reset, phone codes and payment start. |
| RLS | On for every table. |
| Dependency audit (production) | No critical issues. 1 high (`zod`), see O1. |

## 4. Still open

| # | Item | What to do |
|---|---|---|
| O1 | `zod` < 4.6.6: memory exhaustion on very large inputs (high) | The fix is zod 4, a breaking upgrade that touches every request schema. Plan it as its own change. The 10 MB request size limit reduces the risk meanwhile. |
| O2 | `CORS_ORIGINS` in `backend/.env` is still the placeholder | Set the real Netlify address(es) before deploying there. Also add the Netlify address to the MapTiler key's allowed origins. |
| O3 | Two customers booking the same slot at the same instant | Only the first to pay keeps it; the other is refused at payment, so nobody pays twice. A database exclusion constraint would stop it earlier (migration; SQL to be reviewed first). |
| O4 | Category tree proposal (`docs/proposals/category_tree.sql`) | Waiting for approval. |
| O5 | Privacy/POPIA (privacy page, cookie banner, consents, 18+, data export and deletion, admin log) | Not started. |
| O6 | 4 old seed accounts (`@connectlocal.test`, with 2 providers and 2 bookings) | Repaired, not deleted. The project rule is "no seed accounts": delete them with their data (SQL to be reviewed first). |
| O7 | A real PayFast sandbox payment (clicking through checkout) | Run `PAY=real bash scripts/smoke-test.sh` with port 3000 public. |
| O8 | Emails go through a personal Gmail account | Fine for the demo (about 500 emails a day; may land in spam). Use a transactional email service in production. Change the Gmail password, since it was shared in chat. |
| O9 | Supabase password policy | Check that it is "lowercase, uppercase, digits", the same as the app. |
| O10 | `is_admin()` / `my_provider_id()` are callable by anon; `GET /users/:id` is public (name, picture, role) | Low risk (they only answer about the caller / public profile data). |
| O11 | Rate limits are kept in memory | Fine for one server. |
| O12 | Android app id `com.example.connect_local`, release builds use the debug key | Change both before publishing to an app store. |

## 5. Repo cleanup

Removed (all still in git history: `git checkout <older commit> -- <path>`):
- `frontend/README.md`: a planned structure that was never used (Riverpod, Google Maps, Dio).
- `frontend/connect-local/FRONTEND_HANDOVER.md`: notes about the device-only version (demo login, "Reset demo data").
- `frontend/connect-local/TEST_CHECKLIST.md`: the same; covered by the smoke test and TEST_ACCOUNTS.md.
- `supabase/.temp/`: Supabase tool state, now git-ignored.

Rewritten: README (what GitHub shows), the backend and app READMEs, CONTRIBUTING (the `delevop` → `main` flow),
both CI workflows. Added: START.md (copy-paste start commands).

## How to repeat

```bash
cd backend && npm run lint && npm test
PORT=3005 node server.js &   API=http://localhost:3005 bash scripts/smoke-test.sh;   kill %1
cd ../frontend/connect-local && flutter analyze && flutter test
```
