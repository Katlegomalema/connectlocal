#!/usr/bin/env bash
# =====================================================================================================
# ConnectLocal smoke test: walks the main flow against a RUNNING backend with plain curl.
#
#   cd backend && npm start                       # in another terminal (or PORT=3005 npm start)
#   bash scripts/smoke-test.sh                    # default API http://localhost:3000
#   API=http://localhost:3005 bash scripts/smoke-test.sh
#   PAY=real bash scripts/smoke-test.sh           # pay the booking fee yourself in the PayFast sandbox
#
# Flow: register customer + provider -> confirm email (test helper) -> verify phone (demo code) -> apply as
# provider (documents straight to Storage) -> admin approves -> bank details + add service -> book -> pay fee
# (PayFast sandbox) -> accept -> PIN on arrival -> complete -> balance in cash -> review -> delete account.
#
# Test helpers use the service-role key from backend/.env ONLY to do what a person would do in an email
# inbox or the Supabase dashboard (confirm the email, make the test admin, simulate the PayFast ITN when
# PAY=simulate). The key is never printed. Everything the script creates is deleted at the end.
# Needs: curl, jq. Exit code 0 = everything passed.
# =====================================================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

API="${API:-http://localhost:3000}/api/v1"
PAY="${PAY:-simulate}"
SB_URL=$(grep -E '^SUPABASE_URL=' .env | cut -d= -f2-)
SB_KEY=$(grep -E '^SUPABASE_SERVICE_ROLE_KEY=' .env | cut -d= -f2-)
STAMP=$(date +%s)
MAILDOMAIN="${SMOKE_EMAIL_DOMAIN:-mailinator.com}" # sign-up checks the domain can receive mail; a public catch-all inbox
PASS=0; FAIL=0
CREATED_USERS=()
BOOKING_ID=""; PROVIDER_ID=""; SERVICE_ID=""; PAYMENT_ID=""; CHECKOUT=""; SKIPPED=0

ok()   { PASS=$((PASS + 1)); printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  \033[31mFAIL\033[0m %s  %s\n' "$1" "${2:-}"; }
step() { printf '\n== %s\n' "$1"; }

# call METHOD PATH [TOKEN] [JSON] [extra curl args...] -> sets $STATUS and $BODY
call() {
  local method=$1 path=$2 token=${3:-} data=${4:-}; shift 4 2>/dev/null || shift $#
  local args=(-s -o /tmp/cl-smoke-body -w '%{http_code}' -X "$method" "$API$path" -H 'Accept: application/json')
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  [ -n "$data" ] && args+=(-H 'Content-Type: application/json' --data "$data")
  STATUS=$(curl "${args[@]}" "$@")
  BODY=$(cat /tmp/cl-smoke-body)
}
expect() { # expect LABEL CODE  (uses $STATUS/$BODY)
  if [ "$STATUS" = "$2" ]; then ok "$1"; return 0; fi
  bad "$1" "(HTTP $STATUS: $(echo "$BODY" | jq -r '.message? // empty' 2>/dev/null | head -c 160))"; return 1
}
sb() { # Supabase helper: sb METHOD PATH [JSON]  (Auth admin / REST, service role)
  curl -s -X "$1" "$SB_URL$2" -H "apikey: $SB_KEY" -H "Authorization: Bearer $SB_KEY" \
    -H 'Content-Type: application/json' -H 'Prefer: return=representation' ${3:+--data "$3"}
}

cleanup() {
  step "Cleanup"
  if [ -n "$BOOKING_ID" ]; then
    for t in payouts reviews messages; do sb DELETE "/rest/v1/$t?booking_id=eq.$BOOKING_ID" >/dev/null; done
    pay_ids=$(sb GET "/rest/v1/payments?booking_id=eq.$BOOKING_ID&select=id" | jq -r '[.[].id] | join(",")')
    [ -n "$pay_ids" ] && sb DELETE "/rest/v1/receipts?payment_id=in.($pay_ids)" >/dev/null
    sb DELETE "/rest/v1/payments?booking_id=eq.$BOOKING_ID" >/dev/null
    sb DELETE "/rest/v1/bookings?id=eq.$BOOKING_ID" >/dev/null
  fi
  if [ -n "$PROVIDER_ID" ]; then
    svc=$(sb GET "/rest/v1/services?provider_id=eq.$PROVIDER_ID&select=id" | jq -r '[.[].id] | join(",")')
    [ -n "$svc" ] && sb DELETE "/rest/v1/service_images?service_id=in.($svc)" >/dev/null
    for t in services provider_gallery provider_documents provider_payout_details provider_availability; do
      sb DELETE "/rest/v1/$t?provider_id=eq.$PROVIDER_ID" >/dev/null
    done
    sb DELETE "/rest/v1/providers?id=eq.$PROVIDER_ID" >/dev/null
  fi
  for id in "${CREATED_USERS[@]}"; do
    for bucket in provider-documents provider-photos; do
      for folder in documents photos; do
        names=$(curl -s -X POST "$SB_URL/storage/v1/object/list/$bucket" -H "apikey: $SB_KEY" -H "Authorization: Bearer $SB_KEY" \
          -H 'Content-Type: application/json' --data "{\"prefix\":\"$id/$folder\"}" | jq -c "[.[]?.name | \"$id/$folder/\" + .]")
        [ "$names" != "[]" ] && [ -n "$names" ] && curl -s -X DELETE "$SB_URL/storage/v1/object/$bucket" -H "apikey: $SB_KEY" \
          -H "Authorization: Bearer $SB_KEY" -H 'Content-Type: application/json' --data "{\"prefixes\":$names}" >/dev/null
      done
    done
    sb DELETE "/auth/v1/admin/users/$id" >/dev/null
  done
  left=$(sb GET "/rest/v1/users?email=like.cl-smoke-*&select=id" | jq 'length')
  echo "  temporary test users left: $left"
  printf '\n%s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIPPED"
  rm -f /tmp/cl-smoke-customer-id /tmp/cl-smoke-provider-id /tmp/cl-smoke-body /tmp/cl-smoke-doc.pdf /tmp/cl-smoke-id.jpg
}
trap cleanup EXIT

register() { # register ROLE NAME -> echoes user id; confirms the email like clicking the link
  local email="cl-smoke-$1-$STAMP@$MAILDOMAIN"
  call POST /auth/register "" "{\"email\":\"$email\",\"password\":\"Smoke!$STAMP\",\"fullName\":\"$2\",\"role\":\"$1\"}"
  local id; id=$(echo "$BODY" | jq -r '.data.userId // empty')
  if [ "$STATUS" = 429 ] && [ -z "$id" ]; then
    # Supabase's built-in mailer allows only a few sign-up emails per hour. Report it, then create the same
    # account the way sign-up does (same metadata -> same handle_new_user trigger) so the rest can run.
    bad "register $1 through the API" "(429: Supabase email limit; set up custom SMTP)"
    id=$(sb POST /auth/v1/admin/users "{\"email\":\"$email\",\"password\":\"Smoke!$STAMP\",\"email_confirm\":true,\"user_metadata\":{\"full_name\":\"$2\",\"role\":\"$1\"}}" | jq -r '.id // empty')
    [ -n "$id" ] || return 1
  elif [ "$STATUS" != 201 ] || [ -z "$id" ]; then bad "register $1" "(HTTP $STATUS $(echo "$BODY" | jq -r .message))"; return 1
  else ok "register $1 ($2)"; fi
  CREATED_USERS+=("$id")
  sb PUT "/auth/v1/admin/users/$id" '{"email_confirm":true}' >/dev/null # = clicking the link in the email
  sb PATCH "/rest/v1/users?id=eq.$id" '{"email_verified":true}' >/dev/null
  echo "$id" > "/tmp/cl-smoke-$1-id"
}
login() { # login ROLE -> echoes the access token
  call POST /auth/login "" "{\"email\":\"cl-smoke-$1-$STAMP@$MAILDOMAIN\",\"password\":\"Smoke!$STAMP\"}"
  echo "$BODY" | jq -r '.data.accessToken // empty'
}

for tool in curl jq; do command -v $tool >/dev/null || { echo "Needs $tool"; exit 2; }; done
[ -n "$SB_URL" ] && [ -n "$SB_KEY" ] || { echo "backend/.env needs SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY"; exit 2; }

step "API is up"
STATUS=$(curl -s -o /tmp/cl-smoke-body -w '%{http_code}' "${API%/api/v1}/health/db"); BODY=$(cat /tmp/cl-smoke-body)
expect "GET /health/db" 200 || exit 1

step "Sign up and verify"
register customer "Thabo Mokoena" || exit 1
register provider "Anne-Marie O'Neil" || exit 1
CUSTOMER_ID=$(cat /tmp/cl-smoke-customer-id); PROVIDER_USER_ID=$(cat /tmp/cl-smoke-provider-id)
call POST /auth/register "" "{\"email\":\"x$STAMP@$MAILDOMAIN\",\"password\":\"Smoke!$STAMP\",\"fullName\":\"Thabo2\"}"
expect "a name with digits is refused" 400
CUSTOMER=$(login customer); [ -n "$CUSTOMER" ] && ok "customer logs in" || bad "customer logs in"
PROVIDER=$(login provider); [ -n "$PROVIDER" ] && ok "provider logs in" || bad "provider logs in"
PHONE="+2782$(printf '%07d' $((STAMP % 10000000)))"
call POST /auth/phone/request-otp "$CUSTOMER" "{\"phoneNumber\":\"$PHONE\"}"; expect "phone code sent" 200
CODE=$(echo "$BODY" | jq -r '.data.devCode // empty')
call POST /auth/phone/verify-otp "$CUSTOMER" "{\"otp\":\"$CODE\"}"; expect "phone verified with the demo code" 200

step "Provider applies; admin approves"
# Registration year must not be in the future: a year between 2000 and 2025.
REG="$((2000 + STAMP % 26))/$(printf '%06d' $((STAMP % 1000000)))/07"
call POST /providers "$PROVIDER" "{\"businessName\":\"Smoke Plumbing $STAMP\",\"registrationNumber\":\"$REG\",\"category\":\"Plumbing\",\"description\":\"Leaks and geysers.\",\"streetAddress\":\"12 Church Street, Pretoria\",\"location\":{\"lat\":-25.7461,\"lng\":28.1881}}"
expect "business profile created" 201 && PROVIDER_ID=$(echo "$BODY" | jq -r '.data.provider.id // .data.id')
if [ -z "$PROVIDER_ID" ] || [ "$PROVIDER_ID" = null ]; then
  SKIPPED=25
  printf '  \033[33mSKIP\033[0m %s later steps: no business profile\n' "$SKIPPED"
  exit 1
fi
printf '%%PDF-1.4\n%% smoke test\n' > /tmp/cl-smoke-doc.pdf; printf '\xff\xd8\xff\xe0smoke' > /tmp/cl-smoke-id.jpg
for doc in "registration_certificate:/tmp/cl-smoke-doc.pdf:application/pdf" "id_document:/tmp/cl-smoke-id.jpg:image/jpeg"; do
  IFS=: read -r type file ctype <<< "$doc"
  call POST /uploads/sign "$PROVIDER" "{\"purpose\":\"provider_document\",\"contentType\":\"$ctype\"}"
  url=$(echo "$BODY" | jq -r '.data.uploadUrl'); path=$(echo "$BODY" | jq -r '.data.path')
  up=$(curl -s -o /dev/null -w '%{http_code}' -X PUT "$url" -H "Content-Type: $ctype" -H 'x-upsert: false' --data-binary "@$file")
  [ "$up" = 200 ] && ok "$type uploaded straight to Storage" || bad "$type upload" "(HTTP $up)"
  call POST /providers/me/documents "$PROVIDER" "{\"documentType\":\"$type\",\"storagePath\":\"$path\"}"; expect "$type attached" 201
done
call POST /providers/me/application/submit "$PROVIDER" ""; expect "application submitted" 200
ADMIN_EMAIL="cl-smoke-admin-$STAMP@$MAILDOMAIN"
admin_id=$(sb POST /auth/v1/admin/users "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"Smoke!$STAMP\",\"email_confirm\":true,\"user_metadata\":{\"full_name\":\"Smoke Admin\"}}" | jq -r '.id // empty')
[ -n "$admin_id" ] && CREATED_USERS+=("$admin_id") && sb PATCH "/rest/v1/users?id=eq.$admin_id" '{"role":"admin"}' >/dev/null
call POST /auth/login "" "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"Smoke!$STAMP\"}"; ADMIN=$(echo "$BODY" | jq -r '.data.accessToken // empty')
call POST "/providers/me/application/submit" "$CUSTOMER" ""; expect "a customer cannot use provider routes" 403
call POST "/admin/providers/$PROVIDER_ID/verify" "$CUSTOMER" ""; expect "a customer cannot approve" 403
call POST "/admin/providers/$PROVIDER_ID/verify" "$ADMIN" ""; expect "admin approves the business" 200

step "Bank details and a service"
call PUT /providers/me/payout-details "$PROVIDER" '{"bankName":"FNB","accountType":"Savings","accountHolderName":"Anne-Marie O'"'"'Neil","accountNumber":"62012345678","branchCode":"250655"}'
expect "bank details saved (encrypted)" 200
call POST /providers/me/services "$PROVIDER" '{"title":"Geyser repair","category":"Plumbing","description":"Fix a geyser element or thermostat.","price":450,"durationMinutes":60,"pricingType":"fixed"}'
expect "service added" 201 && SERVICE_ID=$(echo "$BODY" | jq -r '.data.service.id')

step "Book and pay the booking fee"
# Next weekday 10:00 South African time (08:00 UTC): inside the standard working hours.
START=$(python3 -c "import datetime as d; t=d.datetime.now(d.timezone.utc)+d.timedelta(days=2)
while t.weekday()>4: t+=d.timedelta(days=1)
print(t.replace(hour=8,minute=0,second=0,microsecond=0).isoformat().replace('+00:00','Z'))")
call POST /bookings "$CUSTOMER" "{\"providerId\":\"$PROVIDER_ID\",\"serviceId\":\"$SERVICE_ID\",\"scheduledStart\":\"$START\",\"address\":\"5 Vilakazi Street, Soweto\"}"
expect "booking requested (R450, fee R67.50)" 201 && BOOKING_ID=$(echo "$BODY" | jq -r '.data.id')
call POST /payments/intent "$CUSTOMER" "{\"bookingId\":\"$BOOKING_ID\",\"purpose\":\"booking_fee\"}" -H "Idempotency-Key: bk-$BOOKING_ID-booking_fee"
expect "fee checkout created" 201 && PAYMENT_ID=$(echo "$BODY" | jq -r '.data.paymentId') && CHECKOUT=$(echo "$BODY" | jq -r '.data.checkoutUrl')
call POST /payments/intent "$CUSTOMER" "{\"bookingId\":\"$BOOKING_ID\",\"purpose\":\"booking_fee\"}" -H "Idempotency-Key: bk-$BOOKING_ID-booking_fee"
[ "$STATUS" = 200 ] && [ "$(echo "$BODY" | jq -r .data.paymentId)" = "${PAYMENT_ID:-x}" ] && ok "same key again: same payment (no second charge)" || bad "same key again" "(HTTP $STATUS)"
if [ -z "$PAYMENT_ID" ] || [ "$PAYMENT_ID" = null ]; then
  SKIPPED=13
  printf '  \033[33mSKIP\033[0m %s later steps (fee, accept, PIN, complete, balance, review, delete account): no payment\n' "$SKIPPED"
  exit 1
fi
if [ "$PAY" = real ]; then
  echo "  Open this link, pay with the PayFast sandbox, then wait here:"; echo "  $CHECKOUT"
  for _ in $(seq 1 100); do call GET "/payments/$PAYMENT_ID" "$CUSTOMER" ""; [ "$(echo "$BODY" | jq -r .data.payment_status)" = paid ] && break; sleep 6; done
else
  # SIMULATED ITN: the same database transaction a verified PayFast ITN runs.
  sb POST /rest/v1/rpc/apply_payfast_payment "{\"p_payment_id\":\"$PAYMENT_ID\",\"p_pf_payment_id\":\"SMOKE-$STAMP\",\"p_amount\":67.5,\"p_raw\":{\"smoke\":true}}" >/dev/null
fi
call GET "/payments/$PAYMENT_ID" "$CUSTOMER" ""
[ "$(echo "$BODY" | jq -r '.data.payment_status // empty')" = paid ] && ok "booking fee paid ($PAY)" || bad "booking fee paid" "($(echo "$BODY" | jq -c .data.payment_status 2>/dev/null))"

step "Accept, PIN on arrival, complete"
call POST "/bookings/$BOOKING_ID/accept" "$PROVIDER" ""; expect "provider accepts" 200
call GET "/bookings/$BOOKING_ID/arrival-pin" "$CUSTOMER" ""; expect "customer sees the PIN" 200; PIN=$(echo "$BODY" | jq -r '.data.pin')
call GET "/bookings/$BOOKING_ID/arrival-pin" "$PROVIDER" ""; expect "provider cannot see the PIN" 403
call POST "/bookings/$BOOKING_ID/start" "$PROVIDER" "{\"pin\":\"$PIN\"}"; expect "PIN entered on arrival: job started" 200
call POST "/bookings/$BOOKING_ID/complete" "$PROVIDER" ""; expect "job completed" 200

step "Balance in cash, review"
call POST "/bookings/$BOOKING_ID/balance/cash-choice" "$CUSTOMER" ""; expect "customer chooses cash" 200
call POST "/bookings/$BOOKING_ID/balance/cash" "$PROVIDER" ""; expect "provider confirms R382.50 cash" 200
call POST /reviews "$CUSTOMER" "{\"bookingId\":\"$BOOKING_ID\",\"rating\":5,\"comment\":\"On time and tidy.\"}"; expect "review left" 201
call POST /reviews "$CUSTOMER" "{\"bookingId\":\"$BOOKING_ID\",\"rating\":5,\"comment\":\"<script>alert(1)</script>\"}"; expect "HTML in a review is refused" 400

step "Delete account"
call DELETE "/users/$PROVIDER_USER_ID" "$CUSTOMER" ""; expect "cannot delete someone else's account" 403
call DELETE "/users/$CUSTOMER_ID" "$CUSTOMER" ""; expect "customer deletes their account" 200
call GET /notifications "$CUSTOMER" ""; expect "the deleted account is signed out everywhere" 401

[ "$FAIL" = 0 ]
