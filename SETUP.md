# ConnectLocal: how to run and deploy

Three parts work together:

| Part | Code | Where it runs |
|---|---|---|
| Backend API (Express) | `backend/` | GitHub Codespace, port **3000** |
| Customer + provider app (Flutter) | `frontend/connect-local/lib/main.dart` | browser (Codespace port 8080 or Netlify), Android phone or emulator |
| Admin website (Flutter web) | `frontend/connect-local/lib/main_admin.dart` | browser (Codespace port 8081 or Netlify) |
| Database, sign-in, files | Supabase | supabase.com (nothing to run) |

The app keeps **no data on the device** except the sign-in tokens. Everything comes from the API, so the
backend must be running for the app and the admin site to work.

> Secrets (Supabase service-role key, database password, PayFast merchant key, encryption keys) live **only**
> in `backend/.env`, which git ignores. The Flutter apps only ever get `API_BASE_URL`.

---

## 1. Backend in Codespaces

### 1.1 First time only

```bash
cd backend
npm ci
cp .env.example .env        # then fill in the values below
```

Fill in `backend/.env`:

| Setting | Where to get it |
|---|---|
| `SUPABASE_URL`, `SUPABASE_KEY` (anon), `SUPABASE_SERVICE_ROLE_KEY` | Supabase → Project Settings → API |
| `DATABASE_URL` | Supabase → **Connect → Session pooler** (user is `postgres.<ref>`, host `aws-0-<region>.pooler.supabase.com:5432`). The direct `db.<ref>.supabase.co` host is IPv6-only and does **not** work from Codespaces. |
| `CODE_HASH_SECRET` | `node -e "console.log(require('crypto').randomBytes(64).toString('base64url'))"` |
| `PAYOUT_ENCRYPTION_KEY` | `node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"` (do not change it later: saved bank numbers could no longer be read) |
| `PAYFAST_MERCHANT_ID`, `PAYFAST_MERCHANT_KEY` | PayFast sandbox dashboard. Leave `PAYFAST_PASSPHRASE` empty if no passphrase is set there. |
| `PAYFAST_MODE` | `sandbox` while testing |
| `PUBLIC_API_URL` | `https://<your-codespace-name>-3000.app.github.dev` (PayFast sends payment notifications here) |
| `CORS_ORIGINS` | your Netlify site addresses, comma-separated (see section 5) |
| `PASSWORD_RESET_REDIRECT_URL` | the app's web address, e.g. the Netlify app URL (see section 6) |

The server refuses to start if `CODE_HASH_SECRET`, `PAYOUT_ENCRYPTION_KEY` or the Supabase keys are missing.

Apply the database migrations (in `supabase/migrations/`) through the Session pooler:

```bash
cd backend
npm run db:push:dry      # shows what would run
npm run db:push -- --yes # applies it
```

### 1.2 Every time

```bash
cd backend
npm start
```

Then make port **3000** Public, in a second terminal:

```bash
cd backend && npm run port:public      # runs: gh codespace ports visibility 3000:public
```

or in VS Code: **Ports** tab → right-click port **3000** → **Port Visibility → Public**.
Do this **every time you restart the server**: Codespaces can set the port back to Private. A Private port answers
with a GitHub sign-in page (302 / 401) instead of JSON. The app then says *"make port 3000 public"*, and in the
browser it looks like a CORS error.

Check it works:

```bash
curl https://<your-codespace-name>-3000.app.github.dev/health
curl https://<your-codespace-name>-3000.app.github.dev/health/db
```

---

## 2. Flutter in Codespaces

Flutter is not installed in the Codespace; a Docker image is used instead. This shortcut is handy (paste it
into the terminal, or add it to `~/.bashrc`):

```bash
alias flutterd='docker run --rm -v flutter-pub-cache:/root/.pub-cache -v "$PWD":/app -w /app ghcr.io/cirruslabs/flutter:stable flutter'
```

### 2.1 Customer + provider app (port 8080)

```bash
cd frontend/connect-local
tool/run_web_codespace.sh
```

It builds the web app pointing at your Codespace's port 3000, serves it on port 8080, and prints the address.

### 2.2 Admin website (port 8081)

```bash
cd frontend/connect-local
tool/run_web_codespace.sh admin
```

### 2.3 The admin account (one time)

There are no demo accounts. The only built-in account is the admin, and you create it once:

1. Supabase → **Authentication → Users → Add user**: enter the email and a strong password, and tick
   **Auto Confirm User**.
2. Supabase → **SQL Editor**:
   ```sql
   update public.users set role = 'admin' where email = 'admin@your-domain.example';
   ```
3. Sign in on the admin website with that email and password. (Admin accounts cannot sign in to the phone app.)

---

## 3. On a phone

The API address must be **HTTPS**: Android blocks plain `http://` addresses. Use the Codespace address
`https://<your-codespace-name>-3000.app.github.dev` with port 3000 set to Public.

### 3.1 In the phone's browser
Make port **8080** Public as well (Ports tab), then open `https://<your-codespace-name>-8080.app.github.dev`
on the phone. For a campus demo, use the Netlify site instead (section 5).

### 3.2 Android Studio (emulator or a phone on USB)
1. Pull the branch, open `frontend/connect-local`, and run **Pub get**.
2. **Run → Edit Configurations… → Additional run args**:
   ```
   --dart-define=API_BASE_URL=https://<your-codespace-name>-3000.app.github.dev
   ```
3. Choose the emulator or phone and press Run.

Command-line version:

```bash
flutter run --dart-define=API_BASE_URL=https://<your-codespace-name>-3000.app.github.dev
```

If `API_BASE_URL` is missing, the app shows the "This build is not connected to the ConnectLocal server" page.

### 3.3 An APK to install on any Android phone

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<your-codespace-name>-3000.app.github.dev
# file: build/app/outputs/flutter-apk/app-release.apk
```

---

## 4. PayFast sandbox payments

1. `PAYFAST_MODE=sandbox`, the sandbox merchant ID and key, and `PUBLIC_API_URL` set in `backend/.env`.
   Restart the backend after any change.
2. Port 3000 **Public**: PayFast's server has to reach `/api/v1/payments/payfast/itn`.
3. In the app, pay a booking fee. The sandbox page opens; complete the payment there. The app shows "paid"
   within a few seconds, and the backend terminal logs the notification (ITN).
4. If the log says `Rejected PayFast ITN from a non-PayFast address`, it also lists the addresses it saw.
   Change `PAYFAST_TRUSTED_PROXY_HOPS` (default 1) to match the forwarding chain, then restart.

**Payouts to providers:** PayFast has no bank-transfer API for this project, so in **sandbox** the payout is
simulated: it is marked paid automatically with a `SIM-…` reference about a minute after the balance is
paid. With `PAYFAST_MODE=live`, payouts stay "pending" until a real transfer service is connected. The
backend never marks one paid with a fake reference in live mode.

---

## 5. Deploy the web builds to Netlify

Netlify's build servers do not have Flutter, so build in the Codespace and upload the finished folder.

### 5.1 Build

`API_BASE_URL` is baked in when you build, so rebuild if the backend address changes.

```bash
cd frontend/connect-local
API=https://<your-codespace-name>-3000.app.github.dev
flutterd build web --release --dart-define=API_BASE_URL=$API -o build/web
flutterd build web --release -t lib/main_admin.dart --dart-define=API_BASE_URL=$API -o build/web_admin
sudo chown -R "$(id -u):$(id -g)" build   # the container writes files as root
```

### 5.2 Upload (two sites: the app and the admin website)

**By hand:** app.netlify.com → **Add new site → Deploy manually** → drag the `build/web` folder in.
Do the same with `build/web_admin` for a second site.

**With the Netlify CLI** (from `frontend/connect-local`):

```bash
npx netlify-cli login
npx netlify-cli deploy --prod --dir build/web          # the app site
npx netlify-cli deploy --prod --dir build/web_admin    # choose/create the admin site
```

The apps use `#/` addresses, so no redirect rules are needed.

### 5.3 Allow the Netlify sites in the backend (CORS)

In `backend/.env` (exact addresses, no trailing slash):

```
CORS_ORIGINS=https://<your-app>.netlify.app,https://<your-admin>.netlify.app
```

Restart the backend. Without this, the browser blocks every API call from the Netlify sites.

### 5.4 For the campus demo (QR code)

- The QR code points to the **app** site, `https://<your-app>.netlify.app`.
- During the demo the Codespace must be **running**, with `npm start` going and port 3000 **Public**.
  A stopped Codespace means "cannot reach the server" in the app.
- Codespaces stop after 30 idle minutes by default. Raise it under GitHub → Settings → Codespaces →
  **Default idle timeout** (max 240 minutes) before the demo.
- Your Codespace address stays the same while you keep using the same Codespace. A new Codespace has a new
  address, so rebuild and redeploy (5.1–5.2) and update `PUBLIC_API_URL`.

---

## 6. Maps and address search

- **Map tiles:** CARTO "Voyager" (OpenStreetMap data), free without a key, allowed for apps and web pages.
  The attribution "© OpenStreetMap contributors © CARTO" must stay visible (it is drawn on every map).
  Another provider: build with `--dart-define=MAP_TILE_URL=...` and `--dart-define=MAP_ATTRIBUTION=...`.
- **Address search** goes through our backend (`GET /api/v1/geo/search?q=`, `/geo/reverse?lat=&lng=`). It calls
  Nominatim at most once per second with ConnectLocal's name, and caches answers. Optional in `backend/.env`:
  `NOMINATIM_EMAIL` (so Nominatim can contact us instead of blocking us).
- No Google Maps key is used anywhere; you can delete `GOOGLE_MAPS_API_KEY` from `backend/.env`.

## 7. Emails (confirm address, reset password)

Supabase sends both emails.

- **Confirm email:** the link opens `EMAIL_REDIRECT_URL` (or the first `FRONTEND_URL`). Set it to the app site.
- **Reset password:**
  1. Set `PASSWORD_RESET_REDIRECT_URL` to the app site, e.g. `https://<your-app>.netlify.app/`.
  2. Add the same address under Supabase → **Authentication → URL Configuration → Redirect URLs**.
  3. Supabase → **Authentication → Email Templates → Reset Password**: make the link
     ```html
     <a href="{{ .RedirectTo }}?type=recovery&token_hash={{ .TokenHash }}">Reset your password</a>
     ```
     The app sees `type=recovery&token_hash=…` in the address, opens the "new password" page, and sends the
     token to the backend (`POST /api/v1/auth/reset-password`).

---

## 8. Checks before you push

```bash
# backend
cd backend
npm run lint
npm test
PORT=3005 node server.js &                               # a second server just for the next line
node --env-file=.env scripts/e2e-booking-flow.mjs 3005   # whole flow against the real database; cleans up after itself
kill %1

# Flutter
cd ../frontend/connect-local
flutterd analyze
flutterd test
```

The end-to-end script creates temporary `cl-curltest-…@connectlocal.test` users and deletes them at the
end. It should finish with `ALL PASSED` and `temporary test users left: 0`.

---

## 9. Common problems

| What you see | Fix |
|---|---|
| App: "cannot reach the server" / "make port 3000 public" / the API returns an HTML page | Port 3000 is Private (`npm run port:public`), or the backend is not running. |
| Login works, then stops after a while | The port went back to Private after a server restart: run `npm run port:public` again. |
| Map: "The map can't load" | No internet on the device. Tap Retry once it is back. |
| "Location is blocked for ConnectLocal" | Phone: Settings → Apps → ConnectLocal → Permissions → Location. Chrome: lock icon in the address bar → Location → Allow. |
| Browser console: "blocked by CORS policy" | Add the site's exact address to `CORS_ORIGINS`, then restart the backend. |
| `Port 3000 is already in use` | `kill $(lsof -t -i:3000)`, or start on another port: `PORT=3001 npm start`. |
| `npm run db:push` cannot connect | Use the Session pooler string (section 1.1), not `db.<ref>.supabase.co`. |
| Provider cannot accept: "Add your bank details" | Provider mode → Payouts → Payout details. The holder name must be the provider or the business. |
| Payout stays pending: "Waiting for bank details" | The provider adds bank details, and the payout goes on the next run (within a minute). |
| The customer's request is missing in the provider's list | The 15% booking fee has not been paid yet. Unpaid requests are hidden and stop holding the time slot after 30 minutes. |
