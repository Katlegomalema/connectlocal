-- =====================================================================================================
-- Phase 5: every booking status change is recorded in booking_status_history, with who did it.
--
-- The backend uses the service role, so the trigger cannot see the user from auth.uid(). Instead the
-- backend sets bookings.status_changed_by in the same UPDATE that changes the status; the trigger copies
-- it into the history row. The first status (pending, on INSERT) is now logged too.
--
-- Also: where the job happens. The app sends one address line plus a map point; the provider needs both.
-- =====================================================================================================

alter table public.bookings
  add column service_address  varchar(300) check (service_address is null or length(btrim(service_address)) >= 5),
  add column service_location extensions.geography(Point, 4326);

alter table public.bookings
  add column status_changed_by uuid references public.users (id) on delete set null;

create index idx_bookings_status_changed_by on public.bookings (status_changed_by)
  where status_changed_by is not null;

create or replace function public.log_booking_status_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.booking_status_history (booking_id, old_status, new_status, changed_by)
    values (new.id, null, new.status, coalesce(new.status_changed_by, new.customer_id));
  elsif old.status is distinct from new.status then
    insert into public.booking_status_history (booking_id, old_status, new_status, changed_by)
    values (new.id, old.status, new.status, new.status_changed_by);
  end if;
  return new;
end;
$$;

revoke all on function public.log_booking_status_change() from public, anon, authenticated;

-- Fire on creation and on status changes only (not on every fee/PIN/balance update).
drop trigger if exists trg_booking_status_history on public.bookings;
create trigger trg_booking_status_history
  after insert or update of status on public.bookings
  for each row execute function public.log_booking_status_change();
