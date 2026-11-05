# Connect Local – test accounts

There are **no built-in or demo accounts**. Everyone registers in the app. The admin has no account in the
phone app; admin signs in on the separate admin site.

## Run for testing (needs the backend)
Accounts are only created through the backend; there are no device-only accounts any more.
Start the backend (Codespace: `cd backend && npm start`, port 3000 set to Public), then:

Phone app:  `flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=https://<codespace>-3000.app.github.dev`
Admin site: `flutter run -d chrome --web-port 8081 -t lib/main_admin.dart --dart-define=API_BASE_URL=https://<codespace>-3000.app.github.dev`

Without `API_BASE_URL`, sign-up and login show "The app is not connected to a server".
Phone verification: the backend creates the 6-digit code; outside production it is returned to the app and
shown on screen like an SMS (no paid SMS).

## Accounts to create (details in business-test-pack.zip)
Customers: Naledi Khumalo, Sam Ndlovu. Providers ("I offer a service"): Lucas Doe, Thabo Mokoena, Ayanda Zulu,
Pieter van Wyk, Nomsa Khumalo, Sipho Dlamini. Any password of 8+ characters.

## Flow
1. Register a provider → apply → admin approves (admin site).
2. Provider adds bank details (Payouts) and services.
3. Customer books and pays the 15% deposit → provider accepts → customer sees PIN → provider enters PIN (Verify & Start) → Complete job.
4. Customer pays the balance (or cash confirmed by the provider) → review. Payouts are automatic.
