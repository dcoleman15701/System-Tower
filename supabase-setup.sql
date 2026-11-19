-- =========================================================
-- System Tower: database setup for player accounts and saves
-- Paste this whole file into Supabase > SQL Editor and click Run.
-- Safe to run again; it won't duplicate anything.
-- =========================================================

-- One row per save slot (1 to 3) per player.
create table if not exists public.saves (
  user_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  slot          smallint not null check (slot between 1 and 3),
  data          jsonb not null,
  char_name_key text,                      -- lowercased character name, for uniqueness
  updated_at    timestamptz not null default now(),
  primary key (user_id, slot)
);

-- Character names are unique across every player (capital letters don't count).
create unique index if not exists saves_char_name_key_unique
  on public.saves (char_name_key) where char_name_key is not null;

-- Let signed-in players reach this table through the Data API.
-- (Needed when "Grant API access to new tables automatically" is off.)
-- Row Level Security below still limits each player to their own rows.
grant select, insert, update, delete on public.saves to authenticated;
revoke all on public.saves from anon;

-- Row Level Security: players can only ever see and change their own saves.
alter table public.saves enable row level security;

drop policy if exists "Players read own saves"   on public.saves;
drop policy if exists "Players add own saves"    on public.saves;
drop policy if exists "Players update own saves" on public.saves;
drop policy if exists "Players delete own saves" on public.saves;

create policy "Players read own saves"   on public.saves for select using (auth.uid() = user_id);
create policy "Players add own saves"    on public.saves for insert with check (auth.uid() = user_id);
create policy "Players update own saves" on public.saves for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Players delete own saves" on public.saves for delete using (auth.uid() = user_id);

-- Lets the game ask "is this character name taken?" without revealing
-- anyone else's saves. Returns only true or false.
create or replace function public.is_name_taken(name_key text, my_slot smallint default null)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.saves
    where char_name_key = lower(name_key)
      and not (user_id = auth.uid() and slot = my_slot)
  );
$$;

revoke all on function public.is_name_taken(text, smallint) from public;
grant execute on function public.is_name_taken(text, smallint) to anon, authenticated;
