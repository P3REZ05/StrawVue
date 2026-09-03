-- =====================================================================
-- 002_audit_logs_contract.sql
-- Corrige: B-1 (crítico)
--
-- CONTEXTO
-- Existen dos definiciones incompatibles de audit_logs:
--   schema.sql        -> entity_type / entity_id / details      (la escribe orders.js)
--   add_audit_logs.sql-> table_name / record_id / old_data /
--                        new_data / changed_by / changed_at     (la lee audit.js)
--
-- DECISIÓN: se adopta la forma de add_audit_logs.sql. Es más rica y ya
-- tiene triggers automáticos, así que no depende de que alguien se
-- acuerde de loguear.
--
-- Esta migración CONVERGE la tabla existente sin borrar datos: si
-- encuentra la forma vieja, copia los valores a las columnas nuevas
-- antes de retirar las viejas.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- 1) Crear la tabla si no existe.
-- ---------------------------------------------------------------------
create table if not exists public.audit_logs (
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

-- ---------------------------------------------------------------------
-- 2) Converger una tabla con la forma vieja, preservando los datos.
-- ---------------------------------------------------------------------
do $$
declare
  tiene_entity_type boolean;
  tiene_table_name  boolean;
begin
  select exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='audit_logs' and column_name='entity_type')
    into tiene_entity_type;
  select exists (select 1 from information_schema.columns
                 where table_schema='public' and table_name='audit_logs' and column_name='table_name')
    into tiene_table_name;

  -- Asegurar todas las columnas destino.
  alter table public.audit_logs add column if not exists table_name text;
  alter table public.audit_logs add column if not exists record_id  bigint;
  alter table public.audit_logs add column if not exists action     text;
  alter table public.audit_logs add column if not exists changed_by text;
  alter table public.audit_logs add column if not exists changed_at timestamptz default now();
  alter table public.audit_logs add column if not exists old_data   jsonb;
  alter table public.audit_logs add column if not exists new_data   jsonb;
  alter table public.audit_logs add column if not exists note       text;

  if tiene_entity_type then
    raise notice 'audit_logs tenia la forma antigua: migrando datos existentes.';

    update public.audit_logs
       set table_name = coalesce(table_name, entity_type, 'desconocido'),
           record_id  = coalesce(record_id, entity_id);

    -- details -> new_data solo si new_data está vacío.
    if exists (select 1 from information_schema.columns
               where table_schema='public' and table_name='audit_logs' and column_name='details') then
      update public.audit_logs set new_data = details where new_data is null and details is not null;
    end if;

    if exists (select 1 from information_schema.columns
               where table_schema='public' and table_name='audit_logs' and column_name='created_at') then
      update public.audit_logs set changed_at = created_at where changed_at is null;
    end if;

    if exists (select 1 from information_schema.columns
               where table_schema='public' and table_name='audit_logs' and column_name='created_by') then
      update public.audit_logs set changed_by = created_by::text where changed_by is null;
    end if;

    alter table public.audit_logs drop column if exists entity_type;
    alter table public.audit_logs drop column if exists entity_id;
    alter table public.audit_logs drop column if exists details;
    alter table public.audit_logs drop column if exists created_by;
    alter table public.audit_logs drop column if exists created_at;
  elsif tiene_table_name then
    raise notice 'audit_logs ya tenia la forma correcta.';
  end if;

  -- Rellenar huecos antes de imponer NOT NULL.
  update public.audit_logs set table_name = 'desconocido' where table_name is null;
  update public.audit_logs set action     = 'UNKNOWN'     where action is null;
  update public.audit_logs set changed_at = now()         where changed_at is null;

  alter table public.audit_logs alter column table_name set not null;
  alter table public.audit_logs alter column action     set not null;
  alter table public.audit_logs alter column changed_at set not null;
  alter table public.audit_logs alter column changed_at set default now();
end $$;

-- ---------------------------------------------------------------------
-- 3) changed_by se rellena solo: el frontend no tiene que mandarlo.
-- ---------------------------------------------------------------------
alter table public.audit_logs
  alter column changed_by set default coalesce(auth.uid()::text, current_user);

create index if not exists idx_audit_logs_changed_at    on public.audit_logs (changed_at desc);
create index if not exists idx_audit_logs_table_record  on public.audit_logs (table_name, record_id);

-- ---------------------------------------------------------------------
-- 4) RLS unificado con is_admin().
-- ---------------------------------------------------------------------
alter table public.audit_logs enable row level security;

drop policy if exists "admins can read audit logs"   on public.audit_logs;
drop policy if exists "admins can insert audit logs" on public.audit_logs;
drop policy if exists "admins can update audit logs" on public.audit_logs;
drop policy if exists "audit_logs_admin_write"       on public.audit_logs;

drop policy if exists "audit_logs_admin_read" on public.audit_logs;
create policy "audit_logs_admin_read" on public.audit_logs
for select to authenticated using (public.is_admin());

drop policy if exists "audit_logs_admin_insert" on public.audit_logs;
create policy "audit_logs_admin_insert" on public.audit_logs
for insert to authenticated with check (public.is_admin());

-- Deliberadamente NO hay política de UPDATE ni de DELETE:
-- un registro de auditoría que se puede editar no es auditoría.

-- ---------------------------------------------------------------------
-- 5) Trigger automático. SECURITY DEFINER para que también registre las
--    escrituras que hace el RPC de pedidos en nombre de un cliente anónimo.
-- ---------------------------------------------------------------------
create or replace function public.audit_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor text := coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), ''),
    current_user
  );
begin
  if tg_op = 'INSERT' then
    insert into public.audit_logs (table_name, record_id, action, changed_by, old_data, new_data)
    values (tg_table_name, new.id, 'INSERT', actor, null, to_jsonb(new));
    return new;
  elsif tg_op = 'UPDATE' then
    -- No registrar updates que no cambian nada.
    if to_jsonb(old) = to_jsonb(new) then
      return new;
    end if;
    insert into public.audit_logs (table_name, record_id, action, changed_by, old_data, new_data)
    values (tg_table_name, new.id, 'UPDATE', actor, to_jsonb(old), to_jsonb(new));
    return new;
  elsif tg_op = 'DELETE' then
    insert into public.audit_logs (table_name, record_id, action, changed_by, old_data, new_data)
    values (tg_table_name, old.id, 'DELETE', actor, to_jsonb(old), null);
    return old;
  end if;
  return null;
end;
$$;

-- ---------------------------------------------------------------------
-- 6) Aplicar el trigger a las tablas que importan.
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'products', 'product_variants', 'inventory_movements',
    'orders', 'payments', 'shipments', 'suppliers', 'purchase_orders'
  ] loop
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists %I on public.%I', 'trg_audit_' || t, t);
      execute format(
        'create trigger %I after insert or update or delete on public.%I
         for each row execute function public.audit_trigger()',
        'trg_audit_' || t, t
      );
    end if;
  end loop;
end $$;
