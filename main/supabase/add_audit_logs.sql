-- Add audit_logs table and trigger function
-- This version is safe for a clean new project.
-- If you already have an old audit_logs table in the DB, it is dropped and recreated.

create extension if not exists pgcrypto;

drop table if exists public.audit_logs cascade;
drop table if exists public.admin_profiles cascade;

create table public.admin_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  role text not null default 'admin',
  created_at timestamptz not null default now()
);

alter table public.admin_profiles enable row level security;

create policy "admin profiles readable by same admin"
on public.admin_profiles for select
to authenticated
using (id = auth.uid());

create policy "admins can update own profile"
on public.admin_profiles for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "admins can insert own profile"
on public.admin_profiles for insert
to authenticated
with check (id = auth.uid());

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  table_name text not null,
  record_id bigint,
  action text not null,
  changed_by text,
  changed_at timestamptz not null default now(),
  old_data jsonb,
  new_data jsonb,
  note text
);

alter table public.audit_logs enable row level security;

create policy "admins can read audit logs"
on public.audit_logs for select
to authenticated
using (
  exists (
    select 1
    from public.admin_profiles ap
    where ap.id = auth.uid()
      and ap.role in ('super_admin', 'admin', 'inventory_manager')
  )
);

create policy "admins can insert audit logs"
on public.audit_logs for insert
to authenticated
with check (
  exists (
    select 1
    from public.admin_profiles ap
    where ap.id = auth.uid()
      and ap.role in ('super_admin', 'admin', 'inventory_manager')
  )
);

create policy "admins can update audit logs"
on public.audit_logs for update
to authenticated
using (
  exists (
    select 1
    from public.admin_profiles ap
    where ap.id = auth.uid()
      and ap.role in ('super_admin', 'admin')
  )
)
with check (
  exists (
    select 1
    from public.admin_profiles ap
    where ap.id = auth.uid()
      and ap.role in ('super_admin', 'admin')
  )
);

create index if not exists idx_audit_logs_changed_at on public.audit_logs (changed_at);
create index if not exists idx_audit_logs_table_record on public.audit_logs (table_name, record_id);

create or replace function public.audit_trigger()
returns trigger
language plpgsql
security definer
as $$
begin
  if (TG_OP = 'INSERT') then
    insert into public.audit_logs(table_name, record_id, action, changed_by, old_data, new_data)
    values (
      TG_TABLE_NAME,
      NEW.id,
      'INSERT',
      coalesce(current_setting('jwt.claims.sub', true), current_setting('request.jwt.claims.sub', true), current_user),
      null,
      row_to_json(NEW)::jsonb
    );
    return NEW;
  elsif (TG_OP = 'UPDATE') then
    insert into public.audit_logs(table_name, record_id, action, changed_by, old_data, new_data)
    values (
      TG_TABLE_NAME,
      NEW.id,
      'UPDATE',
      coalesce(current_setting('jwt.claims.sub', true), current_setting('request.jwt.claims.sub', true), current_user),
      row_to_json(OLD)::jsonb,
      row_to_json(NEW)::jsonb
    );
    return NEW;
  elsif (TG_OP = 'DELETE') then
    insert into public.audit_logs(table_name, record_id, action, changed_by, old_data, new_data)
    values (
      TG_TABLE_NAME,
      OLD.id,
      'DELETE',
      coalesce(current_setting('jwt.claims.sub', true), current_setting('request.jwt.claims.sub', true), current_user),
      row_to_json(OLD)::jsonb,
      null
    );
    return OLD;
  end if;
  return null;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'trg_audit_product_variants'
  ) then
    create trigger trg_audit_product_variants
    after insert or update or delete
    on public.product_variants
    for each row execute function public.audit_trigger();
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'trg_audit_products'
  ) then
    create trigger trg_audit_products
    after insert or update or delete
    on public.products
    for each row execute function public.audit_trigger();
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_trigger where tgname = 'trg_audit_inventory_movements'
  ) then
    create trigger trg_audit_inventory_movements
    after insert or update or delete
    on public.inventory_movements
    for each row execute function public.audit_trigger();
  end if;
end $$;

-- End of audit addition
