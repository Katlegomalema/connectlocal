-- =====================================================================================================
-- Booking options and time slots (frontend-booking-updates: "Visit the business" / "House call",
-- working hours, slot length). Saved on the server so every device sees the same thing and the API can
-- check a booking before it is created.
--
--   providers.offers_visit       customers may come to the business / salon
--   providers.offers_house_call  the provider goes to the customer (the old behaviour, so default true)
--   providers.slot_minutes       length of one booking slot (30 min ... full day)
--   bookings.at_business         true = the customer visits the business; false = house call
--   provider_availability        already holds the working hours (one row per open weekday); one row per
--                                day is now enforced (the API already sent one per day).
-- Adding NOT NULL columns with a constant default does not rewrite the tables.
-- =====================================================================================================

alter table public.providers
  add column offers_visit      boolean not null default false,
  add column offers_house_call boolean not null default true,
  add column slot_minutes      integer not null default 60;

alter table public.providers
  add constraint providers_slot_minutes_allowed check (slot_minutes in (30, 60, 120, 240, 480)),
  add constraint providers_offers_a_booking_option check (offers_visit or offers_house_call);

alter table public.bookings
  add column at_business boolean not null default false;

create unique index if not exists uq_provider_availability_day
  on public.provider_availability (provider_id, day_of_week);
