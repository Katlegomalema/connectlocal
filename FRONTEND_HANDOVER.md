# Frontend hand-over (for the backend / Supabase team)

The UI is finished and runs on in-memory sample data. Each place below is where
real data plugs in. Search the code for `TODO (backend)` and `TODO (DB)` for the rest.

## Sign-in (`lib/features/auth/auth_service.dart`)
- `AuthService.login(email, password)` and `AuthService.signInWithGoogle()`.
- Replace `DemoAuthService` and change the last line of the file to use the real one.
- Return an `AuthResult` (name, email, isProvider, isAdmin).
- Google: throw `AuthCancelledException` if the person closes the Google window
  (the app stays quiet), or `AuthException('message')` for a real failure.
- The login and register screens already show loading states and errors.
- Android Google sign-in also needs the SHA-1/SHA-256 fingerprints registered in
  Google Cloud / Supabase.

## Photos (`lib/features/shared/photo.dart`, `photo_picker.dart`)
- The app lets people take/choose real photos (camera + gallery) for: customer
  profile picture, business picture, service photos, provider-application portfolio.
- A photo is a `PhotoRef`: picked on the device = `bytes` set; already online = `url` set.
- On save: upload every `PhotoRef` with `bytes` (Supabase Storage), then store the
  returned public URL as `PhotoRef(url: ...)`. Screens display both kinds.
- Where photos live in state (`lib/features/community/state/app_state.dart`):
  `customerPhoto`, `me.avatar` (business), `ServiceModel.photos`,
  `ProviderApplicationRecord.photos`.
- Photos are already shrunk to max 1600 px / quality 85 and limited to 8 MB each.

## Location (`AppState.refreshLocation`)
- Real GPS distance to each provider uses `ProviderModel.latitude/longitude`.
  Load these from the database (geocode the provider's address when they save it).

## Other
- Phone verification (Profile > Verify Phone) accepts any 6 digits until an SMS
  service is connected.
- Payment is simulated (3-second "processing" screen).

## Booking, fee and payment rules (v8)
- **Booking fee = 15% of the service cost** (`kBookingFeeRate` in `community/models/models.dart`).
  Service cost = hourly rate x hours. The fee is not part of the provider's earnings.
- Flow: customer picks date, time, duration, address -> **pays the booking fee** -> request goes to
  the provider (status Pending) -> provider accepts or declines -> if accepted the customer **pays the
  service cost** -> provider marks the job complete (only after the customer paid) -> customer can review.
- Refunds: fee is refunded if the provider declines or the customer cancels while Pending. After the
  provider accepted, the fee is non-refundable (service payment is refunded if already paid).
  These rules are in `AppState.setStatus` / `cancelBooking`; confirm them with the business owner.
- A verified phone number (Profile > Verify Phone) is required before sending a request.
- Customer and provider notifications are separate lists (`customerNotifications` / `notifications`).
- Payment is still simulated (`PaymentProcessingScreen`, 3 s). Replace with the real provider and
  call `addCustomerBooking` (fee paid) / `payBalance` (service paid) on success.

## v9: PayFast, service PIN, verification

**Colours:** blue main, red accent (Book buttons, service PIN card), green for success.

**Payments** (`lib/features/booking/payment_service.dart`)
- Booking fee (15%) is always paid by card. Service cost: card or cash.
- The app never handles card numbers. `paymentService` is currently `DemoPayFastService` (simulated). Replace with a real implementation.
- Backend must: (1) build the PayFast form fields (merchant_id, merchant_key, return_url, cancel_url, notify_url, m_payment_id, amount, item_name) and sign them with the passphrase (MD5 signature) - never put merchant_key/passphrase in the app; (2) return a checkout URL (sandbox: https://sandbox.payfast.co.za/eng/process) which the app opens; (3) receive PayFast's ITN on notify_url, validate signature, source IP, amount and server confirmation, then mark the payment `paid` + `verified`; (4) the app polls/gets the result and calls `payBalance` / `addCustomerBooking`.
- Every payment is a `PaymentRecord` (kind, method, amount, gatewayReference, status, verified). Card payments are verified by the ITN; cash by the provider entering the PIN and ticking "cash received".

**Service PIN**
- A unique 4-digit PIN is generated when the provider accepts. Only the customer sees it.
- A job can only be completed by the provider entering that PIN (`AppState.completeWithPin`). 5 wrong tries lock the job. Card jobs must be paid first. Store/check the PIN on the server in production.

**Verification**
- Providers submit a registration number (format 2019/123456/07) and a registration document; an admin reviews and approves, which sets `ProviderModel.verified` (blue tick). An automatic CIPC lookup can be added later.
- Customers need a verified email and phone before booking (`AppState.isClientVerified`).

## Admin website (separate from the phone app)
- Admin screens no longer open from the phone app; admin accounts that try to sign in there are told to use the admin website.
- Run: `flutter run -d chrome -t lib/main_admin.dart`. Build: `flutter build web -t lib/main_admin.dart`.
- Admin demo login: admin@email.com + any password (debug only). Real admin access must be enforced by the backend (role check on every request).
- The admin site currently has its own sample data; it needs the shared backend to see real applications.

## Working verifications (no paid services) - `lib/features/shared/verification.dart`
- Phone: a real 6-digit code is generated, expires after 5 minutes, allows 5 tries and is single use. With no SMS provider the code is shown on screen as a "demo SMS". Replace `OtpService` with SMS/Supabase.
- SA ID number: 13 digits, valid birth date, Luhn check digit, citizenship digit; applicant must be 18+. Admin sees the result plus the ID photo.
- Business registration number: format YYYY/NNNNNN/TT, valid year, valid company-type code, no duplicates. Admin sees the result plus the registration document and decides.
- Service PIN and booking-fee/payment records work as described in v9.
- Paid upgrades later: CIPC lookup, Smile ID face match, real SMS.

## Held payments (escrow-style) with PayFast
- Card service payments are recorded as `held` ("Held by ConnectLocal") and become `released` when the provider enters the customer's PIN. Cancelling refunds a held payment. Cash is never held. The booking fee is platform revenue and is not held.
- Real PayFast: use PayFast's marketplace/split-payment features (check their current terms) so funds are not held in your own account; the PIN event triggers the payout/release on the backend. Sandbox: https://sandbox.payfast.co.za (free test merchant account). The app only simulates this today.

## Admin review (v14)
- Applications can no longer be approved from a list. Tapping one opens `ApplicationReviewScreen` with applicant details, automatic checks (registration format, duplicate number, ID validity/age), both documents, portfolio, and three admin checkboxes. "Verify & approve" stays disabled until documents exist, all automatic checks pass and all boxes are ticked. Rejecting needs a reason, which is sent to the applicant.
- Admin screens now use the same components as the rest of the app (`ui_kit.dart`). Onboarding/status illustrations were recoloured from teal to the brand blue; the logo files are untouched.

## Test accounts
See `TEST_ACCOUNTS.md` (password `Test@1234`, debug builds only).

## Reviews
Customers review from the booking detail page or the "Leave a review" button on completed jobs in My Bookings (one review per PIN-verified job). Reviews show on the provider profile and the provider dashboard (`AppState.reviewsFor`, `ReviewsSection`).

## Provider onboarding & shared state (v22)
- Applying: Profile -> Become a Provider. The applicant sees an `ApplicationBanner` on Home (under review / approved / rejected + reason) and a notification.
- When the admin approves, a real `ProviderModel` is created (verified, owned by the applicant's e-mail). The owner gets Provider mode on next login, sees a "Get ready" checklist and adds services + prices under Services (Add a service). The business appears in other customers' search as soon as it has an active service.
- Notifications are stored per person (customer name / provider id), so a booking request or approval reaches the right account.
- Payment methods (all through PayFast): card, Instant EFT, Apple Pay (iOS/macOS only), plus cash for the service cost. Which methods actually work depends on what is enabled on the merchant's PayFast account; confirm with PayFast.
- Admin dashboard: stats, Manage tiles (Applications, Users, Bookings, Payments) and a 5-item bottom bar.

## Real business locations
No default point any more. The "Become a Provider" form needs a real address: it is looked up with OpenStreetMap Nominatim (`shared/geocoding.dart`, South Africa only), or the provider taps "Use my current location" (GPS + reverse lookup). The coordinates travel with the application, become the provider's map pin and distance when approved, and update when the address is edited in Business profile. Nominatim is free but rate-limited (about 1 request/second): fine for testing; use a paid geocoder (Google, Mapbox, HERE) in production. Run `flutter pub get` (new package: http).

## v24 – data no longer disappears (local persistence)

**Cause of "approved application vanished":** the whole app lived in memory only. A browser refresh,
hot restart, or restarting `flutter run` (Chrome gets a new random port = a new empty storage) wiped
every application, approval, business, booking and payment. There was no bug in the approve logic.

**Fix:** `state/app_state_storage.dart` saves the whole `AppState` (applications, businesses + services,
owners, bookings, payments, chats, notifications, reviews, profile) to the device (`shared_preferences`)
shortly after every change and restores it before the app starts (`main.dart`).

- Run the web app on a FIXED port so the storage is kept between runs:
  `flutter run -d chrome --web-port 5000`
- Photos are saved up to ~3 MB in total (browser limit ~5 MB). Documents are saved first; extra photos
  beyond the budget are not kept after a restart.
- Profile → Demo shortcuts → **Reset demo data** clears the saved data (then refresh).
- The separate admin website (`main_admin.dart`) is still its own app with its own data. For testing
  keep using the in-app admin (`kAdminInApp`) until the backend exists.
- BACKEND HAND-OVER: delete `app_state_storage.dart` and the `loadSaved()` call; each JSON block maps to a table.

## v25 – signing up as a provider from the start

- **Register** now asks "I need a service" / "I offer a service" (`_RoleChoice`). Both are the same kind of account.
- The choice is kept in `AppState.providerSignupIntent` until the first sign-in. `runSignIn` then opens
  `ProviderOnboardingScreen` (new, `community/screens/provider_onboarding_screen.dart`) instead of customer Home.
- The onboarding screen shows a 4-step checklist and the real application status:
  not started -> Start application; pending -> "Browse as a customer meanwhile"; approved -> Open Provider mode;
  rejected -> reason + Apply again. After submitting the form the person returns to this screen.
- Existing accounts still use Profile -> Become a Provider.
- BACKEND HAND-OVER: save the chosen role on the user row at sign-up (replace `providerSignupIntent`).
- v26: fixed blank Register screen (role cards Row needed IntrinsicHeight inside the scroll view).

## v27 – how providers get paid (payout details + payouts)

- `PayoutAccount`, `Payout`, `PayoutStatus` in models.dart; state in AppState (`savePayoutAccount`, `providerPayouts`,
  `payouts`, `markPayoutPaid`) and saved by app_state_storage.dart.
- Provider: **Payout details** form (`payout_details_screen.dart`): bank list with universal branch codes, account type,
  holder name (must match the person's or business name – `bankNameMatches`), account number 9–11 digits, branch code 6 digits.
  **Payouts** screen (`payouts_screen.dart`): bank summary, Pending/Paid totals, history. Open from the dashboard ⋮ menu
  ("Payouts & bank details"); an orange banner on the dashboard asks for bank details until they exist.
- A provider can't accept a booking until bank details exist (`payout_gate.dart` → `confirmBooking`).
- When the PIN completes a card job the held payment is "Released" and a **Payout due** (service price) is created.
  Cash jobs create no payout (the provider keeps the cash; the 15% fee was paid online).
- Admin: dashboard → **Payouts** (badge = number due): shows the provider's bank details, **Mark as paid** + EFT reference;
  the provider is notified and sees "Paid" with the reference.
- BACKEND HAND-OVER: store bank details server-side (encrypted, never sent back in full); replace the manual EFT step with
  PayFast payouts / split payments.

## v28 – real accounts, no demo data
- Removed the demo accounts, sample providers (Bobs, Thandi, Lerato, Green Gardens, Mandla, "Connect Local Services"),
  seed bookings and seed applications, and the "act as provider" testing switch. The app starts empty.
- Accounts are created in the app (`AppState.registerAccount`, `authenticate`) and saved on the device; the password is a
  salted SHA-256 hash (new dependency `crypto`). `LocalAuthService` (auth_service.dart) replaces `DemoAuthService`;
  set in main.dart. The only built-in login is the admin (`kAdminEmail` / `kAdminPassword`, debug builds only).
- Email verification is simulated by the "Verify now (demo)" button on the verify screen.
- Admin → Users lists the real accounts; Disable/Enable really blocks sign-in.
- Storage key bumped to `connect_local_state_v2` (old v1 saves with sample data are ignored).
- BACKEND HAND-OVER: replace `LocalAuthService` with Supabase Auth; drop `accounts`, `salt`, `passwordHash` and use user ids
  instead of names to match bookings/notifications.
- v29: fixed compile error in app_state_storage.dart (local variable 'accounts' shadowed the accounts field).

## v30 – new payment & PIN flow
1. Customer sends a request and pays the 15% **booking fee** online (PayFast). That secures the booking.
2. Provider accepts (needs bank details). Nothing more is paid yet. The customer sees the 4-digit PIN.
3. Provider **arrives**; the customer reads the PIN; the provider enters it (`startWithPin`). This verifies the provider for
   that booking and starts the job (`pinVerified`, shown as "In progress"; the customer can no longer cancel).
4. Provider taps **Complete job** (`completeJob`) -> status Completed; the customer is notified to pay.
5. Customer pays the **service cost after the job**: card / Instant EFT / Apple Pay (PayFast) -> recorded Paid and a Payout due is
   created for the provider; or **cash** -> provider taps "Cash received" (`confirmCashReceived`); no payout for cash.
6. Reviews are available once the service cost is paid.
Removed: paying the full price before the job, "held until PIN", `completeWithPin`.
BACKEND NOTE: unpaid completed jobs are a risk for providers (only the 15% fee is paid up front). Flag them in the admin and block
the customer's new bookings until paid.
- v31: fixed 'final color assigned twice' in customer_booking_detail_screen.dart.

## v32 – service packages, simpler time, clearer booking stages, richer admin bookings
- **Packages:** a service is priced per hour OR has fixed-price packages (e.g. "Install 1 CCTV camera" R1 500 / "Install 3 CCTV cameras" R3 800).
  `ServicePackage`, `ServiceModel.packages`, `priceLabel` ("From R1500" / "R350/hour"). Add/Edit service has a Per hour / Packages switch.
  The booking screen lets the customer choose a package (no duration) or hours. `Booking.packageName`, `quantityLabel`.
- **Time:** the four fixed time slots were removed; the customer picks one preferred time with the time picker.
- **Stages:** `Booking.stage` (Awaiting provider, Booking secured, In progress, Payment due, Cash payment pending, Completed, Declined, Cancelled)
  is shown on every booking card. A finished job that is not paid yet stays under **Upcoming** (customer and provider) until it is paid.
- **Admin → Bookings:** summary (Active / Unpaid total / Completed), tabs by stage, and per booking: fee, service cost status (DUE flagged),
  PIN verification, payout status and the review.
- BACKEND HAND-OVER: services -> `service_packages` table (service_id, name, price, description); bookings get `package_name`.

## v33 – login fix, bigger buttons, automatic payouts, pricing types, more payment methods, document upload
- **Login:** removed `AutofillGroup` and the manual `unfocus()` (they froze the fields on web after a wrong password). After a failed sign-in the password is cleared and focused so the person just retypes.
- **Buttons:** `PillButton` is now 46 px tall / 14 px text; the provider booking card actions are full-width ("Enter PIN to start", "Complete job", "Cash received"). The duplicate stage chip was removed from the footer.
- **Payouts are automatic:** `_createPayout` records a **Paid** payout (ref `PF-PO-n`) as soon as the customer pays; the admin Payouts screen is read-only (history + provider bank details). BACKEND: replace with a PayFast split payment / payout.
- **Pricing types:** `PricingType {hourly, fixed, packages}` on `ServiceModel` (persisted as `pricingType`). Salon-style services use **Fixed price** (no duration); the booking record stores `packageName = 'Fixed price'`.
- **Payment methods:** added Capitec Pay (`cp`), Scan to Pay (`mp`, SnapScan/Zapper/Masterpass), Samsung Pay (`sp`, Android only), Mobicred (`mc`). Booking fee: online methods only; service cost: also cash.
- **Uploads:** `PhotoPicker.pick(allowDocument: true)` offers Take a photo / Choose from gallery / Choose a document (PDF) (`file_picker` added to pubspec; run `flutter pub get`). Camera is now offered in the browser too (phone browsers open the camera). PDFs show a PDF tile (`PhotoRef.isDocument`).

## v34 – commission business model
- **Model:** ConnectLocal keeps a commission (default 10%, `kDefaultCommissionRate`, admin-editable) of each job. The provider pays nothing up front.
- **Deposit:** the 15% booking fee is now a deposit that counts toward the price. `Booking.balance = price - bookingFee` is what the customer pays after the job (`customerTotal == price`). Payment/PIN flow unchanged.
- **Payout:** online -> provider gets `price - commission`; cash -> provider keeps the cash balance and ConnectLocal pays `max(0, deposit - commission)`. `Payout` gained `jobTotal` and `commission`. Created automatically in `_createPayout` (online: `payBalance`; cash: `confirmCashReceived`).
- **Admin -> Earnings** (`admin_earnings_screen.dart`): commission earned, deposits held, jobs value, paid to providers, a slider to set the rate (0-30%, only affects jobs paid afterwards) and a per-job list. `AppState.commissionRate` is persisted (`commissionRate`).
- BACKEND: store the rate in a settings table; do the split with PayFast split payments; handle commission > deposit on cash jobs (provider owes the difference).

## v35 – clearer Add Service form
- Explains that each service (Security audit, Alarm system check, ...) is added separately with its own price; the business name/description come from the application and are shown on the profile.
- Service name hint "e.g. Security audit"; the name cannot equal the business name; the description is labelled "What does this service include?".
- After publishing, the snackbar offers "Add another". Removed the duplicate packages explanation.

## v36 – several services in one go
- Add Service (Per hour and Fixed price): "Add another service" adds name / price / description rows; Publish creates one service per row (same category, pricing type and photos). Rows with a blank description use the main description.

## v37 – Add Service fixes
- Per hour and Fixed price now keep separate prices and extra-service rows (`_hourlyPrice`/`_fixedPrice`, `_extraHourly`/`_extraFixed`), so entries no longer carry over when switching the pricing type.
- The first service is labelled "Service 1" and extra ones "Service 2, 3..." (was "Another service (2)").

## v38 – directions both ways, map picker, in-app camera, cleaner booking flow
- **Directions:** `openDirectionsTo(context, lat, lng, address)` (shared/location_map.dart) opens Google Maps directions. Customer -> provider: "Get directions" on the provider profile and "Get directions to the provider" on the booking detail. Provider -> customer: "Get directions to the customer" on the provider's booking detail (uses the customer's pinned spot, else the typed address). `Booking`/`BookingRequest` gained `latitude`/`longitude` (persisted as `lat`/`lng`).
- **Map picker:** `pickOnMap()` (shared/map_picker_screen.dart): drag the map under a fixed pin, tap, search an address (Nominatim) or "My location"; returns a `GeoPoint` with a readable address. Used by the booking form ("Choose on map"). Typing the address by hand clears the pinned spot.
- **No more red Book buttons:** provider profile services are selectable cards (radio); the big blue button books the selected service ("Book <service>"). Home and search cards are tap-to-open with a chevron.
- **PIN button:** "Enter PIN to Verify & Start"; dialog button "Verify & Start".
- **Camera:** in the browser "Take a photo" opens a live camera preview (`camera` package, `CameraCaptureScreen`); on phones the native camera is used. Needs HTTPS or localhost and camera permission.
- **Wording:** the booking fee is now called the **deposit** everywhere (same 15%, it counts toward the price).
- **Notifications:** snackbars last 3 s and have a close (X) icon (theme + every call site). The demo SMS code snackbar stays 30 s.
- Run `flutter pub get` (new package: camera).

## v39 – business location on the map
- Provider application: "Choose on map" (next to "Use my current location") opens the map picker; the chosen spot and its address fill the business address and are used for directions.
