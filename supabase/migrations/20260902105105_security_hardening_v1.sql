-- Already applied to the remote database on 20260902 (exported from supabase_migrations.schema_migrations).
-- Do not edit: kept so the local migration history matches the remote one.

-- 1. Lock down search_path on every function
alter function public.set_updated_at() set search_path = public, pg_temp;
alter function public.log_booking_status_change() set search_path = public, pg_temp;
alter function public.block_admin_log_mutation() set search_path = public, pg_temp;
alter function public.refresh_provider_rating() set search_path = public, pg_temp;
alter function public.handle_new_auth_user() set search_path = public, pg_temp;
alter function public.is_admin() set search_path = public, pg_temp;

-- 2. handle_new_auth_user should only run via the signup trigger
revoke execute on function public.handle_new_auth_user() from anon, authenticated;

-- 3. is_admin() shouldn't be callable by logged-out users
revoke execute on function public.is_admin() from anon;

-- 4. Stop the ranking materialized view being publicly queryable
revoke select on public.provider_performance_mv from anon, authenticated;

-- 5. Real policies for admin_logs
create policy "admin_logs_admin_select" on public.admin_logs
  for select using (is_admin());
create policy "admin_logs_admin_insert" on public.admin_logs
  for insert with check (is_admin() and auth.uid() = admin_id);

-- 6. Wire is_admin() into tables where admins act
create policy "providers_admin_manage" on public.providers
  for update using (is_admin());

create policy "provider_documents_admin_manage" on public.provider_documents
  for all using (is_admin());

create policy "disputes_admin_manage" on public.disputes
  for all using (is_admin());

create policy "disputes_insert_participant" on public.disputes
  for insert with check (
    auth.uid() = raised_by
    and booking_id in (
      select id from public.bookings
      where customer_id = auth.uid()
         or provider_id in (select id from public.providers where user_id = auth.uid())
    )
  );
