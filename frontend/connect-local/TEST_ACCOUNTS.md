# Connect Local – test accounts

There are **no built-in or demo accounts**. Everyone registers in the app. The admin has no account in the
phone app; admin signs in on the separate admin site.

## Run for testing
There is no offline mode any more: the app and the admin site always talk to the backend. See `SETUP.md`
in the project root for the commands (`API_BASE_URL` is required).

Phone verification works in every build: the backend makes the 6-digit code and (outside production) the
app shows it on screen, because no paid SMS is used.

The admin signs in on the admin site with a Supabase account whose `role` is `admin` (SETUP.md, step 4).
Passwords need 8+ characters with a capital, a small letter, a number and a symbol.

## Accounts to create (details in business-test-pack.zip)
Customers: Naledi Khumalo, Sam Ndlovu. Providers ("I offer a service"): Lucas Doe, Thabo Mokoena, Ayanda Zulu,
Pieter van Wyk, Nomsa Khumalo, Sipho Dlamini.

## Flow
1. Register a provider → apply → admin approves (admin site).
2. Provider adds bank details (Payouts) and services.
3. Customer books and pays the 15% deposit → provider accepts → customer sees PIN → provider enters PIN (Verify & Start) → Complete job.
4. Customer pays the balance (or cash confirmed by the provider) → review. Payouts are automatic.
