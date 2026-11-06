# Environment Setup Guide — ConnectLocal

## 1. Introduction
Provides instructions for setting up a local development environment for ConnectLocal, covering both backend and frontend components.

## 2. Purpose
To ensure all team members (and reviewers) can reliably reproduce a working local development environment.

## 3. Scope
Covers local tool installation, environment variable configuration, and initial project bootstrap. Deployment to staging/production is covered separately in `Deployment-Guide.md`.

## 4. Detailed Content

### 4.1 Required Tools
| Tool | Minimum Version | Purpose |
|---|---|---|
| Node.js | 18.x | Backend runtime |
| npm | 9.x | Package management |
| Flutter SDK | 3.19.x | Frontend development |
| Git | 2.x | Version control |
| Supabase CLI | Latest | Local Supabase emulation, migrations |
| Android Studio / Xcode | Latest | Mobile platform builds (as applicable to OS) |
| VS Code (recommended) | Latest | IDE, with ESLint, Dart, and Flutter extensions |

### 4.2 Backend Setup
```bash
cd backend
npm install
cp .env.example .env
# Populate .env with Supabase, database, and PayFast sandbox credentials
npm run migrate
npm run dev
# API available at http://localhost:4000
```

### 4.3 Frontend Setup
```bash
cd frontend
flutter pub get
cp .env.example .env
# Populate .env with API_BASE_URL=http://localhost:4000 and Supabase client settings
flutter run -d chrome     # Web
flutter run                # Connected device/emulator
```

### 4.4 Local Supabase (Optional, for offline development)
```bash
supabase init
supabase start
# Apply migrations
supabase db reset
```
Local Supabase provides a fully offline Postgres + Auth + Storage stack, useful for development without consuming the shared staging project's quota.

### 4.5 Verifying the Setup
1. Backend: `curl http://localhost:4000/api/v1/health` should return `{ "status": "ok" }`.
2. Frontend: the app should load to the login screen without console errors.
3. Run `npm run lint` (backend) and `flutter analyze` (frontend) — both should complete without errors.
4. Run `npm run test:unit` (backend) and `flutter test` (frontend) — both should pass.

### 4.6 Common Issues
| Issue | Resolution |
|---|---|
| `flutter pub get` fails on plugin resolution | Ensure Flutter SDK version matches `frontend/pubspec.yaml` constraints; run `flutter upgrade` |
| Backend fails to connect to Supabase | Verify `SUPABASE_URL` and keys in `.env`; check Supabase project is not paused (free tier auto-pauses after inactivity) |
| Map tiles not rendering | Check the Flutter map tile-layer URL, network permissions, and any tile-provider usage policy; no backend map key is involved |

## 5. Assumptions
- Developers have administrative rights on their local machine to install the required tools.

## 6. Constraints
- iOS development requires macOS; team members on Windows/Linux develop and test primarily against Android and Web targets.

## 7. Future Enhancements
- Provide a Dev Container / Docker Compose setup for fully containerized, OS-agnostic local development.
