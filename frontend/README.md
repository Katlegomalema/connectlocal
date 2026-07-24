# ConnectLocal — Frontend (Flutter)

## Overview
This directory contains the Flutter application for ConnectLocal, targeting Android, iOS, and Web from a single codebase.

## Folder Structure (planned)
```
frontend/
├── lib/
│   ├── main.dart
│   ├── app.dart                  # App widget, routing, theming
│   ├── core/
│   │   ├── config/               # env, constants, theme
│   │   ├── network/               # API client, interceptors
│   │   └── widgets/                # shared/reusable widgets
│   ├── features/
│   │   ├── auth/                   # login, register, verification
│   │   ├── profile/                 # customer profile
│   │   ├── provider/                 # provider profile & onboarding
│   │   ├── search/                    # map & list search
│   │   ├── booking/                    # booking flow & management
│   │   ├── messaging/                   # conversations & chat
│   │   ├── reviews/                      # review submission & display
│   │   ├── payments/                      # PayFast payment flow
│   │   ├── notifications/                  # notification center
│   │   └── admin/                           # admin dashboard (web-focused)
│   └── shared/
│       ├── models/                # data models shared across features
│       └── providers/              # Riverpod providers
├── test/                            # mirrors lib/ structure
├── assets/                           # fonts, icons, images
├── pubspec.yaml
└── .env.example
```

## State Management
Riverpod is used for state management, keeping business logic out of widgets and enabling straightforward unit testing of state notifiers.

## Getting Started
See the root [README.md](../README.md) Getting Started section and [`docs/deployment/Environment-Setup.md`](../docs/deployment/Environment-Setup.md) for full setup instructions.

## Key Dependencies (planned)
- `supabase_flutter` — Auth, Realtime, Storage client
- `google_maps_flutter` — map rendering and geolocation
- `riverpod` / `flutter_riverpod` — state management
- `go_router` — declarative routing
- `dio` — HTTP client for the ConnectLocal API
- `flutter_secure_storage` — secure token storage

## Testing
Run `flutter test` for unit/widget tests and `flutter analyze` for static analysis. See [`docs/testing/Unit-Testing.md`](../docs/testing/Unit-Testing.md) for conventions.
