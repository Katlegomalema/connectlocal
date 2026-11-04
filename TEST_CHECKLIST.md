# Connect Local – test checklist

Run with a fixed port so data is kept: `flutter run -d chrome --web-port 5000`
There are no demo users: create every account yourself (see TEST_ACCOUNTS.md). Only the admin is built in: admin@email.com / Test@1234. Start clean: Profile → Reset demo data → refresh.
Tick each box. If something fails, note the screen + the red error text from the terminal.

## A. Start-up
- [ ] App opens on the splash screen, then onboarding/login with no red error
- [ ] Refresh the page – app comes back (data kept)

## B. Sign up as a customer ("I need a service")
- [ ] Register shows the two role cards (both same height), form fields and Google button
- [ ] Empty fields / bad email / short password / mismatched passwords each show a message
- [ ] Choose "I need a service" → SIGN UP → verify-email screen → "Verify now (demo)" → Login
- [ ] Registering the same email again is refused; wrong password at login is refused; unknown email is refused
- [ ] Admin → Users shows the new account; Disable blocks login, Enable restores it
- [ ] Login lands on customer Home (no provider onboarding screen)
- [ ] Profile has "Become a Provider" and NO provider-mode switch

## C. Sign up as a provider ("I offer a service")
- [ ] Choose "I offer a service" → SIGN UP → Login → lands on "Become a provider" screen
- [ ] Checklist shows step 1 done, step 2 current; "Browse as a customer for now" opens Home
- [ ] Start application → form opens
- [ ] Bad reg number (2022/311204/99) is rejected; bad ID (8807225234083) is rejected
- [ ] Address: type an address → location found; "Use my current location" works (or shows a clear message)
- [ ] Upload certificate, ID photo and portfolio photos from the business-test-pack
- [ ] Submit → confirmation page → "Back to Home" returns to the onboarding screen showing "Application under review"
- [ ] Applying again with the SAME registration number is rejected

## D. Admin review
- [ ] Log in as admin@email.com → dashboard shows counts and Applications
- [ ] Pending tab lists the new application; open it
- [ ] Automatic checks (ID, reg number, duplicates) show correct ticks; documents open full-size
- [ ] "Verify & approve" stays disabled until the 3 boxes are ticked
- [ ] Reject another application with a reason → appears in Rejected tab
- [ ] Approve → application appears in the Approved tab (stays there after a page refresh)
- [ ] Users, Bookings and Payments tabs open without errors

## E. After approval (the new provider)
- [ ] Log in as that user → notification "approved" and lands in Provider dashboard (or onboarding shows "Open Provider mode")
- [ ] Rejected applicant sees the reason and "Apply again"
- [ ] Provider → Services → add 3 services with prices and photos (data from the pack); one per hour, one with Packages (e.g. 1 / 2 / 3 cameras)
- [ ] Edit a service, switch one off, switch it on again
- [ ] Switch to Customer mode and back; Logout button works in both modes

## F. Customer finds and books
- [ ] Log in as the customer (e.g. Naledi, created by you) → search by name, by service ("clean", "garden") and by category chips
- [ ] New business appears with a "verified" badge, correct distance and map pin in its area
- [ ] Provider profile shows services, portfolio photos, reviews section
- [ ] Book a service: pick the date, ONE preferred time, then either a package (choose between packages with different prices) or hours; address → **booking fee (15%)** screen → pay by Card, Instant EFT (and Apple Pay on Apple devices)
- [ ] Booking appears in My Bookings as Pending ("you pay the rest after the service"); the provider got a notification

## G. Provider handles the booking (new flow)
- [ ] Log in as the provider → booking shows on the dashboard and Bookings
- [ ] Provider without bank details is asked to add them when accepting (use the test bank details)
- [ ] Decline one → customer's booking fee shows as refunded
- [ ] Accept one → customer sees "Booking secured" and the PIN; NO payment is asked yet
- [ ] Chat works both ways
- [ ] Provider "arrives": Enter PIN → wrong PIN rejected (5 wrong tries locks it); correct PIN → "In progress"; customer sees "Provider verified"
- [ ] After the job started the customer can no longer cancel
- [ ] "Complete job" is only available after the PIN; completing it notifies the customer
- [ ] Customer now sees "Pay R…" (also in My Bookings): pay by card → Paid; provider Payouts shows "Payout due"
- [ ] Second booking: customer chooses cash → provider taps "Cash received" → Paid, no payout created
- [ ] Admin → Payouts → Mark as paid (reference) → provider sees "Paid"
- [ ] Earnings / analytics update

## H. Reviews
- [ ] Customer can leave a review once the service cost is paid (stars + comment)
- [ ] Review shows on the provider's public profile and on the provider dashboard
- [ ] A booking can't be reviewed twice

## I. Layout and polish (check every main screen)
- [ ] Back arrows are close to titles and aligned; no screen without a way back
- [ ] Buttons have titles; nothing overflows (yellow/black stripes) at phone width
- [ ] Narrow the browser window to phone size and re-check Register, Home, booking, dashboard

## J. Persistence
- [ ] Refresh mid-flow: applications, approvals, services, bookings, payments and chats are all still there
- [ ] Reset demo data really clears everything

## K. Report back
For each failure send: screen name, what you did, what happened, and the terminal error.

## L. Stages and tabs (new)
- [ ] A package service shows "From R…" in lists and the package choices on the booking screen; price summary follows the chosen package
- [ ] Booking card stage changes: Awaiting provider → Booking secured → In progress → Payment due → Completed
- [ ] A finished but unpaid job stays under **Upcoming** (customer and provider) with "Payment due"; it moves to Past only after payment
- [ ] Cash chosen: "Cash payment pending" until the provider taps "Cash received"
- [ ] Admin → Bookings: Active / Unpaid / Completed summary; the Unpaid tab lists jobs that are done but unpaid; each card shows fee, service cost, PIN, payout, review

## M. v33 checks
- [ ] Login with a wrong password: message shows, password clears, you can type again with no refresh
- [ ] Booking card buttons (Enter PIN to start / Complete job / Cash received / Confirm / Decline) are large and full width
- [ ] After the customer pays, the provider's Payouts shows the amount as **Paid** automatically; Admin → Payouts has no "Mark as paid" button
- [ ] Add a service with **Fixed price** (e.g. Haircut R150): the booking screen shows the price, no duration or packages
- [ ] Payment screen lists Card, Instant EFT, Capitec Pay, Scan to Pay, Mobicred (+ Apple Pay on iPhone, Samsung Pay on Android, Cash after the job)
- [ ] Provider application: ID and certificate can be a photo, a camera shot or a PDF; admin sees a PDF tile for PDFs

## N. v34 commission checks
- [ ] Booking screen: "Pay now (15% deposit)" and "Pay after the service" = price - deposit
- [ ] After the job the customer is asked for the remaining balance only (not the full price)
- [ ] Online payment: provider Payouts shows "Job R3800 - ConnectLocal R380" and R3420 paid
- [ ] Cash payment: after "Cash received" the provider gets deposit minus commission as a payout
- [ ] Admin -> Earnings: commission earned grows; change the rate to 15% and the next job uses 15%

## O. v38 checks
- [ ] Provider profile: tap a service card to select it; the blue button says "Book <service>" and opens the booking form for it. No red Book buttons on the profile, home or search cards
- [ ] Booking form: "Choose on map" opens the map; drag/search/"My location", Confirm; the address fills in
- [ ] Provider -> booking detail -> "Get directions to the customer" opens Google Maps to the pinned spot (or the typed address)
- [ ] Customer -> booking detail -> "Get directions to the provider"; provider profile -> "Get directions"
- [ ] Provider card button reads "Enter PIN to Verify & Start"
- [ ] "Take a photo" opens a live camera preview (allow the camera in the browser), capture returns the photo
- [ ] Pop-up messages disappear after about 3 s and have an X to close them
- [ ] No screen says "booking fee" any more (it says deposit)
