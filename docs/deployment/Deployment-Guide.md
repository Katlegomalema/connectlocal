# Deployment Guide — ConnectLocal

## 1. Introduction
Provides step-by-step instructions for deploying ConnectLocal's backend and frontend to the staging environment described in `docs/architecture/Deployment-Architecture.md`.

## 2. Purpose
To enable any team member (or reviewer reproducing the environment) to deploy the system consistently and correctly.

## 3. Scope
Covers backend deployment to Render, database migration application via Supabase, and frontend distribution (Web hosting + debug APK builds).

## 4. Detailed Content

### 4.1 Prerequisites
- GitHub repository access with `main` branch push/merge rights.
- Render account linked to the GitHub repository.
- Supabase project created (staging).
- Google Maps Platform API key with Maps SDK, Places, Geocoding, and Distance Matrix APIs enabled.
- PayFast sandbox merchant account.

### 4.2 Backend Deployment (Render)
1. In Render, create a new **Web Service** and connect it to the `connectlocal` GitHub repository, root directory `backend/`.
2. Set the build command: `npm install && npm run build`.
3. Set the start command: `npm run migrate && npm start`.
4. Configure environment variables in Render's dashboard (see `README.md` Environment Variables section) — never commit these to source control.
5. Enable **Auto-Deploy** on push to `main`.
6. Trigger the first deploy manually to verify build success.
7. Verify the health check endpoint: `GET https://<render-service>.onrender.com/api/v1/health` returns `200 OK`.

### 4.3 Database Migration
1. Install the Supabase CLI locally: `npm install -g supabase`.
2. Authenticate: `supabase login`.
3. Link the project: `supabase link --project-ref <project-ref>`.
4. Apply migrations: `supabase db push` (or, in CI/Render's start command, `npm run migrate` which wraps the equivalent SQL execution).
5. Verify schema via Supabase Studio's Table Editor.

### 4.4 Frontend Deployment
**Web:**
1. `cd frontend && flutter build web --release`
2. Deploy the `build/web` directory to a static host (Render Static Site, Firebase Hosting, or Netlify).
3. Configure the `API_BASE_URL` build-time environment variable to point at the deployed Render backend URL.

**Android (debug/internal testing only, per academic scope):**
1. `flutter build apk --debug`
2. Distribute the resulting APK directly to test devices or via a service such as Firebase App Distribution.

**iOS (simulator/TestFlight internal, if Apple Developer access is available):**
1. `flutter build ios --debug` (requires macOS + Xcode).
2. Run via Xcode on a simulator or registered test device.

### 4.5 Post-Deployment Verification
1. Register a test account through the deployed Web app.
2. Verify email delivery and login.
3. Create a test provider, submit verification, approve via a seeded admin account.
4. Complete a full booking → payment (PayFast sandbox) → review cycle.
5. Confirm push notifications are received on a test device (if FCM configured).

### 4.6 Rollback Procedure
1. In Render, navigate to the service's Deploys tab.
2. Select the last known-good deploy and click "Rollback to this deploy."
3. If the rollback involves a database migration, run the corresponding down-migration script from `backend/migrations/` before rolling back application code, to avoid schema/code mismatches.

## 5. Assumptions
- The team deploying has appropriate access credentials for Render, Supabase, Google Cloud Console, and PayFast.

## 6. Constraints
- Render's free/starter tier may introduce cold-start delays after idle periods; documented as a known limitation for demo scheduling.

## 7. Future Enhancements
- Fully automated migration + deploy pipeline via GitHub Actions rather than Render's build-command-embedded migration step.
- Blue-green deployment for zero-downtime releases.
