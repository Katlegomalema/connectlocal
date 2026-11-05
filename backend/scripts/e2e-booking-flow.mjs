/**
 * End-to-end check of the booking flow against a running API and the REAL database.
 *
 *   PORT=3005 npm start            # in one terminal (or use your running server's port)
 *   node --env-file=.env scripts/e2e-booking-flow.mjs 3005
 *
 * Creates temporary users (cl-curltest-*@connectlocal.test), a temporary verified provider and services,
 * runs: book -> fee -> accept -> PIN on arrival (5 tries) -> complete -> cash balance -> payout -> review,
 * plus decline and cancel, checks booking_status_history, then (Phase 6) notifications, the booking chat,
 * public reviews, the admin lists and account suspension, and ALWAYS deletes everything it created.
 *
 * PayFast: the signed checkout page is checked when PayFast credentials are set. The ITN is SIMULATED
 * (marked below) because only PayFast can produce a valid ITN (it confirms each one via /eng/query/validate).
 */

const { supabaseAdmin: db } = await import(new URL('../src/config/supabase.js', import.meta.url));

const BASE = `http://localhost:${process.argv[2] || 3000}/api/v1`;
const stamp = Date.now();
const users = [];
const bookingIds = [];
let providerId;
let failures = 0;

const check = (label, ok, extra = '') => {
  if (!ok) failures += 1;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}${extra !== '' ? `  (${extra})` : ''}`);
};

async function call(method, path, { token, body } = {}) {
  const res = await fetch(path.startsWith('http') ? path : `${BASE}${path}`, {
    method,
    headers: {
      ...(body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    },
    body: body ? JSON.stringify(body) : undefined
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* an HTML page */ }
  return {
    status: res.status, json, text, data: json?.data
  };
}

async function makeUser(role, { phone, tag } = {}) {
  const email = `cl-curltest-${tag || role}-${stamp}@connectlocal.test`;
  const password = `Tt1!${crypto.randomUUID()}`;
  const { data, error } = await db.auth.admin.createUser({
    email, password, email_confirm: true, user_metadata: { full_name: `E2E ${role}`, role }
  });
  if (error) throw new Error(error.message);
  users.push(data.user.id);
  await db.from('users')
    .update({ email_verified: true, ...(phone ? { phone_number: phone, phone_verified: true } : {}) })
    .eq('id', data.user.id);
  const login = await call('POST', '/auth/login', { body: { email, password } });
  return { id: data.user.id, token: login.data.accessToken };
}

/** In two days at 06:00 UTC (08:00 South African time) plus [hours]: always inside the test working hours. */
const inTwoDays = (hours) => {
  const d = new Date(Date.now() + 2 * 86400000);
  d.setUTCHours(6, 0, 0, 0);
  return new Date(d.getTime() + hours * 3600000).toISOString();
};

try {
  const customer = await makeUser('customer', { phone: `+2782${String(stamp).slice(-7)}` });
  const providerUser = await makeUser('provider');
  const who = (id) => ({ [customer.id]: 'customer', [providerUser.id]: 'provider' }[id] || String(id));
  const history = async (id) => ((await db.from('booking_status_history')
    .select('new_status, changed_by').eq('booking_id', id).order('changed_at')).data || [])
    .map((h) => `${h.new_status}:${who(h.changed_by)}`).join(' > ');

  const { data: cat } = await db.from('service_categories').select('id').eq('name', 'Cleaning Services').single();
  const { data: prov } = await db.from('providers').insert({
    user_id: providerUser.id,
    business_name: `E2E Booking Co ${stamp}`,
    verification_status: 'verified',
    submitted_at: new Date().toISOString()
  }).select('id').single();
  providerId = prov.id;
  // Working hours for the test: every day 06:00-20:00 (SAST). 0 = Sunday in the database.
  await db.from('provider_availability').insert([0, 1, 2, 3, 4, 5, 6]
    .map((day) => ({ provider_id: providerId, day_of_week: day, start_time: '06:00', end_time: '20:00' })));
  const { data: fixed } = await db.from('services').insert({
    provider_id: providerId, category_id: cat.id, service_name: 'Window wash', base_price: 450, duration_minutes: 60, pricing_type: 'fixed'
  }).select('id').single();
  const { data: hourly } = await db.from('services').insert({
    provider_id: providerId, category_id: cat.id, service_name: 'Deep clean', base_price: 300, duration_minutes: 60, pricing_type: 'hourly'
  }).select('id').single();

  // ---- booking 1: fixed R450, balance in cash ---------------------------------------------------------
  let r = await call('POST', '/bookings', {
    token: customer.token,
    body: {
      providerId, serviceId: fixed.id, scheduledStart: inTwoDays(0), address: '12 Main Rd, Pretoria', latitude: -25.75, longitude: 28.19
    }
  });
  const b1 = r.data;
  const id1 = b1?.id;
  bookingIds.push(id1);

  // ---- booking options, working hours, slots ---------------------------------------------------------
  r = await call('GET', `/providers/${providerId}/schedule`);
  check('public schedule: house calls only by default, 1-hour slots, 30-min gap, the new booking is busy',
    r.status === 200 && r.data?.offersHouseCall === true && r.data?.offersVisit === false && r.data?.slotMinutes === 60
    && r.data?.gapMinutes === 30 && r.data?.busy?.some((b) => new Date(b.start).getTime() === new Date(inTwoDays(0)).getTime())
    && !r.text.includes(customer.id), r.json?.message);
  r = await call('POST', '/bookings', {
    token: customer.token,
    body: { providerId, serviceId: fixed.id, scheduledStart: inTwoDays(1.25), address: '12 Main Rd, Pretoria' }
  });
  check('a slot inside the 30-minute gap after a booking is refused -> 409', r.status === 409, r.json?.message);
  r = await call('POST', '/bookings', {
    token: customer.token,
    body: { providerId, serviceId: fixed.id, scheduledStart: inTwoDays(11.5), address: '12 Main Rd, Pretoria' }
  });
  check('a time after closing (19:30 + 1 h > 20:00) is refused -> 409', r.status === 409
    && /working hours/.test(r.json?.message || ''), r.json?.message);
  r = await call('POST', '/bookings', {
    token: customer.token, body: { providerId, serviceId: fixed.id, scheduledStart: inTwoDays(2), atBusiness: true }
  });
  check('"visit the business" refused while the provider only does house calls', r.status === 400, r.json?.message);
  r = await call('PUT', '/providers/me/schedule', { token: providerUser.token, body: { offersVisit: true } });
  check('a visit needs a business address first', r.status === 400 && /address/.test(r.json?.message || ''), r.json?.message);
  await call('PATCH', '/providers/me', { token: providerUser.token, body: { streetAddress: '5 Salon St, Hatfield' } });
  r = await call('PUT', '/providers/me/schedule', {
    token: providerUser.token,
    body: {
      offersVisit: true, offersHouseCall: true, slotMinutes: 60, workingHours: [1, 2, 3, 4, 5, 6, 7].map((day) => ({ day, open: 360, close: 1200 }))
    }
  });
  check('provider saves booking options and working hours', r.status === 200 && r.data?.schedule?.offersVisit === true
    && r.data?.schedule?.customHours === true && r.data?.schedule?.workingHours?.length === 7, r.json?.message);
  r = await call('PUT', '/providers/me/schedule', { token: providerUser.token, body: { offersVisit: false, offersHouseCall: false } });
  check('at least one booking option must stay on', r.status === 400, r.json?.message);
  r = await call('POST', '/bookings', {
    token: customer.token, body: { providerId, serviceId: fixed.id, scheduledStart: inTwoDays(2), atBusiness: true }
  });
  bookingIds.push(r.data?.id);
  check('"visit the business" booking: stored as at_business with the business address, no customer map point',
    r.status === 201 && r.data?.at_business === true && r.data?.service_address === '5 Salon St, Hatfield'
    && r.data?.service_location === null, `${r.status} ${r.json?.message || ''}`);
  if (r.data?.id) {
    const cancelVisit = await call('POST', `/bookings/${r.data.id}/cancel`, { token: customer.token });
    check('cancelled request frees its slot', cancelVisit.status === 200
      && !(await call('GET', `/providers/${providerId}/schedule`)).data?.busy
        ?.some((b) => new Date(b.start).getTime() === new Date(inTwoDays(2)).getTime()));
  }
  check('book fixed R450 -> fee 67.50, balance 382.50, pending', r.status === 201 && Number(b1.booking_fee_amount) === 67.5
    && Number(b1.balance_amount) === 382.5 && b1.status === 'pending', `${r.status} ${r.json?.message || ''}`);
  check('job address and map point stored', b1?.service_address === '12 Main Rd, Pretoria'
    && Math.abs((b1?.service_location?.latitude ?? 0) + 25.75) < 0.001);

  r = await call('GET', `/bookings/${id1}`, { token: providerUser.token });
  check(
    'provider sees the customer name but not the phone before accepting',
    r.data?.customer?.full_name === 'E2E customer' && r.data?.customer?.phone_number === null
  );
  r = await call('POST', `/bookings/${id1}/accept`, { token: providerUser.token });
  check('cannot accept before the fee is paid -> 409', r.status === 409, r.json?.message);

  r = await call('POST', '/payments/intent', { token: customer.token, body: { bookingId: id1, purpose: 'booking_fee' } });
  if (r.status === 200 || r.status === 201) {
    check('fee checkout: R67.50, sandbox, signed link', r.data.amount === 67.5 && r.data.sandbox === true
      && /\/payments\/.+\/checkout\?e=\d+&t=[0-9a-f]{64}$/.test(r.data.checkoutUrl));
    // The link uses PUBLIC_API_URL (the Codespace address); open the same path on this test server.
    const localCheckout = `${BASE}${r.data.checkoutUrl.split('/api/v1')[1]}`;
    const page = await call('GET', localCheckout);
    check('checkout page posts a signed form to sandbox.payfast.co.za', page.status === 200
      && page.text.includes('action="https://sandbox.payfast.co.za/eng/process"')
      && page.text.includes('name="amount" value="67.50"') && /name="signature" value="[0-9a-f]{32}"/.test(page.text));
    check('checkout page never contains the passphrase', !page.text.toLowerCase().includes('passphrase'));
    const tampered = await call('GET', localCheckout.replace(/t=[0-9a-f]+/, `t=${'0'.repeat(64)}`));
    check('tampered checkout link refused', tampered.status === 401, tampered.status);
  } else {
    check(
      'without PayFast credentials the intent fails with a clear message',
      r.status === 502 && /PAYFAST_MERCHANT_ID/.test(r.json?.message || ''),
      `${r.status} ${r.json?.message}`
    );
  }
  // SIMULATED ITN: what processPayFastItn does after PayFast confirms the fee.
  const { data: existingFee } = await db.from('payments').select('id').eq('booking_id', id1).eq('purpose', 'booking_fee')
    .maybeSingle();
  const feePayment = {
    payment_status: 'paid', gateway_provider: 'payfast', transaction_reference: `SIM-${stamp}`, paid_at: new Date().toISOString()
  };
  if (existingFee) await db.from('payments').update(feePayment).eq('id', existingFee.id);
  else {
    await db.from('payments').insert({
      booking_id: id1, amount: 67.5, currency: 'ZAR', purpose: 'booking_fee', method: 'card', ...feePayment
    });
  }
  await db.from('bookings').update({ booking_fee_status: 'paid' }).eq('id', id1);

  r = await call('POST', `/bookings/${id1}/accept`, { token: providerUser.token });
  check('cannot accept without bank details -> 409', r.status === 409 && /bank details/.test(r.json?.message || ''), r.json?.message);
  r = await call('PUT', '/providers/me/payout-details', {
    token: providerUser.token,
    body: { bankName: 'FNB', accountType: 'Savings', accountHolderName: 'Somebody Else', accountNumber: '62012345678', branchCode: '250655' }
  });
  check("someone else's bank account refused", r.status === 400, r.json?.message);
  r = await call('PUT', '/providers/me/payout-details', {
    token: providerUser.token,
    body: { bankName: 'FNB', accountType: 'Savings', accountHolderName: 'E2E Provider', accountNumber: '620 1234 5678', branchCode: '250655' }
  });
  check('bank details saved; only the last 4 digits come back', r.status === 200 && r.data?.payoutDetails?.accountLast4 === '5678'
    && !r.text.includes('62012345678'), r.json?.message);
  const { data: stored } = await db.from('provider_payout_details').select('account_number_encrypted, account_last4').eq('provider_id', providerId).single();
  check('account number stored encrypted (not readable in the database)', /^v1:/.test(stored?.account_number_encrypted || '')
    && !stored.account_number_encrypted.includes('62012345678'));

  r = await call('POST', `/bookings/${id1}/accept`, { token: providerUser.token });
  check('accept after the fee -> accepted, no PIN hash in the answer', r.status === 200 && r.data?.status === 'accepted'
    && !JSON.stringify(r.json).includes('arrival_pin_hash'), r.json?.message);
  r = await call('GET', `/bookings/${id1}`, { token: providerUser.token });
  check('after accepting the provider sees the customer phone', Boolean(r.data?.customer?.phone_number));
  r = await call('GET', `/bookings/${id1}/arrival-pin`, { token: providerUser.token });
  check('provider cannot read the PIN -> 403', r.status === 403, r.status);
  r = await call('GET', `/bookings/${id1}/arrival-pin`, { token: customer.token });
  const pin = r.data?.pin;
  check('customer gets a 4-digit PIN', /^\d{4}$/.test(pin || ''), r.status);

  const wrong = pin === '0000' ? '1111' : '0000';
  r = await call('POST', `/bookings/${id1}/start`, { token: providerUser.token, body: { pin: wrong } });
  check('wrong PIN -> 400 "4 tries left"', r.status === 400 && /4 tries left/.test(r.json?.message), r.json?.message);
  r = await call('POST', `/bookings/${id1}/start`, { token: providerUser.token, body: { pin: wrong } });
  check('wrong again -> "3 tries left" (counted on the server)', /3 tries left/.test(r.json?.message || ''), r.json?.message);
  r = await call('POST', `/bookings/${id1}/complete`, { token: providerUser.token });
  check('cannot complete before the PIN -> 409', r.status === 409, r.json?.message);
  r = await call('POST', `/bookings/${id1}/start`, { token: providerUser.token, body: { pin } });
  check('right PIN -> in_progress', r.status === 200 && r.data?.status === 'in_progress', r.json?.message);
  r = await call('POST', `/bookings/${id1}/complete`, { token: providerUser.token });
  check('complete -> completed', r.status === 200 && r.data?.status === 'completed', r.json?.message);

  r = await call('POST', '/reviews', { token: customer.token, body: { bookingId: id1, rating: 5, comment: 'Great' } });
  check('review before the balance is paid -> 409', r.status === 409, r.json?.message);
  r = await call('POST', `/bookings/${id1}/balance/cash`, { token: customer.token });
  check('customer cannot confirm cash -> 403', r.status === 403, r.status);
  r = await call('POST', `/bookings/${id1}/balance/cash-choice`, { token: customer.token });
  check('customer chooses cash (saved on the server)', r.status === 200 && r.data?.balance_payment_method === 'cash'
    && r.data?.balance_status === 'pending', r.json?.message);
  r = await call('POST', `/bookings/${id1}/balance/cash`, { token: providerUser.token });
  const payout = r.data?.payout;
  check('provider confirms cash R382.50', r.status === 200 && Number(r.data?.payment?.amount) === 382.5, r.json?.message);
  check('automatic payout: gross 450, commission 45, cash 382.50 -> payout 22.50', payout
    && Number(payout.gross_amount) === 450 && Number(payout.commission_amount) === 45
    && Number(payout.cash_collected_amount) === 382.5 && Number(payout.payout_amount) === 22.5);
  r = await call('POST', `/bookings/${id1}/balance/cash`, { token: providerUser.token });
  check('cash cannot be confirmed twice -> 409', r.status === 409, r.json?.message);
  let paidPayout = null;
  for (let i = 0; i < 20 && !paidPayout; i += 1) {
    // eslint-disable-next-line no-await-in-loop
    const list = await call('GET', '/providers/me/payouts', { token: providerUser.token });
    paidPayout = list.data?.payouts?.find((p) => p.bookingId === id1 && p.status === 'paid');
    // eslint-disable-next-line no-await-in-loop
    if (!paidPayout) await new Promise((resolve) => { setTimeout(resolve, 500); });
  }
  check('payout paid automatically (simulated transfer, SIM- reference), nobody marked it', paidPayout
    && paidPayout.payoutAmount === 22.5 && /^SIM-[0-9A-F]{10}$/.test(paidPayout.reference || ''), JSON.stringify(paidPayout && { amount: paidPayout.payoutAmount, ref: paidPayout.reference }));
  const { data: payoutNote } = await db.from('notifications').select('title').eq('user_id', providerUser.id).eq('title', 'Payout sent');
  check('provider notified "Payout sent"', (payoutNote || []).length === 1);
  r = await call('POST', '/reviews', { token: customer.token, body: { bookingId: id1, rating: 5, comment: 'Great' } });
  check('review after payment -> 201', r.status === 201, r.json?.message);
  r = await call('POST', '/reviews', { token: customer.token, body: { bookingId: id1, rating: 4 } });
  check('second review for the same booking refused', r.status >= 400 && r.status < 500, r.status);
  const seq1 = await history(id1);
  check(
    'history: pending(customer) > accepted > in_progress > completed (provider)',
    seq1 === 'pending:customer > accepted:provider > in_progress:provider > completed:provider',
    seq1
  );

  // ---- Phase 6: notifications ------------------------------------------------------------------------
  const titles = async (token) => ((await call('GET', '/notifications?limit=50', { token })).data?.notifications || [])
    .map((n) => n.title);
  const customerTitles = await titles(customer.token);
  check('customer notified: accepted, job started, pay the balance, payment received', [
    'Booking accepted', 'Job started', 'Job done: please pay the balance', 'Payment received'
  ].every((t) => customerTitles.includes(t)), customerTitles.join(' | '));
  const providerTitles = await titles(providerUser.token);
  check('provider notified: balance paid, new review, payout sent', ['Balance paid', 'New review', 'Payout sent']
    .every((t) => providerTitles.includes(t)), providerTitles.join(' | '));
  r = await call('PATCH', '/notifications/read-all', { token: customer.token });
  const unreadAfter = await call('GET', '/notifications?unreadOnly=true', { token: customer.token });
  check('mark all read -> 0 unread', r.status === 200 && unreadAfter.data?.total === 0, unreadAfter.data?.total);

  // ---- Phase 6: reviews ---------------------------------------------------------------------------------
  r = await call('GET', `/reviews/${providerId}`);
  const pub = r.data?.reviews?.[0];
  check('public reviews (no sign-in): first name, comment, service; no customer id', r.status === 200
    && pub?.customerFirstName === 'E2E' && pub?.comment === 'Great' && pub?.serviceName === 'Window wash'
    && !r.text.includes(customer.id), JSON.stringify(pub));
  r = await call('GET', `/bookings/${id1}`, { token: customer.token });
  const embedded = Array.isArray(r.data?.review) ? r.data.review[0] : r.data?.review;
  check('the booking carries its review (app knows it was reviewed after a restart)', embedded?.rating === 5);

  // ---- Phase 6: booking chat ---------------------------------------------------------------------------
  r = await call('POST', '/messages', { token: customer.token, body: { bookingId: id1, body: 'Hello, the gate code is 1234' } });
  check('customer sends a chat message', r.status === 201 && r.data?.mine === true && r.data?.bookingId === id1, r.json?.message);
  r = await call('GET', '/messages/conversations', { token: providerUser.token });
  const providerConv = r.data?.conversations?.find((c) => c.booking_id === id1);
  check('GET /messages/conversations works (not taken as an id); provider has 1 unread', r.status === 200
    && providerConv?.unread_count === 1 && providerConv?.last_message_mine === false, `${r.status} ${JSON.stringify(providerConv)}`);
  r = await call('GET', `/messages/booking/${id1}`, { token: providerUser.token });
  check('provider reads the booking chat', r.status === 200 && r.data?.messages?.length === 1
    && r.data.messages[0].mine === false && r.data.messages[0].text.startsWith('Hello'), r.json?.message);
  r = await call('GET', '/messages/conversations', { token: providerUser.token });
  check('opening the chat marks it read', r.data?.conversations?.find((c) => c.booking_id === id1)?.unread_count === 0);
  r = await call('POST', '/messages', { token: providerUser.token, body: { bookingId: id1, body: 'Thanks, see you soon' } });
  check('provider replies in the same conversation', r.status === 201);
  r = await call('GET', `/messages/booking/${id1}`, { token: customer.token });
  check('customer sees both messages in order', r.data?.messages?.map((m) => m.mine).join(',') === 'true,false');
  const outsider = await makeUser('customer', { tag: 'outsider' });
  r = await call('GET', `/messages/booking/${id1}`, { token: outsider.token });
  check('someone else cannot read the chat -> 403', r.status === 403, r.status);
  r = await call('POST', '/messages', { token: outsider.token, body: { bookingId: id1, body: 'hi' } });
  check('someone else cannot write in the chat -> 403', r.status === 403, r.status);
  r = await call('GET', '/messages/booking/not-a-uuid', { token: customer.token });
  check('bad booking id -> 400', r.status === 400, r.status);

  // ---- Phase 6: admin website ----------------------------------------------------------------------------
  const admin = await makeUser('customer', { tag: 'admin' });
  await db.from('users').update({ role: 'admin' }).eq('id', admin.id);
  r = await call('GET', '/admin/bookings?limit=100', { token: customer.token });
  check('a customer cannot use the admin API -> 403', r.status === 403, r.status);
  r = await call('GET', '/admin/bookings?limit=100', { token: admin.token });
  const adminBooking = r.data?.bookings?.find((b) => b.id === id1);
  check('admin: every booking with names, never the PIN hash', r.status === 200 && adminBooking?.provider?.business_name
    && adminBooking?.customer?.full_name === 'E2E customer' && !r.text.includes('arrival_pin_hash'), r.json?.message);
  r = await call('GET', '/admin/payments?limit=100', { token: admin.token });
  check('admin: payments (fee by card + balance in cash)', r.status === 200
    && r.data?.payments?.filter((p) => p.bookingId === id1).map((p) => `${p.purpose}/${p.method}`).sort()
      .join(',') === 'balance/cash,booking_fee/card', r.json?.message);
  r = await call('GET', '/admin/payouts?limit=100', { token: admin.token });
  const adminPayout = r.data?.payouts?.find((p) => p.bookingId === id1);
  check('admin: payout paid, bank details masked (last 4 only)', adminPayout?.status === 'paid'
    && adminPayout?.bank?.accountLast4 === '5678' && !r.text.includes('62012345678') && !r.text.includes('encrypted'),
  JSON.stringify(adminPayout?.bank));
  r = await call('GET', '/admin/users?limit=100', { token: admin.token });
  const adminProvider = r.data?.users?.find((u) => u.id === providerUser.id);
  check('admin: users with their business', adminProvider?.business?.name === `E2E Booking Co ${stamp}`
    && adminProvider?.status === 'active', JSON.stringify(adminProvider));
  r = await call('GET', '/admin/analytics', { token: admin.token });
  check('admin: analytics with the fixed 10% commission', r.status === 200 && r.data?.commissionRate === 0.1);
  r = await call('PUT', `/admin/users/${outsider.id}`, { token: admin.token, body: { status: 'suspended' } });
  const blocked = await call('GET', '/notifications', { token: outsider.token });
  check('a suspended account is locked out', r.status === 200 && [401, 403].includes(blocked.status), `${r.status}/${blocked.status}`);
  r = await call('PUT', `/admin/users/${outsider.id}`, { token: admin.token, body: { status: 'active' } });
  const back = await call('GET', '/notifications', { token: outsider.token });
  check('re-activated -> can use the app again', r.status === 200 && back.status === 200, back.status);
  r = await call('PUT', `/admin/users/${admin.id}`, { token: admin.token, body: { status: 'suspended' } });
  check('an admin cannot suspend themselves', r.status === 400, r.status);

  // ---- Phase 6: one registration number, one business --------------------------------------------------
  const regNumber = `2019/${String(stamp).slice(-6)}/07`;
  await db.from('providers').update({ business_registration_number: regNumber }).eq('id', providerId);
  const second = await makeUser('provider', { tag: 'provider2' });
  r = await call('POST', '/providers', {
    token: second.token, body: { businessName: 'Copy Cat Co', registrationNumber: regNumber, category: 'Cleaning Services' }
  });
  check('a registration number already used by another business -> 409', r.status === 409, `${r.status} ${r.json?.message}`);

  // ---- booking 2: hourly 3 h x R300, declined ---------------------------------------------------------
  r = await call('POST', '/bookings', {
    token: customer.token,
    body: {
      providerId, serviceId: hourly.id, scheduledStart: inTwoDays(5), hours: 3, address: '12 Main Rd, Pretoria'
    }
  });
  const b2 = r.data;
  bookingIds.push(b2?.id);
  check(
    'hourly 3 h x R300 -> total 900, fee 135, 3-hour slot',
    r.status === 201 && Number(b2.total_amount) === 900
    && Number(b2.booking_fee_amount) === 135 && new Date(b2.scheduled_end) - new Date(b2.scheduled_start) === 3 * 3600000,
    `${r.status} ${r.json?.message || ''}`
  );
  r = await call('POST', `/bookings/${b2.id}/decline`, { token: providerUser.token, body: { reason: 'Fully booked' } });
  check('provider declines -> rejected, nothing to refund (fee unpaid)', r.status === 200 && r.data?.status === 'rejected'
    && r.data?.feeRefund === 'not_paid', r.data?.feeRefund);
  const seq2 = await history(b2.id);
  check('history records the decline by the provider', seq2 === 'pending:customer > rejected:provider', seq2);

  // ---- booking 3: customer cancels while pending ------------------------------------------------------
  r = await call('POST', '/bookings', {
    token: customer.token,
    body: {
      providerId, serviceId: fixed.id, scheduledStart: inTwoDays(9), address: '12 Main Rd, Pretoria'
    }
  });
  const b3 = r.data;
  bookingIds.push(b3?.id);
  r = await call('POST', `/bookings/${b3.id}/cancel`, { token: customer.token, body: { reason: 'Plans changed' } });
  check('customer cancels while pending -> cancelled', r.status === 200 && r.data?.status === 'cancelled', r.json?.message);
  const seq3 = await history(b3.id);
  check('history records the cancel by the customer', seq3 === 'pending:customer > cancelled:customer', seq3);
} catch (error) {
  failures += 1;
  console.log('ERROR', error.message);
} finally {
  // Bookings, payments and payouts are linked with ON DELETE RESTRICT: delete children first.
  const ids = bookingIds.filter(Boolean);
  if (ids.length) {
    const { data: payments } = await db.from('payments').select('id').in('booking_id', ids);
    await db.from('payouts').delete().in('booking_id', ids);
    if (payments?.length) await db.from('receipts').delete().in('payment_id', payments.map((p) => p.id));
    await db.from('reviews').delete().in('booking_id', ids);
    await db.from('payments').delete().in('booking_id', ids);
    await db.from('bookings').delete().in('id', ids);
  }
  if (users.length) await db.from('providers').delete().in('user_id', users).neq('id', providerId || '00000000-0000-0000-0000-000000000000');
  if (providerId) {
    await db.from('provider_payout_details').delete().eq('provider_id', providerId);
    await db.from('services').delete().eq('provider_id', providerId);
    await db.from('providers').delete().eq('id', providerId);
  }
  for (const id of users) await db.auth.admin.deleteUser(id);
  const { count } = await db.from('users').select('id', { count: 'exact', head: true }).like('email', 'cl-curltest-%');
  const { count: detailsLeft } = await db.from('provider_payout_details').select('provider_id', { count: 'exact', head: true })
    .eq('provider_id', providerId || '00000000-0000-0000-0000-000000000000');
  console.log(`\ncleanup: temporary test users left: ${count}, bank details left: ${detailsLeft}`);
  console.log(failures ? `${failures} FAILED` : 'ALL PASSED');
  process.exitCode = failures ? 1 : 0;
}
