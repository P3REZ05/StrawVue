-- =====================================================================
-- 009_comprobantes_pago.sql
-- Bucket para los comprobantes de pago.
--
-- A DIFERENCIA de product-images, este bucket es PRIVADO.
-- Un comprobante de Nequi o de transferencia lleva el nombre del cliente,
-- su telefono, el numero de cuenta y el monto. Publicarlo con una URL
-- adivinable seria exponer datos financieros de terceros.
--
-- Se accede con URLs firmadas de corta duracion, que genera el frontend
-- solo para un administrador autenticado.
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'payment-proofs',
  'payment-proofs',
  false,                                     -- PRIVADO
  3145728,                                   -- 3 MB: una captura de pantalla
  array['image/webp', 'image/png', 'image/jpeg', 'application/pdf']
)
on conflict (id) do update
set public             = excluded.public,
    file_size_limit    = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Sin politica de SELECT publica: solo administradores, y solo a traves de
-- una URL firmada.
drop policy if exists "payment_proofs_admin_lee" on storage.objects;
create policy "payment_proofs_admin_lee" on storage.objects
for select to authenticated
using (bucket_id = 'payment-proofs' and public.is_admin());

drop policy if exists "payment_proofs_admin_inserta" on storage.objects;
create policy "payment_proofs_admin_inserta" on storage.objects
for insert to authenticated
with check (bucket_id = 'payment-proofs' and public.is_admin());

drop policy if exists "payment_proofs_admin_borra" on storage.objects;
create policy "payment_proofs_admin_borra" on storage.objects
for delete to authenticated
using (bucket_id = 'payment-proofs' and public.is_admin());

-- ---------------------------------------------------------------------
-- Datos del envio que la interfaz todavia no capturaba.
-- Las columnas ya existen en `shipments`; aqui solo se documentan y se
-- añade el indice para buscar por numero de guia, que es como pregunta
-- el cliente por su pedido.
-- ---------------------------------------------------------------------
create index if not exists idx_shipments_tracking
on public.shipments (tracking_number) where tracking_number is not null;

create index if not exists idx_shipments_order on public.shipments (order_id);
create index if not exists idx_payments_order  on public.payments (order_id);

comment on column public.shipments.carrier is 'Transportadora: Servientrega, Interrapidisimo, Coordinadora...';
comment on column public.shipments.tracking_number is 'Numero de guia que se le da al cliente';
comment on column public.shipments.delivered_at is 'Se llena al marcar el pedido como entregado';
comment on column public.payments.proof_url is 'Ruta en el bucket privado payment-proofs, no una URL publica';
