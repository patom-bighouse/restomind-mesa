-- ============================================================================
-- CRM: el superadmin puede poner una contraseña nueva a un vendedor desde
-- CRM → Vendedores → Editar, sin depender del correo de recuperación.
--
-- Solo superadmin, y solo sobre usuarios que sean vendedores (no sirve para
-- cambiar la contraseña de dueños ni de otros superadmins).
-- Re-ejecutable. Ejecutar después de crm_vendedores.sql, en staging y en
-- producción.
-- ============================================================================

create or replace function fn_crm_vendedor_cambiar_password(p_vendedor uuid, p_password text)
returns void
language plpgsql
security definer
set search_path to 'public', 'extensions'
as $$
declare
  v_user uuid;
begin
  if not fn_es_superadmin() then
    raise exception 'Solo el superadmin puede cambiar contraseñas de vendedores.';
  end if;

  -- Misma política que exige Supabase Auth en el proyecto.
  if p_password is null or length(p_password) < 8
     or p_password !~ '[a-z]' or p_password !~ '[A-Z]' or p_password !~ '[0-9]' then
    raise exception 'La contraseña debe tener al menos 8 caracteres, con una minúscula, una mayúscula y un número.';
  end if;

  select v.user_id into v_user from vendedores v where v.id = p_vendedor;
  if v_user is null then
    raise exception 'Este vendedor no tiene usuario de acceso.';
  end if;
  if exists (select 1 from superadmins s where s.user_id = v_user) then
    raise exception 'No se puede cambiar así la contraseña de un superadmin.';
  end if;

  update auth.users
  set encrypted_password = crypt(p_password, gen_salt('bf')),
      updated_at = now()
  where id = v_user;
end;
$$;

revoke execute on function fn_crm_vendedor_cambiar_password(uuid, text) from public, anon;
grant execute on function fn_crm_vendedor_cambiar_password(uuid, text) to authenticated;
