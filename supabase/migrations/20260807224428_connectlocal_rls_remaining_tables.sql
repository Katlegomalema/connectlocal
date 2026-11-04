-- Already applied to the remote database on 20260807 (exported from supabase_migrations.schema_migrations).
-- Do not edit: kept so the local migration history matches the remote one.

-- Enable RLS on the remaining tables and add sensible policies

alter table public.service_categories enable row level security;
create policy "categories_select_public" on public.service_categories
  for select using (is_active = true);

alter table public.service_images enable row level security;
create policy "service_images_select_public" on public.service_images
  for select using (true);
create policy "service_images_manage_owner" on public.service_images
  for all using (
    service_id in (
      select id from public.services
      where provider_id in (select id from public.providers where user_id = auth.uid())
    )
  );

alter table public.provider_gallery enable row level security;
create policy "provider_gallery_select_public" on public.provider_gallery
  for select using (true);
create policy "provider_gallery_manage_owner" on public.provider_gallery
  for all using (provider_id in (select id from public.providers where user_id = auth.uid()));

alter table public.provider_availability enable row level security;
create policy "availability_select_public" on public.provider_availability
  for select using (true);
create policy "availability_manage_owner" on public.provider_availability
  for all using (provider_id in (select id from public.providers where user_id = auth.uid()));

alter table public.provider_time_off enable row level security;
create policy "time_off_select_public" on public.provider_time_off
  for select using (true);
create policy "time_off_manage_owner" on public.provider_time_off
  for all using (provider_id in (select id from public.providers where user_id = auth.uid()));

alter table public.booking_status_history enable row level security;
create policy "booking_history_select_participants" on public.booking_status_history
  for select using (
    booking_id in (
      select id from public.bookings
      where customer_id = auth.uid()
         or provider_id in (select id from public.providers where user_id = auth.uid())
    )
  );

alter table public.receipts enable row level security;
create policy "receipts_select_participants" on public.receipts
  for select using (
    payment_id in (
      select id from public.payments where booking_id in (
        select id from public.bookings
        where customer_id = auth.uid()
           or provider_id in (select id from public.providers where user_id = auth.uid())
      )
    )
  );

-- Most sensitive: bank/payout info — owner only, no public policy at all
alter table public.provider_payout_details enable row level security;
create policy "payout_details_owner_only" on public.provider_payout_details
  for all using (provider_id in (select id from public.providers where user_id = auth.uid()));

alter table public.search_history enable row level security;
create policy "search_history_owner" on public.search_history
  for all using (auth.uid() = user_id);

alter table public.provider_views enable row level security;
create policy "provider_views_owner" on public.provider_views
  for select using (auth.uid() = user_id);
create policy "provider_views_insert_any_authenticated" on public.provider_views
  for insert with check (auth.role() = 'authenticated');

alter table public.recommendation_logs enable row level security;
create policy "recommendation_logs_owner" on public.recommendation_logs
  for select using (auth.uid() = user_id);
