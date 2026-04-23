-- MyMoney Ledger / Supabase production schema
-- Run this in the Supabase SQL Editor after creating the project.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  icon text not null default '💳',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  type text not null check (type in ('income', 'expense')),
  icon text not null default '🏷️',
  color_value bigint not null default 1818494975,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('income', 'expense', 'transfer')),
  amount numeric(12,2) not null check (amount > 0),
  category_id uuid references public.categories(id) on delete set null,
  account_id uuid not null references public.accounts(id) on delete cascade,
  transfer_account_id uuid references public.accounts(id) on delete cascade,
  note text not null default '',
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint transfer_target_check check (
    (type <> 'transfer' and transfer_account_id is null)
    or
    (type = 'transfer' and transfer_account_id is not null and transfer_account_id <> account_id)
  )
);

create table if not exists public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  month text not null,
  limit_amount numeric(12,2) not null check (limit_amount > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint budgets_month_format check (month ~ '^[0-9]{4}-[0-9]{2}$'),
  constraint budgets_unique_per_month unique (user_id, category_id, month)
);

create table if not exists public.ledger_snapshots (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists ux_accounts_user_name on public.accounts(user_id, name);
create unique index if not exists ux_categories_user_name_type on public.categories(user_id, name, type);
create index if not exists idx_accounts_user_id on public.accounts(user_id);
create index if not exists idx_categories_user_id on public.categories(user_id);
create index if not exists idx_transactions_user_id_occurred_at on public.transactions(user_id, occurred_at desc);
create index if not exists idx_transactions_account_id on public.transactions(account_id);
create index if not exists idx_budgets_user_id_month on public.budgets(user_id, month);
create index if not exists idx_ledger_snapshots_updated_at on public.ledger_snapshots(updated_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.seed_defaults_for_user(target_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.accounts (user_id, name, icon)
  values
    (target_user, 'Wallet', '👛'),
    (target_user, 'Card', '💳'),
    (target_user, 'Bank', '🏦')
  on conflict do nothing;

  insert into public.categories (user_id, name, type, icon, color_value, is_default)
  values
    (target_user, 'Salary', 'income', '💼', 4281656201, true),
    (target_user, 'Freelance', 'income', '🧾', 4279274217, true),
    (target_user, 'Gift', 'income', '🎁', 4280463140, true),
    (target_user, 'Food', 'expense', '🍔', 4294535696, true),
    (target_user, 'Bills', 'expense', '💡', 4293914860, true),
    (target_user, 'Shopping', 'expense', '🛍️', 4287326846, true),
    (target_user, 'Travel', 'expense', '✈️', 4278637774, true),
    (target_user, 'Health', 'expense', '🩺', 4279563486, true)
  on conflict do nothing;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do update set email = excluded.email, updated_at = now();

  perform public.seed_defaults_for_user(new.id);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at before update on public.profiles
for each row execute procedure public.set_updated_at();

drop trigger if exists set_accounts_updated_at on public.accounts;
create trigger set_accounts_updated_at before update on public.accounts
for each row execute procedure public.set_updated_at();

drop trigger if exists set_categories_updated_at on public.categories;
create trigger set_categories_updated_at before update on public.categories
for each row execute procedure public.set_updated_at();

drop trigger if exists set_transactions_updated_at on public.transactions;
create trigger set_transactions_updated_at before update on public.transactions
for each row execute procedure public.set_updated_at();

drop trigger if exists set_budgets_updated_at on public.budgets;
create trigger set_budgets_updated_at before update on public.budgets
for each row execute procedure public.set_updated_at();

drop trigger if exists set_ledger_snapshots_updated_at on public.ledger_snapshots;
create trigger set_ledger_snapshots_updated_at before update on public.ledger_snapshots
for each row execute procedure public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.accounts enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;
alter table public.budgets enable row level security;
alter table public.ledger_snapshots enable row level security;

drop policy if exists "Users manage own profile" on public.profiles;
create policy "Users manage own profile"
on public.profiles
for all
using (auth.uid() is not null and auth.uid() = id)
with check (auth.uid() is not null and auth.uid() = id);

drop policy if exists "Users manage own accounts" on public.accounts;
create policy "Users manage own accounts"
on public.accounts
for all
using (auth.uid() is not null and auth.uid() = user_id)
with check (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "Users manage own categories" on public.categories;
create policy "Users manage own categories"
on public.categories
for all
using (auth.uid() is not null and auth.uid() = user_id)
with check (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "Users manage own transactions" on public.transactions;
create policy "Users manage own transactions"
on public.transactions
for all
using (auth.uid() is not null and auth.uid() = user_id)
with check (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "Users manage own budgets" on public.budgets;
create policy "Users manage own budgets"
on public.budgets
for all
using (auth.uid() is not null and auth.uid() = user_id)
with check (auth.uid() is not null and auth.uid() = user_id);

drop policy if exists "Users manage own ledger snapshot" on public.ledger_snapshots;
create policy "Users manage own ledger snapshot"
on public.ledger_snapshots
for all
using (auth.uid() is not null and auth.uid() = user_id)
with check (auth.uid() is not null and auth.uid() = user_id);

do $$
begin
  begin
    alter publication supabase_realtime add table public.accounts;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.categories;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.transactions;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.budgets;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.ledger_snapshots;
  exception when duplicate_object then null;
  end;
end $$;
