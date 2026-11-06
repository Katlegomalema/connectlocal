-- =====================================================================================================
-- Phase 4: provider applications, documents in Supabase Storage, categories.
--
--   1. Storage buckets
--        provider-documents  PRIVATE  (registration certificate, ID document) - admin views via signed URLs
--        provider-photos     PUBLIC   (business logo, portfolio, service photos)
--      No storage policies for anon/authenticated: clients cannot list, read (private) or write objects
--      directly. They upload with a one-time signed upload URL that the backend issues for a path inside
--      their own folder ("<user id>/..."); bucket limits (size, file type) are enforced by Storage.
--   2. providers: application review fields + registration number format (YYYY/NNNNNN/TT, unique)
--   3. provider_documents: store the Storage path (not a public URL) and limit the document types
--   4. service_categories: add the app's missing categories; names unique (case-insensitive)
--
-- The applicant's SA ID number is NOT stored (decision 5 Nov 2026): only the ID document, privately.
-- =====================================================================================================

-- 1. Storage buckets ---------------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('provider-documents', 'provider-documents', false, 10485760,                 -- 10 MB
   array['application/pdf', 'image/jpeg', 'image/png', 'image/webp']),
  ('provider-photos', 'provider-photos', true, 5242880,                         -- 5 MB
   array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 2. Provider application review -------------------------------------------------------------------------
alter table public.providers
  add column submitted_at     timestamptz,   -- when the application (with documents) was sent for review
  add column reviewed_at      timestamptz,
  add column reviewed_by      uuid references public.users (id) on delete set null,
  add column rejection_reason text check (rejection_reason is null or length(rejection_reason) between 3 and 1000);

-- CIPC company registration number, e.g. 2019/123456/07 (CLAUDE.md: format YYYY/NNNNNN/TT).
alter table public.providers
  add constraint providers_registration_number_format
    check (business_registration_number is null or business_registration_number ~ '^[0-9]{4}/[0-9]{6}/[0-9]{2}$'),
  add constraint providers_rejected_has_reason
    check (verification_status <> 'rejected' or rejection_reason is not null) not valid;

create unique index uq_providers_registration_number
  on public.providers (business_registration_number)
  where business_registration_number is not null;

create index idx_providers_reviewed_by on public.providers (reviewed_by) where reviewed_by is not null;
create index idx_providers_pending_review on public.providers (submitted_at)
  where verification_status = 'pending' and submitted_at is not null;

-- 3. Provider documents live in the private bucket ---------------------------------------------------------
alter table public.provider_documents
  add column storage_path text,
  alter column document_url drop not null;

alter table public.provider_documents
  add constraint provider_documents_has_location
    check (storage_path is not null or document_url is not null),
  add constraint provider_documents_path_shape
    check (storage_path is null or storage_path ~ '^[0-9a-f-]{36}/documents/[A-Za-z0-9._-]{1,200}$'),
  add constraint provider_documents_type
    check (document_type in ('registration_certificate', 'id_document', 'proof_of_address', 'other'));

-- One current document of each type per provider (a re-upload replaces the old row).
create unique index uq_provider_documents_type
  on public.provider_documents (provider_id, document_type)
  where document_type <> 'other';

-- 4. Categories ---------------------------------------------------------------------------------------------
create unique index uq_service_categories_name on public.service_categories (lower(name));

insert into public.service_categories (name, description, icon)
values
  ('Home Repair', 'Handyman, electrical, painting and general repairs', '🛠️'),
  ('Cleaning',    'Home, office and deep cleaning',                    '🧹'),
  ('Gardening',   'Garden care, lawns and landscaping',                '🌿'),
  ('Security',    'CCTV, alarms, gates and access control',            '🔒')
on conflict (lower(name)) do nothing;
