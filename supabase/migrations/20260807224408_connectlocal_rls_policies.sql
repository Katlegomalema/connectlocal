-- Already applied to the remote database on 20260807 (exported from supabase_migrations.schema_migrations).
-- Do not edit: kept so the local migration history matches the remote one.

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

alter table public.users enable row level security;
alter table public.providers enable row level security;
alter table public.services enable row level security;
alter table public.bookings enable row level security;
alter table public.payments enable row level security;
alter table public.reviews enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.provider_documents enable row level security;
alter table public.customer_addresses enable row level security;
alter table public.favorites enable row level security;
alter table public.admin_logs enable row level security;
alter table public.disputes enable row level security;

create policy "users_select_own" on public.users
  for select using (auth.uid() = id);
create policy "users_update_own" on public.users
  for update using (auth.uid() = id);

create policy "providers_select_public" on public.providers
  for select using (verification_status = 'verified' or auth.uid() = user_id);
create policy "providers_insert_own" on public.providers
  for insert with check (auth.uid() = user_id);
create policy "providers_update_own" on public.providers
  for update using (auth.uid() = user_id);

create policy "services_select_public" on public.services
  for select using (active = true);
create policy "services_manage_own" on public.services
  for all using (
    provider_id in (select id from public.providers where user_id = auth.uid())
  );

create policy "bookings_select_participants" on public.bookings
  for select using (
    auth.uid() = customer_id
    or provider_id in (select id from public.providers where user_id = auth.uid())
  );
create policy "bookings_insert_customer" on public.bookings
  for insert with check (auth.uid() = customer_id);
create policy "bookings_update_participants" on public.bookings
  for update using (
    auth.uid() = customer_id
    or provider_id in (select id from public.providers where user_id = auth.uid())
  );

create policy "payments_select_participants" on public.payments
  for select using (
    booking_id in (
      select id from public.bookings
      where customer_id = auth.uid()
         or provider_id in (select id from public.providers where user_id = auth.uid())
    )
  );

create policy "reviews_select_public" on public.reviews
  for select using (true);
create policy "reviews_insert_own_booking" on public.reviews
  for insert with check (
    auth.uid() = customer_id
    and booking_id in (select id from public.bookings where customer_id = auth.uid() and status = 'completed')
  );

create policy "messages_select_participants" on public.messages
  for select using (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "messages_insert_own" on public.messages
  for insert with check (auth.uid() = sender_id);

create policy "notifications_select_own" on public.notifications
  for select using (auth.uid() = user_id);
create policy "notifications_update_own" on public.notifications
  for update using (auth.uid() = user_id);

create policy "provider_documents_select_owner" on public.provider_documents
  for select using (
    provider_id in (select id from public.providers where user_id = auth.uid())
  );
create policy "provider_documents_insert_owner" on public.provider_documents
  for insert with check (
    provider_id in (select id from public.providers where user_id = auth.uid())
  );

create policy "customer_addresses_owner" on public.customer_addresses
  for all using (auth.uid() = user_id);

create policy "favorites_owner" on public.favorites
  for all using (auth.uid() = user_id);

create policy "disputes_select_participants" on public.disputes
  for select using (
    booking_id in (
      select id from public.bookings
      where customer_id = auth.uid()
         or provider_id in (select id from public.providers where user_id = auth.uid())
    )
  );

create or replace function is_admin()
returns boolean as $$
  select exists (
    select 1 from public.users where id = auth.uid() and role = 'admin'
  );
$$ language sql security definer stable;
