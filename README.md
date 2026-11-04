# ConnectLocal (Flutter app)

Customer, provider and admin app for ConnectLocal. The front end is complete and runs on **sample data held in memory** (nothing is saved when the app closes). This repo is ready for the backend and database to be connected.

## Start here
- Read **ConnectLocal Backend and Database Hand-over** (the document that came with this folder). It lists the data, rules, suggested API and all 41 `TODO` markers.
- Sign-in has one connection point: `lib/features/auth/auth_service.dart`.
- All other data is held in `lib/features/community/state/app_state.dart`.
- Search the project for `TODO` to find every place that needs real data.

## Run it
```
flutter pub get
flutter run
```
Debug builds show "Demo shortcuts" on Profile and accept two test accounts (any password):
`provider@email.com` (provider) and `admin@email.com` (admin). Any other email is a customer.

## Build
```
flutter build apk --release                                   # real build: no shortcuts, no test accounts
flutter build apk --release --dart-define=DEMO_ACCOUNTS=true  # team-only demo APK, keeps test accounts
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

## Before publishing
The app id is still `com.example.connect_local` and release builds are signed with the debug key. Change both for the Play Store.

## Folders
- `lib/features/auth` sign-in, register, reset password
- `lib/features/community` customer and provider screens, app state
- `lib/features/booking` booking and payment
- `lib/features/admin` admin screens
- `lib/screens` older shared screens (some unused; see the hand-over document, section 8)
