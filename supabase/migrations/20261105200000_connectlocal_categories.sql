-- =====================================================================================================
-- ConnectLocal service categories (the 10 the app shows, same list as AppState.kCategories in Flutter):
--   Beauty & Health, Healthcare, Plumbing, Cleaning Services, Education & Tutoring, Automotive Services,
--   Electrical Services, Events & Photography, Home Maintenance, Other
--
--   1. Rename older categories that mean the same thing, so services already linked to them keep their
--      category (e.g. 'Cleaning' -> 'Cleaning Services'). Skipped when the new name already exists.
--   2. Add the categories that are still missing; re-activate any of the 10 that were switched off.
--   3. Switch off (is_active = false) every other category. Nothing is deleted: services that still point at
--      an old category keep working, the old category is only hidden from the category list.
--
-- Relies on uq_service_categories_name (lower(name)) from 20261105090000_provider_applications_storage.sql.
-- =====================================================================================================

-- 1. Renames ---------------------------------------------------------------------------------------------
update public.service_categories as category
set name = renamed.new_name
from (values
  ('Home Repair', 'Home Maintenance'),
  ('Cleaning',    'Cleaning Services'),
  ('Beauty',      'Beauty & Health'),
  ('Tutoring',    'Education & Tutoring'),
  ('Electrical',  'Electrical Services'),
  ('Automotive',  'Automotive Services'),
  ('Photography', 'Events & Photography')
) as renamed (old_name, new_name)
where lower(category.name) = lower(renamed.old_name)
  and not exists (
    select 1 from public.service_categories as existing
    where lower(existing.name) = lower(renamed.new_name)
  );

-- 2. The 10 categories -----------------------------------------------------------------------------------
insert into public.service_categories (name, description, icon, is_active)
values
  ('Beauty & Health',      'Hair, barbers, nails, make-up, massage and wellness',      '💇', true),
  ('Healthcare',           'Nursing, home care, physiotherapy and health services',     '🩺', true),
  ('Plumbing',             'Leaks, geysers, drains, pipes and bathroom installs',       '🔧', true),
  ('Cleaning Services',    'Home, office, deep, carpet and window cleaning',            '🧹', true),
  ('Education & Tutoring', 'School subjects, exam prep, languages and music lessons',   '📚', true),
  ('Automotive Services',  'Mechanics, servicing, tyres, panel beating and car wash',   '🚗', true),
  ('Electrical Services',  'Wiring, compliance certificates, lights and appliances',    '💡', true),
  ('Events & Photography', 'Photographers, DJs, decor, catering and event planning',    '📷', true),
  ('Home Maintenance',     'Handyman, painting, tiling, roofing, gardens and repairs',  '🛠️', true),
  ('Other',                'Any other local service',                                   '✨', true)
on conflict (lower(name)) do update
  set is_active   = true,
      description = excluded.description,
      icon        = excluded.icon;

-- 3. Hide every other category ---------------------------------------------------------------------------
update public.service_categories
set is_active = false
where is_active
  and lower(name) not in (
    'beauty & health', 'healthcare', 'plumbing', 'cleaning services', 'education & tutoring',
    'automotive services', 'electrical services', 'events & photography', 'home maintenance', 'other'
  );
