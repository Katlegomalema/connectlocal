-- =====================================================================================================
-- PayFast: a customer must never be charged twice (slow networks, double taps, PayFast sending an ITN again).
--
--   1. payments.idempotency_key: the app sends an Idempotency-Key header with "start payment"; the same key
--      always gets the same payment (unique).
--   2. One OPEN (pending) payment per booking and purpose: two "start payment" requests at the same moment
--      cannot create two checkouts. (One PAID payment per booking and purpose already exists:
--      uq_payments_one_paid_per_purpose, 20261104230000.)
--   3. One receipt per payment.
--   4. apply_payfast_payment(): marks the payment paid, writes the receipt and updates the booking in ONE
--      transaction, with the payment row locked, so a repeated ITN can never apply twice.
--      payments.transaction_reference (= PayFast's pf_payment_id) is already unique.
-- =====================================================================================================

alter table public.payments
  add column idempotency_key varchar(100);

create unique index uq_payments_idempotency_key
  on public.payments (idempotency_key) where idempotency_key is not null;

create unique index uq_payments_one_open_per_purpose
  on public.payments (booking_id, purpose) where payment_status = 'pending';

create unique index uq_receipts_payment on public.receipts (payment_id);

create or replace function public.apply_payfast_payment(
  p_payment_id    uuid,
  p_pf_payment_id varchar,
  p_amount        numeric,
  p_raw           jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_payment public.payments%rowtype;
  v_booking_status public.booking_status;
begin
  -- Lock the payment: a second ITN for it waits here, then sees it is no longer pending.
  select * into v_payment from public.payments where id = p_payment_id for update;
  if not found then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  if v_payment.payment_status <> 'pending' then
    return jsonb_build_object('outcome', 'already_processed', 'status', v_payment.payment_status,
                              'booking_id', v_payment.booking_id, 'purpose', v_payment.purpose);
  end if;
  if round(p_amount, 2) <> round(v_payment.amount, 2) then
    return jsonb_build_object('outcome', 'amount_mismatch', 'expected', v_payment.amount);
  end if;
  if p_pf_payment_id is not null and exists (
       select 1 from public.payments where transaction_reference = p_pf_payment_id and id <> p_payment_id) then
    return jsonb_build_object('outcome', 'duplicate_reference');
  end if;

  select status into v_booking_status from public.bookings where id = v_payment.booking_id for update;

  update public.payments
     set payment_status = 'paid',
         transaction_reference = p_pf_payment_id,
         gateway_response_raw = p_raw,
         paid_at = now()
   where id = p_payment_id;

  insert into public.receipts (payment_id) values (p_payment_id)
  on conflict (payment_id) do nothing;

  if v_payment.purpose = 'balance' then
    update public.bookings
       set balance_status = 'paid', balance_payment_method = 'card'
     where id = v_payment.booking_id;
  else
    update public.bookings
       set booking_fee_status = 'paid'
     where id = v_payment.booking_id;
  end if;

  return jsonb_build_object('outcome', 'paid', 'booking_id', v_payment.booking_id,
                            'purpose', v_payment.purpose, 'booking_status', v_booking_status);
end;
$$;

-- Only the backend (service role) may call it; never the app's anon/authenticated keys.
revoke all on function public.apply_payfast_payment(uuid, varchar, numeric, jsonb) from public, anon, authenticated;
grant execute on function public.apply_payfast_payment(uuid, varchar, numeric, jsonb) to service_role;
