# ConnectLocal: Flutter app

Two apps from one code base, both talking only to the ConnectLocal API:

| App | Entry point | Who |
|---|---|---|
| Customer + provider app (web, Android) | `lib/main.dart` | "I need a service" / "I offer a service" |
| Admin website | `lib/main_admin.dart` | the ConnectLocal admin (verifies businesses) |

All data comes from the API. Only the sign-in tokens are stored on the device. A build without
`--dart-define=API_BASE_URL=...` shows a "not connected to the ConnectLocal server" page.

## Run

In Codespaces (Flutter runs in Docker) see [START.md](../../START.md). With Flutter installed:

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000                       # app
flutter run -d chrome -t lib/main_admin.dart --dart-define=API_BASE_URL=http://localhost:3000  # admin site
```

Maps use MapTiler when a key is given (`--dart-define=MAPTILER_KEY=...`; `tool/run_web_codespace.sh` reads the
git-ignored file `.maptiler-key`), otherwise Esri's street map. See [SETUP.md](../../SETUP.md) section 6.

## Build

```bash
flutter build web -t lib/main.dart       --dart-define=API_BASE_URL=https://<api> --dart-define=MAPTILER_KEY=<key>
flutter build web -t lib/main_admin.dart --dart-define=API_BASE_URL=https://<api> -o build/web_admin
flutter build apk --release              --dart-define=API_BASE_URL=https://<api> --dart-define=MAPTILER_KEY=<key>
```

## Code map

| Folder | What is in it |
|---|---|
| `lib/core/` | `api_client.dart` (tokens, refresh, retries, friendly errors), `connect_local_repository.dart` (every endpoint), payment keys |
| `lib/features/community/` | customer and provider screens, `state/app_state.dart` (app state, server-only), models; `provider_ui/` = provider-only screens |
| `lib/features/booking/` | booking, time slots, PayFast payment screens |
| `lib/features/auth/` | sign-in, register, verify email/phone, reset password |
| `lib/features/admin/` | admin website screens |
| `lib/features/shared/` | validators (same rules as the backend), maps, photos, SA time helpers |
| `test/` | unit and widget tests (`test/e2e/` uploads to a real API and skips itself without one) |

## Checks

```bash
flutter analyze
flutter test
```

Before publishing to an app store: change the app id (`com.example.connect_local` in `android/app/build.gradle.kts`)
and set up a release signing key (release builds use the debug key today).
