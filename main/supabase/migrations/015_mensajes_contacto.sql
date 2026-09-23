-- =====================================================================
-- 015_mensajes_contacto.sql
-- El formulario de contacto pasa a guardar algo.
--
-- ANTES `Contact.vue:9` era literalmente esto:
--
--     function submit() {
--       sent.value = true
--     }
--
-- El cliente rellenaba nombre, correo, teléfono y mensaje, veía
-- "¡Mensaje recibido!" y el mensaje no iba a ninguna parte. No es un fallo
-- técnico visible —nada peta, nada aparece en consola— y por eso llevaba
-- ahí desde el principio.
--
-- AHORA se guarda en `contact_messages` y hay una bandeja en el panel.
-- =====================================================================

create table if not exists public.contact_messages (
  id           bigint generated always as identity primary key,
  name         text not null,
  email        text not null,
  phone        text,
  message      text not null,
  status       text not null default 'new' check (status in ('new', 'read', 'answered', 'archived')),
  admin_note   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.contact_messages is
  'Mensajes del formulario publico de contacto. Los escribe anon; solo un admin los lee.';
comment on column public.contact_messages.status is
  'new -> read -> answered. archived saca el mensaje de la bandeja sin borrarlo.';

create index if not exists ix_contact_messages_bandeja
  on public.contact_messages (status, created_at desc);

drop trigger if exists trg_contact_messages_updated_at on public.contact_messages;
create trigger trg_contact_messages_updated_at
  before update on public.contact_messages
  for each row execute function public.set_updated_at();

alter table public.contact_messages enable row level security;

-- Cualquiera puede escribir: es un formulario público, igual que el pedido.
--
-- Pero NADIE anónimo puede leer. Esta tabla guarda nombre, correo y teléfono
-- de personas reales; una política de lectura pública convertiría el
-- formulario en un directorio de datos personales servido por la API.
-- Por eso hay dos políticas separadas y no un `for all`.
drop policy if exists "contact_messages_public_insert" on public.contact_messages;
create policy "contact_messages_public_insert" on public.contact_messages
  for insert with check (true);

drop policy if exists "contact_messages_admin_read" on public.contact_messages;
create policy "contact_messages_admin_read" on public.contact_messages
  for select using (public.is_admin());

drop policy if exists "contact_messages_admin_update" on public.contact_messages;
create policy "contact_messages_admin_update" on public.contact_messages
  for update using (public.is_admin()) with check (public.is_admin());

-- Sin `delete`: un mensaje se archiva, no se borra. Si alguien pide que se
-- eliminen sus datos, se hace a mano y queda constancia de por qué.
revoke all on public.contact_messages from anon, authenticated;
grant insert on public.contact_messages to anon, authenticated;
grant select, update on public.contact_messages to authenticated;

drop trigger if exists trg_contact_messages_audit on public.contact_messages;
create trigger trg_contact_messages_audit
  after insert or update or delete on public.contact_messages
  for each row execute function public.audit_trigger();
