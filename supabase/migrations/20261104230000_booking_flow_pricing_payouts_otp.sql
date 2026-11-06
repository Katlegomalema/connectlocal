-- =====================================================================================================
-- Known problem 5 (CLAUDE.md): add what the app needs to the schema.
--
--   1. Types (enums)
--   2. services.pricing_type + service_packages
--   3. bookings: package snapshot, 15% booking fee, balance, payment method, arrival PIN (hash only)
--   4. payments: purpose (booking fee / balance) + method (card / cash)
--   5. payouts (10% commission, automatic payouts)
--   6. phone_otps (6-digit code, hash only, 5 minutes, 5 tries, single use)
--   7. Provider map search + primary category   (was backend/migrations/202611030001, never applied)
--   8. device_tokens for push notifications     (was backend/migrations/202611030002, never applied)
--   9. users.full_name 100 -> 150 chars (the API already accepts 150)
--  10. Indexes for foreign keys that had none
--
-- PIN and OTP: the backend hashes them with HMAC-SHA256 and a server secret (pepper) before storing.
-- The plain values are never stored. New tables get RLS enabled here; policies are in the next migration.
-- All existing rows are demo data; new NOT NULL columns get safe defaults.
-- =====================================================================================================

-- 1. Types -------------------------------------------------------------------------------------------
create type public.pricing_type as enum ('hourly', 'fixed', 'package');
create type public.payment_method as enum ('card', 'cash');
create type public.payment_purpose as enum ('booking_fee', 'balance');
create type public.payout_status as enum ('pending', 'processing', 'paid', 'failed');

-- 2. Pricing -----------------------------------------------------------------------------------------
alter table public.services
  add column pricing_type public.pricing_type not null default 'fixed';

comment on column public.services.base_price is
  'hourly: price per hour; fixed: total price; package: lowest package price (display only)';

create table public.service_packages (
  id               uuid primary key default gen_random_uuid(),
  service_id       uuid not null references public.services (id) on delete cascade,
  name             varchar(100) not null check (length(btrim(name)) between 2 and 100),
  description      text check (description is null or length(description) <= 2000),
  price            numeric(10, 2) not null check (price > 0),
  duration_minutes integer check (duration_minutes is null or duration_minutes > 0),
  sort_order       integer not null default 0,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint service_packages_service_name_key unique (service_id, name) -- also serves as the FK index
);

create trigger trg_service_packages_updated_at
  before update on public.service_packages
  for each row execute function public.set_updated_at();

alter table public.service_packages enable row level security;

-- 3. Bookings ----------------------------------------------------------------------------------------
alter table public.bookings
  -- what was booked (snapshot, so later price/package edits don't change old bookings)
  add column pricing_type_at_booking public.pricing_type not null default 'fixed',
  add column package_id              uuid references public.service_packages (id) on delete set null,
  add column package_name_at_booking varchar(100),
  add column quantity                integer not null default 1 check (quantity between 1 and 100),
  -- 15% booking fee, paid by card up front; it is a deposit that counts toward the price
  add column booking_fee_rate        numeric(5, 4) not null default 0.15 check (booking_fee_rate between 0 and 1),
  add column booking_fee_amount      numeric(10, 2) not null default 0 check (booking_fee_amount >= 0),
  add column booking_fee_status      public.payment_status not null default 'pending',
  -- balance = price - fee, paid after completion by card or cash (computed by the database)
  add column balance_amount          numeric(10, 2) generated always as (total_amount - booking_fee_amount) stored,
  add column balance_status          public.payment_status not null default 'pending',
  add column balance_payment_method  public.payment_method,
  -- 4-digit arrival PIN: only the HMAC hash is stored; the provider enters the PIN on arrival
  add column arrival_pin_hash        text,
  add column arrival_pin_attempts    smallint not null default 0 check (arrival_pin_attempts between 0 and 5),
  add column arrival_pin_verified_at timestamptz;

alter table public.bookings
  add constraint bookings_fee_not_above_total
    check (booking_fee_amount <= total_amount),
  add constraint bookings_package_snapshot
    check (pricing_type_at_booking <> 'package' or package_name_at_booking is not null),
  add constraint bookings_pin_hash_length
    check (arrival_pin_hash is null or length(arrival_pin_hash) between 32 and 255),
  add constraint bookings_balance_method_when_paid
    check (balance_status <> 'paid' or balance_payment_method is not null);

-- A job can only be in progress / completed after the provider entered the PIN on arrival.
-- NOT VALID: checked for every new or changed row, but the existing demo booking (already 'completed',
-- created before PINs existed) is not re-checked.
alter table public.bookings
  add constraint bookings_started_needs_pin
    check (status not in ('in_progress', 'completed') or arrival_pin_verified_at is not null) not valid;

create index idx_bookings_package on public.bookings (package_id) where package_id is not null;

-- 4. Payments ----------------------------------------------------------------------------------------
alter table public.payments
  add column purpose public.payment_purpose not null default 'booking_fee',
  add column method  public.payment_method  not null default 'card';

alter table public.payments
  add constraint payments_card_has_gateway
    check (method <> 'card' or payment_status = 'pending' or gateway_provider is not null);

-- At most one successful booking-fee payment and one successful balance payment per booking.
create unique index uq_payments_one_paid_per_purpose
  on public.payments (booking_id, purpose) where payment_status = 'paid';

-- 5. Payouts (automatic; ConnectLocal keeps a 10% commission) -----------------------------------------
create table public.payouts (
  id                    uuid primary key default gen_random_uuid(),
  booking_id            uuid not null references public.bookings (id) on delete restrict,
  provider_id           uuid not null references public.providers (id) on delete restrict,
  gross_amount          numeric(10, 2) not null check (gross_amount >= 0),           -- full job price
  commission_rate       numeric(5, 4) not null default 0.10 check (commission_rate between 0 and 1),
  commission_amount     numeric(10, 2) not null check (commission_amount >= 0),
  cash_collected_amount numeric(10, 2) not null default 0 check (cash_collected_amount >= 0), -- cash the provider already received
  payout_amount         numeric(10, 2) generated always as (gross_amount - commission_amount - cash_collected_amount) stored,
  status                public.payout_status not null default 'pending',
  payout_reference      varchar(100),
  failure_reason        text,
  paid_at               timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint payouts_booking_id_key unique (booking_id),                 -- one payout per booking
  constraint payouts_not_negative check (commission_amount + cash_collected_amount <= gross_amount),
  constraint payouts_paid_has_time check (status <> 'paid' or paid_at is not null),
  constraint payouts_failed_has_reason check (status <> 'failed' or failure_reason is not null)
);

create index idx_payouts_provider_status on public.payouts (provider_id, status, created_at);

create trigger trg_payouts_updated_at
  before update on public.payouts
  for each row execute function public.set_updated_at();

alter table public.payouts enable row level security;

-- 6. Phone OTP (no paid SMS: the app/backend generates the code) ---------------------------------------
create table public.phone_otps (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users (id) on delete cascade,
  phone_number varchar(20) not null check (phone_number ~ '^\+[1-9][0-9]{7,14}$'),
  code_hash    text not null check (length(code_hash) between 32 and 255),
  attempts     smallint not null default 0 check (attempts between 0 and 5),
  expires_at   timestamptz not null,
  consumed_at  timestamptz,
  created_at   timestamptz not null default now(),
  constraint phone_otps_max_5_minutes check (expires_at > created_at and expires_at <= created_at + interval '5 minutes')
);

-- Single use: at most one open (unconsumed) code per user. The backend closes the old code before
-- issuing a new one.
create unique index uq_phone_otps_one_open_per_user on public.phone_otps (user_id) where consumed_at is null;
-- For rate limiting ("max N codes per hour") and as the FK index.
create index idx_phone_otps_user_created on public.phone_otps (user_id, created_at);

alter table public.phone_otps enable row level security;

-- 7. Provider map search + primary category ---------------------------------------------------------
-- PostGIS is already installed in the "extensions" schema.
alter table public.providers
  add column location            extensions.geography(Point, 4326),
  add column primary_category_id uuid references public.service_categories (id) on delete set null;

create index idx_providers_location on public.providers using gist (location);
create index idx_providers_primary_category on public.providers (primary_category_id)
  where primary_category_id is not null;

create function public.search_nearby_providers(
  search_latitude  double precision,
  search_longitude double precision,
  search_radius_km double precision
)
returns table (
  id                   uuid,
  user_id              uuid,
  business_name        varchar,
  business_description text,
  city                 varchar,
  province             varchar,
  service_radius_km    integer,
  rating_average       numeric,
  rating_count         integer,
  latitude             double precision,
  longitude            double precision,
  distance_km          double precision
)
language sql
stable
set search_path = ''
as $function$
  select
    provider.id,
    provider.user_id,
    provider.business_name,
    provider.business_description,
    provider.city,
    provider.province,
    provider.service_radius_km,
    provider.rating_average,
    provider.rating_count,
    extensions.st_y(provider.location::extensions.geometry) as latitude,
    extensions.st_x(provider.location::extensions.geometry) as longitude,
    extensions.st_distance(
      provider.location,
      extensions.st_setsrid(extensions.st_makepoint(search_longitude, search_latitude), 4326)::extensions.geography
    ) / 1000 as distance_km
  from public.providers as provider
  where provider.is_active
    and provider.verification_status = 'verified'
    and provider.location is not null
    and extensions.st_dwithin(
      provider.location,
      extensions.st_setsrid(extensions.st_makepoint(search_longitude, search_latitude), 4326)::extensions.geography,
      least(search_radius_km, coalesce(provider.service_radius_km, search_radius_km)) * 1000
    )
  order by distance_km, provider.id
$function$;

-- Only the backend (service role) may call it.
revoke all on function public.search_nearby_providers(double precision, double precision, double precision)
  from public, anon, authenticated;
grant execute on function public.search_nearby_providers(double precision, double precision, double precision)
  to service_role;

-- 8. Push notification device tokens -----------------------------------------------------------------
create table public.device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users (id) on delete cascade,
  token      text not null unique,
  platform   text not null check (platform in ('android', 'ios', 'web')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_device_tokens_user on public.device_tokens (user_id);

create trigger trg_device_tokens_updated_at
  before update on public.device_tokens
  for each row execute function public.set_updated_at();

alter table public.device_tokens enable row level security;

-- 9. users.full_name: match the API limit (widening varchar does not rewrite the table) ---------------
alter table public.users alter column full_name type varchar(150);

-- 10. Indexes for foreign keys that had none (Supabase advisor: "unindexed foreign keys") -------------
create index idx_admin_logs_admin              on public.admin_logs (admin_id);
create index idx_booking_status_history_booking on public.booking_status_history (booking_id, changed_at);
create index idx_booking_status_history_changed_by on public.booking_status_history (changed_by) where changed_by is not null;
create index idx_bookings_service              on public.bookings (service_id);
create index idx_bookings_customer_address     on public.bookings (customer_address_id) where customer_address_id is not null;
create index idx_disputes_booking              on public.disputes (booking_id);
create index idx_disputes_raised_by            on public.disputes (raised_by);
create index idx_disputes_payment              on public.disputes (payment_id) where payment_id is not null;
create index idx_disputes_resolved_by          on public.disputes (resolved_by) where resolved_by is not null;
create index idx_favorites_provider            on public.favorites (provider_id);
create index idx_messages_sender               on public.messages (sender_id);
create index idx_messages_receiver             on public.messages (receiver_id, is_read);
create index idx_provider_documents_reviewed_by on public.provider_documents (reviewed_by) where reviewed_by is not null;
create index idx_provider_gallery_provider     on public.provider_gallery (provider_id, sort_order);
create index idx_provider_time_off_provider    on public.provider_time_off (provider_id, start_at);
create index idx_provider_views_user           on public.provider_views (user_id) where user_id is not null;
create index idx_receipts_payment              on public.receipts (payment_id);
create index idx_recommendation_logs_provider  on public.recommendation_logs (provider_id);
create index idx_recommendation_logs_user      on public.recommendation_logs (user_id) where user_id is not null;
create index idx_reviews_customer              on public.reviews (customer_id);
create index idx_search_history_category       on public.search_history (category_id) where category_id is not null;
create index idx_service_categories_parent     on public.service_categories (parent_category_id) where parent_category_id is not null;
create index idx_service_images_service        on public.service_images (service_id, sort_order);
