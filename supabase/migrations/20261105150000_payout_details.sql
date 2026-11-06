-- =====================================================================================================
-- Provider bank details for automatic payouts (CLAUDE.md: needed before accepting bookings; account
-- numbers stored encrypted and never returned in full).
--
-- The backend encrypts the account number with AES-256-GCM (key in backend/.env, PAYOUT_ENCRYPTION_KEY)
-- and stores "v1:<iv>:<tag>:<ciphertext>" (base64). Only the last 4 digits are kept in clear, for display.
-- provider_payout_details stays API-only (no RLS policies for anon/authenticated, see migration 2).
-- =====================================================================================================

alter table public.provider_payout_details
  add column account_type  varchar(30)
    check (account_type is null or account_type in ('Cheque / Current', 'Savings', 'Transmission')),
  add column account_last4 char(4) check (account_last4 is null or account_last4 ~ '^[0-9]{4}$'),
  add column updated_at    timestamptz not null default now();

alter table public.provider_payout_details
  add constraint payout_details_branch_code_digits
    check (branch_code is null or branch_code ~ '^[0-9]{6}$'),
  add constraint payout_details_encrypted_format
    check (account_number_encrypted is null or account_number_encrypted ~ '^v1:[A-Za-z0-9+/=]+:[A-Za-z0-9+/=]+:[A-Za-z0-9+/=]+$'),
  add constraint payout_details_complete
    check (account_number_encrypted is null
           or (bank_name is not null and account_holder_name is not null and account_last4 is not null));

create trigger trg_payout_details_updated_at
  before update on public.provider_payout_details
  for each row execute function public.set_updated_at();
