-- GOVI: perfiles públicos vinculados a auth.users
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Miembro de GOVI',
  username text unique,
  bio text not null default '',
  avatar_url text,
  cover_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
drop policy if exists "Profiles are visible to everyone" on public.profiles;
create policy "Profiles are visible to everyone" on public.profiles for select using (true);
drop policy if exists "Users can create their own profile" on public.profiles;
create policy "Users can create their own profile" on public.profiles for insert to authenticated with check (auth.uid() = id);
drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

create or replace function public.govi_sync_profile()
returns trigger language plpgsql security definer set search_path = public
as $$
declare
  meta jsonb;
  base_name text;
  base_username text;
begin
  meta := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  base_name := coalesce(nullif(meta->>'display_name',''), split_part(new.email,'@',1), 'Miembro de GOVI');
  base_username := nullif(meta->>'username','');
  insert into public.profiles (id, display_name, username, bio, avatar_url, cover_url)
  values (new.id, base_name, base_username, coalesce(meta->>'bio',''), meta->>'avatar_url', meta->>'cover_url')
  on conflict (id) do update set
    display_name = excluded.display_name,
    username = coalesce(excluded.username, public.profiles.username),
    bio = excluded.bio,
    avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
    cover_url = coalesce(excluded.cover_url, public.profiles.cover_url),
    updated_at = now();
  return new;
end;
$$;
drop trigger if exists govi_auth_user_profile on auth.users;
create trigger govi_auth_user_profile
after insert or update of raw_user_meta_data on auth.users
for each row execute procedure public.govi_sync_profile();

insert into public.profiles (id, display_name, username, bio, avatar_url, cover_url)
select id,
       coalesce(nullif(raw_user_meta_data->>'display_name',''), split_part(email,'@',1), 'Miembro de GOVI'),
       nullif(raw_user_meta_data->>'username',''),
       coalesce(raw_user_meta_data->>'bio',''),
       raw_user_meta_data->>'avatar_url',
       raw_user_meta_data->>'cover_url'
from auth.users
on conflict (id) do nothing;
