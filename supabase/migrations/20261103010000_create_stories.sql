-- GOVI: historias de 24 horas
create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null default '',
  media_url text,
  media_type text check (media_type in ('image','video') or media_type is null),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  constraint stories_content_or_media check (length(trim(content)) > 0 or media_url is not null)
);

create index if not exists stories_expires_at_idx on public.stories (expires_at);
create index if not exists stories_user_created_idx on public.stories (user_id, created_at desc);

alter table public.stories enable row level security;

drop policy if exists "Stories are visible while active" on public.stories;
create policy "Stories are visible while active"
on public.stories for select
to authenticated
using (expires_at > now());

drop policy if exists "Users can publish own stories" on public.stories;
create policy "Users can publish own stories"
on public.stories for insert
to authenticated
with check (auth.uid() = user_id and expires_at > now());

drop policy if exists "Users can delete own stories" on public.stories;
create policy "Users can delete own stories"
on public.stories for delete
to authenticated
using (auth.uid() = user_id);

grant select, insert, delete on public.stories to authenticated;
