-- ============================================================================
-- Carta multiidioma con traducción IA: se traduce una vez desde el
-- panel (nunca en vivo por cada visita — coste y latencia por cliente)
-- y se guarda en menu_item_traducciones. Mesa.jsx sustituye nombre y
-- descripción cuando el comensal elige un idioma con traducción
-- disponible; sin ninguna guardada, se ve la carta en español, como
-- siempre.
--
-- Es un módulo de pago (la clave de IA la paga la plataforma, no cada
-- restaurante) — se suma al catálogo `modulos` que ya usa
-- SuperAdminRestaurantes.jsx para activar/desactivar por restaurante.
-- ============================================================================

insert into modulos (key, nombre, descripcion, requiere, orden) values
  ('multiidioma', 'Carta multiidioma con IA', 'Traduce la carta automáticamente al idioma del comensal que escanea el QR.', 'nucleo', 5)
on conflict (key) do update set
  nombre = excluded.nombre,
  descripcion = excluded.descripcion,
  requiere = excluded.requiere,
  orden = excluded.orden;

-- Snapshot del texto en español al momento de traducir (nombre_origen/
-- descripcion_origen), para poder avisar en el panel cuándo una
-- traducción quedó desactualizada porque el plato se editó después.
create table menu_item_traducciones (
  id uuid primary key default gen_random_uuid(),
  menu_item_id uuid not null references menu_items(id) on delete cascade,
  idioma text not null,
  nombre text not null,
  descripcion text,
  nombre_origen text not null,
  descripcion_origen text,
  generado_en timestamp with time zone not null default now(),
  unique (menu_item_id, idioma)
);

alter table menu_item_traducciones enable row level security;

grant select, insert, update, delete on table menu_item_traducciones to authenticated;
grant select on table menu_item_traducciones to anon;

drop policy if exists menu_item_traducciones_dueno on menu_item_traducciones;
create policy menu_item_traducciones_dueno on menu_item_traducciones for all
  using (
    exists (
      select 1 from menu_items mi
      join restaurants r on r.id = mi.restaurant_id
      where mi.id = menu_item_traducciones.menu_item_id
        and (r.user_id = auth.uid() or exists (select 1 from superadmins s where s.user_id = auth.uid()))
    )
  );

-- El cliente (anon, en Mesa.jsx) solo necesita leerlas para mostrar la
-- carta en el idioma elegido.
drop policy if exists menu_item_traducciones_select_publico on menu_item_traducciones;
create policy menu_item_traducciones_select_publico on menu_item_traducciones for select using (true);
