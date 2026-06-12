-- Finance app schema: expenses, budgets, credit cards, overspending alerts.
-- Run this in the Supabase SQL editor (or `supabase db push`).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.categories (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  name       text not null,
  color      text not null default '#2563eb',
  created_at timestamptz not null default now(),
  unique (user_id, name)
);

create table public.credit_cards (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  name          text not null,
  last4         text not null default '' check (char_length(last4) <= 4),
  credit_limit  numeric(12, 2) check (credit_limit is null or credit_limit > 0),
  -- Day of month the statement is generated (clamped to month length client-side).
  statement_day int  not null check (statement_day between 1 and 31),
  -- Payment due this many days after the statement date.
  grace_days    int  not null default 18 check (grace_days between 1 and 60),
  created_at    timestamptz not null default now()
);

create table public.expenses (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  category_id    uuid references public.categories (id) on delete set null,
  card_id        uuid references public.credit_cards (id) on delete set null,
  amount         numeric(12, 2) not null check (amount > 0),
  note           text not null default '',
  payment_method text not null default 'upi'
                 check (payment_method in ('cash', 'upi', 'card', 'netbanking', 'other')),
  spent_at       date not null default current_date,
  created_at     timestamptz not null default now()
);

create index expenses_user_date_idx on public.expenses (user_id, spent_at desc);
create index expenses_card_idx on public.expenses (card_id) where card_id is not null;

-- A budget row with category_id = null is the overall monthly budget.
create table public.budgets (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  category_id uuid references public.categories (id) on delete cascade,
  month       date not null check (extract(day from month) = 1),
  amount      numeric(12, 2) not null check (amount > 0),
  created_at  timestamptz not null default now()
);

create unique index budgets_unique_idx on public.budgets
  (user_id, coalesce(category_id, '00000000-0000-0000-0000-000000000000'::uuid), month);

create table public.alerts (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  category_id uuid references public.categories (id) on delete cascade,
  month       date not null,
  type        text not null check (type in ('warning', 'exceeded')),
  message     text not null,
  is_read     boolean not null default false,
  created_at  timestamptz not null default now()
);

-- One warning + one exceeded alert per budget per month.
create unique index alerts_unique_idx on public.alerts
  (user_id, coalesce(category_id, '00000000-0000-0000-0000-000000000000'::uuid), month, type);

-- ---------------------------------------------------------------------------
-- Row Level Security: every table is scoped to the owning user.
-- ---------------------------------------------------------------------------

alter table public.categories   enable row level security;
alter table public.credit_cards enable row level security;
alter table public.expenses     enable row level security;
alter table public.budgets      enable row level security;
alter table public.alerts       enable row level security;

create policy "own categories"   on public.categories
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own credit_cards" on public.credit_cards
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own expenses"     on public.expenses
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own budgets"      on public.budgets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own alerts"       on public.alerts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- Overspending alerts: after each expense write, compare month-to-date spend
-- against the matching category budget and the overall budget. Crossing 80%
-- raises a 'warning', crossing 100% raises 'exceeded'. The unique index plus
-- ON CONFLICT DO NOTHING makes alerts fire once per budget per month.
-- ---------------------------------------------------------------------------

create or replace function public.check_overspend()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month date := date_trunc('month', new.spent_at)::date;
begin
  -- Category budget
  if new.category_id is not null then
    perform public.raise_overspend_alerts(new.user_id, new.category_id, v_month);
  end if;
  -- Overall budget
  perform public.raise_overspend_alerts(new.user_id, null, v_month);
  return new;
end;
$$;

create or replace function public.raise_overspend_alerts(
  p_user uuid, p_category uuid, p_month date
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_budget numeric;
  v_spent  numeric;
  v_label  text;
begin
  select b.amount into v_budget
  from budgets b
  where b.user_id = p_user
    and b.month = p_month
    and b.category_id is not distinct from p_category;

  if v_budget is null then
    return;
  end if;

  if p_category is null then
    v_spent := (select coalesce(sum(e.amount), 0) from expenses e
                where e.user_id = p_user
                  and e.spent_at >= p_month
                  and e.spent_at < p_month + interval '1 month');
    v_label := 'Overall budget';
  else
    v_spent := (select coalesce(sum(e.amount), 0) from expenses e
                where e.user_id = p_user
                  and e.category_id = p_category
                  and e.spent_at >= p_month
                  and e.spent_at < p_month + interval '1 month');
    select coalesce(c.name, 'Category') || ' budget' into v_label
    from categories c where c.id = p_category;
  end if;

  if v_spent > v_budget then
    insert into alerts (user_id, category_id, month, type, message)
    values (p_user, p_category, p_month, 'exceeded',
            v_label || ' exceeded: spent ' || to_char(v_spent, 'FM999999990.00')
            || ' of ' || to_char(v_budget, 'FM999999990.00'))
    on conflict do nothing;
  elsif v_spent >= v_budget * 0.8 then
    insert into alerts (user_id, category_id, month, type, message)
    values (p_user, p_category, p_month, 'warning',
            v_label || ' at ' || round(v_spent / v_budget * 100) || '%: spent '
            || to_char(v_spent, 'FM999999990.00') || ' of '
            || to_char(v_budget, 'FM999999990.00'))
    on conflict do nothing;
  end if;
end;
$$;

create trigger expenses_overspend_check
  after insert or update of amount, category_id, spent_at on public.expenses
  for each row execute function public.check_overspend();

-- ---------------------------------------------------------------------------
-- Seed default categories for every new user.
-- ---------------------------------------------------------------------------

create or replace function public.seed_default_categories()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into categories (user_id, name, color) values
    (new.id, 'Food & Dining',  '#f59e0b'),
    (new.id, 'Groceries',      '#16a34a'),
    (new.id, 'Transport',      '#2563eb'),
    (new.id, 'Shopping',       '#db2777'),
    (new.id, 'Bills & Utilities', '#7c3aed'),
    (new.id, 'Entertainment',  '#0891b2'),
    (new.id, 'Health',         '#dc2626'),
    (new.id, 'Other',          '#6b7280');
  return new;
end;
$$;

create trigger seed_categories_on_signup
  after insert on auth.users
  for each row execute function public.seed_default_categories();

-- ---------------------------------------------------------------------------
-- Realtime: the app subscribes to these tables for live updates.
-- ---------------------------------------------------------------------------

alter publication supabase_realtime add table
  public.categories,
  public.credit_cards,
  public.expenses,
  public.budgets,
  public.alerts;
