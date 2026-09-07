-- =====================================================================
-- 008_storage_imagenes.sql
-- Bucket de imágenes de producto y sus políticas.
--
-- El bucket se crea directamente en storage.buckets, así queda versionado
-- junto al resto del esquema en vez de ser un clic suelto en el dashboard.
--
-- `file_size_limit` es la última defensa: el optimizador del cliente ya
-- reduce las fotos a menos de 300 KB, pero si alguien sube por otra vía,
-- el plan gratuito (1 GB) no se llena con un solo archivo.
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  5242880,                                   -- 5 MB por archivo
  array['image/webp', 'image/png', 'image/jpeg', 'image/avif']
)
on conflict (id) do update
set public             = excluded.public,
    file_size_limit    = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------
-- Lectura pública: es el catálogo, lo tiene que ver cualquiera.
-- Escritura, actualización y borrado: solo administradores.
-- ---------------------------------------------------------------------
drop policy if exists "product_images_lectura_publica" on storage.objects;
create policy "product_images_lectura_publica" on storage.objects
for select using (bucket_id = 'product-images');

drop policy if exists "product_images_admin_inserta" on storage.objects;
create policy "product_images_admin_inserta" on storage.objects
for insert to authenticated
with check (bucket_id = 'product-images' and public.is_admin());

drop policy if exists "product_images_admin_actualiza" on storage.objects;
create policy "product_images_admin_actualiza" on storage.objects
for update to authenticated
using (bucket_id = 'product-images' and public.is_admin())
with check (bucket_id = 'product-images' and public.is_admin());

drop policy if exists "product_images_admin_borra" on storage.objects;
create policy "product_images_admin_borra" on storage.objects
for delete to authenticated
using (bucket_id = 'product-images' and public.is_admin());
