-- =====================================================================================================
-- Known problem 6 (CLAUDE.md): clean up RLS, and close two privilege-escalation holes.
--
-- Access model (matches CLAUDE.md: Flutter app -> Express API -> Supabase):
--   * The backend uses the service role, which bypasses RLS. It enforces all business rules.
--   * Direct client access (anon / authenticated keys) is least-privilege:
--       - read public catalogue data (verified providers only) and your own data
--       - write only harmless personal data: addresses, favourites, search history, profile views,
--         sending messages, and marking messages / notifications as read
--       - money, booking status, verification, reviews and ratings: API only (no client write policies)
--   * One policy per table per action, with explicit TO roles, (select auth.uid()) so it is evaluated
--     once per query, and WITH CHECK on every UPDATE.
--
-- Fixes found in the live database (4 Nov 2026):
--   A. handle_new_user() took "role" from sign-up metadata -> anyone could sign up as admin.
--   B. "Users update own account" had no column limit -> any user could set role = 'admin' or mark their
--      own email/phone as verified. Same for providers (verification_status, rating) and bookings
--      (status, total_amount).
--   C. is_admin() / my_provider_id() were SECURITY INVOKER and read RLS-protected tables from inside
--      RLS policies (recursion risk); anon could not execute them, but TO public policies called them.
--   D. 127 policies, mostly duplicates from two setup rounds; all TO public; provider_views used the
--      deprecated auth.role(); no UPDATE policy had WITH CHECK; unverified providers were public.
--   E. anon/authenticated had TRUNCATE/TRIGGER/REFERENCES on every table (RLS does not cover TRUNCATE).
-- =====================================================================================================

-- A. Sign-up trigger: a new account is only ever customer or provider -------------------------------
-- (The admin is created separately; it can never come from sign-up metadata.)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.users (id, full_name, email, role, email_verified, created_at)
  values (
    new.id,
    left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), 'New user'), 150),
    new.email,
    case when new.raw_user_meta_data ->> 'role' = 'provider'
         then 'provider'::public.user_role
         else 'customer'::public.user_role end,
    new.email_confirmed_at is not null,
    now()
  );
  return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

-- Unused duplicate of handle_new_user (no trigger uses it; same admin-role hole).
drop function if exists public.handle_new_auth_user();

-- C. Helper functions used by policies ----------------------------------------------------------------
-- SECURITY DEFINER so they read users/providers without re-entering RLS; empty search_path; STABLE so the
-- planner can cache them. Both only ever answer about the caller (auth.uid()).
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.users u
    where u.id = (select auth.uid())
      and u.role = 'admin'
      and u.is_active
      and u.deleted_at is null
  );
$$;

create or replace function public.my_provider_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id from public.providers p where p.user_id = (select auth.uid());
$$;

-- anon gets EXECUTE too: for anon, auth.uid() is null so these return false / null. This lets a policy
-- be shared by anon and authenticated (one policy per action) without "permission denied for function".
revoke all on function public.is_admin(), public.my_provider_id() from public;
grant execute on function public.is_admin(), public.my_provider_id() to anon, authenticated, service_role;

-- Trigger-only functions: nobody needs to call them directly.
revoke all on function public.block_admin_log_mutation(), public.log_booking_status_change(),
  public.refresh_provider_rating(), public.set_updated_at() from public, anon, authenticated;

-- E. Table privileges -------------------------------------------------------------------------------------
revoke truncate, trigger, references on all tables in schema public from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke truncate, trigger, references on tables from anon, authenticated;

-- Writes are API-only on every table except the few listed below.
revoke insert, update, delete on all tables in schema public from anon, authenticated;

-- Tables that clients must not even read (secrets, money flows, internal data): API only.
revoke all on public.provider_payout_details, public.phone_otps, public.device_tokens, public.admin_logs
  from anon, authenticated;

-- Harmless personal writes allowed to signed-in users (row access is limited by the policies below).
grant insert, update, delete on public.customer_addresses to authenticated;
grant insert, delete on public.favorites to authenticated;
grant insert, delete on public.search_history to authenticated;
grant insert on public.provider_views to authenticated;
grant insert on public.messages to authenticated;
grant update (is_read) on public.messages to authenticated;       -- column-level: only the read flag
grant update (is_read) on public.notifications to authenticated;  -- column-level: only the read flag

-- D. Policies: drop every existing policy in public, then create exactly one per action ---------------
do $$
declare
  p record;
begin
  for p in select tablename, policyname from pg_policies where schemaname = 'public' loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end;
$$;

-- users: you see yourself; admins see everyone. No client writes (sign-up trigger + API only).
create policy users_select on public.users
  for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));

-- providers: verified + active providers are public; owners and admins also see unverified ones.
create policy providers_select on public.providers
  for select to anon, authenticated
  using (
    (verification_status = 'verified' and is_active)
    or user_id = (select auth.uid())
    or (select public.is_admin())
  );

-- Provider sub-resources follow the provider's visibility (the subquery is itself filtered by
-- providers_select, so unverified providers' data stays hidden).
create policy provider_availability_select on public.provider_availability
  for select to anon, authenticated
  using (exists (select 1 from public.providers p where p.id = provider_id));

create policy provider_time_off_select on public.provider_time_off
  for select to anon, authenticated
  using (exists (select 1 from public.providers p where p.id = provider_id));

create policy provider_gallery_select on public.provider_gallery
  for select to anon, authenticated
  using (exists (select 1 from public.providers p where p.id = provider_id));

create policy provider_documents_select on public.provider_documents
  for select to authenticated
  using (provider_id = (select public.my_provider_id()) or (select public.is_admin()));

-- Catalogue
create policy service_categories_select on public.service_categories
  for select to anon, authenticated
  using (is_active or (select public.is_admin()));

create policy services_select on public.services
  for select to anon, authenticated
  using (
    (active and exists (select 1 from public.providers p
                        where p.id = provider_id and p.verification_status = 'verified' and p.is_active))
    or provider_id = (select public.my_provider_id())
    or (select public.is_admin())
  );

create policy service_packages_select on public.service_packages
  for select to anon, authenticated
  using (
    exists (select 1 from public.services s where s.id = service_id)   -- filtered by services_select
    and (is_active
         or exists (select 1 from public.services s
                    where s.id = service_id and s.provider_id = (select public.my_provider_id()))
         or (select public.is_admin()))
  );

create policy service_images_select on public.service_images
  for select to anon, authenticated
  using (exists (select 1 from public.services s where s.id = service_id));

-- Reviews: public unless flagged; the author, the provider and admins always see them.
create policy reviews_select on public.reviews
  for select to anon, authenticated
  using (
    not is_flagged
    or customer_id = (select auth.uid())
    or provider_id = (select public.my_provider_id())
    or (select public.is_admin())
  );

-- Bookings and everything hanging off a booking: participants + admins. Writes are API only.
create policy bookings_select on public.bookings
  for select to authenticated
  using (
    customer_id = (select auth.uid())
    or provider_id = (select public.my_provider_id())
    or (select public.is_admin())
  );

create policy booking_status_history_select on public.booking_status_history
  for select to authenticated
  using (exists (select 1 from public.bookings b where b.id = booking_id));  -- filtered by bookings_select

create policy payments_select on public.payments
  for select to authenticated
  using (exists (select 1 from public.bookings b where b.id = booking_id));

create policy receipts_select on public.receipts
  for select to authenticated
  using (exists (select 1 from public.payments p where p.id = payment_id));  -- filtered by payments_select

create policy disputes_select on public.disputes
  for select to authenticated
  using (exists (select 1 from public.bookings b where b.id = booking_id));

create policy payouts_select on public.payouts
  for select to authenticated
  using (provider_id = (select public.my_provider_id()) or (select public.is_admin()));

-- Customer addresses: owner manages them; the provider of a booking at that address can read it.
create policy customer_addresses_select on public.customer_addresses
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select public.is_admin())
    or exists (select 1 from public.bookings b
               where b.customer_address_id = customer_addresses.id  -- qualified: bare "id" would mean b.id
                 and b.provider_id = (select public.my_provider_id()))
  );

create policy customer_addresses_insert on public.customer_addresses
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy customer_addresses_update on public.customer_addresses
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy customer_addresses_delete on public.customer_addresses
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- Favourites
create policy favorites_select on public.favorites
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy favorites_insert on public.favorites
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy favorites_delete on public.favorites
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- Search history
create policy search_history_select on public.search_history
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

create policy search_history_insert on public.search_history
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy search_history_delete on public.search_history
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- Profile views (replaces the auth.role() policy)
create policy provider_views_select on public.provider_views
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or provider_id = (select public.my_provider_id())
    or (select public.is_admin())
  );

create policy provider_views_insert on public.provider_views
  for insert to authenticated
  with check (user_id = (select auth.uid()));

-- Recommendation logs
create policy recommendation_logs_select on public.recommendation_logs
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

-- Messages: participants read; you send as yourself; the receiver may only flip is_read (column grant).
create policy messages_select on public.messages
  for select to authenticated
  using (sender_id = (select auth.uid()) or receiver_id = (select auth.uid()));

create policy messages_insert on public.messages
  for insert to authenticated
  with check (sender_id = (select auth.uid()));

create policy messages_update on public.messages
  for update to authenticated
  using (receiver_id = (select auth.uid()))
  with check (receiver_id = (select auth.uid()));

-- Notifications: own only; only is_read may change (column grant).
create policy notifications_select on public.notifications
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy notifications_update on public.notifications
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- No policies (API only, RLS on = deny all for anon/authenticated):
--   provider_payout_details, phone_otps, device_tokens, admin_logs
