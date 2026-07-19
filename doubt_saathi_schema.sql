-- ============================================
-- DOUBT SAATHI - DATABASE SCHEMA (safe to re-run)
-- ============================================

-- 1. PROFILES TABLE
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  username text not null,
  username_updated_at timestamptz default now(),
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Profiles are viewable by everyone" on public.profiles;
create policy "Profiles are viewable by everyone"
  on public.profiles for select
  using (true);

drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- 2. DOUBTS TABLE
create table if not exists public.doubts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  subject text not null,
  content text not null,
  created_at timestamptz default now()
);

alter table public.doubts enable row level security;

drop policy if exists "Doubts are viewable by everyone" on public.doubts;
create policy "Doubts are viewable by everyone"
  on public.doubts for select
  using (true);

drop policy if exists "Logged in users can post doubts" on public.doubts;
create policy "Logged in users can post doubts"
  on public.doubts for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own doubts" on public.doubts;
create policy "Users can delete their own doubts"
  on public.doubts for delete
  using (auth.uid() = user_id);

-- 3. REPLIES TABLE
create table if not exists public.replies (
  id uuid default gen_random_uuid() primary key,
  doubt_id uuid references public.doubts(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  content text not null,
  created_at timestamptz default now()
);

alter table public.replies enable row level security;

drop policy if exists "Replies are viewable by everyone" on public.replies;
create policy "Replies are viewable by everyone"
  on public.replies for select
  using (true);

drop policy if exists "Logged in users can post replies" on public.replies;
create policy "Logged in users can post replies"
  on public.replies for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own replies" on public.replies;
create policy "Users can delete their own replies"
  on public.replies for delete
  using (auth.uid() = user_id);

-- 4. AUTO-CREATE PROFILE ON SIGNUP
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username)
  values (new.id, 'Student' || substr(new.id::text, 1, 5))
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 5. 30-DAY NAME LOCK TRIGGER
create or replace function public.check_username_lock()
returns trigger as $$
begin
  if old.username <> new.username and
     old.username_updated_at > now() - interval '30 days' then
    raise exception 'Naam sirf 30 din me ek baar change kar sakte ho';
  end if;

  if old.username <> new.username then
    new.username_updated_at = now();
  end if;

  return new;
end;
$$ language plpgsql;

drop trigger if exists enforce_username_lock on public.profiles;
create trigger enforce_username_lock
  before update on public.profiles
  for each row execute procedure public.check_username_lock();
