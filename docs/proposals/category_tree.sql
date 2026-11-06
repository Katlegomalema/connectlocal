-- =====================================================================================================
-- PROPOSAL (not applied, not in supabase/migrations yet): one clean list of local-service categories with
-- subcategories. After your OK this file moves to supabase/migrations/ and is applied with `npm run db:push`.
--
-- Nothing is deleted. Existing rows are renamed where they mean the same thing, so services and providers
-- keep their category ("Beauty & Health" has 1 service + 1 provider -> becomes "Beauty & Hair").
--
-- New columns on service_categories:
--   parent_id   null = a main category; otherwise the main category this subcategory belongs to (2 levels)
--   sort_order  the order the app shows them in (the app no longer has its own list)
--   icon        now an icon KEY the app turns into an icon (e.g. 'plumbing'); unknown key -> a generic icon
-- The existing unique index uq_service_categories_name (lower(name)) stays: no duplicate names, ever.
-- =====================================================================================================

alter table public.service_categories
  add column parent_id  uuid references public.service_categories (id) on delete restrict,
  add column sort_order integer not null default 0;

alter table public.service_categories
  add constraint service_categories_not_own_parent check (parent_id is null or parent_id <> id);

create index idx_service_categories_parent on public.service_categories (parent_id, sort_order);

-- Only two levels: a subcategory cannot have subcategories.
create or replace function public.check_category_depth()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if new.parent_id is not null and exists (
       select 1 from public.service_categories where id = new.parent_id and parent_id is not null) then
    raise exception 'A subcategory cannot have its own subcategories' using errcode = '23514';
  end if;
  if new.parent_id is not null and exists (
       select 1 from public.service_categories where parent_id = new.id) then
    raise exception 'A category with subcategories cannot become a subcategory' using errcode = '23514';
  end if;
  return new;
end $$;

create trigger trg_service_categories_depth
  before insert or update of parent_id on public.service_categories
  for each row execute function public.check_category_depth();

-- 1. Renames (same meaning, keeps links) ------------------------------------------------------------------
update public.service_categories c set name = r.new_name
from (values
  ('Beauty & Health',      'Beauty & Hair'),
  ('Cleaning Services',    'Cleaning'),
  ('Education & Tutoring', 'Tutoring & Lessons'),
  ('Electrical Services',  'Electrical'),
  ('Automotive Services',  'Automotive'),
  ('Healthcare',           'Health & Care'),
  ('Gardening',            'Gardening & Landscaping'),
  ('Security',             'Security & CCTV'),
  ('Home Maintenance',     'Home Repairs & Building')
) as r (old_name, new_name)
where lower(c.name) = lower(r.old_name)
  and not exists (select 1 from public.service_categories e where lower(e.name) = lower(r.new_name));

-- 2. Main categories (insert missing, set order/icon/description, switch on) ------------------------------
insert into public.service_categories (name, description, icon, sort_order, is_active, parent_id)
values
  ('Plumbing',                'Leaks, geysers, drains, pipes and bathroom installs',       'plumbing',    10, true, null),
  ('Electrical',              'Wiring, compliance certificates, lights and solar',         'electrical',  20, true, null),
  ('Cleaning',                'Homes, offices, carpets and windows',                       'cleaning',    30, true, null),
  ('Gardening & Landscaping', 'Garden service, lawns, trees and irrigation',               'gardening',   40, true, null),
  ('Home Repairs & Building', 'Handyman, painting, tiling, roofing and carpentry',         'handyman',    50, true, null),
  ('Appliance Repair',        'Fridges, washing machines, stoves and small appliances',    'appliance',   60, true, null),
  ('IT & Tech Help',          'Computers, phones, Wi-Fi and software setup',               'tech',        70, true, null),
  ('Security & CCTV',         'CCTV, alarms, electric fencing and gate motors',            'security',    80, true, null),
  ('Moving & Transport',      'House moves, bakkie hire, deliveries and rubble removal',   'moving',      90, true, null),
  ('Pest Control',            'Termites, rodents, cockroaches and fumigation',             'pest',       100, true, null),
  ('Beauty & Hair',           'Hair, barbers, nails, make-up and massage',                 'beauty',     110, true, null),
  ('Tutoring & Lessons',      'School subjects, matric prep, languages and music',         'tutoring',   120, true, null),
  ('Health & Care',           'Home nursing, elderly care and physiotherapy',              'health',     130, true, null),
  ('Automotive',              'Mechanics, car wash, tyres and panel beating',              'automotive', 140, true, null),
  ('Events & Photography',    'Photographers, DJs, catering and decor',                    'events',     150, true, null),
  ('Other',                   'Any other local service',                                   'other',      999, true, null)
on conflict (lower(name)) do update
  set description = excluded.description, icon = excluded.icon, sort_order = excluded.sort_order,
      is_active = true, parent_id = null;

-- 3. Subcategories --------------------------------------------------------------------------------------
insert into public.service_categories (name, description, icon, sort_order, is_active, parent_id)
select s.name, null, null, s.sort_order, true, p.id
from (values
  ('Plumbing', 'Leaks & Burst Pipes', 1), ('Plumbing', 'Geysers', 2), ('Plumbing', 'Drains & Blockages', 3),
  ('Plumbing', 'Bathroom & Kitchen Installs', 4),
  ('Electrical', 'Wiring & Repairs', 1), ('Electrical', 'Certificate of Compliance (CoC)', 2),
  ('Electrical', 'Lights & Plugs', 3), ('Electrical', 'Solar & Backup Power', 4),
  ('Cleaning', 'Home Cleaning', 1), ('Cleaning', 'Office Cleaning', 2), ('Cleaning', 'Deep & Move-out Cleaning', 3),
  ('Cleaning', 'Carpets & Upholstery', 4), ('Cleaning', 'Window Cleaning', 5),
  ('Gardening & Landscaping', 'Garden Service', 1), ('Gardening & Landscaping', 'Lawn Mowing', 2),
  ('Gardening & Landscaping', 'Tree Felling & Trimming', 3), ('Gardening & Landscaping', 'Landscaping', 4),
  ('Gardening & Landscaping', 'Irrigation', 5),
  ('Home Repairs & Building', 'Handyman', 1), ('Home Repairs & Building', 'Painting', 2),
  ('Home Repairs & Building', 'Tiling', 3), ('Home Repairs & Building', 'Roofing & Waterproofing', 4),
  ('Home Repairs & Building', 'Carpentry', 5),
  ('Appliance Repair', 'Fridges & Freezers', 1), ('Appliance Repair', 'Washing Machines', 2),
  ('Appliance Repair', 'Stoves & Ovens', 3), ('Appliance Repair', 'Small Appliances', 4),
  ('IT & Tech Help', 'Computer & Laptop Repair', 1), ('IT & Tech Help', 'Phone Repair', 2),
  ('IT & Tech Help', 'Wi-Fi & Networks', 3), ('IT & Tech Help', 'Software & Setup', 4),
  ('Security & CCTV', 'CCTV Installation', 1), ('Security & CCTV', 'Alarm Systems', 2),
  ('Security & CCTV', 'Electric Fencing', 3), ('Security & CCTV', 'Gate Motors & Intercoms', 4),
  ('Moving & Transport', 'House Moves', 1), ('Moving & Transport', 'Bakkie Hire & Deliveries', 2),
  ('Moving & Transport', 'Rubble Removal', 3),
  ('Pest Control', 'Termites', 1), ('Pest Control', 'Rodents', 2), ('Pest Control', 'Fumigation', 3),
  ('Beauty & Hair', 'Hair Styling', 1), ('Beauty & Hair', 'Barber', 2), ('Beauty & Hair', 'Nails', 3),
  ('Beauty & Hair', 'Make-up', 4), ('Beauty & Hair', 'Massage & Spa', 5),
  ('Tutoring & Lessons', 'School Subjects', 1), ('Tutoring & Lessons', 'Matric & Exam Prep', 2),
  ('Tutoring & Lessons', 'Languages', 3), ('Tutoring & Lessons', 'Music Lessons', 4),
  ('Health & Care', 'Home Nursing', 1), ('Health & Care', 'Elderly Care', 2), ('Health & Care', 'Physiotherapy', 3),
  ('Automotive', 'Mechanic', 1), ('Automotive', 'Car Wash & Valet', 2), ('Automotive', 'Tyres', 3),
  ('Automotive', 'Panel Beating', 4),
  ('Events & Photography', 'Photography', 1), ('Events & Photography', 'DJ & Sound', 2),
  ('Events & Photography', 'Catering', 3), ('Events & Photography', 'Decor & Hire', 4)
) as s (parent_name, name, sort_order)
join public.service_categories p on lower(p.name) = lower(s.parent_name) and p.parent_id is null
on conflict (lower(name)) do update
  set parent_id = excluded.parent_id, sort_order = excluded.sort_order, is_active = true;

-- 4. Anything else is switched off (hidden), never deleted ------------------------------------------------
update public.service_categories
set is_active = false
where parent_id is null
  and lower(name) not in (
    'plumbing', 'electrical', 'cleaning', 'gardening & landscaping', 'home repairs & building', 'appliance repair',
    'it & tech help', 'security & cctv', 'moving & transport', 'pest control', 'beauty & hair', 'tutoring & lessons',
    'health & care', 'automotive', 'events & photography', 'other');
