-- Already applied to the remote database on 20260807 (exported from supabase_migrations.schema_migrations).
-- Do not edit: kept so the local migration history matches the remote one.

-- Automatically create a public.users row whenever someone signs up via Supabase Auth
create or replace function public.handle_new_auth_user()
returns trigger as $$
begin
  insert into public.users (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', 'New User'),
    new.email,
    coalesce((new.raw_user_meta_data->>'role')::user_role, 'customer')
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();
