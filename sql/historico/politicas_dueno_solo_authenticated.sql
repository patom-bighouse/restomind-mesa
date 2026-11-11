-- ============================================================================
-- Políticas "del dueño" solo para usuarios con sesión (authenticated).
--
-- Desde sql/fix_seguridad_anon_columnas.sql (8 sep 2026) el rol anónimo
-- (mesa del cliente, Camarero con PIN, web pública) solo puede leer algunas
-- columnas de restaurants, y no user_id. Pero las políticas *_dueno de
-- estas tablas estaban declaradas para todos los roles y consultan
-- restaurants.user_id. Cuando la política pública de la tabla tiene una
-- condición (menus: activo = true; upsell_rules: activa = true...),
-- Postgres evalúa también la del dueño para el anónimo, da "permission
-- denied for table restaurants" y TODA la lectura falla. (Si la pública es
-- "using (true)", Postgres no llega a evaluarla y funcionaba.)
--
-- Efecto: la mesa y Camarero no podían leer los menús (precios por
-- horario) ni las reglas de upsell. Detectado el 8 nov 2026 con un menú
-- que no se aplicaba en la mesa desde el móvil (desde un navegador con la
-- sesión del panel iniciada sí funcionaba). Se cambian todas las *_dueno
-- afectadas para que no vuelva a pasar en ninguna.
--
-- Arreglo: esas políticas pasan a "to authenticated". Para el anónimo nunca
-- daban acceso (comparan con auth.uid(), que para él es null), así que no
-- se pierde nada: el anónimo queda con sus políticas públicas (*_select_publico)
-- y el dueño/superadmin con las suyas, igual que antes.
--
-- Regla para tablas nuevas: las políticas que usen auth.uid() o consulten
-- restaurants, siempre "to authenticated".
--
-- Re-ejecutable (solo cambia las que existan). Ejecutar en staging y
-- después en producción.
-- ============================================================================

do $$
declare
  p record;
  v_cambiadas int := 0;
begin
  for p in
    select pp.schemaname, pp.tablename, pp.policyname
    from pg_policies pp
    where pp.schemaname = 'public'
      and pp.policyname in (
        'categoria_traducciones_dueno',
        'clientes_sellos_dueno',
        'limpieza_pasos_dueno',
        'menu_item_modificador_grupos_dueno',
        'menu_item_modificador_precios_dueno',
        'menu_item_precios_menu_dueno',
        'menu_item_traducciones_dueno',
        'menus_dueno',
        'modificador_grupo_traducciones_dueno',
        'modificador_grupos_dueno',
        'modificador_opcion_traducciones_dueno',
        'modificador_opciones_dueno',
        'promos_sellos_dueno',
        'restaurant_info_dueno',
        'upsell_rules_dueno',
        'upsell_traducciones_dueno'
      )
      and 'public' = any(pp.roles)
      -- Solo políticas de dueño/superadmin (comparan con auth.uid()).
      and coalesce(pp.qual, '') like '%auth.uid()%'
  loop
    execute format('alter policy %I on %I.%I to authenticated', p.policyname, p.schemaname, p.tablename);
    v_cambiadas := v_cambiadas + 1;
    raise notice 'Solo authenticated: %.%', p.tablename, p.policyname;
  end loop;
  raise notice 'Políticas cambiadas: %', v_cambiadas;
end;
$$;

notify pgrst, 'reload schema';
