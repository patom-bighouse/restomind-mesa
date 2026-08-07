drop policy if exists "public_read_menu_images" on storage.objects;
create policy "public_read_menu_images" on storage.objects
  for select to public
  using (bucket_id = 'menu-images');

drop policy if exists "owner_upload_menu_images" on storage.objects;
create policy "owner_upload_menu_images" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'menu-images'
    and public.is_restaurant_owner( ((storage.foldername(name))[1])::uuid )
  );

drop policy if exists "owner_update_menu_images" on storage.objects;
create policy "owner_update_menu_images" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'menu-images'
    and public.is_restaurant_owner( ((storage.foldername(name))[1])::uuid )
  );

drop policy if exists "owner_delete_menu_images" on storage.objects;
create policy "owner_delete_menu_images" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'menu-images'
    and public.is_restaurant_owner( ((storage.foldername(name))[1])::uuid )
  );
