-- =====================================================================
-- 028_politicas_admin_solo_authenticated.sql
-- Las políticas de admin dejan de aplicarse a los visitantes anónimos.
--
-- CONTEXTO
-- La migración 001 escribió todas sus políticas de administración con
-- `for ... to authenticated using (public.is_admin())`, y además revocó de
-- `public` el permiso para ejecutar `is_admin()`. Las dos cosas van juntas a
-- propósito: si la política no lleva `to authenticated`, Postgres se la aplica
-- también al rol `anon`, que entonces evalúa `is_admin()` en cada lectura
-- pública de esa tabla.
--
-- A las migraciones 014 (`home_banners`), 015 (`contact_messages`), 019
-- (`home_offers`) y 020 (`product_badges`, `product_badge_assignments`) se les
-- escapó el `to authenticated`. Las seis políticas se corrigen aquí.
--
-- QUÉ EFECTO TIENE HOY: ninguno visible. Se comprobó contra la base real que
-- `anon` **sí** puede ejecutar `is_admin()` —Supabase concede permisos por
-- defecto sobre las funciones nuevas del esquema público, y eso pesa más que
-- el `revoke` de la 001—, así que la tienda lee esas tablas sin error.
--
-- POR QUÉ SE CORRIGE IGUAL:
--   · cada lectura anónima ejecuta de más una función `security definer` que
--     consulta `admin_profiles`, y eso se paga en cada visita a la portada;
--   · el que funcione depende de un permiso que la propia 001 intentó quitar.
--     Basta con que alguien lo revoque de verdad —o que Supabase cambie ese
--     comportamiento— para que la portada se quede sin ofertas y las tarjetas
--     sin etiquetas, sin un error que lo explique.
--
-- Una política de administración no tiene nada que decirle a un visitante
-- anónimo. Que lo diga el `to authenticated`.
-- =====================================================================

drop policy if exists "home_offers_admin_all" on public.home_offers;
create policy "home_offers_admin_all" on public.home_offers
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "product_badges_admin_all" on public.product_badges;
create policy "product_badges_admin_all" on public.product_badges
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "product_badge_assignments_admin_all" on public.product_badge_assignments;
create policy "product_badge_assignments_admin_all" on public.product_badge_assignments
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- `contact_messages` es el caso que más importa de los seis: la tabla guarda
-- datos personales de quien escribe por el formulario. Sus políticas de
-- lectura y de actualización son correctas —solo pasan si `is_admin()`—, pero
-- que se evalúen para un anónimo es hacerle esa pregunta a alguien que no
-- tiene por qué estar en la conversación.
drop policy if exists "contact_messages_admin_read" on public.contact_messages;
create policy "contact_messages_admin_read" on public.contact_messages
  for select to authenticated using (public.is_admin());

drop policy if exists "contact_messages_admin_update" on public.contact_messages;
create policy "contact_messages_admin_update" on public.contact_messages
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "home_banners_admin_all" on public.home_banners;
create policy "home_banners_admin_all" on public.home_banners
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- Comprobación: ninguna política de admin debe seguir aplicándose a `public`.
-- ---------------------------------------------------------------------
select tablename, policyname, roles::text
from pg_policies
where schemaname = 'public'
  and policyname like '%admin%'
  and roles::text like '%public%'
order by tablename;
