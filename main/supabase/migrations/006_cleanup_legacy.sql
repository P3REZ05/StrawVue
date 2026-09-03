-- =====================================================================
-- 006_cleanup_legacy.sql
-- Corrige: S-3
--
-- OJO: esta migración BORRA la tabla legacy public.admins.
-- Ejecutar solo después de confirmar en 000_diagnostico.sql que
-- admin_profiles ya tiene tu usuario y que puedes entrar al panel.
--
-- public.admins guarda password_hash y no la usa ningún código del
-- proyecto: la autenticación va por Supabase Auth + admin_profiles.
-- Es superficie de ataque muerta.
-- =====================================================================

-- 1) Normalizar roles: add_audit_logs.sql recreó admin_profiles con
--    default 'admin', mientras el resto del proyecto usa 'super_admin'.
update public.admin_profiles set role = 'super_admin' where role = 'admin';

alter table public.admin_profiles
  drop constraint if exists admin_profiles_role_check;

alter table public.admin_profiles
  add constraint admin_profiles_role_check
  check (role in ('super_admin', 'inventory_admin', 'sales_admin', 'orders_admin'));

alter table public.admin_profiles alter column role set default 'super_admin';

-- 2) Retirar la tabla legacy.
drop table if exists public.admins cascade;
