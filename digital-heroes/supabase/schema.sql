-- DIGITAL HEROES: Supabase schema + RLS
create extension if not exists pgcrypto;
create type public.user_role as enum ('member','admin');
create type public.subscription_state as enum ('inactive','active','past_due','cancelled');
create table public.charities(id uuid primary key default gen_random_uuid(),name text not null,description text default '',image_url text,active boolean default true,created_at timestamptz default now());
create table public.profiles(id uuid primary key references auth.users(id) on delete cascade,full_name text,role public.user_role default 'member',subscription_status public.subscription_state default 'inactive',renewal_date date,charity_id uuid references public.charities(id),charity_percent numeric(5,2) default 10 check(charity_percent between 10 and 100),created_at timestamptz default now(),updated_at timestamptz default now());
create table public.scores(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,played_at date not null,stableford integer not null check(stableford between 1 and 45),created_at timestamptz default now(),unique(user_id,played_at));
create table public.draws(id uuid primary key default gen_random_uuid(),draw_month date not null unique,draw_type text not null default 'random' check(draw_type in ('random','algorithmic')),status text not null default 'draft' check(status in ('draft','simulated','published')),subscriber_count integer default 0,prize_pool numeric(12,2) default 0,jackpot_rollover numeric(12,2) default 0,created_at timestamptz default now(),published_at timestamptz);
create table public.draw_entries(id uuid primary key default gen_random_uuid(),draw_id uuid references public.draws(id) on delete cascade,user_id uuid references public.profiles(id) on delete cascade,numbers jsonb not null,created_at timestamptz default now(),unique(draw_id,user_id));
create table public.winners(id uuid primary key default gen_random_uuid(),draw_id uuid references public.draws(id) on delete cascade,user_id uuid references public.profiles(id),tier integer not null check(tier in (3,4,5)),proof_url text,status text default 'pending' check(status in ('pending','approved','rejected')),payout_status text default 'pending' check(payout_status in ('pending','paid')),payout_amount numeric(12,2) default 0,created_at timestamptz default now());
create table public.subscriptions(id uuid primary key default gen_random_uuid(),user_id uuid references public.profiles(id) on delete cascade,stripe_customer_id text,stripe_subscription_id text,plan text check(plan in ('monthly','yearly')),status text,amount numeric(12,2),charity_amount numeric(12,2),current_period_end timestamptz,created_at timestamptz default now());

-- Auto-create profile after signup.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','Member')); return new; end; $$;
drop trigger if exists on_auth_user_created on auth.users; create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

-- Keep only latest 5 scores per member.
create or replace function public.keep_latest_five_scores() returns trigger language plpgsql security definer set search_path=public as $$
begin delete from public.scores s where s.user_id=new.user_id and s.id not in (select id from public.scores where user_id=new.user_id order by played_at desc,created_at desc limit 5); return new; end; $$;
drop trigger if exists scores_keep_five on public.scores; create trigger scores_keep_five after insert or update on public.scores for each row execute procedure public.keep_latest_five_scores();

-- RLS helpers
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin'); $$;
alter table public.profiles enable row level security; alter table public.scores enable row level security; alter table public.charities enable row level security; alter table public.draws enable row level security; alter table public.draw_entries enable row level security; alter table public.winners enable row level security; alter table public.subscriptions enable row level security;
create policy "public active charities" on public.charities for select using(active=true or public.is_admin());
create policy "own profile" on public.profiles for select using(id=auth.uid() or public.is_admin()); create policy "own profile update" on public.profiles for update using(id=auth.uid() or public.is_admin()); create policy "admin profiles" on public.profiles for all using(public.is_admin()) with check(public.is_admin());
create policy "own scores" on public.scores for select using(user_id=auth.uid() or public.is_admin()); create policy "insert own scores" on public.scores for insert with check(user_id=auth.uid() or public.is_admin()); create policy "update own scores" on public.scores for update using(user_id=auth.uid() or public.is_admin()) with check(user_id=auth.uid() or public.is_admin()); create policy "delete own scores" on public.scores for delete using(user_id=auth.uid() or public.is_admin());
create policy "admin charities" on public.charities for all using(public.is_admin()) with check(public.is_admin());
create policy "draw member read" on public.draws for select using(status='published' or public.is_admin()); create policy "draw admin" on public.draws for all using(public.is_admin()) with check(public.is_admin());
create policy "entry own" on public.draw_entries for select using(user_id=auth.uid() or public.is_admin()); create policy "entry admin" on public.draw_entries for all using(public.is_admin()) with check(public.is_admin());
create policy "winner own" on public.winners for select using(user_id=auth.uid() or public.is_admin()); create policy "winner admin" on public.winners for all using(public.is_admin()) with check(public.is_admin());
create policy "subscription own" on public.subscriptions for select using(user_id=auth.uid() or public.is_admin()); create policy "subscription admin" on public.subscriptions for all using(public.is_admin()) with check(public.is_admin());

-- Prize allocation: 40% 5-match jackpot, 35% 4-match, 25% 3-match.
create or replace function public.prize_split(pool numeric) returns table(tier integer,amount numeric) language sql immutable as $$ select * from (values (5,round(pool*.40,2)),(4,round(pool*.35,2)),(3,round(pool*.25,2))) x(tier,amount); $$;
