-- Already applied to the remote database on 20260807 (exported from supabase_migrations.schema_migrations).
-- Do not edit: kept so the local migration history matches the remote one.

-- ============================================================================
-- ConnectLocal — Full Database Schema (PostgreSQL / Supabase)
-- Version: 2.0
-- ============================================================================

create extension if not exists "pgcrypto";
create extension if not exists "postgis";

create type user_role as enum ('customer', 'provider', 'admin');
create type verification_status as enum ('pending', 'verified', 'rejected', 'suspended');
create type booking_status as enum ('pending', 'accepted', 'rejected', 'in_progress', 'completed', 'cancelled');
create type payment_status as enum ('pending', 'paid', 'failed', 'refunded', 'partially_refunded');
create type approval_status as enum ('pending', 'approved', 'rejected');
create type notification_type as enum ('booking', 'payment', 'message', 'review', 'system');
create type cancelled_by_type as enum ('customer', 'provider', 'admin');
create type dispute_status as enum ('open', 'under_review', 'resolved', 'rejected');

create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- ============================================================================
-- 1. USERS
-- ============================================================================
create table public.users (
  id              uuid primary key references auth.users(id) on delete cascade,
  full_name       varchar(100) not null,
  email           varchar(255) not null unique,
  phone_number    varchar(20) unique,
  role            user_role not null default 'customer',
  email_verified  boolean not null default false,
  phone_verified  boolean not null default false,
  profile_image   text,
  is_active       boolean not null default true,
  last_login_at   timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

create trigger trg_users_updated_at
  before update on public.users
  for each row execute function set_updated_at();

-- ============================================================================
-- 2. PROVIDERS
-- ============================================================================
create table public.providers (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null unique references public.users(id) on delete cascade,
  business_name         varchar(150) not null,
  business_description  text,
  business_registration_number varchar(50),
  street_address        varchar(150),
  suburb                varchar(100),
  city                  varchar(100),
  province              varchar(100),
  postal_code           varchar(10),
  location              geography(Point, 4326),
  service_radius_km     integer default 15,
  verification_status   verification_status not null default 'pending',
  rating_average        numeric(3,2) default 0.00,
  rating_count          integer default 0,
  response_time_avg_minutes integer,
  is_active             boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index idx_providers_location on public.providers using gist (location);
create index idx_providers_verification on public.providers (verification_status) where is_active = true;

create trigger trg_providers_updated_at
  before update on public.providers
  for each row execute function set_updated_at();

-- ============================================================================
-- 3. SERVICE CATEGORIES
-- ============================================================================
create table public.service_categories (
  id                uuid primary key default gen_random_uuid(),
  parent_category_id uuid references public.service_categories(id) on delete set null,
  name              varchar(100) not null,
  description       text,
  icon              text,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now()
);

-- ============================================================================
-- 4. SERVICES
-- ============================================================================
create table public.services (
  id              uuid primary key default gen_random_uuid(),
  provider_id     uuid not null references public.providers(id) on delete cascade,
  category_id     uuid not null references public.service_categories(id) on delete restrict,
  service_name    varchar(150) not null,
  description     text,
  base_price      numeric(10,2) not null check (base_price >= 0),
  currency        varchar(3) not null default 'ZAR',
  duration_minutes integer not null check (duration_minutes > 0),
  min_notice_hours integer default 24,
  active          boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index idx_services_provider_active on public.services (provider_id, active);
create index idx_services_category on public.services (category_id);

create trigger trg_services_updated_at
  before update on public.services
  for each row execute function set_updated_at();

-- ============================================================================
-- 5. SERVICE IMAGES
-- ============================================================================
create table public.service_images (
  id          uuid primary key default gen_random_uuid(),
  service_id  uuid not null references public.services(id) on delete cascade,
  image_url   text not null,
  sort_order  integer default 0,
  created_at  timestamptz not null default now()
);

-- ============================================================================
-- 6. PROVIDER GALLERY
-- ============================================================================
create table public.provider_gallery (
  id           uuid primary key default gen_random_uuid(),
  provider_id  uuid not null references public.providers(id) on delete cascade,
  image_url    text not null,
  caption      varchar(200),
  sort_order   integer default 0,
  created_at   timestamptz not null default now()
);

-- ============================================================================
-- 7. PROVIDER AVAILABILITY
-- ============================================================================
create table public.provider_availability (
  id           uuid primary key default gen_random_uuid(),
  provider_id  uuid not null references public.providers(id) on delete cascade,
  day_of_week  integer not null check (day_of_week between 0 and 6),
  start_time   time not null,
  end_time     time not null,
  created_at   timestamptz not null default now(),
  check (end_time > start_time)
);

create index idx_provider_availability on public.provider_availability (provider_id, day_of_week);

-- ============================================================================
-- 8. PROVIDER TIME OFF
-- ============================================================================
create table public.provider_time_off (
  id           uuid primary key default gen_random_uuid(),
  provider_id  uuid not null references public.providers(id) on delete cascade,
  start_at     timestamptz not null,
  end_at       timestamptz not null,
  reason       varchar(200),
  created_at   timestamptz not null default now(),
  check (end_at > start_at)
);

-- ============================================================================
-- 9. CUSTOMER ADDRESSES
-- ============================================================================
create table public.customer_addresses (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.users(id) on delete cascade,
  label          varchar(50),
  street_address varchar(150) not null,
  suburb         varchar(100),
  city           varchar(100) not null,
  province       varchar(100) not null,
  postal_code    varchar(10),
  location       geography(Point, 4326),
  is_default     boolean not null default false,
  created_at     timestamptz not null default now()
);

create index idx_customer_addresses_user on public.customer_addresses (user_id);

-- ============================================================================
-- 10. BOOKINGS
-- ============================================================================
create table public.bookings (
  id                        uuid primary key default gen_random_uuid(),
  customer_id               uuid not null references public.users(id) on delete restrict,
  provider_id               uuid not null references public.providers(id) on delete restrict,
  service_id                uuid not null references public.services(id) on delete restrict,
  customer_address_id       uuid references public.customer_addresses(id) on delete set null,
  scheduled_start           timestamptz not null,
  scheduled_end             timestamptz not null,
  service_price_at_booking  numeric(10,2) not null check (service_price_at_booking >= 0),
  duration_minutes_at_booking integer not null,
  status                    booking_status not null default 'pending',
  total_amount              numeric(10,2) not null check (total_amount >= 0),
  notes                     text,
  cancelled_by              cancelled_by_type,
  cancellation_reason       text,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now(),
  check (scheduled_end > scheduled_start)
);

create index idx_bookings_provider_time on public.bookings (provider_id, scheduled_start);
create index idx_bookings_customer_time on public.bookings (customer_id, created_at);

create unique index unique_provider_slot
  on public.bookings (provider_id, scheduled_start)
  where status in ('pending', 'accepted', 'in_progress');

create trigger trg_bookings_updated_at
  before update on public.bookings
  for each row execute function set_updated_at();

-- ============================================================================
-- 11. BOOKING STATUS HISTORY
-- ============================================================================
create table public.booking_status_history (
  id           uuid primary key default gen_random_uuid(),
  booking_id   uuid not null references public.bookings(id) on delete cascade,
  old_status   booking_status,
  new_status   booking_status not null,
  changed_by   uuid references public.users(id) on delete set null,
  changed_at   timestamptz not null default now()
);

create or replace function log_booking_status_change()
returns trigger as $$
begin
  if (old.status is distinct from new.status) then
    insert into public.booking_status_history (booking_id, old_status, new_status)
    values (new.id, old.status, new.status);
  end if;
  return new;
end;
$$ language plpgsql;

create trigger trg_booking_status_history
  after update on public.bookings
  for each row execute function log_booking_status_change();

-- ============================================================================
-- 12. PAYMENTS
-- ============================================================================
create table public.payments (
  id                    uuid primary key default gen_random_uuid(),
  booking_id            uuid not null references public.bookings(id) on delete restrict,
  amount                numeric(10,2) not null check (amount > 0),
  currency              varchar(3) not null default 'ZAR',
  gateway_provider      varchar(50),
  transaction_reference varchar(100) unique,
  gateway_response_raw  jsonb,
  payment_status        payment_status not null default 'pending',
  refunded_amount       numeric(10,2) default 0,
  paid_at               timestamptz,
  created_at            timestamptz not null default now()
);

create index idx_payments_booking on public.payments (booking_id);

-- ============================================================================
-- 13. RECEIPTS
-- ============================================================================
create table public.receipts (
  id              uuid primary key default gen_random_uuid(),
  payment_id      uuid not null references public.payments(id) on delete cascade,
  sequence_number bigserial unique,
  receipt_url     text,
  created_at      timestamptz not null default now()
);

-- ============================================================================
-- 14. REVIEWS
-- ============================================================================
create table public.reviews (
  id                    uuid primary key default gen_random_uuid(),
  booking_id            uuid not null unique references public.bookings(id) on delete cascade,
  customer_id           uuid not null references public.users(id) on delete cascade,
  provider_id           uuid not null references public.providers(id) on delete cascade,
  rating                integer not null check (rating between 1 and 5),
  review_text           text,
  provider_response_text varchar(1000),
  provider_response_at  timestamptz,
  is_flagged            boolean not null default false,
  created_at            timestamptz not null default now()
);

create index idx_reviews_provider on public.reviews (provider_id);

create or replace function refresh_provider_rating()
returns trigger as $$
begin
  update public.providers
  set rating_average = coalesce((select round(avg(rating)::numeric, 2) from public.reviews where provider_id = coalesce(new.provider_id, old.provider_id)), 0),
      rating_count    = (select count(*) from public.reviews where provider_id = coalesce(new.provider_id, old.provider_id))
  where id = coalesce(new.provider_id, old.provider_id);
  return null;
end;
$$ language plpgsql;

create trigger trg_reviews_rating_sync
  after insert or update or delete on public.reviews
  for each row execute function refresh_provider_rating();

-- ============================================================================
-- 15. MESSAGES
-- ============================================================================
create table public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null default gen_random_uuid(),
  booking_id      uuid references public.bookings(id) on delete set null,
  sender_id       uuid not null references public.users(id) on delete cascade,
  receiver_id     uuid not null references public.users(id) on delete cascade,
  message_text    text not null,
  is_read         boolean not null default false,
  created_at      timestamptz not null default now(),
  check (sender_id != receiver_id)
);

create index idx_messages_conversation on public.messages (conversation_id, created_at);
create index idx_messages_booking on public.messages (booking_id, created_at);

-- ============================================================================
-- 16. NOTIFICATIONS
-- ============================================================================
create table public.notifications (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references public.users(id) on delete cascade,
  title                varchar(150) not null,
  message              text,
  notification_type    notification_type not null,
  related_entity_type  varchar(50),
  related_entity_id    uuid,
  is_read              boolean not null default false,
  is_pushed            boolean not null default false,
  created_at           timestamptz not null default now()
);

create index idx_notifications_user on public.notifications (user_id, is_read, created_at);

-- ============================================================================
-- 17. PROVIDER DOCUMENTS
-- ============================================================================
create table public.provider_documents (
  id               uuid primary key default gen_random_uuid(),
  provider_id      uuid not null references public.providers(id) on delete cascade,
  document_type    varchar(50) not null,
  document_url     text not null,
  approval_status  approval_status not null default 'pending',
  rejection_reason text,
  reviewed_by      uuid references public.users(id) on delete set null,
  reviewed_at      timestamptz,
  expiry_date      date,
  uploaded_at      timestamptz not null default now()
);

create index idx_provider_documents_provider on public.provider_documents (provider_id);

-- ============================================================================
-- 18. PROVIDER PAYOUT DETAILS
-- ============================================================================
create table public.provider_payout_details (
  id                  uuid primary key default gen_random_uuid(),
  provider_id         uuid not null unique references public.providers(id) on delete cascade,
  bank_name           varchar(100),
  account_holder_name varchar(150),
  account_number_encrypted text,
  branch_code         varchar(20),
  payout_provider_token text,
  created_at          timestamptz not null default now()
);

-- ============================================================================
-- 19. DISPUTES
-- ============================================================================
create table public.disputes (
  id           uuid primary key default gen_random_uuid(),
  booking_id   uuid not null references public.bookings(id) on delete restrict,
  raised_by    uuid not null references public.users(id) on delete restrict,
  payment_id   uuid references public.payments(id) on delete set null,
  reason       text not null,
  status       dispute_status not null default 'open',
  resolution_notes text,
  resolved_by  uuid references public.users(id) on delete set null,
  resolved_at  timestamptz,
  created_at   timestamptz not null default now()
);

-- ============================================================================
-- 20. FAVORITES
-- ============================================================================
create table public.favorites (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users(id) on delete cascade,
  provider_id  uuid not null references public.providers(id) on delete cascade,
  created_at   timestamptz not null default now(),
  unique (user_id, provider_id)
);

-- ============================================================================
-- 21. SEARCH HISTORY
-- ============================================================================
create table public.search_history (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references public.users(id) on delete set null,
  search_query varchar(200),
  category_id  uuid references public.service_categories(id) on delete set null,
  location_text varchar(150),
  results_count integer,
  created_at   timestamptz not null default now()
);

create index idx_search_history_user on public.search_history (user_id, created_at);

-- ============================================================================
-- 22. PROVIDER VIEWS
-- ============================================================================
create table public.provider_views (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references public.users(id) on delete set null,
  provider_id  uuid not null references public.providers(id) on delete cascade,
  viewed_at    timestamptz not null default now()
);

create index idx_provider_views_provider on public.provider_views (provider_id, viewed_at);

-- ============================================================================
-- 23. RECOMMENDATION LOGS
-- ============================================================================
create table public.recommendation_logs (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid references public.users(id) on delete set null,
  provider_id    uuid not null references public.providers(id) on delete cascade,
  recommended_at timestamptz not null default now(),
  was_clicked    boolean default false,
  was_booked     boolean default false,
  model_version  varchar(50)
);

-- ============================================================================
-- 24. ADMIN LOGS
-- ============================================================================
create table public.admin_logs (
  id               uuid primary key default gen_random_uuid(),
  admin_id         uuid not null references public.users(id) on delete restrict,
  action           varchar(100) not null,
  target_table     varchar(100),
  target_record_id uuid,
  old_value        jsonb,
  new_value        jsonb,
  ip_address       inet,
  created_at       timestamptz not null default now()
);

create or replace function block_admin_log_mutation()
returns trigger as $$
begin
  raise exception 'admin_logs is append-only: % not permitted', tg_op;
end;
$$ language plpgsql;

create trigger trg_block_admin_log_update
  before update or delete on public.admin_logs
  for each row execute function block_admin_log_mutation();

-- ============================================================================
-- MATERIALIZED VIEW
-- ============================================================================
create materialized view public.provider_performance_mv as
select
  p.id as provider_id,
  p.business_name,
  count(b.id) filter (where b.status = 'completed') as completed_bookings,
  count(b.id) filter (where b.status = 'cancelled') as cancelled_bookings,
  round(
    (count(b.id) filter (where b.status = 'completed'))::numeric
    / nullif(count(b.id), 0) * 100, 2
  ) as completion_rate_pct,
  p.rating_average,
  p.rating_count
from public.providers p
left join public.bookings b on b.provider_id = p.id
group by p.id, p.business_name, p.rating_average, p.rating_count;
