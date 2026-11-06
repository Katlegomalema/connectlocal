-- Already applied to the remote database on 20260902 (exported from supabase_migrations.schema_migrations).
-- Do not edit: kept so the local migration history matches the remote one.

-- The real fix: revoke from PUBLIC, not just anon/authenticated individually
revoke execute on function public.handle_new_auth_user() from public;
revoke execute on function public.is_admin() from public;

-- handle_new_auth_user needs no explicit grants — triggers invoke it
-- automatically regardless of EXECUTE grants, so revoking from everyone
-- is correct and safe.

-- is_admin() is still genuinely useful for the app to call directly
-- (e.g. Flutter checking "should I show the admin dashboard button?"),
-- so re-grant it deliberately, only to logged-in users.
grant execute on function public.is_admin() to authenticated;
