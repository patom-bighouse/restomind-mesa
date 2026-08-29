-- ============================================================================
-- Amplía la carta multiidioma (sql/multiidioma_carta.sql) a lo demás
-- que un comensal ve en Mesa.jsx y no es texto fijo de la app: nombres
-- de categoría, nombres de modificadores/opciones ("Punto de
-- cocción" → "Poco hecho"...) y mensajes de upsell. Mismo mecanismo:
-- se traduce una vez desde el mismo botón "Traducir con IA" y se
-- guarda; Mesa.jsx sustituye si hay traducción para el idioma elegido.
-- ============================================================================

create table categoria_traducciones (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references categories(id) on delete cascade,
  idioma text not null,
  nombre text not null,
  nombre_origen text not null,
  generado_en timestamp with time zone not null default now(),
  unique (category_id, idioma)
);

alter table categoria_traducciones enable row level security;
grant select, insert, update, delete on table categoria_traducciones to authenticated;
grant select on table categoria_traducciones to anon;

drop policy if exists categoria_traducciones_dueno on categoria_traducciones;
create policy categoria_traducciones_dueno on categoria_traducciones for all
  using (
    exists (
      select 1 from categories c
      join restaurants r on r.id = c.restaurant_id
      where c.id = categoria_traducciones.category_id
        and (r.user_id = auth.uid() or exists (select 1 from superadmins s where s.user_id = auth.uid()))
    )
  );

drop policy if exists categoria_traducciones_select_publico on categoria_traducciones;
create policy categoria_traducciones_select_publico on categoria_traducciones for select using (true);


create table modificador_grupo_traducciones (
  id uuid primary key default gen_random_uuid(),
  grupo_id uuid not null references modificador_grupos(id) on delete cascade,
  idioma text not null,
  nombre text not null,
  nombre_origen text not null,
  generado_en timestamp with time zone not null default now(),
  unique (grupo_id, idioma)
);

alter table modificador_grupo_traducciones enable row level security;
grant select, insert, update, delete on table modificador_grupo_traducciones to authenticated;
grant select on table modificador_grupo_traducciones to anon;

drop policy if exists modificador_grupo_traducciones_dueno on modificador_grupo_traducciones;
create policy modificador_grupo_traducciones_dueno on modificador_grupo_traducciones for all
  using (
    exists (
      select 1 from modificador_grupos g
      join restaurants r on r.id = g.restaurant_id
      where g.id = modificador_grupo_traducciones.grupo_id
        and (r.user_id = auth.uid() or exists (select 1 from superadmins s where s.user_id = auth.uid()))
    )
  );

drop policy if exists modificador_grupo_traducciones_select_publico on modificador_grupo_traducciones;
create policy modificador_grupo_traducciones_select_publico on modificador_grupo_traducciones for select using (true);


create table modificador_opcion_traducciones (
  id uuid primary key default gen_random_uuid(),
  opcion_id uuid not null references modificador_opciones(id) on delete cascade,
  idioma text not null,
  nombre text not null,
  nombre_origen text not null,
  generado_en timestamp with time zone not null default now(),
  unique (opcion_id, idioma)
);

alter table modificador_opcion_traducciones enable row level security;
grant select, insert, update, delete on table modificador_opcion_traducciones to authenticated;
grant select on table modificador_opcion_traducciones to anon;

drop policy if exists modificador_opcion_traducciones_dueno on modificador_opcion_traducciones;
create policy modificador_opcion_traducciones_dueno on modificador_opcion_traducciones for all
  using (
    exists (
      select 1 from modificador_opciones o
      join modificador_grupos g on g.id = o.grupo_id
      join restaurants r on r.id = g.restaurant_id
      where o.id = modificador_opcion_traducciones.opcion_id
        and (r.user_id = auth.uid() or exists (select 1 from superadmins s where s.user_id = auth.uid()))
    )
  );

drop policy if exists modificador_opcion_traducciones_select_publico on modificador_opcion_traducciones;
create policy modificador_opcion_traducciones_select_publico on modificador_opcion_traducciones for select using (true);


create table upsell_traducciones (
  id uuid primary key default gen_random_uuid(),
  upsell_rule_id uuid not null references upsell_rules(id) on delete cascade,
  idioma text not null,
  mensaje text not null,
  mensaje_origen text not null,
  generado_en timestamp with time zone not null default now(),
  unique (upsell_rule_id, idioma)
);

alter table upsell_traducciones enable row level security;
grant select, insert, update, delete on table upsell_traducciones to authenticated;
grant select on table upsell_traducciones to anon;

drop policy if exists upsell_traducciones_dueno on upsell_traducciones;
create policy upsell_traducciones_dueno on upsell_traducciones for all
  using (
    exists (
      select 1 from upsell_rules u
      join restaurants r on r.id = u.restaurant_id
      where u.id = upsell_traducciones.upsell_rule_id
        and (r.user_id = auth.uid() or exists (select 1 from superadmins s where s.user_id = auth.uid()))
    )
  );

drop policy if exists upsell_traducciones_select_publico on upsell_traducciones;
create policy upsell_traducciones_select_publico on upsell_traducciones for select using (true);
