-- =====================================================================
-- 003_updated_at.sql
-- Corrige: B-2 (crítico)
--
-- CONTEXTO
-- orders.js hacía `update({ ..., updated_at })` sobre payments y shipments.
-- Ninguna de las dos tablas tenía esa columna, así que PostgREST devolvía
-- error 42703 y updateStatus reventaba DESPUÉS de haber mutado el estado
-- local: la UI mostraba "pagado" y la base seguía en "pending".
--
-- Se añade la columna y un trigger que la mantiene, para que el frontend
-- no tenga que enviarla nunca más.
-- =====================================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['orders', 'payments', 'shipments', 'products', 'product_variants'] loop
    if to_regclass('public.' || t) is not null then
      execute format('alter table public.%I add column if not exists updated_at timestamptz default now()', t);
      execute format('update public.%I set updated_at = coalesce(updated_at, created_at, now()) where updated_at is null', t);
      execute format('drop trigger if exists %I on public.%I', 'trg_set_updated_at_' || t, t);
      execute format(
        'create trigger %I before update on public.%I
         for each row execute function public.set_updated_at()',
        'trg_set_updated_at_' || t, t
      );
    end if;
  end loop;
end $$;
