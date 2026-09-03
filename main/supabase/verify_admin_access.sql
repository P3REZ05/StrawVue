-- Verificacion y alta controlada del perfil administrador.
-- Ejecutar en Supabase SQL Editor con el UUID del usuario creado en
-- Authentication > Users. No usar la tabla legacy public.admins.

-- 1) Verifica los usuarios Auth existentes:
select id, email, created_at
from auth.users
order by created_at;

-- 2) Verifica si el usuario ya tiene perfil:
select id, full_name, email, role
from public.admin_profiles
where id = 'REEMPLAZA-CON-EL-UUID-DE-AUTH-USERS'::uuid;

-- 3) Si no existe, crea SOLO ese perfil:
insert into public.admin_profiles (id, full_name, email, role)
select id, coalesce(raw_user_meta_data->>'full_name', email), email, 'super_admin'
from auth.users
where id = 'REEMPLAZA-CON-EL-UUID-DE-AUTH-USERS'::uuid
on conflict (id) do update
set role = 'super_admin',
    email = excluded.email;

-- 4) Confirma el resultado:
select id, full_name, email, role
from public.admin_profiles
where id = 'REEMPLAZA-CON-EL-UUID-DE-AUTH-USERS'::uuid;