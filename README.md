# ConnectLocal (Flutter)

Two apps from one code base:
- **Phone/web app** (customers + providers): `lib/main.dart`
- **Admin website** (separate): `lib/main_admin.dart`. The phone app has no admin code or admin login.

The front end is complete. Data is kept on the device until the backend team connects the database.
No demo accounts or shortcuts exist: everyone registers.

## Run
```
flutter pub get
flutter run -d chrome --web-port 5000                       # phone app
flutter run -d chrome -t lib/main_admin.dart                # admin site
```
Testing without a backend: add `--dart-define=DEV_TOOLS=true` (email/SMS/reset-link stand-ins) and, for the admin site,
`--dart-define=DEV_ADMIN_EMAIL=... --dart-define=DEV_ADMIN_PASSWORD=...`. See TEST_ACCOUNTS.md.

## Build
```
flutter build apk --release
flutter build web -t lib/main_admin.dart     # admin site
```

## Folders
- `lib/features/auth` sign-in, register, reset password
- `lib/features/community` customer and provider screens, app state (`provider_ui/` = provider-only screens)
- `lib/features/booking` booking and payment
- `lib/features/admin` admin site screens + `admin_auth.dart`
- `lib/features/shared` config, maps, photo picker, helpers
- `lib/screens` older screens (some unused)

The app id is still `com.example.connect_local` and release builds use the debug key: change both before publishing.
