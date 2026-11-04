# Connect Local – test accounts

**There are no ready-made demo users any more.** Everyone creates their own account in the app
(customers and providers), exactly like real users. Data is kept on the device between runs
(run with `flutter run -d chrome --web-port 5000`; Profile → Reset demo data clears everything).

## The only built-in account: Admin
| Email | Password |
|---|---|
| admin@email.com | Test@1234 |

(Open it from Profile → Demo shortcuts → "Admin portal (testing)" while the app is in debug mode,
or from the separate admin site.) Admins can't be created in the app.

## Accounts to create (see business-test-pack.zip for all the details and documents)
Register at "Create Account". After SIGN UP, tap **"Verify now (demo)"** on the verify screen
(it stands in for the e-mail link), then log in. Use the password `Test@1234` for all of them (any 8+ characters work).

Customers: Naledi Khumalo (naledi@email.com), Sam Ndlovu (sam@email.com)
Providers ("I offer a service"): Lucas Doe, Thabo Mokoena, Ayanda Zulu, Pieter van Wyk, Nomsa Khumalo, Sipho Dlamini

Rules checked: valid email, 8+ character password, matching passwords, one account per email,
one account per full name (names are used to match bookings in this prototype).

## Flow
1. Register a provider → apply with the pack documents → log in as admin → approve.
2. Log in as the provider → add bank details (Payouts) → add services and prices.
3. Register/log in as a customer → search → book → pay the 15% booking fee.
4. Provider accepts → customer sees the PIN → provider "arrives" and enters the PIN (job starts) → provider taps Complete job.
5. Customer pays the rest (card/EFT online, or cash that the provider confirms) → leaves a review.
6. Admin → Payouts → Mark as paid.

Disabling a user in Admin → Users really blocks that person from logging in.
