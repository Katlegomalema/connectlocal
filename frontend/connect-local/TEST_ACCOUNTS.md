# Connect Local – test accounts

There are **no built-in or demo accounts**. Everyone registers in the app. The admin has no account in the
phone app; admin signs in on the separate admin site.

## Run for testing without a backend
Phone app:  `flutter run -d chrome --web-port 5000 --dart-define=DEV_TOOLS=true`
Admin site: `flutter run -d chrome -t lib/main_admin.dart --dart-define=DEV_ADMIN_EMAIL=you@example.com --dart-define=DEV_ADMIN_PASSWORD=pick-a-password`

Phone verification works in every build: the app generates the 6-digit code and shows it on screen (turn off with `SIMULATED_SMS=false`). `DEV_TOOLS` shows the stand-ins for the email link / reset link. A normal build hides them and
phone/email verification then needs the backend. The two apps keep separate local data until the backend
connects them.

## Accounts to create (details in business-test-pack.zip)
Customers: Naledi Khumalo, Sam Ndlovu. Providers ("I offer a service"): Lucas Doe, Thabo Mokoena, Ayanda Zulu,
Pieter van Wyk, Nomsa Khumalo, Sipho Dlamini. Any password of 8+ characters.

## Flow
1. Register a provider → apply → admin approves (admin site).
2. Provider adds bank details (Payouts) and services.
3. Customer books and pays the 15% deposit → provider accepts → customer sees PIN → provider enters PIN (Verify & Start) → Complete job.
4. Customer pays the balance (or cash confirmed by the provider) → review. Payouts are automatic.
