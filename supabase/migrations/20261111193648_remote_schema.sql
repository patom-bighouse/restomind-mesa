SET local check_function_bodies = off;

CREATE SCHEMA "router";

CREATE EXTENSION "pg_net" SCHEMA "public";

CREATE TABLE "public"."camarero_pin_intentos" (
  "camarero_id"     uuid                     NOT NULL,
  "fallidos"        integer                  NOT NULL DEFAULT 0,
  "bloqueado_hasta" timestamp with time zone,
  "ultimo_intento"  timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "camarero_pin_intentos_pkey" PRIMARY KEY (camarero_id)
);

ALTER TABLE "public"."camarero_pin_intentos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."camareros" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id" uuid                     NOT NULL,
  "nombre"        text                     NOT NULL,
  "activo"        boolean                  NOT NULL DEFAULT true,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  "permisos"      text[]                   NOT NULL DEFAULT '{pedidos}'::text[],
  "pin_hash"      text                     NOT NULL,
  CONSTRAINT "camareros_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."camareros"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."camareros" FROM "anon";

CREATE TABLE "public"."categoria_traducciones" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "category_id"   uuid                     NOT NULL,
  "idioma"        text                     NOT NULL,
  "nombre"        text                     NOT NULL,
  "nombre_origen" text                     NOT NULL,
  "generado_en"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "categoria_traducciones_category_id_idioma_key" UNIQUE (category_id, idioma),
  CONSTRAINT "categoria_traducciones_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."categoria_traducciones"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."categories" (
  "id"                 uuid    NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id"      uuid,
  "nombre"             text    NOT NULL,
  "orden"              integer DEFAULT 0,
  "activa"             boolean DEFAULT true,
  "categoria_padre_id" uuid,
  CONSTRAINT "categories_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."categories"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."clientes_movimientos" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "cliente_id"       uuid                     NOT NULL,
  "tipo"             text                     NOT NULL,
  "puntos"           integer                  NOT NULL,
  "motivo"           text,
  "order_id"         uuid,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  "table_session_id" uuid,
  CONSTRAINT "clientes_movimientos_pkey" PRIMARY KEY (id),
  CONSTRAINT "clientes_movimientos_puntos_check" CHECK ((puntos > 0)),
  CONSTRAINT "clientes_movimientos_tipo_check" CHECK ((tipo = ANY (ARRAY['suma'::text, 'resta'::text])))
);

ALTER TABLE "public"."clientes_movimientos"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."clientes_movimientos" FROM "anon";

CREATE TABLE "public"."clientes_sellos" (
  "id"                  uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "cliente_id"          uuid                     NOT NULL,
  "promo_id"            uuid                     NOT NULL,
  "unidades_acumuladas" integer                  NOT NULL DEFAULT 0,
  "premios_disponibles" integer                  NOT NULL DEFAULT 0,
  "fecha_inicio_ciclo"  timestamp with time zone,
  "updated_at"          timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "clientes_sellos_cliente_id_promo_id_key" UNIQUE (cliente_id, promo_id),
  CONSTRAINT "clientes_sellos_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."clientes_sellos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."clientes" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id"   uuid                     NOT NULL,
  "telefono"        text                     NOT NULL,
  "nombre"          text,
  "puntos"          integer                  NOT NULL DEFAULT 0,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"      timestamp with time zone NOT NULL DEFAULT now(),
  "gasto_acumulado" numeric(10,2)            NOT NULL DEFAULT 0,
  "ultima_visita"   timestamp with time zone,
  CONSTRAINT "clientes_pkey" PRIMARY KEY (id),
  CONSTRAINT "clientes_restaurant_id_telefono_key" UNIQUE (restaurant_id, telefono)
);

ALTER TABLE "public"."clientes"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."clientes" FROM "anon";

CREATE TABLE "public"."condiciones_aceptaciones" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id" uuid                     NOT NULL,
  "user_id"       uuid                     NOT NULL,
  "version"       text                     NOT NULL,
  "aceptado_en"   timestamp with time zone NOT NULL DEFAULT now(),
  "ip"            text,
  "user_agent"    text,
  CONSTRAINT "condiciones_aceptaciones_pkey" PRIMARY KEY (id),
  CONSTRAINT "condiciones_aceptaciones_restaurant_id_version_key" UNIQUE (restaurant_id, VERSION)
);

ALTER TABLE "public"."condiciones_aceptaciones"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."condiciones_aceptaciones" FROM "anon";

CREATE TABLE "public"."crm_actividades" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "cuenta_id"     uuid                     NOT NULL,
  "tipo"          text                     NOT NULL,
  "descripcion"   text                     NOT NULL,
  "resultado"     text,
  "fecha"         timestamp with time zone NOT NULL DEFAULT now(),
  "autor_nombre"  text,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "crm_actividades_pkey" PRIMARY KEY (id),
  CONSTRAINT "crm_actividades_tipo_check" CHECK ((tipo = ANY (ARRAY['llamada'::text, 'visita'::text, 'whatsapp'::text, 'email'::text, 'demo'::text, 'nota'::text]))),
  "autor_user_id" uuid                     DEFAULT auth.uid()
);

ALTER TABLE "public"."crm_actividades"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."crm_actividades" FROM "anon";

CREATE TABLE "public"."crm_busquedas" (
  "id"           uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "autor_nombre" text,
  "parametros"   jsonb                    NOT NULL DEFAULT '{}'::jsonb,
  "consultas"    integer                  NOT NULL DEFAULT 0,
  "resultados"   integer                  NOT NULL DEFAULT 0,
  "created_at"   timestamp with time zone NOT NULL DEFAULT now(),
  "locales"      jsonb,
  CONSTRAINT "crm_busquedas_consultas_check" CHECK ((consultas >= 0)),
  CONSTRAINT "crm_busquedas_pkey" PRIMARY KEY (id),
  "user_id"      uuid                     DEFAULT auth.uid()
);

ALTER TABLE "public"."crm_busquedas"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."crm_comisiones" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "cuenta_id"     uuid                     NOT NULL,
  "vendedor_id"   uuid                     NOT NULL,
  "restaurant_id" uuid,
  "periodo"       date                     NOT NULL,
  "numero_cuota"  integer                  NOT NULL,
  "cuota_base"    numeric(10,2)            NOT NULL,
  "porcentaje"    numeric(5,2)             NOT NULL,
  "importe"       numeric(10,2)            NOT NULL,
  "estado"        text                     NOT NULL DEFAULT 'pendiente'::text,
  "pagada_en"     timestamp with time zone,
  "nota"          text,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "crm_comisiones_cuenta_id_periodo_key" UNIQUE (cuenta_id, periodo),
  CONSTRAINT "crm_comisiones_estado_check" CHECK ((estado = ANY (ARRAY['pendiente'::text, 'pagada'::text, 'anulada'::text, 'a_descontar'::text, 'descontada'::text]))),
  CONSTRAINT "crm_comisiones_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."crm_comisiones"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."crm_comisiones" FROM "anon";

CREATE TABLE "public"."crm_config" (
  "id"                       boolean                  NOT NULL DEFAULT true,
  "places_gratis_mes"        integer                  NOT NULL DEFAULT 1000,
  "places_precio_1000"       numeric(8,2)             NOT NULL DEFAULT 35,
  "vendedores_pueden_buscar" boolean                  NOT NULL DEFAULT false,
  "updated_at"               timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "crm_config_id_check" CHECK (id),
  CONSTRAINT "crm_config_pkey" PRIMARY KEY (id),
  CONSTRAINT "crm_config_places_gratis_mes_check" CHECK ((places_gratis_mes >= 0)),
  CONSTRAINT "crm_config_places_precio_1000_check" CHECK ((places_precio_1000 >= (0)::numeric))
);

ALTER TABLE "public"."crm_config"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."crm_cuentas" (
  "id"                   uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "nombre"               text                     NOT NULL,
  "contacto_nombre"      text,
  "contacto_cargo"       text,
  "telefono"             text,
  "email"                text,
  "ciudad"               text,
  "pais"                 text,
  "direccion"            text,
  "tipo_local"           text,
  "num_mesas"            integer,
  "fuente"               text,
  "etapa"                text                     NOT NULL DEFAULT 'prospecto'::text,
  "motivo_perdida"       text,
  "plan_interes"         text,
  "cuota_estimada"       numeric(10,2),
  "proxima_accion"       text,
  "proxima_accion_fecha" date,
  "notas"                text,
  "vendedor_id"          uuid,
  "restaurant_id"        uuid,
  "comision_pct"         numeric(5,2),
  "comision_cuotas"      integer,
  "comision_inicio"      date,
  "ganado_en"            timestamp with time zone,
  "perdido_en"           timestamp with time zone,
  "ultima_actividad_en"  timestamp with time zone,
  "created_at"           timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"           timestamp with time zone NOT NULL DEFAULT now(),
  "maps_url"             text,
  "google_place_id"      text,
  "web"                  text,
  "valoracion"           numeric(2,1),
  "num_resenas"          integer,
  "nivel_precio"         smallint,
  "tamano_estimado"      text,
  CONSTRAINT "crm_cuentas_comision_cuotas_check" CHECK (((comision_cuotas IS NULL) OR (comision_cuotas > 0))),
  CONSTRAINT "crm_cuentas_comision_pct_check" CHECK (((comision_pct IS NULL) OR ((comision_pct >= (0)::numeric) AND (comision_pct <= (100)::numeric)))),
  CONSTRAINT "crm_cuentas_etapa_check"
    CHECK ((etapa = ANY (ARRAY['prospecto'::text, 'contactado'::text, 'demo'::text, 'propuesta'::text, 'negociacion'::text, 'ganado'::text, 'perdido'::text]))),
  CONSTRAINT "crm_cuentas_maps_url_check" CHECK (((maps_url IS NULL) OR (maps_url ~* '^https?://'::text))),
  CONSTRAINT "crm_cuentas_nivel_precio_check" CHECK (((nivel_precio IS NULL) OR ((nivel_precio >= 0) AND (nivel_precio <= 4)))),
  CONSTRAINT "crm_cuentas_num_mesas_check" CHECK (((num_mesas IS NULL) OR (num_mesas >= 0))),
  CONSTRAINT "crm_cuentas_pkey" PRIMARY KEY (id),
  CONSTRAINT "crm_cuentas_restaurant_id_key" UNIQUE (restaurant_id),
  CONSTRAINT "crm_cuentas_tamano_estimado_check"
    CHECK (((tamano_estimado IS NULL) OR (tamano_estimado = ANY (ARRAY['pequeno'::text, 'mediano'::text, 'grande'::text, 'muy_grande'::text])))),
  CONSTRAINT "crm_cuentas_web_check" CHECK (((web IS NULL) OR (web ~* '^https?://'::text))),
  "created_by"           uuid                     DEFAULT auth.uid()
);

ALTER TABLE "public"."crm_cuentas"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."crm_cuentas" FROM "anon";

CREATE TABLE "public"."crm_historial" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "cuenta_id"      uuid                     NOT NULL,
  "campo"          text                     NOT NULL,
  "valor_anterior" text,
  "valor_nuevo"    text,
  "created_at"     timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "crm_historial_campo_check" CHECK ((campo = ANY (ARRAY['etapa'::text, 'vendedor'::text]))),
  CONSTRAINT "crm_historial_pkey" PRIMARY KEY (id),
  "user_id"        uuid                     DEFAULT auth.uid()
);

ALTER TABLE "public"."crm_historial"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."crm_historial" FROM "anon";

CREATE TABLE "public"."crm_tareas" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "cuenta_id"     uuid                     NOT NULL,
  "titulo"        text                     NOT NULL,
  "completada"    boolean                  NOT NULL DEFAULT false,
  "completada_en" timestamp with time zone,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "crm_tareas_pkey" PRIMARY KEY (id),
  "created_by"    uuid                     DEFAULT auth.uid()
);

ALTER TABLE "public"."crm_tareas"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."crm_tareas" FROM "anon";

CREATE TABLE "public"."ingredientes" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id" uuid                     NOT NULL,
  "nombre"        text                     NOT NULL,
  "unidad"        text                     NOT NULL DEFAULT 'unidad'::text,
  "stock_actual"  numeric                  NOT NULL DEFAULT 0,
  "umbral_alerta" numeric,
  "activo"        boolean                  NOT NULL DEFAULT true,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "ingredientes_pkey" PRIMARY KEY (id),
  CONSTRAINT "ingredientes_unidad_check" CHECK ((unidad = ANY (ARRAY['kg'::text, 'g'::text, 'l'::text, 'ml'::text, 'unidad'::text])))
);

ALTER TABLE "public"."ingredientes"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."ingredientes" FROM "anon";

CREATE TABLE "public"."limpieza_pasos" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id" uuid                     NOT NULL,
  "texto"         text                     NOT NULL,
  "orden"         integer                  NOT NULL DEFAULT 0,
  "activo"        boolean                  NOT NULL DEFAULT true,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "limpieza_pasos_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."limpieza_pasos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."menu_item_modificador_grupos" (
  "id"             uuid    NOT NULL DEFAULT gen_random_uuid(),
  "menu_item_id"   uuid    NOT NULL,
  "grupo_id"       uuid    NOT NULL,
  "obligatorio"    boolean NOT NULL DEFAULT false,
  "tipo_seleccion" text    NOT NULL DEFAULT 'unica'::text,
  "orden"          integer NOT NULL DEFAULT 0,
  CONSTRAINT "menu_item_modificador_grupos_menu_item_id_grupo_id_key" UNIQUE (menu_item_id, grupo_id),
  CONSTRAINT "menu_item_modificador_grupos_pkey" PRIMARY KEY (id),
  CONSTRAINT "menu_item_modificador_grupos_tipo_seleccion_check" CHECK ((tipo_seleccion = ANY (ARRAY['unica'::text, 'multiple'::text])))
);

ALTER TABLE "public"."menu_item_modificador_grupos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."menu_item_modificador_precios" (
  "id"           uuid    NOT NULL DEFAULT gen_random_uuid(),
  "menu_item_id" uuid    NOT NULL,
  "opcion_id"    uuid    NOT NULL,
  "precio_extra" numeric NOT NULL DEFAULT 0,
  CONSTRAINT "menu_item_modificador_precios_menu_item_id_opcion_id_key" UNIQUE (menu_item_id, opcion_id),
  CONSTRAINT "menu_item_modificador_precios_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."menu_item_modificador_precios"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."menu_item_precios_menu" (
  "id"           uuid         NOT NULL DEFAULT gen_random_uuid(),
  "menu_id"      uuid         NOT NULL,
  "menu_item_id" uuid         NOT NULL,
  "precio"       numeric(8,2),
  "excluido"     boolean      NOT NULL DEFAULT false,
  CONSTRAINT "menu_item_precios_menu_menu_id_menu_item_id_key" UNIQUE (menu_id, menu_item_id),
  CONSTRAINT "menu_item_precios_menu_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."menu_item_precios_menu"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."menu_item_traducciones" (
  "id"                 uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "menu_item_id"       uuid                     NOT NULL,
  "idioma"             text                     NOT NULL,
  "nombre"             text                     NOT NULL,
  "descripcion"        text,
  "nombre_origen"      text                     NOT NULL,
  "descripcion_origen" text,
  "generado_en"        timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "menu_item_traducciones_menu_item_id_idioma_key" UNIQUE (menu_item_id, idioma),
  CONSTRAINT "menu_item_traducciones_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."menu_item_traducciones"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."menu_items" (
  "id"               uuid         NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id"    uuid,
  "category_id"      uuid,
  "nombre"           text         NOT NULL,
  "descripcion"      text,
  "precio"           numeric(8,2) NOT NULL,
  "foto_url"         text,
  "emoji"            text,
  "disponible"       boolean      DEFAULT true,
  "orden"            integer      DEFAULT 0,
  "precio_costo"     numeric,
  "sector_cocina_id" uuid,
  "alergenos"        jsonb        NOT NULL DEFAULT '[]'::jsonb,
  CONSTRAINT "menu_items_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."menu_items"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."menus" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id"   uuid                     NOT NULL,
  "nombre"          text                     NOT NULL,
  "zona"            text,
  "hora_inicio"     time without time zone,
  "hora_fin"        time without time zone,
  "dias_semana"     smallint[],
  "activo"          boolean                  NOT NULL DEFAULT true,
  "orden"           integer                  NOT NULL DEFAULT 0,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  "aplica_whatsapp" boolean                  NOT NULL DEFAULT false,
  CONSTRAINT "menus_aplica_whatsapp_sin_zona" CHECK (((NOT aplica_whatsapp) OR (zona IS NULL))),
  CONSTRAINT "menus_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."menus"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."modificador_grupo_traducciones" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "grupo_id"      uuid                     NOT NULL,
  "idioma"        text                     NOT NULL,
  "nombre"        text                     NOT NULL,
  "nombre_origen" text                     NOT NULL,
  "generado_en"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "modificador_grupo_traducciones_grupo_id_idioma_key" UNIQUE (grupo_id, idioma),
  CONSTRAINT "modificador_grupo_traducciones_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."modificador_grupo_traducciones"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."modificador_grupos" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id" uuid                     NOT NULL,
  "nombre"        text                     NOT NULL,
  "orden"         integer                  NOT NULL DEFAULT 0,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "modificador_grupos_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."modificador_grupos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."modificador_opcion_traducciones" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "opcion_id"     uuid                     NOT NULL,
  "idioma"        text                     NOT NULL,
  "nombre"        text                     NOT NULL,
  "nombre_origen" text                     NOT NULL,
  "generado_en"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "modificador_opcion_traducciones_opcion_id_idioma_key" UNIQUE (opcion_id, idioma),
  CONSTRAINT "modificador_opcion_traducciones_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."modificador_opcion_traducciones"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."modificador_opciones" (
  "id"       uuid    NOT NULL DEFAULT gen_random_uuid(),
  "grupo_id" uuid    NOT NULL,
  "nombre"   text    NOT NULL,
  "orden"    integer NOT NULL DEFAULT 0,
  CONSTRAINT "modificador_opciones_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."modificador_opciones"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."modulos" (
  "key"         text    NOT NULL,
  "nombre"      text    NOT NULL,
  "descripcion" text,
  "requiere"    text,
  "orden"       integer NOT NULL DEFAULT 0,
  "plan"        text,
  CONSTRAINT "modulos_pkey" PRIMARY KEY (key)
);

ALTER TABLE "public"."modulos"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."modulos" FROM "anon";

CREATE TABLE "public"."niveles_fidelizacion" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id" uuid                     NOT NULL,
  "nombre"        text                     NOT NULL,
  "umbral_gasto"  numeric(10,2)            NOT NULL DEFAULT 0,
  "orden"         integer                  NOT NULL DEFAULT 0,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "niveles_fidelizacion_pkey" PRIMARY KEY (id),
  CONSTRAINT "niveles_fidelizacion_restaurant_id_nombre_key" UNIQUE (restaurant_id, nombre)
);

ALTER TABLE "public"."niveles_fidelizacion"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."niveles_fidelizacion" FROM "anon";

CREATE TABLE "public"."order_deliveries" (
  "id"                    uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "order_id"              uuid                     NOT NULL,
  "restaurant_id"         uuid                     NOT NULL,
  "proveedor"             text                     NOT NULL,
  "estado"                text                     NOT NULL DEFAULT 'cotizando'::text,
  "costo_envio"           numeric,
  "moneda"                text,
  "quien_paga"            text,
  "proveedor_quote_id"    text,
  "proveedor_delivery_id" text,
  "tracking_url"          text,
  "created_at"            timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"            timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "order_deliveries_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."order_deliveries"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."order_deliveries" FROM "anon";

CREATE TABLE "public"."order_item_modificadores" (
  "id"            uuid    NOT NULL DEFAULT gen_random_uuid(),
  "order_item_id" uuid    NOT NULL,
  "grupo_id"      uuid,
  "opcion_id"     uuid,
  "grupo_nombre"  text    NOT NULL,
  "opcion_nombre" text    NOT NULL,
  "precio_extra"  numeric NOT NULL DEFAULT 0,
  CONSTRAINT "order_item_modificadores_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."order_item_modificadores"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."order_item_modificadores" FROM "anon";

CREATE TABLE "public"."order_items" (
  "id"                 uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "order_id"           uuid,
  "menu_item_id"       uuid,
  "nombre_snapshot"    text                     NOT NULL,
  "precio_snapshot"    numeric(8,2)             NOT NULL,
  "cantidad"           integer                  NOT NULL DEFAULT 1,
  "notas"              text,
  "agregado_at"        timestamp with time zone NOT NULL DEFAULT now(),
  "restaurant_id"      uuid                     NOT NULL,
  "costo_snapshot"     numeric,
  "comensal"           integer,
  "premio_canjeado_id" uuid,
  "promo_sello_id"     uuid,
  CONSTRAINT "order_items_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."order_items"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."order_items" FROM "anon";

CREATE TABLE "public"."order_sector_confirmaciones" (
  "id"                    uuid    NOT NULL DEFAULT gen_random_uuid(),
  "order_id"              uuid    NOT NULL,
  "sector_cocina_id"      uuid    NOT NULL,
  "confirmado_preparando" boolean NOT NULL DEFAULT false,
  "confirmado_listo"      boolean NOT NULL DEFAULT false,
  CONSTRAINT "order_sector_confirmaciones_order_id_sector_cocina_id_key" UNIQUE (order_id, sector_cocina_id),
  CONSTRAINT "order_sector_confirmaciones_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."order_sector_confirmaciones"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."order_sector_confirmaciones" FROM "anon";

CREATE TABLE "public"."orders" (
  "id"                uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id"     uuid,
  "table_id"          uuid,
  "tipo"              text                     DEFAULT 'mesa'::text,
  "estado"            text                     DEFAULT 'pendiente'::text,
  "cliente_nombre"    text,
  "cliente_telefono"  text,
  "notas"             text,
  "total"             numeric(8,2)             DEFAULT 0,
  "created_at"        timestamp with time zone DEFAULT now(),
  "updated_at"        timestamp with time zone DEFAULT now(),
  "table_session_id"  uuid,
  "metodo_entrega"    text                     NOT NULL DEFAULT 'retiro_local'::text,
  "direccion_entrega" text,
  "lat_entrega"       numeric,
  "lng_entrega"       numeric,
  "tomado_por"        uuid,
  "preparando_at"     timestamp with time zone,
  "listo_at"          timestamp with time zone,
  "entregado_at"      timestamp with time zone,
  "hora_recogida"     timestamp with time zone,
  CONSTRAINT "orders_estado_check" CHECK ((estado = ANY (ARRAY['pendiente'::text, 'preparando'::text, 'listo'::text, 'entregado'::text, 'cancelado'::text]))),
  CONSTRAINT "orders_metodo_entrega_check" CHECK ((metodo_entrega = ANY (ARRAY['retiro_local'::text, 'domicilio'::text]))),
  CONSTRAINT "orders_pkey" PRIMARY KEY (id),
  CONSTRAINT "orders_tipo_check" CHECK ((tipo = ANY (ARRAY['mesa'::text, 'takeaway'::text])))
);

ALTER TABLE "public"."orders"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."orders" FROM "anon";

CREATE TABLE "public"."planes" (
  "key"         text          NOT NULL,
  "nombre"      text          NOT NULL,
  "descripcion" text,
  "orden"       integer       NOT NULL DEFAULT 0,
  "precio"      numeric(10,2),
  CONSTRAINT "planes_pkey" PRIMARY KEY (key),
  CONSTRAINT "planes_precio_check" CHECK (((precio IS NULL) OR (precio >= (0)::numeric)))
);

ALTER TABLE "public"."planes"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."premios_fidelizacion" (
  "id"                uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id"     uuid                     NOT NULL,
  "nombre"            text                     NOT NULL,
  "descripcion"       text,
  "costo_puntos"      integer                  NOT NULL,
  "nivel_minimo_id"   uuid,
  "activo"            boolean                  NOT NULL DEFAULT true,
  "orden"             integer                  NOT NULL DEFAULT 0,
  "created_at"        timestamp with time zone NOT NULL DEFAULT now(),
  "tipo"              text                     NOT NULL DEFAULT 'plato_gratis'::text,
  "menu_item_id"      uuid,
  "descuento_importe" numeric(10,2),
  CONSTRAINT "premios_fidelizacion_config_check" CHECK ((((tipo = 'plato_gratis'::text) AND (menu_item_id IS
    NOT NULL) AND (descuento_importe IS NULL)) OR ((tipo = 'descuento'::text) AND (descuento_importe IS
    NOT NULL) AND (descuento_importe > (0)::numeric) AND (menu_item_id IS NULL)))),
  CONSTRAINT "premios_fidelizacion_costo_puntos_check" CHECK ((costo_puntos > 0)),
  CONSTRAINT "premios_fidelizacion_pkey" PRIMARY KEY (id),
  CONSTRAINT "premios_fidelizacion_tipo_check" CHECK ((tipo = ANY (ARRAY['plato_gratis'::text, 'descuento'::text])))
);

ALTER TABLE "public"."premios_fidelizacion"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."premios_fidelizacion" FROM "anon";

CREATE TABLE "public"."promos_sellos" (
  "id"                   uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id"        uuid                     NOT NULL,
  "nombre"               text                     NOT NULL,
  "producto_objetivo_id" uuid                     NOT NULL,
  "cantidad_objetivo"    integer                  NOT NULL,
  "producto_premio_id"   uuid                     NOT NULL,
  "cantidad_premio"      integer                  NOT NULL DEFAULT 1,
  "caducidad_dias"       integer,
  "activo"               boolean                  NOT NULL DEFAULT true,
  "orden"                integer                  NOT NULL DEFAULT 0,
  "created_at"           timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "promos_sellos_caducidad_dias_check" CHECK (((caducidad_dias IS NULL) OR (caducidad_dias > 0))),
  CONSTRAINT "promos_sellos_cantidad_objetivo_check" CHECK ((cantidad_objetivo > 0)),
  CONSTRAINT "promos_sellos_cantidad_premio_check" CHECK ((cantidad_premio > 0)),
  CONSTRAINT "promos_sellos_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."promos_sellos"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."receta_items" (
  "id"             uuid    NOT NULL DEFAULT gen_random_uuid(),
  "menu_item_id"   uuid    NOT NULL,
  "ingrediente_id" uuid    NOT NULL,
  "cantidad"       numeric NOT NULL,
  CONSTRAINT "receta_items_cantidad_check" CHECK ((cantidad > (0)::numeric)),
  CONSTRAINT "receta_items_menu_item_id_ingrediente_id_key" UNIQUE (menu_item_id, ingrediente_id),
  CONSTRAINT "receta_items_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."receta_items"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."receta_items" FROM "anon";

CREATE TABLE "public"."resenas" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id"    uuid                     NOT NULL,
  "table_session_id" uuid,
  "puntuacion"       integer                  NOT NULL,
  "comentario"       text,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "resenas_pkey" PRIMARY KEY (id),
  CONSTRAINT "resenas_puntuacion_check" CHECK (((puntuacion >= 1) AND (puntuacion <= 5))),
  CONSTRAINT "resenas_table_session_id_key" UNIQUE (table_session_id)
);

ALTER TABLE "public"."resenas"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."resenas" FROM "anon";

CREATE TABLE "public"."reservations" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id"    uuid,
  "nombre"           text                     NOT NULL,
  "telefono"         text                     NOT NULL,
  "fecha"            date                     NOT NULL,
  "hora"             time without time zone   NOT NULL,
  "personas"         integer                  NOT NULL,
  "estado"           text                     DEFAULT 'confirmada'::text,
  "notas"            text,
  "origen"           text                     DEFAULT 'whatsapp'::text,
  "created_at"       timestamp with time zone DEFAULT now(),
  "zona"             text                     DEFAULT 'sin preferencia'::text,
  "duracion_minutos" integer                  DEFAULT 120,
  CONSTRAINT "reservations_estado_check" CHECK ((estado = ANY (ARRAY['pendiente'::text, 'confirmada'::text, 'cancelada'::text, 'noshow'::text]))),
  CONSTRAINT "reservations_origen_check" CHECK ((origen = ANY (ARRAY['whatsapp'::text, 'web'::text, 'telefono'::text, 'manual'::text]))),
  CONSTRAINT "reservations_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."reservations"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."reservations" FROM "anon";

CREATE TABLE "public"."restaurant_billing" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id"  uuid                     NOT NULL,
  "iban"           text,
  "titular_cuenta" text,
  "created_at"     timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"     timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "restaurant_billing_pkey" PRIMARY KEY (id),
  CONSTRAINT "restaurant_billing_restaurant_id_key" UNIQUE (restaurant_id)
);

ALTER TABLE "public"."restaurant_billing"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."restaurant_billing" FROM "anon";

CREATE TABLE "public"."restaurant_info" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id" uuid                     NOT NULL,
  "titulo"        text                     NOT NULL,
  "contenido"     text                     NOT NULL DEFAULT ''::text,
  "orden"         integer                  NOT NULL DEFAULT 0,
  "activo"        boolean                  NOT NULL DEFAULT true,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  "updated_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "restaurant_info_contenido_check" CHECK ((char_length(contenido) <= 2000)),
  CONSTRAINT "restaurant_info_pkey" PRIMARY KEY (id),
  CONSTRAINT "restaurant_info_titulo_check" CHECK (((char_length(titulo) >= 1) AND (char_length(titulo) <= 80)))
);

ALTER TABLE "public"."restaurant_info"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."restaurant_modulos" (
  "restaurant_id" uuid                     NOT NULL,
  "modulo_key"    text                     NOT NULL,
  "activo"        boolean                  NOT NULL DEFAULT true,
  "activado_en"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "restaurant_modulos_pkey" PRIMARY KEY (restaurant_id, modulo_key)
);

ALTER TABLE "public"."restaurant_modulos"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."restaurant_modulos" FROM "anon";

CREATE TABLE "public"."restaurants" (
  "id"                       uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "nombre"                   text                     NOT NULL,
  "slug"                     text                     NOT NULL,
  "logo_url"                 text,
  "whatsapp"                 text,
  "direccion"                text,
  "config"                   jsonb                    DEFAULT '{}'::jsonb,
  "activo"                   boolean                  DEFAULT true,
  "created_at"               timestamp with time zone DEFAULT now(),
  "user_id"                  uuid,
  "modo_cocina"              text                     NOT NULL DEFAULT 'orden_llegada'::text,
  "minutos_limite_agrupado"  integer                  NOT NULL DEFAULT 20,
  "pais"                     text                     NOT NULL DEFAULT 'ES'::text,
  "moneda"                   text                     NOT NULL DEFAULT 'EUR'::text,
  "email_dueno"              text,
  "subdominio"               text,
  "plan"                     text,
  "trial_termina_en"         date,
  "precio_override"          numeric(10,2),
  "precio_override_hasta"    date,
  "whatsapp_phone_number_id" text,
  "permanencia_hasta"        date,
  "baja_en"                  date,
  "baja_motivo"              text,
  "baja_penalizacion"        numeric(10,2),
  "precio_contrato"          numeric(10,2),
  CONSTRAINT "restaurants_modo_cocina_check" CHECK ((modo_cocina = ANY (ARRAY['orden_llegada'::text, 'agrupado_mesa'::text]))),
  CONSTRAINT "restaurants_moneda_check" CHECK ((moneda = ANY (ARRAY['EUR'::text, 'USD'::text, 'MXN'::text, 'ARS'::text, 'COP'::text, 'CLP'::text, 'PEN'::text]))),
  CONSTRAINT "restaurants_pkey" PRIMARY KEY (id),
  CONSTRAINT "restaurants_slug_key" UNIQUE (slug),
  CONSTRAINT "restaurants_subdominio_formato" CHECK (((subdominio IS NULL) OR (subdominio ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$'::text)))
);

ALTER TABLE "public"."restaurants"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."sectores_cocina" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id" uuid                     NOT NULL,
  "nombre"        text                     NOT NULL,
  "orden"         integer                  NOT NULL DEFAULT 0,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "sectores_cocina_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."sectores_cocina"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."sectores_cocina" FROM "anon";

CREATE TABLE "public"."stock_movimientos" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id"  uuid                     NOT NULL,
  "ingrediente_id" uuid                     NOT NULL,
  "tipo"           text                     NOT NULL,
  "cantidad"       numeric                  NOT NULL,
  "motivo"         text,
  "order_id"       uuid,
  "created_at"     timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "stock_movimientos_pkey" PRIMARY KEY (id),
  CONSTRAINT "stock_movimientos_tipo_check" CHECK ((tipo = ANY (ARRAY['venta'::text, 'merma'::text, 'reposicion'::text, 'ajuste'::text])))
);

ALTER TABLE "public"."stock_movimientos"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."stock_movimientos" FROM "anon";

CREATE TABLE "public"."superadmins" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"    uuid,
  "nombre"     text,
  "created_at" timestamp with time zone DEFAULT now(),
  CONSTRAINT "superadmins_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."superadmins"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."superadmins" FROM "anon";

CREATE TABLE "public"."table_session_payments" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "table_session_id" uuid                     NOT NULL,
  "restaurant_id"    uuid                     NOT NULL,
  "monto"            numeric(10,2)            NOT NULL,
  "metodo_pago"      text                     NOT NULL,
  "estado"           text                     NOT NULL DEFAULT 'registrado'::text,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "table_session_payments_estado_check" CHECK ((estado = ANY (ARRAY['registrado'::text, 'anulado'::text]))),
  CONSTRAINT "table_session_payments_metodo_pago_check" CHECK ((metodo_pago = ANY (ARRAY['tarjeta'::text, 'efectivo'::text, 'bizum'::text, 'vale_regalo'::text, 'otro'::text]))),
  CONSTRAINT "table_session_payments_monto_check" CHECK ((monto > (0)::numeric)),
  CONSTRAINT "table_session_payments_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."table_session_payments"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."table_session_payments" FROM "anon";

CREATE TABLE "public"."table_sessions" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "table_id"         uuid                     NOT NULL,
  "restaurant_id"    uuid                     NOT NULL,
  "estado"           text                     NOT NULL DEFAULT 'abierta'::text,
  "abierta_at"       timestamp with time zone NOT NULL DEFAULT now(),
  "cerrada_at"       timestamp with time zone,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  "total"            numeric(10,2)            DEFAULT 0,
  "estado_pago"      text                     NOT NULL DEFAULT 'pendiente'::text,
  "metodo_pago"      text,
  "pagada_at"        timestamp with time zone,
  "motivo_exencion"  text,
  "comensales"       integer,
  "camarero_id"      uuid,
  "cliente_telefono" text,
  "cliente_nombre"   text,
  CONSTRAINT "table_sessions_estado_check" CHECK ((estado = ANY (ARRAY['abierta'::text, 'cerrada'::text]))),
  CONSTRAINT "table_sessions_estado_pago_check" CHECK ((estado_pago = ANY (ARRAY['pendiente'::text, 'pagado'::text, 'exento'::text]))),
  CONSTRAINT "table_sessions_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."table_sessions"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."table_sessions" FROM "anon";

CREATE TABLE "public"."tables" (
  "id"                uuid    NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id"     uuid,
  "numero"            integer NOT NULL,
  "zona"              text    DEFAULT 'interior'::text,
  "capacidad"         integer DEFAULT 4,
  "qr_token"          text    DEFAULT (gen_random_uuid())::text,
  "activa"            boolean DEFAULT true,
  "pos_x"             numeric,
  "pos_y"             numeric,
  "forma"             text    NOT NULL DEFAULT 'circular'::text,
  "necesita_limpieza" boolean NOT NULL DEFAULT false,
  "limpieza_progreso" jsonb   NOT NULL DEFAULT '[]'::jsonb,
  CONSTRAINT "tables_forma_check" CHECK ((forma = ANY (ARRAY['circular'::text, 'rectangular'::text]))),
  CONSTRAINT "tables_pkey" PRIMARY KEY (id),
  CONSTRAINT "tables_qr_token_key" UNIQUE (qr_token)
);

ALTER TABLE "public"."tables"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."upsell_rules" (
  "id"                    uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id"         uuid                     NOT NULL,
  "trigger_item_id"       uuid                     NOT NULL,
  "sugerida_categoria_id" uuid                     NOT NULL,
  "mensaje"               text,
  "activa"                boolean                  NOT NULL DEFAULT true,
  "created_at"            timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "upsell_rules_pkey" PRIMARY KEY (id),
  CONSTRAINT "upsell_rules_restaurant_id_trigger_item_id_sugerida_categor_key" UNIQUE (restaurant_id, trigger_item_id, sugerida_categoria_id)
);

ALTER TABLE "public"."upsell_rules"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."upsell_traducciones" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "upsell_rule_id" uuid                     NOT NULL,
  "idioma"         text                     NOT NULL,
  "mensaje"        text                     NOT NULL,
  "mensaje_origen" text                     NOT NULL,
  "generado_en"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "upsell_traducciones_pkey" PRIMARY KEY (id),
  CONSTRAINT "upsell_traducciones_upsell_rule_id_idioma_key" UNIQUE (upsell_rule_id, idioma)
);

ALTER TABLE "public"."upsell_traducciones"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."vale_movimientos" (
  "id"               uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "vale_id"          uuid                     NOT NULL,
  "importe"          numeric                  NOT NULL,
  "order_id"         uuid,
  "created_at"       timestamp with time zone NOT NULL DEFAULT now(),
  "table_session_id" uuid,
  CONSTRAINT "vale_movimientos_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."vale_movimientos"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."vale_movimientos" FROM "anon";

CREATE TABLE "public"."vales_regalo" (
  "id"                    uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id"         uuid                     NOT NULL,
  "codigo"                text                     NOT NULL,
  "importe_inicial"       numeric                  NOT NULL,
  "saldo_actual"          numeric                  NOT NULL,
  "destinatario_nombre"   text,
  "destinatario_telefono" text,
  "fecha_vencimiento"     date                     NOT NULL,
  "activo"                boolean                  NOT NULL DEFAULT true,
  "created_at"            timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "vales_regalo_importe_inicial_check" CHECK ((importe_inicial > (0)::numeric)),
  CONSTRAINT "vales_regalo_pkey" PRIMARY KEY (id),
  CONSTRAINT "vales_regalo_restaurant_id_codigo_key" UNIQUE (restaurant_id, codigo)
);

ALTER TABLE "public"."vales_regalo"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."vales_regalo" FROM "anon";

CREATE TABLE "public"."vendedores" (
  "id"              uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "user_id"         uuid,
  "nombre"          text                     NOT NULL,
  "email"           text                     NOT NULL,
  "telefono"        text,
  "activo"          boolean                  NOT NULL DEFAULT true,
  "comision_pct"    numeric(5,2)             NOT NULL DEFAULT 10,
  "comision_cuotas" integer,
  "created_at"      timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "vendedores_comision_cuotas_check" CHECK (((comision_cuotas IS NULL) OR (comision_cuotas > 0))),
  CONSTRAINT "vendedores_comision_pct_check" CHECK (((comision_pct >= (0)::numeric) AND (comision_pct <= (100)::numeric))),
  CONSTRAINT "vendedores_pkey" PRIMARY KEY (id),
  CONSTRAINT "vendedores_user_id_key" UNIQUE (user_id)
);

ALTER TABLE "public"."vendedores"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."vendedores" FROM "anon";

CREATE TABLE "public"."waiter_calls" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id" uuid,
  "table_id"      uuid,
  "estado"        text                     DEFAULT 'pendiente'::text,
  "created_at"    timestamp with time zone DEFAULT now(),
  CONSTRAINT "waiter_calls_estado_check" CHECK ((estado = ANY (ARRAY['pendiente'::text, 'atendido'::text]))),
  CONSTRAINT "waiter_calls_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."waiter_calls"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."webhook_entregas" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "webhook_id" uuid                     NOT NULL,
  "evento"     text                     NOT NULL,
  "payload"    jsonb                    NOT NULL,
  "request_id" bigint,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "webhook_entregas_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."webhook_entregas"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."webhook_entregas" FROM "anon";

CREATE TABLE "public"."webhooks" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id" uuid                     NOT NULL,
  "url"           text                     NOT NULL,
  "secreto"       text                     NOT NULL,
  "eventos"       text[]                   NOT NULL DEFAULT '{}'::text[],
  "activo"        boolean                  NOT NULL DEFAULT true,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "webhooks_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."webhooks"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."webhooks" FROM "anon";

CREATE TABLE "public"."whatsapp_mensajes_procesados" (
  "wamid"         text                     NOT NULL,
  "restaurant_id" uuid,
  "recibido_at"   timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "whatsapp_mensajes_procesados_pkey" PRIMARY KEY (wamid)
);

ALTER TABLE "public"."whatsapp_mensajes_procesados"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."whatsapp_sessions" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "restaurant_id" uuid,
  "telefono"      text                     NOT NULL,
  "contexto"      jsonb                    DEFAULT '{}'::jsonb,
  "updated_at"    timestamp with time zone DEFAULT now(),
  CONSTRAINT "whatsapp_sessions_pkey" PRIMARY KEY (id),
  CONSTRAINT "whatsapp_sessions_restaurant_id_telefono_key" UNIQUE (restaurant_id, telefono)
);

ALTER TABLE "public"."whatsapp_sessions"
  ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE "public"."whatsapp_sessions" FROM "anon", "authenticated";

CREATE TABLE "router"."clientes_cache" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "telefono"       text                     NOT NULL,
  "es_cliente"     boolean                  NOT NULL,
  "producto"       text,
  "datos_cliente"  jsonb,
  "actualizado_en" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "clientes_cache_pkey" PRIMARY KEY (id)
);

ALTER TABLE "router"."clientes_cache"
  ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.fn_aceptar_condiciones (
  p_restaurant_id uuid,
  p_version       text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_headers json := nullif(current_setting('request.headers', true), '')::json;
begin
  if not exists (select 1 from restaurants r where r.id = p_restaurant_id and r.user_id = auth.uid()) then
    raise exception 'Solo el titular del restaurante puede aceptar las condiciones.';
  end if;
  if coalesce(trim(p_version), '') = '' then
    raise exception 'Versión de las condiciones no válida.';
  end if;

  insert into condiciones_aceptaciones (restaurant_id, user_id, version, ip, user_agent)
  values (
    p_restaurant_id, auth.uid(), p_version,
    split_part(coalesce(v_headers->>'x-forwarded-for', v_headers->>'x-real-ip', ''), ',', 1),
    left(v_headers->>'user-agent', 400)
  )
  on conflict (restaurant_id, version) do nothing;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."fn_aceptar_condiciones"(uuid, text) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_activar_modulo_nucleo()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'extensions'
  AS $function$
begin
  insert into restaurant_modulos (restaurant_id, modulo_key, activo)
  values (new.id, 'nucleo', true)
  on conflict (restaurant_id, modulo_key) do nothing;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_actualizar_precio_contrato (
  p_restaurant_id uuid,
  p_precio        numeric DEFAULT NULL::numeric
)
  RETURNS numeric
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_precio numeric;
begin
  if not fn_es_superadmin() then
    raise exception 'No autorizado.';
  end if;
  if p_precio is not null and p_precio < 0 then
    raise exception 'El precio no puede ser negativo.';
  end if;

  if p_precio is null then
    select pl.precio into v_precio
    from restaurants r join planes pl on pl.key = r.plan
    where r.id = p_restaurant_id;
    if v_precio is null then
      raise exception 'El restaurante no tiene plan o su plan no tiene precio.';
    end if;
  else
    v_precio := round(p_precio, 2);
  end if;

  update restaurants set precio_contrato = v_precio where id = p_restaurant_id;
  if not found then
    raise exception 'Restaurante no encontrado.';
  end if;
  return v_precio;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."fn_actualizar_precio_contrato"(uuid, numeric) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_ahora_madrid()
  RETURNS timestamp WITHOUT time zone
  LANGUAGE sql
  STABLE
  SET search_path TO 'public'
  AS $function$ select now() at time zone 'Europe/Madrid' $function$;

CREATE OR REPLACE FUNCTION public.fn_aplicar_descuento (
  p_restaurant_id uuid,
  p_precio        numeric,
  p_dias          integer
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  if p_precio is null or p_precio < 0 then
    raise exception 'Precio inválido.';
  end if;
  update restaurants
  set precio_override = p_precio, precio_override_hasta = fn_hoy_madrid() + p_dias
  where id = p_restaurant_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_asegurar_sector_confirmacion()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'extensions'
  AS $function$
declare
  v_sector_id uuid;
begin
  if new.menu_item_id is not null then
    select mi.sector_cocina_id into v_sector_id
    from menu_items mi
    where mi.id = new.menu_item_id;
 
    if v_sector_id is not null then
      insert into order_sector_confirmaciones (order_id, sector_cocina_id)
      values (new.order_id, v_sector_id)
      on conflict (order_id, sector_cocina_id) do nothing;
    end if;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_asignar_modulo_a_plan (
  p_modulo_key text,
  p_plan_key   text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  if not exists (select 1 from planes where key = p_plan_key) then
    raise exception 'Plan no válido.';
  end if;

  update modulos set plan = p_plan_key where key = p_modulo_key;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_asignar_plan (
  p_restaurant_id uuid,
  p_plan_key      text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_orden_destino integer;
  v_precio numeric;
begin
  if not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;

  select orden, precio into v_orden_destino, v_precio from planes where key = p_plan_key;
  if v_orden_destino is null then
    raise exception 'Plan no válido.';
  end if;

  -- Cambio de plan (o primer plan): precio de contrato = tarifa actual.
  -- El mismo plan otra vez conserva el precio que ya tenía.
  update restaurants
  set precio_contrato = case
        when plan is distinct from p_plan_key or precio_contrato is null then v_precio
        else precio_contrato
      end,
      plan = p_plan_key
  where id = p_restaurant_id;

  insert into restaurant_modulos (restaurant_id, modulo_key, activo)
  select p_restaurant_id, m.key, true
  from modulos m
  join planes pl on pl.key = m.plan
  where pl.orden <= v_orden_destino
  on conflict (restaurant_id, modulo_key) do update set activo = true;

  update restaurant_modulos rm
  set activo = false
  from modulos m
  join planes pl on pl.key = m.plan
  where rm.modulo_key = m.key
    and rm.restaurant_id = p_restaurant_id
    and pl.orden > v_orden_destino;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."fn_asignar_plan"(uuid, text) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_bloquear_si_restaurante_inactivo()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_restaurant_id uuid;
begin
  if tg_table_name = 'order_items' then
    select o.restaurant_id into v_restaurant_id from orders o where o.id = new.order_id;
  else
    v_restaurant_id := new.restaurant_id;
  end if;

  if v_restaurant_id is not null and not fn_restaurante_activo(v_restaurant_id) then
    raise exception 'Este restaurante no está disponible en este momento.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_camarero_abrir_mesa (
  p_table_id      uuid,
  p_restaurant_id uuid,
  p_camarero_id   uuid,
  p_comensales    integer
)
  RETURNS TABLE (
    id               uuid,
    table_id         uuid,
    comensales       integer,
    camarero_id      uuid,
    cliente_telefono text,
    cliente_nombre   text
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_id uuid;
begin
  if not exists (select 1 from tables t where t.id = p_table_id and t.restaurant_id = p_restaurant_id and t.activa = true) then
    raise exception 'Mesa no encontrada.';
  end if;
  if p_camarero_id is not null and not exists (
    select 1 from camareros c where c.id = p_camarero_id and c.restaurant_id = p_restaurant_id and c.activo = true
  ) then
    raise exception 'Camarero no válido.';
  end if;

  insert into table_sessions (table_id, restaurant_id, comensales, camarero_id)
  values (p_table_id, p_restaurant_id, p_comensales, p_camarero_id)
  returning table_sessions.id into v_id;

  return query
    select ts.id, ts.table_id, ts.comensales, ts.camarero_id, ts.cliente_telefono, ts.cliente_nombre
    from table_sessions ts where ts.id = v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_camarero_editar_cliente_sesion (
  p_table_session_id uuid,
  p_restaurant_id    uuid,
  p_camarero_id      uuid,
  p_telefono         text,
  p_nombre           text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not exists (
    select 1 from camareros c where c.id = p_camarero_id and c.restaurant_id = p_restaurant_id and c.activo = true
  ) then
    raise exception 'Camarero no válido.';
  end if;

  update table_sessions
  set cliente_telefono = p_telefono,
      cliente_nombre = coalesce(p_nombre, cliente_nombre)
  where id = p_table_session_id and restaurant_id = p_restaurant_id and estado = 'abierta';
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_camarero_listar_pedidos_sesion (
  p_restaurant_id    uuid,
  p_camarero_id      uuid,
  p_table_session_id uuid
)
  RETURNS TABLE (
    order_id                 uuid,
    order_created_at         timestamp with time zone,
    order_estado             text,
    order_total              numeric,
    order_notas              text,
    item_id                  uuid,
    item_nombre              text,
    item_precio              numeric,
    item_cantidad            integer,
    item_notas               text,
    item_modificadores       text,
    item_modificadores_extra numeric
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'pedidos') then
    raise exception 'No autorizado';
  end if;

  return query
    select
      o.id, o.created_at, o.estado, o.total, o.notas,
      oi.id, oi.nombre_snapshot, oi.precio_snapshot, oi.cantidad, oi.notas,
      (
        select string_agg(oim.opcion_nombre, ', ' order by oim.grupo_nombre, oim.opcion_nombre)
        from order_item_modificadores oim
        where oim.order_item_id = oi.id
      ) as item_modificadores,
      (
        select coalesce(sum(oim.precio_extra), 0)
        from order_item_modificadores oim
        where oim.order_item_id = oi.id
      ) as item_modificadores_extra
    from orders o
    join table_sessions ts on ts.id = o.table_session_id
    left join order_items oi on oi.order_id = o.id
    where o.table_session_id = p_table_session_id
      and ts.restaurant_id = p_restaurant_id
      and o.estado != 'cancelado'
    order by o.created_at asc, oi.id asc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_camarero_listar_sesiones (
  p_restaurant_id uuid
)
  RETURNS TABLE (
    id               uuid,
    table_id         uuid,
    comensales       integer,
    camarero_id      uuid,
    cliente_telefono text,
    cliente_nombre   text
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select ts.id, ts.table_id, ts.comensales, ts.camarero_id, ts.cliente_telefono, ts.cliente_nombre
  from table_sessions ts
  where ts.restaurant_id = p_restaurant_id and ts.estado = 'abierta'
$function$;

CREATE OR REPLACE FUNCTION public.fn_camarero_toggle_limpieza (
  p_table_id      uuid,
  p_restaurant_id uuid,
  p_paso_id       uuid
)
  RETURNS TABLE (
    necesita_limpieza boolean,
    limpieza_progreso uuid[]
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_actual uuid[];
  v_nuevo uuid[];
  v_completo boolean;
begin
  select t.limpieza_progreso into v_actual
  from tables t where t.id = p_table_id and t.restaurant_id = p_restaurant_id;

  if not found then
    raise exception 'Mesa no encontrada.';
  end if;

  v_actual := coalesce(v_actual, '{}');
  if p_paso_id = any(v_actual) then
    v_nuevo := array_remove(v_actual, p_paso_id);
  else
    v_nuevo := v_actual || p_paso_id;
  end if;

  select not exists (
    select 1 from limpieza_pasos lp
    where lp.restaurant_id = p_restaurant_id and lp.activo = true and not (lp.id = any(v_nuevo))
  ) into v_completo;

  update tables set limpieza_progreso = v_nuevo, necesita_limpieza = not v_completo
  where id = p_table_id and restaurant_id = p_restaurant_id;

  return query select (not v_completo), v_nuevo;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_camarero_tomar_mesa (
  p_table_session_id uuid,
  p_restaurant_id    uuid,
  p_camarero_id      uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not exists (
    select 1 from camareros c where c.id = p_camarero_id and c.restaurant_id = p_restaurant_id and c.activo = true
  ) then
    raise exception 'Camarero no válido.';
  end if;

  update table_sessions
  set camarero_id = p_camarero_id
  where id = p_table_session_id and restaurant_id = p_restaurant_id and estado = 'abierta';
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_canjear_vale_regalo (
  p_table_session_id uuid,
  p_vale_codigo      text,
  p_vale_importe     numeric
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_restaurant_id uuid;
  v_vale record;
begin
  select restaurant_id into v_restaurant_id
  from table_sessions
  where id = p_table_session_id and estado = 'abierta';

  if v_restaurant_id is null then
    raise exception 'La sesión de mesa no existe o ya está cerrada';
  end if;

  if p_vale_importe is null or p_vale_importe <= 0 then
    raise exception 'Importe inválido';
  end if;

  select id, saldo_actual, activo, fecha_vencimiento into v_vale
  from vales_regalo
  where restaurant_id = v_restaurant_id and upper(codigo) = upper(p_vale_codigo)
  for update;

  if v_vale.id is null then
    raise exception 'Ese vale no existe';
  end if;
  if not v_vale.activo then
    raise exception 'Ese vale ya no está activo';
  end if;
  if v_vale.fecha_vencimiento < fn_hoy_madrid() then
    raise exception 'Ese vale ya venció';
  end if;
  if p_vale_importe > v_vale.saldo_actual then
    raise exception 'El vale no tiene saldo suficiente';
  end if;

  update vales_regalo set saldo_actual = saldo_actual - p_vale_importe where id = v_vale.id;

  insert into vale_movimientos (vale_id, importe, table_session_id)
  values (v_vale.id, -p_vale_importe, p_table_session_id);

  insert into table_session_payments (table_session_id, restaurant_id, monto, metodo_pago)
  values (p_table_session_id, v_restaurant_id, p_vale_importe, 'vale_regalo');
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_carta_takeaway (
  p_restaurant_id uuid,
  p_momento       timestamp with time zone DEFAULT now()
)
  RETURNS TABLE (
    id           uuid,
    nombre       text,
    descripcion  text,
    precio       numeric,
    precio_carta numeric,
    emoji        text,
    category_id  uuid,
    categories   json,
    menu_nombre  text
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with activo as (
    select fn_menu_activo(p_restaurant_id, null, p_momento, true) as menu_id
  )
  select mi.id, mi.nombre, mi.descripcion,
         coalesce(mp.precio, mi.precio) as precio,
         mi.precio as precio_carta,
         mi.emoji, mi.category_id,
         case when c.id is null then null else json_build_object('nombre', c.nombre, 'orden', c.orden) end as categories,
         m.nombre as menu_nombre
  from menu_items mi
  cross join activo a
  left join menus m on m.id = a.menu_id
  left join categories c on c.id = mi.category_id
  left join menu_item_precios_menu mp on mp.menu_id = a.menu_id and mp.menu_item_id = mi.id
  where mi.restaurant_id = p_restaurant_id
    and mi.disponible = true
    and coalesce(mp.excluido, false) = false
  order by c.orden nulls last, mi.orden nulls last, mi.nombre
$function$;

CREATE OR REPLACE FUNCTION public.fn_condiciones_pendientes (
  p_restaurant_id uuid,
  p_version       text
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1 from restaurants r
    where r.id = p_restaurant_id
      and r.user_id = auth.uid()
      and r.permanencia_hasta is not null
      and not exists (
        select 1 from condiciones_aceptaciones a
        where a.restaurant_id = r.id and a.version = p_version
      )
  )
$function$;

REVOKE ALL ON FUNCTION "public"."fn_condiciones_pendientes"(uuid, text) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_consultar_vale (
  p_restaurant_id uuid,
  p_codigo        text
)
  RETURNS TABLE (
    id                uuid,
    saldo_actual      numeric,
    activo            boolean,
    fecha_vencimiento date
  )
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select id, saldo_actual, activo, fecha_vencimiento
  from vales_regalo
  where restaurant_id = p_restaurant_id and upper(codigo) = upper(p_codigo)
  limit 1
$function$;

CREATE OR REPLACE FUNCTION public.fn_crear_camarero (
  p_restaurant_id uuid,
  p_nombre        text,
  p_pin           text,
  p_permisos      text[]
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'extensions'
  AS $function$
declare
  v_id uuid;
begin
  if not exists (select 1 from restaurants r where r.id = p_restaurant_id and r.user_id = auth.uid())
     and not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  if p_pin !~ '^\d{4}$' then
    raise exception 'El PIN debe ser de 4 dígitos numéricos.';
  end if;
  if exists (
    select 1 from camareros c
    where c.restaurant_id = p_restaurant_id and crypt(p_pin, c.pin_hash) = c.pin_hash
  ) then
    raise exception 'Ya existe un camarero con ese PIN en este restaurante.';
  end if;

  insert into camareros (restaurant_id, nombre, pin_hash, permisos)
  values (p_restaurant_id, p_nombre, crypt(p_pin, gen_salt('bf')), p_permisos)
  returning id into v_id;

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_crear_reserva_web (
  p_restaurant_id uuid,
  p_nombre        text,
  p_telefono      text,
  p_fecha         date,
  p_hora          time without time zone,
  p_personas      integer,
  p_zona          text                   DEFAULT 'sin preferencia'::text,
  p_notas         text                   DEFAULT NULL::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'extensions'
  AS $function$
declare
  v_motivo text;
begin
  if p_nombre is null or trim(p_nombre) = '' then
    raise exception 'Falta el nombre';
  end if;
  if p_telefono is null or trim(p_telefono) = '' then
    raise exception 'Falta el teléfono';
  end if;
  if p_personas is null or p_personas < 1 then
    raise exception 'Cantidad de personas inválida';
  end if;
  if p_fecha is null or p_fecha < fn_hoy_madrid() then
    raise exception 'La fecha tiene que ser hoy o más adelante';
  end if;
  if p_hora is null then
    raise exception 'Falta la hora';
  end if;
  if not exists (select 1 from restaurants where id = p_restaurant_id) then
    raise exception 'Restaurante no encontrado';
  end if;

  -- Hoy: hora no pasada y al menos 15 minutos de antelación (como el agente).
  if p_fecha + p_hora <= date_trunc('minute', fn_ahora_madrid()) then
    raise exception 'Las % de hoy ya han pasado. Elige una hora más tarde.', to_char(p_hora, 'HH24:MI');
  end if;
  if p_fecha + p_hora < date_trunc('minute', fn_ahora_madrid()) + interval '15 minutes' then
    raise exception 'Para reservar hoy necesitamos al menos 15 minutos de antelación. Elige una hora más tarde.';
  end if;

  v_motivo := fn_reserva_fuera_de_horario(p_restaurant_id, p_fecha, p_hora);
  if v_motivo is not null then
    raise exception '%', v_motivo;
  end if;

  insert into reservations (restaurant_id, nombre, telefono, fecha, hora, personas, zona, notas, estado, origen)
  values (p_restaurant_id, trim(p_nombre), trim(p_telefono), p_fecha, p_hora, p_personas, coalesce(nullif(trim(p_zona), ''), 'sin preferencia'), nullif(trim(p_notas), ''), 'pendiente', 'web');
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_crm_actividades_antes()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if auth.uid() is not null then
    new.autor_user_id := auth.uid();
    new.autor_nombre := coalesce(
      (select nombre from vendedores where user_id = auth.uid()),
      (select coalesce(nombre, 'Admin') from superadmins where user_id = auth.uid()),
      new.autor_nombre
    );
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_crm_actividades_despues()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  update crm_cuentas
  set ultima_actividad_en = greatest(coalesce(ultima_actividad_en, new.fecha), new.fecha)
  where id = new.cuenta_id;
  return null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_crm_busqueda_cargar (
  p_id uuid
)
  RETURNS TABLE (
    parametros jsonb,
    locales    jsonb,
    created_at timestamp with time zone
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with b as (
    select b.parametros, b.locales, b.created_at
    from crm_busquedas b
    where b.id = p_id
      and fn_crm_puede_buscar()
      and (fn_es_superadmin() or b.user_id = auth.uid())
      and b.locales is not null
      and b.created_at >= now() - interval '30 days'
  ), dups as (
    select d.place_id, d.motivo from b, fn_crm_duplicados(b.locales) d
  )
  select b.parametros,
         coalesce((
           select jsonb_agg(x.local || jsonb_build_object('duplicado', d.motivo) order by x.n)
           from jsonb_array_elements(b.locales) with ordinality as x(local, n)
           left join dups d on d.place_id = x.local->>'place_id'
         ), '[]'::jsonb),
         b.created_at
  from b
$function$;

REVOKE ALL ON FUNCTION "public"."fn_crm_busqueda_cargar"(uuid) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_crm_busquedas_recientes()
  RETURNS TABLE (
    id           uuid,
    parametros   jsonb,
    resultados   integer,
    autor_nombre text,
    created_at   timestamp with time zone
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select b.id, b.parametros, b.resultados, b.autor_nombre, b.created_at
  from crm_busquedas b
  where fn_crm_puede_buscar()
    and (fn_es_superadmin() or b.user_id = auth.uid())
    and b.locales is not null
    and b.resultados > 0
    and b.created_at >= now() - interval '30 days'
  order by b.created_at desc
  limit 20
$function$;

REVOKE ALL ON FUNCTION "public"."fn_crm_busquedas_recientes"() FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_crm_cuenta_puede_ver (
  p_cuenta_id uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select fn_es_superadmin()
    or exists (
      select 1 from crm_cuentas c
      where c.id = p_cuenta_id and c.vendedor_id = fn_mi_vendedor_id()
    )
$function$;

REVOKE ALL ON FUNCTION "public"."fn_crm_cuenta_puede_ver"(uuid) FROM "anon";

CREATE OR REPLACE FUNCTION public.fn_crm_cuentas_antes()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_admin boolean := auth.uid() is null or fn_es_superadmin();
  v_vendedor record;
begin
  if not v_admin then
    if tg_op = 'INSERT' then
      new.vendedor_id := fn_mi_vendedor_id();
      if new.vendedor_id is null then
        raise exception 'No autorizado.';
      end if;
      new.restaurant_id := null;
      new.comision_pct := null;
      new.comision_cuotas := null;
      new.comision_inicio := null;
    else
      new.vendedor_id := old.vendedor_id;
      new.restaurant_id := old.restaurant_id;
      new.comision_pct := old.comision_pct;
      new.comision_cuotas := old.comision_cuotas;
      new.comision_inicio := old.comision_inicio;
      new.created_by := old.created_by;
      -- Un cliente ya convertido no vuelve atrás en el embudo desde el
      -- lado del vendedor: eso lo decide el superadmin.
      if old.restaurant_id is not null then
        new.etapa := old.etapa;
      end if;
    end if;
  end if;

  -- Condiciones de comisión por defecto del vendedor asignado.
  if new.vendedor_id is not null
     and (tg_op = 'INSERT' or new.vendedor_id is distinct from old.vendedor_id)
     and new.comision_pct is null then
    select comision_pct, comision_cuotas into v_vendedor from vendedores where id = new.vendedor_id;
    new.comision_pct := v_vendedor.comision_pct;
    new.comision_cuotas := v_vendedor.comision_cuotas;
  end if;

  if new.etapa = 'ganado' and (tg_op = 'INSERT' or old.etapa is distinct from 'ganado') then
    new.ganado_en := coalesce(new.ganado_en, now());
  end if;
  if new.etapa = 'perdido' and (tg_op = 'INSERT' or old.etapa is distinct from 'perdido') then
    new.perdido_en := now();
  end if;
  if new.etapa <> 'perdido' then
    new.perdido_en := null;
  end if;

  -- Al vincular el restaurante, la comisión arranca por defecto el mes
  -- siguiente (el superadmin puede cambiarlo).
  if new.restaurant_id is not null and new.comision_inicio is null then
    new.comision_inicio := (date_trunc('month', fn_hoy_madrid()) + interval '1 month')::date;
  end if;

  new.updated_at := now();
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_crm_cuentas_despues()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if tg_op = 'INSERT' then
    insert into crm_historial (cuenta_id, campo, valor_anterior, valor_nuevo)
    values (new.id, 'etapa', null, new.etapa);
    if new.vendedor_id is not null then
      insert into crm_historial (cuenta_id, campo, valor_anterior, valor_nuevo)
      values (new.id, 'vendedor', null, new.vendedor_id::text);
    end if;
  else
    if new.etapa is distinct from old.etapa then
      insert into crm_historial (cuenta_id, campo, valor_anterior, valor_nuevo)
      values (new.id, 'etapa', old.etapa, new.etapa);
    end if;
    if new.vendedor_id is distinct from old.vendedor_id then
      insert into crm_historial (cuenta_id, campo, valor_anterior, valor_nuevo)
      values (new.id, 'vendedor', old.vendedor_id::text, new.vendedor_id::text);
    end if;
  end if;
  return null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_crm_cuota_restaurante (
  p_restaurant_id uuid,
  p_fecha         date DEFAULT CURRENT_DATE
)
  RETURNS numeric
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select case
    when r.precio_override is not null
         and (r.precio_override_hasta is null or r.precio_override_hasta >= p_fecha)
      then r.precio_override
    else coalesce(r.precio_contrato, pl.precio, 0)
  end
  from restaurants r
  left join planes pl on pl.key = r.plan
  where r.id = p_restaurant_id
$function$;

REVOKE ALL ON FUNCTION "public"."fn_crm_cuota_restaurante"(uuid, date) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_crm_duplicados (
  p_locales jsonb
)
  RETURNS TABLE (
    place_id text,
    motivo   text
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with l as (
    select x->>'place_id' as place_id,
           right(regexp_replace(coalesce(x->>'telefono', ''), '\D', '', 'g'), 9) as tel
    from jsonb_array_elements(coalesce(p_locales, '[]'::jsonb)) x
  )
  select l.place_id,
         case when exists (select 1 from crm_cuentas c where c.google_place_id = l.place_id)
              then 'google' else 'telefono' end
  from l
  where fn_crm_puede_buscar()
    and (
      exists (select 1 from crm_cuentas c where c.google_place_id = l.place_id)
      or (length(l.tel) = 9 and exists (
        select 1 from crm_cuentas c
        where right(regexp_replace(coalesce(c.telefono, ''), '\D', '', 'g'), 9) = l.tel
      ))
    )
$function$;

REVOKE ALL ON FUNCTION "public"."fn_crm_duplicados"(jsonb) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_crm_generar_comisiones (
  p_periodo date
)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ini date := date_trunc('month', p_periodo)::date;
  v_fin date := (date_trunc('month', p_periodo) + interval '1 month - 1 day')::date;
  v_n integer;
begin
  if not fn_es_superadmin() then
    raise exception 'No autorizado.';
  end if;
  if v_ini > date_trunc('month', fn_hoy_madrid())::date then
    raise exception 'No se pueden generar comisiones de meses futuros.';
  end if;

  insert into crm_comisiones (cuenta_id, vendedor_id, restaurant_id, periodo, numero_cuota, cuota_base, porcentaje, importe)
  select c.id, c.vendedor_id, c.restaurant_id, v_ini, prev.n + 1, q.cuota, c.comision_pct,
         round(q.cuota * c.comision_pct / 100, 2)
  from crm_cuentas c
  join restaurants r on r.id = c.restaurant_id
  cross join lateral (select fn_crm_cuota_restaurante(r.id, v_ini) as cuota) q
  cross join lateral (
    select count(*)::integer as n from crm_comisiones x
    where x.cuenta_id = c.id and x.estado <> 'anulada'
  ) prev
  where c.vendedor_id is not null
    and coalesce(c.comision_pct, 0) > 0
    and c.comision_inicio is not null
    and c.comision_inicio <= v_fin
    and coalesce(r.activo, true)
    and (r.trial_termina_en is null or r.trial_termina_en < v_fin)
    and q.cuota > 0
    and (c.comision_cuotas is null or prev.n < c.comision_cuotas)
  on conflict (cuenta_id, periodo) do nothing;

  get diagnostics v_n = row_count;
  return v_n;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."fn_crm_generar_comisiones"(date) FROM "anon";

CREATE OR REPLACE FUNCTION public.fn_crm_importar_restaurantes()
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_n integer;
begin
  if not fn_es_superadmin() then
    raise exception 'No autorizado.';
  end if;

  insert into crm_cuentas (nombre, email, telefono, direccion, pais, etapa, fuente, plan_interes, restaurant_id, ganado_en)
  select r.nombre, r.email_dueno, r.whatsapp, r.direccion, r.pais, 'ganado', 'Cliente existente', r.plan, r.id, r.created_at
  from restaurants r
  where not exists (select 1 from crm_cuentas c where c.restaurant_id = r.id);

  get diagnostics v_n = row_count;
  return v_n;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."fn_crm_importar_restaurantes"() FROM "anon";

CREATE OR REPLACE FUNCTION public.fn_crm_permanencias()
  RETURNS TABLE (
    cuenta_id         uuid,
    permanencia_hasta date,
    baja_en           date,
    baja_penalizacion numeric
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select c.id, r.permanencia_hasta, r.baja_en, r.baja_penalizacion
  from crm_cuentas c
  join restaurants r on r.id = c.restaurant_id
  where fn_es_superadmin() or c.vendedor_id = fn_mi_vendedor_id()
$function$;

REVOKE ALL ON FUNCTION "public"."fn_crm_permanencias"() FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_crm_puede_buscar()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select fn_es_superadmin()
    or (fn_mi_vendedor_id() is not null
        and coalesce((select vendedores_pueden_buscar from crm_config where id), false))
$function$;

REVOKE ALL ON FUNCTION "public"."fn_crm_puede_buscar"() FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_crm_registrar_busqueda (
  p_parametros jsonb,
  p_consultas  integer,
  p_resultados integer,
  p_locales    jsonb   DEFAULT NULL::jsonb
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_id uuid;
begin
  if not fn_crm_puede_buscar() then
    raise exception 'No tienes permiso para buscar restaurantes.';
  end if;

  -- Caducidad de los datos de Google.
  update crm_busquedas set locales = null
  where locales is not null and created_at < now() - interval '30 days';

  insert into crm_busquedas (user_id, autor_nombre, parametros, consultas, resultados, locales)
  values (
    auth.uid(),
    coalesce((select v.nombre from vendedores v where v.user_id = auth.uid() limit 1), 'Superadmin'),
    coalesce(p_parametros, '{}'::jsonb),
    greatest(coalesce(p_consultas, 0), 0),
    greatest(coalesce(p_resultados, 0), 0),
    p_locales
  )
  returning id into v_id;
  return v_id;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."fn_crm_registrar_busqueda"(jsonb, integer, integer, jsonb) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_crm_restaurantes_cuentas()
  RETURNS TABLE (
    cuenta_id             uuid,
    restaurant_id         uuid,
    nombre                text,
    plan                  text,
    activo                boolean,
    trial_termina_en      date,
    precio_override       numeric,
    precio_override_hasta date,
    cuota_actual          numeric,
    alta_en               timestamp with time zone
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select c.id, r.id, r.nombre, r.plan, coalesce(r.activo, true), r.trial_termina_en,
         r.precio_override, r.precio_override_hasta,
         fn_crm_cuota_restaurante(r.id, fn_hoy_madrid()), r.created_at
  from crm_cuentas c
  join restaurants r on r.id = c.restaurant_id
  where fn_es_superadmin() or c.vendedor_id = fn_mi_vendedor_id()
$function$;

REVOKE ALL ON FUNCTION "public"."fn_crm_restaurantes_cuentas"() FROM "anon";

CREATE OR REPLACE FUNCTION public.fn_crm_uso_places()
  RETURNS TABLE (
    gratis_mes     integer,
    usadas_mes     integer,
    restantes      integer,
    excedidas      integer,
    precio_1000    numeric,
    coste_estimado numeric,
    mes            date
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with cfg as (
    select places_gratis_mes, places_precio_1000 from crm_config where id
  ), inicio as (
    select date_trunc('month', now() at time zone 'America/Los_Angeles') as ini
  ), uso as (
    select coalesce(sum(b.consultas), 0)::int as usadas
    from crm_busquedas b, inicio i
    where (b.created_at at time zone 'America/Los_Angeles') >= i.ini
  )
  select cfg.places_gratis_mes,
         uso.usadas,
         greatest(cfg.places_gratis_mes - uso.usadas, 0),
         greatest(uso.usadas - cfg.places_gratis_mes, 0),
         cfg.places_precio_1000,
         round(greatest(uso.usadas - cfg.places_gratis_mes, 0) * cfg.places_precio_1000 / 1000.0, 2),
         (select ini::date from inicio)
  from cfg, uso
  where fn_crm_puede_buscar()
$function$;

REVOKE ALL ON FUNCTION "public"."fn_crm_uso_places"() FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_crm_vendedor_cambiar_password (
  p_vendedor uuid,
  p_password text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'extensions'
  AS $function$
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
$function$;

REVOKE ALL ON FUNCTION "public"."fn_crm_vendedor_cambiar_password"(uuid, text) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_dar_baja_restaurante (
  p_restaurant_id       uuid,
  p_motivo              text,
  p_cobrar_penalizacion boolean DEFAULT true
)
  RETURNS TABLE (
    penalizacion           numeric,
    comisiones_anuladas    integer,
    comisiones_a_descontar integer
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  p record;
  v_anuladas integer := 0;
  v_descontar integer := 0;
  v_nota text := 'Baja dentro de la permanencia (' || to_char(fn_hoy_madrid(), 'DD/MM/YYYY') || ')';
begin
  if not fn_es_superadmin() then
    raise exception 'No autorizado.';
  end if;

  select * into p from fn_permanencia_penalizacion(p_restaurant_id, fn_hoy_madrid());

  update restaurants
  set activo = false,
      baja_en = fn_hoy_madrid(),
      baja_motivo = nullif(trim(coalesce(p_motivo, '')), ''),
      baja_penalizacion = case when p.en_permanencia then (case when p_cobrar_penalizacion then p.penalizacion else 0 end) end
  where id = p_restaurant_id;

  if p.en_permanencia then
    update crm_comisiones set estado = 'anulada', nota = v_nota
    where restaurant_id = p_restaurant_id and estado = 'pendiente';
    get diagnostics v_anuladas = row_count;

    update crm_comisiones set estado = 'a_descontar', nota = v_nota
    where restaurant_id = p_restaurant_id and estado = 'pagada';
    get diagnostics v_descontar = row_count;
  end if;

  penalizacion := case when p.en_permanencia and p_cobrar_penalizacion then p.penalizacion else 0 end;
  comisiones_anuladas := v_anuladas;
  comisiones_a_descontar := v_descontar;
  return next;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."fn_dar_baja_restaurante"(uuid, text, boolean) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_disparar_webhooks (
  p_restaurant_id uuid,
  p_evento        text,
  p_payload       jsonb
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'extensions'
  AS $function$
declare
  v_webhook record;
  v_cuerpo jsonb;
  v_firma text;
  v_request_id bigint;
begin
  for v_webhook in
    select id, url, secreto from webhooks
    where restaurant_id = p_restaurant_id and activo = true and p_evento = any(eventos)
  loop
    v_cuerpo := jsonb_build_object(
      'evento', p_evento,
      'restaurant_id', p_restaurant_id,
      'timestamp', extract(epoch from now())::bigint,
      'datos', p_payload
    );
    -- Firma HMAC-SHA256 del cuerpo tal cual se envía, para que quien
    -- lo reciba pueda verificar que viene de verdad de Restomind.
    v_firma := encode(hmac(v_cuerpo::text::bytea, v_webhook.secreto::bytea, 'sha256'), 'hex');

    select net.http_post(
      url := v_webhook.url,
      body := v_cuerpo,
      headers := jsonb_build_object('Content-Type', 'application/json', 'X-Restomind-Signature', v_firma)
    ) into v_request_id;

    insert into webhook_entregas (webhook_id, evento, payload, request_id)
    values (v_webhook.id, p_evento, v_cuerpo, v_request_id);
  end loop;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."fn_disparar_webhooks"(uuid, text, jsonb) FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE FUNCTION public.fn_es_superadmin()
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (select 1 from superadmins s where s.user_id = auth.uid())
$function$;

REVOKE ALL ON FUNCTION "public"."fn_es_superadmin"() FROM "anon";

CREATE OR REPLACE FUNCTION public.fn_estado_fidelizacion (
  p_restaurant_id uuid,
  p_telefono      text
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_puntos integer := 0;
  v_gasto numeric := 0;
  v_cliente_id uuid;
  v_nivel_actual json;
  v_proximo_nivel json;
  v_premios_puntos json;
  v_premios_sellos json;
  v_sellos_progreso json;
begin
  select id, coalesce(puntos, 0), coalesce(gasto_acumulado, 0)
    into v_cliente_id, v_puntos, v_gasto
  from clientes
  where restaurant_id = p_restaurant_id and telefono = fn_normalizar_telefono(p_telefono);

  v_puntos := coalesce(v_puntos, 0);
  v_gasto := coalesce(v_gasto, 0);

  select json_build_object('id', id, 'nombre', nombre, 'umbral_gasto', umbral_gasto)
    into v_nivel_actual
  from niveles_fidelizacion
  where restaurant_id = p_restaurant_id and umbral_gasto <= v_gasto
  order by umbral_gasto desc
  limit 1;

  select json_build_object('id', id, 'nombre', nombre, 'umbral_gasto', umbral_gasto)
    into v_proximo_nivel
  from niveles_fidelizacion
  where restaurant_id = p_restaurant_id and umbral_gasto > v_gasto
  order by umbral_gasto asc
  limit 1;

  select coalesce(json_agg(json_build_object(
      'id', p.id,
      'origen', 'puntos',
      'nombre', p.nombre,
      'descripcion', p.descripcion,
      'costo_puntos', p.costo_puntos,
      'tipo', p.tipo,
      'menu_item_nombre', mi.nombre,
      'descuento_importe', p.descuento_importe,
      'disponible', (p.costo_puntos <= v_puntos)
    ) order by p.costo_puntos), '[]'::json)
    into v_premios_puntos
  from premios_fidelizacion p
  left join menu_items mi on mi.id = p.menu_item_id
  where p.restaurant_id = p_restaurant_id
    and p.activo = true
    and (
      p.nivel_minimo_id is null
      or exists (
        select 1 from niveles_fidelizacion nm
        where nm.id = p.nivel_minimo_id and nm.umbral_gasto <= v_gasto
      )
    );

  select coalesce(json_agg(json_build_object(
      'id', ps.id,
      'origen', 'sello',
      'nombre', ps.nombre,
      'descripcion', null,
      'costo_puntos', 0,
      'tipo', 'plato_gratis',
      'menu_item_nombre', mp.nombre,
      'cantidad_premio', ps.cantidad_premio,
      'premios_disponibles', cs.premios_disponibles,
      'disponible', true
    ) order by ps.orden), '[]'::json)
    into v_premios_sellos
  from promos_sellos ps
  join clientes_sellos cs on cs.promo_id = ps.id and cs.cliente_id = v_cliente_id
  join menu_items mp on mp.id = ps.producto_premio_id
  where ps.restaurant_id = p_restaurant_id
    and ps.activo = true
    and cs.premios_disponibles > 0;

  select coalesce(json_agg(json_build_object(
      'id', ps.id,
      'nombre', ps.nombre,
      'producto_objetivo_nombre', mo.nombre,
      'producto_premio_nombre', mp.nombre,
      'cantidad_objetivo', ps.cantidad_objetivo,
      'cantidad_premio', ps.cantidad_premio,
      'unidades_acumuladas', coalesce(cs.unidades_acumuladas, 0)
    ) order by ps.orden), '[]'::json)
    into v_sellos_progreso
  from promos_sellos ps
  join menu_items mo on mo.id = ps.producto_objetivo_id
  join menu_items mp on mp.id = ps.producto_premio_id
  left join clientes_sellos cs on cs.promo_id = ps.id and cs.cliente_id = v_cliente_id
  where ps.restaurant_id = p_restaurant_id and ps.activo = true;

  return json_build_object(
    'puntos', v_puntos,
    'gasto_acumulado', v_gasto,
    'nivel_actual', v_nivel_actual,
    'proximo_nivel', v_proximo_nivel,
    'premios', (
      select coalesce(json_agg(elem), '[]'::json)
      from (
        select json_array_elements(v_premios_puntos) as elem
        union all
        select json_array_elements(v_premios_sellos) as elem
      ) t
    ),
    'sellos_progreso', v_sellos_progreso
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_estado_sesion_mesa (
  p_session_id uuid,
  p_qr_token   text
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'extensions'
  AS $function$
declare
  v_estado text;
begin
  select ts.estado into v_estado
  from table_sessions ts
  join tables t on t.id = ts.table_id
  where ts.id = p_session_id
    and t.qr_token = p_qr_token;
  return v_estado;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_hora_madrid()
  RETURNS time WITHOUT time zone
  LANGUAGE sql
  STABLE
  SET search_path TO 'public'
  AS $function$ select (now() at time zone 'Europe/Madrid')::time $function$;

CREATE OR REPLACE FUNCTION public.fn_hoy_madrid()
  RETURNS date
  LANGUAGE sql
  STABLE
  SET search_path TO 'public'
  AS $function$ select (now() at time zone 'Europe/Madrid')::date $function$;

CREATE OR REPLACE FUNCTION public.fn_info_restaurante_publica (
  p_restaurant_id uuid
)
  RETURNS TABLE (
    titulo    text,
    contenido text
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select i.titulo, i.contenido
  from restaurant_info i
  where i.restaurant_id = p_restaurant_id
    and i.activo = true
    and btrim(i.contenido) <> ''
    and exists (
      select 1 from restaurant_modulos rm
      where rm.restaurant_id = p_restaurant_id
        and rm.modulo_key = 'info_restaurante'
        and rm.activo = true
    )
  order by i.orden, i.created_at;
$function$;

CREATE OR REPLACE FUNCTION public.fn_iniciar_trial (
  p_restaurant_id uuid,
  p_dias          integer DEFAULT 14
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  update restaurants set trial_termina_en = fn_hoy_madrid() + p_dias where id = p_restaurant_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_limpiar_descuento (
  p_restaurant_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  update restaurants set precio_override = null, precio_override_hasta = null where id = p_restaurant_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_limpiar_trial (
  p_restaurant_id uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  update restaurants set trial_termina_en = null where id = p_restaurant_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_listar_camareros_nombres (
  p_restaurant_id uuid
)
  RETURNS TABLE (
    id     uuid,
    nombre text
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select c.id, c.nombre from camareros c
  where c.restaurant_id = p_restaurant_id and c.activo = true
  order by c.nombre
$function$;

CREATE OR REPLACE FUNCTION public.fn_marcar_timestamp_estado_pedido()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if new.estado is distinct from old.estado then
    case new.estado
      when 'preparando' then
        new.preparando_at := coalesce(new.preparando_at, now());
        new.listo_at := null;
        new.entregado_at := null;
      when 'listo' then
        new.listo_at := coalesce(new.listo_at, now());
        new.entregado_at := null;
      when 'entregado' then
        new.entregado_at := coalesce(new.entregado_at, now());
      when 'pendiente' then
        -- Cocina revirtió el pedido hasta el principio: las marcas de
        -- estados posteriores ya no corresponden a este ciclo.
        new.preparando_at := null;
        new.listo_at := null;
        new.entregado_at := null;
      else
        -- 'cancelado' u otro estado: no se tocan las marcas ya puestas.
        null;
    end case;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_menu_activo (
  p_restaurant_id uuid,
  p_zona          text                     DEFAULT NULL::text,
  p_momento       timestamp with time zone DEFAULT now(),
  p_whatsapp      boolean                  DEFAULT false
)
  RETURNS uuid
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select m.id
  from menus m,
       lateral (select (p_momento at time zone 'Europe/Madrid') as local) l
  where m.restaurant_id = p_restaurant_id
    and m.activo = true
    and (m.zona is null or m.zona = p_zona)
    and (not p_whatsapp or m.aplica_whatsapp)
    and (
      m.hora_inicio is null or m.hora_fin is null or (
        case when m.hora_inicio <= m.hora_fin
          then l.local::time >= m.hora_inicio and l.local::time < m.hora_fin
          -- franja que cruza la medianoche (22:00-02:00)
          else l.local::time >= m.hora_inicio or l.local::time < m.hora_fin
        end
      )
    )
    and (
      m.dias_semana is null or array_length(m.dias_semana, 1) is null
      or extract(dow from l.local)::smallint = any(m.dias_semana)
    )
  order by
    (case when m.zona is not null then 1 else 0 end
     + case when m.hora_inicio is not null then 1 else 0 end
     + case when m.dias_semana is not null and array_length(m.dias_semana, 1) > 0 then 1 else 0 end) desc,
    m.orden asc
  limit 1
$function$;

CREATE OR REPLACE FUNCTION public.fn_mi_restaurante()
  RETURNS TABLE (
    id     uuid,
    activo boolean
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select r.id, coalesce(r.activo, true)
  from restaurants r
  where r.user_id = auth.uid()
  limit 1
$function$;

REVOKE ALL ON FUNCTION "public"."fn_mi_restaurante"() FROM "anon";

CREATE OR REPLACE FUNCTION public.fn_mi_vendedor_id()
  RETURNS uuid
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select v.id from vendedores v where v.user_id = auth.uid() and v.activo limit 1
$function$;

REVOKE ALL ON FUNCTION "public"."fn_mi_vendedor_id"() FROM "anon";

CREATE OR REPLACE FUNCTION public.fn_normalizar_telefono (
  p_telefono text
)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  SET search_path TO 'public'
  AS $function$
  select nullif(
    case
      -- 34 + 9 cifras españolas (6/7/8/9) → 9 cifras
      when d ~ '^34[6789]\d{8}$' then substr(d, 3)
      else d
    end, '')
  from (
    -- solo dígitos, sin el 00 internacional
    select regexp_replace(regexp_replace(coalesce(p_telefono, ''), '\D', '', 'g'), '^00', '') as d
  ) x
$function$;

CREATE OR REPLACE FUNCTION public.fn_otorgar_puntos_fidelizacion()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tasa numeric;
  v_puntos integer;
  v_cliente_id uuid;
  v_conteo jsonb;
begin
  if new.estado = 'entregado'
     and (old.estado is distinct from 'entregado')
     and new.tipo = 'takeaway'
     and new.cliente_telefono is not null
  then
    select coalesce((config->>'puntos_por_euro')::numeric, 1)
      into v_tasa
    from restaurants
    where id = new.restaurant_id;

    v_puntos := greatest(floor(coalesce(new.total, 0) * v_tasa), 0);

    insert into clientes (restaurant_id, telefono, nombre, puntos, gasto_acumulado, ultima_visita)
    values (new.restaurant_id, new.cliente_telefono, new.cliente_nombre, v_puntos, coalesce(new.total, 0), now())
    on conflict (restaurant_id, telefono) do update
      set puntos = clientes.puntos + v_puntos,
          gasto_acumulado = clientes.gasto_acumulado + coalesce(new.total, 0),
          ultima_visita = now(),
          nombre = coalesce(excluded.nombre, clientes.nombre),
          updated_at = now()
    returning id into v_cliente_id;

    if v_puntos > 0 then
      insert into clientes_movimientos (cliente_id, tipo, puntos, motivo, order_id)
      values (v_cliente_id, 'suma', v_puntos, 'Pedido take away entregado', new.id);
    end if;

    select jsonb_object_agg(oi.menu_item_id::text, oi.cantidad_total)
      into v_conteo
    from (
      select menu_item_id, sum(cantidad) as cantidad_total
      from order_items
      where order_id = new.id and menu_item_id is not null and premio_canjeado_id is null and promo_sello_id is null
      group by menu_item_id
    ) oi;

    perform fn_procesar_sellos(new.restaurant_id, v_cliente_id, coalesce(v_conteo, '{}'::jsonb));
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_otorgar_puntos_mesa()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_restaurant_id uuid;
  v_tasa numeric;
  v_puntos integer;
  v_cliente_id uuid;
  v_conteo jsonb;
begin
  if new.estado = 'cerrada'
     and (old.estado is distinct from 'cerrada')
     and new.cliente_telefono is not null
  then
    select restaurant_id into v_restaurant_id from table_sessions where id = new.id;

    select coalesce((config->>'puntos_por_euro')::numeric, 1)
      into v_tasa
    from restaurants
    where id = v_restaurant_id;

    v_puntos := greatest(floor(coalesce(new.total, 0) * v_tasa), 0);

    insert into clientes (restaurant_id, telefono, nombre, puntos, gasto_acumulado, ultima_visita)
    values (v_restaurant_id, new.cliente_telefono, new.cliente_nombre, v_puntos, coalesce(new.total, 0), now())
    on conflict (restaurant_id, telefono) do update
      set puntos = clientes.puntos + v_puntos,
          gasto_acumulado = clientes.gasto_acumulado + coalesce(new.total, 0),
          ultima_visita = now(),
          nombre = coalesce(excluded.nombre, clientes.nombre),
          updated_at = now()
    returning id into v_cliente_id;

    if v_puntos > 0 then
      insert into clientes_movimientos (cliente_id, tipo, puntos, motivo, table_session_id)
      values (v_cliente_id, 'suma', v_puntos, 'Visita en mesa', new.id);
    end if;

    select jsonb_object_agg(oi.menu_item_id::text, oi.cantidad_total)
      into v_conteo
    from (
      select oi.menu_item_id, sum(oi.cantidad) as cantidad_total
      from order_items oi
      join orders o on o.id = oi.order_id
      where o.table_session_id = new.id
        and oi.menu_item_id is not null
        and oi.premio_canjeado_id is null
        and oi.promo_sello_id is null
      group by oi.menu_item_id
    ) oi;

    perform fn_procesar_sellos(v_restaurant_id, v_cliente_id, coalesce(v_conteo, '{}'::jsonb));
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_permanencia_penalizacion (
  p_restaurant_id uuid,
  p_fecha         date DEFAULT public.fn_hoy_madrid()
)
  RETURNS TABLE (
    permanencia_hasta date,
    en_permanencia    boolean,
    en_trial          boolean,
    meses_pendientes  integer,
    cuota             numeric,
    porcentaje        numeric,
    penalizacion      numeric
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_pct constant numeric := 50;
  r record;
  v_edad interval;
  v_meses integer := 0;
  v_cuota numeric;
begin
  if not fn_es_superadmin() then
    raise exception 'No autorizado.';
  end if;

  select x.permanencia_hasta, x.trial_termina_en into r from restaurants x where x.id = p_restaurant_id;
  if not found then
    raise exception 'Restaurante no encontrado.';
  end if;

  if r.permanencia_hasta is not null and r.permanencia_hasta > p_fecha then
    v_edad := age(r.permanencia_hasta, p_fecha);
    v_meses := (extract(year from v_edad) * 12 + extract(month from v_edad))::integer
               + case when extract(day from v_edad) > 0 then 1 else 0 end;
  end if;
  v_cuota := coalesce(fn_crm_cuota_restaurante(p_restaurant_id, p_fecha), 0);

  permanencia_hasta := r.permanencia_hasta;
  en_permanencia := v_meses > 0;
  en_trial := r.trial_termina_en is not null and r.trial_termina_en >= p_fecha;
  meses_pendientes := v_meses;
  cuota := v_cuota;
  porcentaje := v_pct;
  penalizacion := case when v_meses > 0 and not en_trial then round(v_meses * v_cuota * v_pct / 100, 2) else 0 end;
  return next;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."fn_permanencia_penalizacion"(uuid, date) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.fn_procesar_sellos (
  p_restaurant_id    uuid,
  p_cliente_id       uuid,
  p_conteo_productos jsonb
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_promo record;
  v_cantidad_pedida integer;
  v_progreso record;
  v_base integer;
  v_total integer;
  v_nuevos_premios integer;
  v_restante integer;
begin
  if p_cliente_id is null or p_conteo_productos is null or p_conteo_productos = '{}'::jsonb then
    return;
  end if;

  for v_promo in
    select * from promos_sellos
    where restaurant_id = p_restaurant_id and activo = true
  loop
    v_cantidad_pedida := coalesce((p_conteo_productos->>(v_promo.producto_objetivo_id::text))::integer, 0);
    if v_cantidad_pedida <= 0 then
      continue;
    end if;

    select * into v_progreso
    from clientes_sellos
    where cliente_id = p_cliente_id and promo_id = v_promo.id
    for update;

    if v_progreso.id is null then
      insert into clientes_sellos (cliente_id, promo_id)
      values (p_cliente_id, v_promo.id)
      returning * into v_progreso;
    end if;

    v_base := v_progreso.unidades_acumuladas;

    -- Caducidad: si el ciclo en curso venció sin llegar al objetivo, se
    -- descarta el progreso acumulado (no afecta a los premios ya ganados).
    if v_base > 0
       and v_promo.caducidad_dias is not null
       and v_progreso.fecha_inicio_ciclo is not null
       and v_progreso.fecha_inicio_ciclo < now() - (v_promo.caducidad_dias || ' days')::interval
    then
      v_base := 0;
    end if;

    v_total := v_base + v_cantidad_pedida;
    v_nuevos_premios := v_total / v_promo.cantidad_objetivo;
    v_restante := v_total % v_promo.cantidad_objetivo;

    update clientes_sellos
    set unidades_acumuladas = v_restante,
        premios_disponibles = premios_disponibles + v_nuevos_premios,
        fecha_inicio_ciclo = case
          when v_restante = 0 then null
          when v_base = 0 then now()
          else fecha_inicio_ciclo
        end,
        updated_at = now()
    where id = v_progreso.id;
  end loop;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_registrar_cliente_sesion (
  p_session_id uuid,
  p_qr_token   text,
  p_telefono   text,
  p_nombre     text DEFAULT NULL::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'extensions'
  AS $function$
begin
  update table_sessions ts
  set cliente_telefono = p_telefono,
      cliente_nombre = coalesce(p_nombre, ts.cliente_nombre)
  from tables t
  where ts.table_id = t.id
    and ts.id = p_session_id
    and t.qr_token = p_qr_token
    and ts.estado = 'abierta';
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_registrar_pedido (
  p_table_session_id  uuid,
  p_items             jsonb,
  p_notas             text    DEFAULT NULL::text,
  p_camarero_id       uuid    DEFAULT NULL::uuid,
  p_premios_canjeados jsonb   DEFAULT '[]'::jsonb,
  p_vale_codigo       text    DEFAULT NULL::text,
  p_vale_importe      numeric DEFAULT NULL::numeric
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_restaurant_id     uuid;
  v_table_id          uuid;
  v_modo_cocina       text;
  v_minutos_limite    int;
  v_cliente_telefono  text;
  v_restaurant_config jsonb;
  v_control_stock_activo boolean;
  v_order_id          uuid;
  v_notas_actual      text;
  v_item              jsonb;
  v_mod                jsonb;
  v_menu_item          record;
  v_order_item_id      uuid;
  v_extra              numeric;
  v_opcion_nombre      text;
  v_grupo_nombre       text;
  v_premio_item        jsonb;
  v_premio             record;
  v_cliente_id         uuid;
  v_cliente_puntos     integer;
  v_cliente_gasto      numeric;
  v_comensal_premio    int;
  v_zona                text;
  v_menu_activo_id      uuid;
  v_precio_override     numeric;
  v_receta              record;
  v_cantidad_pedida      int;
  v_vale                 record;
  v_promo_sello           record;
begin
  perform pg_advisory_xact_lock(hashtext(p_table_session_id::text));

  select ts.restaurant_id, ts.table_id, r.modo_cocina, r.minutos_limite_agrupado, ts.cliente_telefono, r.config
    into v_restaurant_id, v_table_id, v_modo_cocina, v_minutos_limite, v_cliente_telefono, v_restaurant_config
  from table_sessions ts
  join restaurants r on r.id = ts.restaurant_id
  where ts.id = p_table_session_id
    and ts.estado = 'abierta';

  if v_restaurant_id is null then
    raise exception 'La sesión de mesa % no existe o ya está cerrada', p_table_session_id;
  end if;

  v_control_stock_activo := coalesce((v_restaurant_config->>'control_stock_activo')::boolean, false);

  select zona into v_zona from tables where id = v_table_id;

  -- Menú activo para esta mesa ahora mismo: más específico gana
  -- (zona+hora+días > menos criterios), igual que en el frontend.
  -- Mismo criterio que WhatsApp: fn_menu_activo (sql/menu_activo_unico.sql).
  v_menu_activo_id := fn_menu_activo(v_restaurant_id, v_zona, now(), false);

  if v_modo_cocina = 'agrupado_mesa' then
    select id into v_order_id
    from orders
    where table_session_id = p_table_session_id
      and estado = 'pendiente'
      and created_at > now() - (v_minutos_limite || ' minutes')::interval
    order by created_at desc
    limit 1;
  end if;

  if v_order_id is null then
    insert into orders (restaurant_id, table_id, table_session_id, tipo, estado, notas, tomado_por)
    values (v_restaurant_id, v_table_id, p_table_session_id, 'mesa', 'pendiente', p_notas, p_camarero_id)
    returning id into v_order_id;
  elsif p_notas is not null and length(trim(p_notas)) > 0 then
    select notas into v_notas_actual from orders where id = v_order_id;
    if v_notas_actual is null or length(trim(v_notas_actual)) = 0 then
      update orders set notas = p_notas where id = v_order_id;
    elsif position(p_notas in v_notas_actual) = 0 then
      update orders set notas = v_notas_actual || ' · ' || p_notas where id = v_order_id;
    end if;
  end if;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    select id, nombre, precio, precio_costo into v_menu_item
    from menu_items
    where id = (v_item->>'menu_item_id')::uuid;

    v_precio_override := null;
    if v_menu_activo_id is not null then
      select precio into v_precio_override
      from menu_item_precios_menu
      where menu_id = v_menu_activo_id
        and menu_item_id = v_menu_item.id
        and excluido = false;
    end if;

    v_cantidad_pedida := (v_item->>'cantidad')::int;

    insert into order_items (
      order_id, menu_item_id, nombre_snapshot, precio_snapshot, costo_snapshot, cantidad, notas, comensal, agregado_at, restaurant_id
    )
    values (
      v_order_id,
      v_menu_item.id,
      v_menu_item.nombre,
      coalesce(v_precio_override, v_menu_item.precio),
      v_menu_item.precio_costo,
      v_cantidad_pedida,
      v_item->>'notas',
      nullif(v_item->>'comensal', '')::int,
      now(),
      v_restaurant_id
    )
    returning id into v_order_item_id;

    if v_control_stock_activo then
      for v_receta in select ri.ingrediente_id, ri.cantidad from receta_items ri where ri.menu_item_id = v_menu_item.id
      loop
        update ingredientes
        set stock_actual = stock_actual - (v_receta.cantidad * v_cantidad_pedida)
        where id = v_receta.ingrediente_id;

        insert into stock_movimientos (restaurant_id, ingrediente_id, tipo, cantidad, order_id)
        values (v_restaurant_id, v_receta.ingrediente_id, 'venta', -(v_receta.cantidad * v_cantidad_pedida), v_order_id);
      end loop;
    end if;

    if v_item ? 'modificadores' then
      for v_mod in select * from jsonb_array_elements(v_item->'modificadores')
      loop
        select nombre into v_grupo_nombre from modificador_grupos where id = (v_mod->>'grupo_id')::uuid;
        select nombre into v_opcion_nombre from modificador_opciones where id = (v_mod->>'opcion_id')::uuid;

        select coalesce(precio_extra, 0) into v_extra
        from menu_item_modificador_precios
        where menu_item_id = v_menu_item.id
          and opcion_id = (v_mod->>'opcion_id')::uuid;

        insert into order_item_modificadores (
          order_item_id, grupo_id, opcion_id, grupo_nombre, opcion_nombre, precio_extra
        )
        values (
          v_order_item_id,
          (v_mod->>'grupo_id')::uuid,
          (v_mod->>'opcion_id')::uuid,
          coalesce(v_grupo_nombre, ''),
          coalesce(v_opcion_nombre, ''),
          coalesce(v_extra, 0)
        );
      end loop;
    end if;
  end loop;

  -- Canje de premios: uno por uno, para que si alguno falla (puntos
  -- insuficientes, nivel no alcanzado, sin premios de sello
  -- disponibles) todo el pedido se cancele en vez de dejar canjes a
  -- medias.
  for v_premio_item in select * from jsonb_array_elements(p_premios_canjeados)
  loop
    if v_cliente_telefono is null then
      raise exception 'No hay un cliente asociado a esta mesa para canjear premios';
    end if;

    select id, puntos, gasto_acumulado into v_cliente_id, v_cliente_puntos, v_cliente_gasto
    from clientes
    where restaurant_id = v_restaurant_id and telefono = v_cliente_telefono;

    -- ---- Premio ganado por sellos (tarjeta de "compra N, la siguiente gratis") ----
    if coalesce(v_premio_item->>'origen', 'puntos') = 'sello' then
      select ps.id, ps.nombre, ps.producto_premio_id, ps.cantidad_premio
        into v_promo_sello
      from promos_sellos ps
      where ps.id = (v_premio_item->>'premio_id')::uuid
        and ps.restaurant_id = v_restaurant_id
        and ps.activo = true;

      if v_promo_sello.id is null then
        raise exception 'Esa promoción ya no está disponible';
      end if;

      if v_cliente_id is null then
        raise exception 'No hay un cliente asociado a esta mesa para canjear premios';
      end if;

      update clientes_sellos
      set premios_disponibles = premios_disponibles - 1, updated_at = now()
      where cliente_id = v_cliente_id and promo_id = v_promo_sello.id and premios_disponibles > 0;

      if not found then
        raise exception 'No tienes premios disponibles para "%"', v_promo_sello.nombre;
      end if;

      v_comensal_premio := nullif(v_premio_item->>'comensal', '')::int;

      select nombre, precio_costo into v_menu_item
      from menu_items where id = v_promo_sello.producto_premio_id;

      insert into order_items (
        order_id, menu_item_id, nombre_snapshot, precio_snapshot, costo_snapshot, cantidad, notas, comensal, promo_sello_id, agregado_at, restaurant_id
      )
      values (
        v_order_id, v_promo_sello.producto_premio_id, v_menu_item.nombre, 0, v_menu_item.precio_costo, v_promo_sello.cantidad_premio,
        'Premio por sellos: ' || v_promo_sello.nombre, v_comensal_premio, v_promo_sello.id, now(), v_restaurant_id
      );

      if v_control_stock_activo then
        for v_receta in select ri.ingrediente_id, ri.cantidad from receta_items ri where ri.menu_item_id = v_promo_sello.producto_premio_id
        loop
          update ingredientes set stock_actual = stock_actual - (v_receta.cantidad * v_promo_sello.cantidad_premio) where id = v_receta.ingrediente_id;
          insert into stock_movimientos (restaurant_id, ingrediente_id, tipo, cantidad, order_id)
          values (v_restaurant_id, v_receta.ingrediente_id, 'venta', -(v_receta.cantidad * v_promo_sello.cantidad_premio), v_order_id);
        end loop;
      end if;

      continue;
    end if;

    -- ---- Premio por puntos (como siempre) ----
    select id, nombre, tipo, costo_puntos, menu_item_id, descuento_importe, nivel_minimo_id
      into v_premio
    from premios_fidelizacion
    where id = (v_premio_item->>'premio_id')::uuid
      and restaurant_id = v_restaurant_id
      and activo = true;

    if v_premio.id is null then
      raise exception 'Ese premio ya no está disponible';
    end if;

    if v_cliente_id is null or coalesce(v_cliente_puntos, 0) < v_premio.costo_puntos then
      raise exception 'No hay puntos suficientes para canjear "%"', v_premio.nombre;
    end if;

    if v_premio.nivel_minimo_id is not null and not exists (
      select 1 from niveles_fidelizacion nm
      where nm.id = v_premio.nivel_minimo_id and nm.umbral_gasto <= coalesce(v_cliente_gasto, 0)
    ) then
      raise exception 'Todavía no alcanzas el nivel necesario para "%"', v_premio.nombre;
    end if;

    update clientes set puntos = puntos - v_premio.costo_puntos, updated_at = now() where id = v_cliente_id;

    insert into clientes_movimientos (cliente_id, tipo, puntos, motivo, order_id)
    values (v_cliente_id, 'resta', v_premio.costo_puntos, 'Canje: ' || v_premio.nombre, v_order_id);

    v_comensal_premio := nullif(v_premio_item->>'comensal', '')::int;

    if v_premio.tipo = 'plato_gratis' then
      select nombre, precio_costo into v_menu_item
      from menu_items where id = v_premio.menu_item_id;

      insert into order_items (
        order_id, menu_item_id, nombre_snapshot, precio_snapshot, costo_snapshot, cantidad, notas, comensal, premio_canjeado_id, agregado_at, restaurant_id
      )
      values (
        v_order_id, v_premio.menu_item_id, v_menu_item.nombre, 0, v_menu_item.precio_costo, 1,
        'Canjeado con puntos', v_comensal_premio, v_premio.id, now(), v_restaurant_id
      );

      if v_control_stock_activo then
        for v_receta in select ri.ingrediente_id, ri.cantidad from receta_items ri where ri.menu_item_id = v_premio.menu_item_id
        loop
          update ingredientes set stock_actual = stock_actual - v_receta.cantidad where id = v_receta.ingrediente_id;
          insert into stock_movimientos (restaurant_id, ingrediente_id, tipo, cantidad, order_id)
          values (v_restaurant_id, v_receta.ingrediente_id, 'venta', -v_receta.cantidad, v_order_id);
        end loop;
      end if;
    else
      insert into order_items (
        order_id, menu_item_id, nombre_snapshot, precio_snapshot, cantidad, notas, comensal, premio_canjeado_id, agregado_at, restaurant_id
      )
      values (
        v_order_id, null, 'Descuento fidelización: ' || v_premio.nombre, -v_premio.descuento_importe, 1,
        null, v_comensal_premio, v_premio.id, now(), v_restaurant_id
      );
    end if;
  end loop;

  -- Vale regalo: se bloquea la fila para que no se pueda gastar el
  -- mismo saldo dos veces en simultáneo desde mesas distintas.
  if p_vale_codigo is not null and p_vale_importe is not null and p_vale_importe > 0 then
    select id, saldo_actual, activo, fecha_vencimiento into v_vale
    from vales_regalo
    where restaurant_id = v_restaurant_id and upper(codigo) = upper(p_vale_codigo)
    for update;

    if v_vale.id is null then
      raise exception 'Ese vale no existe';
    end if;
    if not v_vale.activo then
      raise exception 'Ese vale ya no está activo';
    end if;
    if v_vale.fecha_vencimiento < fn_hoy_madrid() then
      raise exception 'Ese vale ya venció';
    end if;
    if p_vale_importe > v_vale.saldo_actual then
      raise exception 'El vale no tiene saldo suficiente';
    end if;

    update vales_regalo set saldo_actual = saldo_actual - p_vale_importe where id = v_vale.id;

    insert into vale_movimientos (vale_id, importe, order_id)
    values (v_vale.id, -p_vale_importe, v_order_id);

    insert into order_items (
      order_id, menu_item_id, nombre_snapshot, precio_snapshot, cantidad, notas, agregado_at, restaurant_id
    )
    values (
      v_order_id, null, 'Vale regalo: ' || upper(p_vale_codigo), -p_vale_importe, 1, null, now(), v_restaurant_id
    );
  end if;

  update orders o
  set total = coalesce((
    select sum(oi.precio_snapshot * oi.cantidad) + coalesce((
      select sum(oim.precio_extra) from order_item_modificadores oim
      join order_items oi2 on oi2.id = oim.order_item_id
      where oi2.order_id = o.id
    ), 0)
    from order_items oi where oi.order_id = o.id
  ), 0)
  where o.id = v_order_id;

  return v_order_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_registrar_resena (
  p_session_id uuid,
  p_qr_token   text,
  p_puntuacion integer,
  p_comentario text    DEFAULT NULL::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'extensions'
  AS $function$
declare
  v_restaurant_id uuid;
begin
  if p_puntuacion is null or p_puntuacion < 1 or p_puntuacion > 5 then
    raise exception 'Puntuación inválida';
  end if;

  select ts.restaurant_id into v_restaurant_id
  from table_sessions ts
  join tables t on t.id = ts.table_id
  where ts.id = p_session_id
    and t.qr_token = p_qr_token
    and ts.estado <> 'abierta';

  if v_restaurant_id is null then
    raise exception 'Sesión no encontrada o todavía abierta';
  end if;

  insert into resenas (restaurant_id, table_session_id, puntuacion, comentario)
  values (v_restaurant_id, p_session_id, p_puntuacion, nullif(trim(p_comentario), ''))
  on conflict (table_session_id) do nothing;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_reserva_cliente_bloquear (
  p_restaurant_id uuid,
  p_telefono      text,
  p_reserva_id    uuid
)
  RETURNS public.reservations
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_res reservations;
begin
  select * into v_res from reservations
  where id = p_reserva_id
    and restaurant_id = p_restaurant_id
    and estado in ('confirmada', 'pendiente')
    and fecha + hora > fn_ahora_madrid()
    and fn_normalizar_telefono(telefono) = fn_normalizar_telefono(p_telefono)
    and coalesce(fn_normalizar_telefono(p_telefono), '') <> ''
  for update;
  if v_res.id is null then
    raise exception 'No encuentro esa reserva: puede que ya esté anulada o que ya haya pasado.' using errcode = 'P0001';
  end if;
  return v_res;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."fn_reserva_cliente_bloquear"(uuid, text, uuid) FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE FUNCTION public.fn_reserva_cliente_cancelar (
  p_restaurant_id uuid,
  p_telefono      text,
  p_reserva_id    uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_res reservations;
begin
  v_res := fn_reserva_cliente_bloquear(p_restaurant_id, p_telefono, p_reserva_id);
  update reservations
  set estado = 'cancelada',
      notas = concat_ws(' | ', nullif(notas, ''),
                'Anulada por el cliente por WhatsApp el ' || to_char(fn_ahora_madrid(), 'DD/MM HH24:MI'))
  where id = v_res.id;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."fn_reserva_cliente_cancelar"(uuid, text, uuid) FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE FUNCTION public.fn_reserva_cliente_modificar (
  p_restaurant_id    uuid,
  p_telefono         text,
  p_reserva_id       uuid,
  p_fecha            date,
  p_hora             time without time zone,
  p_personas         integer,
  p_zona             text,
  p_duracion_minutos integer,
  p_aplicar          boolean                DEFAULT false
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_res reservations;
  v_motivo text;
  v_libre boolean;
  v_zona text := coalesce(nullif(trim(p_zona), ''), 'sin preferencia');
begin
  if p_fecha is null or p_hora is null or p_personas is null or p_personas < 1 then
    return 'Faltan datos para cambiar la reserva.';
  end if;

  -- Mismo bloqueo que fn_reserva_whatsapp_crear (restaurante + día), para
  -- el día nuevo y el de antes, en orden fijo para no bloquearse entre sí.
  perform pg_advisory_xact_lock(hashtext(p_restaurant_id::text || d::text))
  from (
    select distinct d from unnest(array[p_fecha, (select fecha from reservations where id = p_reserva_id)]) d
    where d is not null order by d
  ) x;

  v_res := fn_reserva_cliente_bloquear(p_restaurant_id, p_telefono, p_reserva_id);

  if p_fecha + p_hora <= date_trunc('minute', fn_ahora_madrid()) + interval '15 minutes' then
    return 'Para hoy necesitamos al menos 15 minutos de antelación.';
  end if;

  v_motivo := fn_reserva_fuera_de_horario(p_restaurant_id, p_fecha, p_hora);
  if v_motivo is not null then
    return v_motivo;
  end if;

  -- La disponibilidad se comprueba sin contar la propia reserva: se marca
  -- un momento como cancelada y se deja como estaba (todo dentro de esta
  -- transacción, nadie más lo ve).
  update reservations set estado = 'cancelada' where id = v_res.id;
  v_libre := fn_reserva_hay_mesa(p_restaurant_id, p_fecha, p_hora, p_personas, v_zona, coalesce(p_duracion_minutos, 120));

  if not v_libre then
    update reservations set estado = v_res.estado where id = v_res.id;
    return format('Lo sentimos, no tenemos mesa libre el %s a las %s para %s personas%s.',
      to_char(p_fecha, 'DD/MM'), to_char(p_hora, 'HH24:MI'), p_personas,
      case when v_zona <> 'sin preferencia' then ' en ' || v_zona else '' end);
  end if;

  if not p_aplicar then
    update reservations set estado = v_res.estado where id = v_res.id;
    return null;
  end if;

  update reservations
  set estado = v_res.estado,
      fecha = p_fecha,
      hora = p_hora,
      personas = p_personas,
      zona = v_zona,
      duracion_minutos = coalesce(p_duracion_minutos, duracion_minutos),
      notas = concat_ws(' | ', nullif(notas, ''),
                format('Cambiada por el cliente por WhatsApp el %s (antes: %s %s, %s pers., %s)',
                  to_char(fn_ahora_madrid(), 'DD/MM HH24:MI'),
                  to_char(v_res.fecha, 'DD/MM'), to_char(v_res.hora, 'HH24:MI'), v_res.personas,
                  coalesce(v_res.zona, 'sin preferencia')))
  where id = v_res.id;
  return null;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."fn_reserva_cliente_modificar"(uuid, text, uuid, date, time WITHOUT time zone, integer, text, integer, boolean) FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE FUNCTION public.fn_reserva_contexto_cliente (
  p_restaurant_id uuid,
  p_telefono      text
)
  RETURNS json
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select json_build_object(
    'reservas', coalesce((
      select json_agg(json_build_object(
               'id', r.id, 'nombre', r.nombre, 'fecha', r.fecha, 'hora', to_char(r.hora, 'HH24:MI'),
               'personas', r.personas, 'zona', r.zona, 'estado', r.estado
             ) order by r.fecha, r.hora)
      from (
        select * from reservations r
        where r.restaurant_id = p_restaurant_id
          and r.estado in ('confirmada', 'pendiente')
          and r.fecha + r.hora > fn_ahora_madrid()
          and fn_normalizar_telefono(r.telefono) = fn_normalizar_telefono(p_telefono)
          and coalesce(fn_normalizar_telefono(p_telefono), '') <> ''
        order by r.fecha, r.hora
        limit 5
      ) r
    ), '[]'::json),
    'max_personas', (
      select case
        when (rs.config ->> 'reservas_max_personas') ~ '^\d+$' and (rs.config ->> 'reservas_max_personas')::int > 0
          then (rs.config ->> 'reservas_max_personas')::int
        else (select max(t.capacidad) from tables t where t.restaurant_id = p_restaurant_id and t.activa = true)
      end
      from restaurants rs where rs.id = p_restaurant_id
    ),
    'telefono_reservas', (
      select nullif(trim(rs.config ->> 'telefono_reservas'), '') from restaurants rs where rs.id = p_restaurant_id
    )
  )
$function$;

REVOKE ALL ON FUNCTION "public"."fn_reserva_contexto_cliente"(uuid, text) FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE FUNCTION public.fn_reserva_fuera_de_horario (
  p_restaurant_id uuid,
  p_fecha         date,
  p_hora          time without time zone
)
  RETURNS text
  LANGUAGE plpgsql
  STABLE
  SET search_path TO 'public'
  AS $function$
declare
  v_config jsonb;
  v_horario jsonb;
  v_margen int;
  v_dias text[] := array['domingo','lunes','martes','miercoles','jueves','viernes','sabado'];
  v_dias_texto text[] := array['domingo','lunes','martes','miércoles','jueves','viernes','sábado'];
  v_dow int := extract(dow from p_fecha)::int;
  v_m int := extract(hour from p_hora)::int * 60 + extract(minute from p_hora)::int;
  v_dia jsonb;
  v_a text;
  v_c text;
  v_ini int;
  v_fin int;
  v_ultima int;
  v_abierto_ese_dia boolean := false;
  v_franjas_texto text[] := '{}';
  v_cierre_tarde int;
begin
  select config into v_config from restaurants where id = p_restaurant_id;
  v_horario := v_config -> 'horario';
  if v_horario is null or jsonb_typeof(v_horario) <> 'object' then
    return null;
  end if;

  v_margen := case
    when (v_config ->> 'reservas_minutos_antes_cierre') ~ '^\d+(\.\d+)?$'
      then floor((v_config ->> 'reservas_minutos_antes_cierre')::numeric)::int
    else 60
  end;

  -- i = 0: franjas del día de la reserva; i = 1: del día anterior (solo
  -- cuentan las que cruzan la medianoche).
  for i in 0..1 loop
    v_dia := v_horario -> v_dias[((v_dow - i + 7) % 7) + 1];
    if v_dia is null or coalesce(v_dia ->> 'abierto', 'false') <> 'true' then
      continue;
    end if;
    for j in 1..2 loop
      v_a := v_dia ->> (case j when 1 then 'apertura' else 'apertura2' end);
      v_c := v_dia ->> (case j when 1 then 'cierre' else 'cierre2' end);
      if coalesce(v_a, '') !~ '^\d{1,2}:\d{2}' or coalesce(v_c, '') !~ '^\d{1,2}:\d{2}' then
        continue;
      end if;
      v_ini := split_part(v_a, ':', 1)::int * 60 + substr(split_part(v_a, ':', 2), 1, 2)::int;
      v_fin := split_part(v_c, ':', 1)::int * 60 + substr(split_part(v_c, ':', 2), 1, 2)::int;
      if v_fin <= v_ini then v_fin := v_fin + 1440; end if;
      -- Último minuto en que se puede empezar una reserva en la franja.
      v_ultima := v_fin - greatest(v_margen, 1);

      if i = 0 then
        v_abierto_ese_dia := true;
        v_franjas_texto := v_franjas_texto || (v_a || '-' || v_c);
        if v_m >= v_ini and v_m <= v_ultima then return null; end if;
        if v_m >= v_ini and v_m < v_fin then v_cierre_tarde := coalesce(v_cierre_tarde, v_fin); end if;
      elsif v_fin > 1440 then
        if v_m + 1440 <= v_ultima then return null; end if;
        if v_m + 1440 < v_fin then v_cierre_tarde := coalesce(v_cierre_tarde, v_fin); end if;
      end if;
    end loop;
  end loop;

  if v_cierre_tarde is not null then
    return format('Lo sentimos, a las %s ya no admitimos reservas: la última es a las %s (cerramos a las %s).',
      to_char(p_hora, 'HH24:MI'),
      to_char(time '00:00' + make_interval(mins => v_cierre_tarde - v_margen), 'HH24:MI'),
      to_char(time '00:00' + make_interval(mins => v_cierre_tarde), 'HH24:MI'));
  end if;
  if not v_abierto_ese_dia then
    return format('Lo sentimos, el restaurante está cerrado el %s.', v_dias_texto[v_dow + 1]);
  end if;
  return format('Lo sentimos, el restaurante no está abierto a las %s. Nuestro horario ese día es %s.',
    to_char(p_hora, 'HH24:MI'), array_to_string(v_franjas_texto, ' y '));
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_reserva_hay_mesa (
  p_restaurant_id    uuid,
  p_fecha            date,
  p_hora             time without time zone,
  p_personas         integer,
  p_zona             text,
  p_duracion_minutos integer
)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  -- Minutos de una sesión que sigue abierta: aunque haya superado la
  -- duración estimada, se cuenta ocupada al menos hasta ahora + este margen.
  c_margen_sesion_abierta constant integer := 30;
  v_inicio integer;
  v_fin integer;
  v_ahora integer;
  v_candidatas uuid[];
  v_ocup record;
  v_elegida uuid;
begin
  v_inicio := extract(hour from p_hora)::int * 60 + extract(minute from p_hora)::int;
  v_fin := v_inicio + p_duracion_minutos;
  -- "Ahora" en minutos desde la medianoche (España) del día de la reserva:
  -- negativo si la reserva es de un día futuro, > 1440 si fuera pasado.
  v_ahora := floor(extract(epoch from ((now() at time zone 'Europe/Madrid') - p_fecha::timestamp)) / 60)::int;

  -- Mesas que individualmente caben el grupo, de la zona pedida (o
  -- todas si "sin preferencia"/null), ordenadas de menor a mayor
  -- capacidad: así el hueco libre más ajustado se gasta primero y no
  -- se "quema" una mesa grande en un grupo pequeño sin necesidad.
  select array_agg(id order by capacidad asc) into v_candidatas
  from tables
  where restaurant_id = p_restaurant_id
    and activa = true
    and capacidad >= p_personas
    and (p_zona is null or p_zona = 'sin preferencia' or zona = p_zona);

  if v_candidatas is null or array_length(v_candidatas, 1) = 0 then
    return false;
  end if;

  -- Demanda ya existente que se solapa con la franja pedida: otras
  -- reservas confirmadas (sin mesa fija — se les asigna por tamaño, de
  -- mayor a menor), incluidas las del día anterior y siguiente que
  -- cruzan la medianoche, y sesiones de mesa abiertas (mesa fija conocida).
  for v_ocup in (
    select x.tam, x.mesa_fija
    from (
      select r.personas as tam, null::uuid as mesa_fija,
             (r.fecha - p_fecha) * 1440
               + extract(hour from r.hora)::int * 60 + extract(minute from r.hora)::int as ini,
             coalesce(r.duracion_minutos, 120) as dur
      from reservations r
      where r.restaurant_id = p_restaurant_id
        and r.fecha between p_fecha - 1 and p_fecha + 1
        and r.estado = 'confirmada'
        and (p_zona is null or p_zona = 'sin preferencia'
             or r.zona is null or r.zona = 'sin preferencia' or r.zona = p_zona)
    ) x
    where v_inicio < x.ini + x.dur and v_fin > x.ini

    union all

    select s.tam, s.mesa_fija
    from (
      select t.capacidad as tam, t.id as mesa_fija,
             floor(extract(epoch from ((ts.abierta_at at time zone 'Europe/Madrid') - p_fecha::timestamp)) / 60)::int as ini,
             -- Igual que getDuracion() en n8n (90/120/150/180 según
             -- comensales); sin comensales cargados, 150 min.
             case
               when ts.comensales is null then 150
               when ts.comensales <= 2 then 90
               when ts.comensales <= 4 then 120
               when ts.comensales <= 8 then 150
               else 180
             end as dur
      from table_sessions ts
      join tables t on t.id = ts.table_id
      where ts.restaurant_id = p_restaurant_id
        and ts.estado = 'abierta'
        and t.activa = true
        and (p_zona is null or p_zona = 'sin preferencia' or t.zona = p_zona)
    ) s
    where v_inicio < greatest(s.ini + s.dur, v_ahora + c_margen_sesion_abierta)
      and v_fin > s.ini

    order by tam desc
  )
  loop
    if v_ocup.mesa_fija is not null then
      -- Sesión de mesa: sabemos exactamente qué mesa ocupa.
      v_candidatas := array_remove(v_candidatas, v_ocup.mesa_fija);
    else
      -- Reserva sin mesa fija: le quitamos a las candidatas la más
      -- ajustada que todavía le entre.
      v_elegida := null;
      select id into v_elegida
      from tables
      where id = any(v_candidatas) and capacidad >= v_ocup.tam
      order by capacidad asc
      limit 1;
      if v_elegida is not null then
        v_candidatas := array_remove(v_candidatas, v_elegida);
      end if;
    end if;
  end loop;

  -- array_length(...) de un array vacío (tras quitarle todos los
  -- elementos con array_remove) da NULL, no 0 — con coalesce nos
  -- aseguramos de que "sin mesas candidatas" dé `false` de verdad, no
  -- NULL (que en el `if not ...` de fn_reserva_whatsapp_crear se
  -- trataría como "no lanzar la excepción", dejando pasar la reserva).
  return coalesce(array_length(v_candidatas, 1), 0) > 0;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_reserva_whatsapp_crear (
  p_restaurant_id    uuid,
  p_nombre           text,
  p_telefono         text,
  p_fecha            date,
  p_hora             time without time zone,
  p_personas         integer,
  p_zona             text,
  p_notas            text,
  p_duracion_minutos integer
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_id uuid;
begin
  -- Serializa todos los intentos de reserva de este restaurante y día:
  -- mientras una transacción tiene el lock, ninguna otra (otra
  -- conversación de WhatsApp, el personal desde el panel, etc.) puede
  -- comprobar/crear para el mismo restaurante+fecha hasta que termine.
  perform pg_advisory_xact_lock(hashtext(p_restaurant_id::text || p_fecha::text));

  if not fn_reserva_hay_mesa(p_restaurant_id, p_fecha, p_hora, p_personas, p_zona, p_duracion_minutos) then
    raise exception 'Ya no hay disponibilidad para esa franja.' using errcode = 'P0001';
  end if;

  insert into reservations (
    restaurant_id, nombre, telefono, fecha, hora, personas, zona, notas, duracion_minutos, estado, origen
  ) values (
    p_restaurant_id, trim(p_nombre), trim(p_telefono), p_fecha, p_hora, p_personas,
    coalesce(nullif(trim(p_zona), ''), 'sin preferencia'), nullif(trim(p_notas), ''),
    p_duracion_minutos, 'confirmada', 'whatsapp'
  )
  returning id into v_id;

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_resetear_pin_camarero (
  p_camarero_id   uuid,
  p_restaurant_id uuid,
  p_pin_nuevo     text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'extensions'
  AS $function$
begin
  if not exists (select 1 from restaurants r where r.id = p_restaurant_id and r.user_id = auth.uid())
     and not exists (select 1 from superadmins s where s.user_id = auth.uid()) then
    raise exception 'No autorizado.';
  end if;
  if p_pin_nuevo !~ '^\d{4}$' then
    raise exception 'El PIN debe ser de 4 dígitos numéricos.';
  end if;
  if exists (
    select 1 from camareros c
    where c.restaurant_id = p_restaurant_id and c.id != p_camarero_id and crypt(p_pin_nuevo, c.pin_hash) = c.pin_hash
  ) then
    raise exception 'Ya existe un camarero con ese PIN en este restaurante.';
  end if;

  update camareros set pin_hash = crypt(p_pin_nuevo, gen_salt('bf'))
  where id = p_camarero_id and restaurant_id = p_restaurant_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_restaurante_accesible (
  p_restaurant_id uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select fn_restaurante_activo(p_restaurant_id)
    or exists (select 1 from superadmins s where s.user_id = auth.uid())
$function$;

CREATE OR REPLACE FUNCTION public.fn_restaurante_activo (
  p_restaurant_id uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select coalesce((select r.activo from restaurants r where r.id = p_restaurant_id), true)
$function$;

CREATE OR REPLACE FUNCTION public.fn_restaurants_permanencia_alta()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO 'public'
  AS $function$
begin
  -- Meses de permanencia desde la fecha de alta (hora de España).
  if new.permanencia_hasta is null then
    new.permanencia_hasta := ((coalesce(new.created_at, now()) at time zone 'Europe/Madrid')::date + interval '3 months')::date;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_restaurants_proteger_comercial()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if auth.uid() is not null and not fn_es_superadmin() then
    new.plan := old.plan;
    new.activo := old.activo;
    new.trial_termina_en := old.trial_termina_en;
    new.precio_override := old.precio_override;
    new.precio_override_hasta := old.precio_override_hasta;
    new.precio_contrato := old.precio_contrato;
    new.permanencia_hasta := old.permanencia_hasta;
    new.baja_en := old.baja_en;
    new.baja_motivo := old.baja_motivo;
    new.baja_penalizacion := old.baja_penalizacion;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_restaurants_proteger_comercial_alta()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if auth.uid() is not null and not fn_es_superadmin() then
    new.precio_contrato := null;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_sesion_abierta_por_token (
  p_qr_token text
)
  RETURNS TABLE (
    id               uuid,
    estado           text,
    abierta_at       timestamp with time zone,
    cliente_telefono text,
    cliente_nombre   text,
    comensales       integer
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select ts.id, ts.estado, ts.abierta_at, ts.cliente_telefono, ts.cliente_nombre, ts.comensales
  from table_sessions ts
  join tables t on t.id = ts.table_id
  where t.qr_token = p_qr_token and ts.estado = 'abierta'
  order by ts.abierta_at desc
  limit 1
$function$;

CREATE OR REPLACE FUNCTION public.fn_staff_cambiar_estado_pedido (
  p_restaurant_id uuid,
  p_camarero_id   uuid,
  p_order_id      uuid,
  p_nuevo_estado  text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'cocina') then
    raise exception 'No autorizado';
  end if;

  if p_nuevo_estado not in ('pendiente', 'preparando', 'listo', 'entregado') then
    raise exception 'Estado inválido';
  end if;

  update orders
  set estado = p_nuevo_estado, updated_at = now()
  where id = p_order_id and restaurant_id = p_restaurant_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_staff_cambiar_estado_reserva (
  p_restaurant_id uuid,
  p_camarero_id   uuid,
  p_reserva_id    uuid,
  p_nuevo_estado  text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'reservas') then
    raise exception 'No autorizado';
  end if;

  if p_nuevo_estado not in ('pendiente', 'confirmada', 'cancelada', 'noshow') then
    raise exception 'Estado inválido';
  end if;

  update reservations
  set estado = p_nuevo_estado
  where id = p_reserva_id and restaurant_id = p_restaurant_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_staff_canjear_puntos (
  p_restaurant_id uuid,
  p_camarero_id   uuid,
  p_cliente_id    uuid,
  p_cantidad      integer,
  p_motivo        text    DEFAULT NULL::text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_puntos_actuales integer;
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'clientes') then
    raise exception 'No autorizado';
  end if;

  if p_cantidad is null or p_cantidad <= 0 then
    raise exception 'Cantidad de puntos inválida';
  end if;

  select puntos into v_puntos_actuales
  from clientes
  where id = p_cliente_id and restaurant_id = p_restaurant_id;

  if v_puntos_actuales is null then
    raise exception 'Cliente no encontrado';
  end if;

  if p_cantidad > v_puntos_actuales then
    raise exception 'Ese cliente no tiene suficientes puntos';
  end if;

  update clientes
  set puntos = puntos - p_cantidad, updated_at = now()
  where id = p_cliente_id;

  insert into clientes_movimientos (cliente_id, tipo, puntos, motivo)
  values (p_cliente_id, 'resta', p_cantidad, coalesce(nullif(trim(p_motivo), ''), 'Canje en el local'));
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_staff_contar_alertas (
  p_restaurant_id uuid,
  p_camarero_id   uuid
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_limpieza integer := 0;
  v_llamadas integer := 0;
begin
  if fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'limpieza') then
    select count(*) into v_limpieza from tables
    where restaurant_id = p_restaurant_id and necesita_limpieza = true;
  end if;

  if fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'pedidos') then
    select count(*) into v_llamadas from waiter_calls
    where restaurant_id = p_restaurant_id and estado = 'pendiente';
  end if;

  return json_build_object('limpieza', v_limpieza, 'llamadas', v_llamadas);
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_staff_crear_reserva_manual (
  p_restaurant_id uuid,
  p_camarero_id   uuid,
  p_nombre        text,
  p_telefono      text,
  p_fecha         date,
  p_hora          time without time zone,
  p_personas      integer,
  p_zona          text                   DEFAULT 'sin preferencia'::text,
  p_notas         text                   DEFAULT NULL::text
)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_id uuid;
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'reservas') then
    raise exception 'No autorizado';
  end if;

  if p_nombre is null or trim(p_nombre) = '' then raise exception 'Falta el nombre'; end if;
  if p_telefono is null or trim(p_telefono) = '' then raise exception 'Falta el teléfono'; end if;
  if p_personas is null or p_personas < 1 then raise exception 'Cantidad de personas inválida'; end if;

  insert into reservations (restaurant_id, nombre, telefono, fecha, hora, personas, zona, notas, estado, origen)
  values (p_restaurant_id, trim(p_nombre), trim(p_telefono), p_fecha, p_hora, p_personas,
    coalesce(nullif(trim(p_zona), ''), 'sin preferencia'), nullif(trim(p_notas), ''), 'confirmada', 'manual')
  returning id into v_id;

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_staff_historial_cliente (
  p_restaurant_id uuid,
  p_camarero_id   uuid,
  p_cliente_id    uuid
)
  RETURNS TABLE (
    id         uuid,
    tipo       text,
    puntos     integer,
    motivo     text,
    created_at timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'clientes') then
    raise exception 'No autorizado';
  end if;

  return query
    select m.id, m.tipo, m.puntos, m.motivo, m.created_at
    from clientes_movimientos m
    join clientes c on c.id = m.cliente_id
    where c.id = p_cliente_id and c.restaurant_id = p_restaurant_id
    order by m.created_at desc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_staff_listar_clientes (
  p_restaurant_id uuid,
  p_camarero_id   uuid
)
  RETURNS TABLE (
    id              uuid,
    telefono        text,
    nombre          text,
    puntos          integer,
    gasto_acumulado numeric,
    ultima_visita   timestamp with time zone,
    updated_at      timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'clientes') then
    raise exception 'No autorizado';
  end if;

  return query
    select c.id, c.telefono, c.nombre, c.puntos, c.gasto_acumulado, c.ultima_visita, c.updated_at
    from clientes c
    where c.restaurant_id = p_restaurant_id
    order by c.puntos desc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_staff_listar_llamadas (
  p_restaurant_id uuid,
  p_camarero_id   uuid
)
  RETURNS TABLE (
    id          uuid,
    table_id    uuid,
    mesa_numero integer,
    mesa_zona   text,
    created_at  timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'pedidos') then
    raise exception 'No autorizado';
  end if;

  return query
    select w.id, w.table_id, t.numero, t.zona, w.created_at
    from waiter_calls w
    join tables t on t.id = w.table_id
    where w.restaurant_id = p_restaurant_id and w.estado = 'pendiente'
    order by w.created_at;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_staff_listar_pedidos_cocina (
  p_restaurant_id uuid,
  p_camarero_id   uuid
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_result json;
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'cocina') then
    raise exception 'No autorizado';
  end if;

  select coalesce(json_agg(json_build_object(
      'id', o.id,
      'estado', o.estado,
      'tipo', o.tipo,
      'notas', o.notas,
      'created_at', o.created_at,
      'mesa_numero', t.numero,
      'mesa_zona', t.zona,
      'items', (
        select coalesce(json_agg(json_build_object(
          'id', oi.id, 'nombre', oi.nombre_snapshot, 'cantidad', oi.cantidad, 'notas', oi.notas
        )), '[]'::json)
        from order_items oi where oi.order_id = o.id
      )
    ) order by o.created_at), '[]'::json)
    into v_result
  from orders o
  left join tables t on t.id = o.table_id
  where o.restaurant_id = p_restaurant_id
    and o.estado in ('pendiente', 'preparando', 'listo');

  return v_result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_staff_listar_reservas (
  p_restaurant_id uuid,
  p_camarero_id   uuid
)
  RETURNS TABLE (
    id         uuid,
    nombre     text,
    telefono   text,
    fecha      date,
    hora       time without time zone,
    personas   integer,
    zona       text,
    notas      text,
    estado     text,
    origen     text,
    created_at timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'reservas') then
    raise exception 'No autorizado';
  end if;

  return query
    select r.id, r.nombre, r.telefono, r.fecha, r.hora, r.personas, r.zona, r.notas, r.estado, r.origen, r.created_at
    from reservations r
    where r.restaurant_id = p_restaurant_id
    order by r.fecha, r.hora;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_staff_marcar_llamada_atendida (
  p_restaurant_id uuid,
  p_camarero_id   uuid,
  p_llamada_id    uuid
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not fn_staff_tiene_permiso(p_restaurant_id, p_camarero_id, 'pedidos') then
    raise exception 'No autorizado';
  end if;

  update waiter_calls set estado = 'atendido'
  where id = p_llamada_id and restaurant_id = p_restaurant_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_staff_tiene_permiso (
  p_restaurant_id uuid,
  p_camarero_id   uuid,
  p_permiso       text
)
  RETURNS boolean
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select fn_restaurante_activo(p_restaurant_id) and exists (
    select 1 from camareros c
    where c.id = p_camarero_id
      and c.restaurant_id = p_restaurant_id
      and c.activo = true
      and p_permiso = any(c.permisos)
  )
$function$;

CREATE OR REPLACE FUNCTION public.fn_trg_normalizar_telefono_cliente()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO 'public'
  AS $function$
begin
  if tg_table_name = 'clientes' then
    new.telefono := coalesce(fn_normalizar_telefono(new.telefono), new.telefono);
  else
    new.cliente_telefono := fn_normalizar_telefono(new.cliente_telefono);
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_trigger_webhook_order_placed()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  perform fn_disparar_webhooks(
    new.restaurant_id,
    'order.placed',
    jsonb_build_object(
      'order_id', new.id,
      'table_id', new.table_id,
      'tipo', new.tipo,
      'estado', new.estado,
      'created_at', new.created_at
    )
  );
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_trigger_webhook_payment_received()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  perform fn_disparar_webhooks(
    new.restaurant_id,
    'payment.received',
    jsonb_build_object(
      'payment_id', new.id,
      'table_session_id', new.table_session_id,
      'monto', new.monto,
      'metodo_pago', new.metodo_pago,
      'created_at', new.created_at
    )
  );
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_trigger_webhook_reservation_created()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  perform fn_disparar_webhooks(
    new.restaurant_id,
    'reservation.created',
    jsonb_build_object(
      'reservation_id', new.id,
      'nombre', new.nombre,
      'telefono', new.telefono,
      'fecha', new.fecha,
      'hora', new.hora,
      'personas', new.personas,
      'zona', new.zona,
      'origen', new.origen,
      'created_at', new.created_at
    )
  );
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_trigger_webhook_waiter_call()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  perform fn_disparar_webhooks(
    new.restaurant_id,
    'waiter.call',
    jsonb_build_object(
      'call_id', new.id,
      'table_id', new.table_id,
      'created_at', new.created_at
    )
  );
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_validar_modulo_pedido()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'extensions'
  AS $function$
begin
  if new.tipo <> 'mesa' then
    if not exists (
      select 1
      from restaurant_modulos
      where restaurant_id = new.restaurant_id
        and modulo_key = 'takeaway_delivery'
        and activo = true
    ) then
      raise exception 'El restaurante % no tiene el módulo takeaway_delivery activo', new.restaurant_id
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_verificar_camarero_pin (
  p_restaurant_id uuid,
  p_camarero_id   uuid,
  p_pin           text
)
  RETURNS TABLE (
    id       uuid,
    nombre   text,
    permisos text[]
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'extensions'
  AS $function$
declare
  v_bloqueo camarero_pin_intentos;
  v_match record;
  v_nuevos_fallidos integer;
begin
  if not fn_restaurante_activo(p_restaurant_id) then
    raise exception 'Este restaurante no está disponible en este momento.';
  end if;

  select c.id, c.nombre, c.permisos, c.pin_hash into v_match
  from camareros c
  where c.id = p_camarero_id and c.restaurant_id = p_restaurant_id and c.activo = true;

  if v_match.id is null then
    raise exception 'Camarero no válido.';
  end if;

  select * into v_bloqueo from camarero_pin_intentos where camarero_id = p_camarero_id;

  if v_bloqueo.bloqueado_hasta is not null and v_bloqueo.bloqueado_hasta > now() then
    raise exception 'Demasiados intentos fallidos. Inténtalo de nuevo en unos minutos.';
  end if;

  if crypt(p_pin, v_match.pin_hash) = v_match.pin_hash then
    insert into camarero_pin_intentos (camarero_id, fallidos, bloqueado_hasta, ultimo_intento)
    values (p_camarero_id, 0, null, now())
    on conflict (camarero_id) do update set fallidos = 0, bloqueado_hasta = null, ultimo_intento = now();

    return query select v_match.id, v_match.nombre, v_match.permisos;
    return;
  end if;

  v_nuevos_fallidos := case
    when v_bloqueo.camarero_id is null or v_bloqueo.ultimo_intento < now() - interval '5 minutes' then 1
    else v_bloqueo.fallidos + 1
  end;

  insert into camarero_pin_intentos (camarero_id, fallidos, bloqueado_hasta, ultimo_intento)
  values (p_camarero_id, v_nuevos_fallidos, case when v_nuevos_fallidos >= 10 then now() + interval '5 minutes' else null end, now())
  on conflict (camarero_id) do update
    set fallidos = v_nuevos_fallidos,
        bloqueado_hasta = case when v_nuevos_fallidos >= 10 then now() + interval '5 minutes' else null end,
        ultimo_intento = now();

  return;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_whatsapp_mensaje_nuevo (
  p_wamid         text,
  p_restaurant_id uuid DEFAULT NULL::uuid
)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_insertadas int;
begin
  if p_wamid is null or p_wamid = '' then
    return true;
  end if;
  -- Limpieza de los de hace más de 3 días.
  delete from whatsapp_mensajes_procesados where recibido_at < now() - interval '3 days';
  insert into whatsapp_mensajes_procesados (wamid, restaurant_id)
  values (p_wamid, p_restaurant_id)
  on conflict (wamid) do nothing;
  get diagnostics v_insertadas = row_count;
  return v_insertadas = 1;
end;
$function$;

REVOKE ALL ON FUNCTION "public"."fn_whatsapp_mensaje_nuevo"(text, uuid) FROM PUBLIC, "anon", "authenticated";

CREATE OR REPLACE FUNCTION public.force_zero_total_on_mesa_insert()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if NEW.tipo = 'mesa' then
    NEW.total := 0;
  end if;
  return NEW;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_session_orders (
  p_session_id uuid,
  p_qr_token   text
)
  RETURNS TABLE (
    order_id                 uuid,
    order_created_at         timestamp with time zone,
    order_estado             text,
    order_total              numeric,
    order_notas              text,
    item_id                  uuid,
    item_nombre              text,
    item_precio              numeric,
    item_cantidad            integer,
    item_notas               text,
    item_modificadores       text,
    item_modificadores_extra numeric
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    o.id, o.created_at, o.estado, o.total, o.notas,
    oi.id, oi.nombre_snapshot, oi.precio_snapshot, oi.cantidad, oi.notas,
    (
      select string_agg(oim.opcion_nombre, ', ' order by oim.grupo_nombre, oim.opcion_nombre)
      from order_item_modificadores oim
      where oim.order_item_id = oi.id
    ) as item_modificadores,
    (
      select coalesce(sum(oim.precio_extra), 0)
      from order_item_modificadores oim
      where oim.order_item_id = oi.id
    ) as item_modificadores_extra
  from orders o
  join table_sessions ts on ts.id = o.table_session_id
  join tables t on t.id = ts.table_id
  left join order_items oi on oi.order_id = o.id
  where o.table_session_id = p_session_id
    and t.qr_token = p_qr_token
    and o.estado != 'cancelado'
  order by o.created_at asc, oi.id asc;
$function$;

CREATE OR REPLACE FUNCTION public.get_table_by_qr (
  p_token text
)
  RETURNS TABLE (
    id            uuid,
    numero        integer,
    zona          text,
    capacidad     integer,
    activa        boolean,
    restaurant_id uuid
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select t.id, t.numero, t.zona, t.capacidad, t.activa, t.restaurant_id
  from tables t
  where t.qr_token = p_token
  limit 1
$function$;

CREATE OR REPLACE FUNCTION public.is_restaurant_owner (
  rid uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    exists (
      select 1 from restaurants r
      where r.id = rid and r.user_id = auth.uid() and coalesce(r.activo, true)
    )
    or exists (
      select 1 from superadmins s
      where s.user_id = auth.uid()
    )
$function$;

CREATE OR REPLACE FUNCTION public.order_is_valid_for_items (
  p_order_id uuid
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1 from orders o
    where o.id = p_order_id
      and o.tipo = 'mesa'
      and o.estado = 'pendiente'
  )
$function$;

CREATE OR REPLACE FUNCTION public.recalc_order_total()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order_id uuid;
  v_total numeric;
begin
  v_order_id := coalesce(NEW.order_id, OLD.order_id);
 
  select coalesce(sum(precio_snapshot * cantidad), 0)
  into v_total
  from order_items
  where order_id = v_order_id;
 
  update orders set total = v_total, updated_at = now()
  where id = v_order_id;
 
  return null;
end;
$function$;

CREATE OR REPLACE FUNCTION public.set_updated_at()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO 'public', 'extensions'
  AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

ALTER TABLE "public"."camarero_pin_intentos"
  ADD CONSTRAINT "camarero_pin_intentos_camarero_id_fkey" FOREIGN KEY (camarero_id) REFERENCES public.camareros(id) ON DELETE CASCADE;

ALTER TABLE "public"."categoria_traducciones"
  ADD CONSTRAINT "categoria_traducciones_category_id_fkey" FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE;

ALTER TABLE "public"."categories"
  ADD CONSTRAINT "categories_categoria_padre_id_fkey" FOREIGN KEY (categoria_padre_id) REFERENCES public.categories(id) ON DELETE SET NULL;

ALTER TABLE "public"."clientes_movimientos"
  ADD CONSTRAINT "clientes_movimientos_cliente_id_fkey" FOREIGN KEY (cliente_id) REFERENCES public.clientes(id) ON DELETE CASCADE;

ALTER TABLE "public"."clientes_sellos"
  ADD CONSTRAINT "clientes_sellos_cliente_id_fkey" FOREIGN KEY (cliente_id) REFERENCES public.clientes(id) ON DELETE CASCADE;

ALTER TABLE "public"."crm_actividades"
  ADD CONSTRAINT "crm_actividades_cuenta_id_fkey" FOREIGN KEY (cuenta_id) REFERENCES public.crm_cuentas(id) ON DELETE CASCADE;

ALTER TABLE "public"."crm_comisiones"
  ADD CONSTRAINT "crm_comisiones_cuenta_id_fkey" FOREIGN KEY (cuenta_id) REFERENCES public.crm_cuentas(id) ON DELETE CASCADE;

ALTER TABLE "public"."crm_historial"
  ADD CONSTRAINT "crm_historial_cuenta_id_fkey" FOREIGN KEY (cuenta_id) REFERENCES public.crm_cuentas(id) ON DELETE CASCADE;

ALTER TABLE "public"."crm_tareas"
  ADD CONSTRAINT "crm_tareas_cuenta_id_fkey" FOREIGN KEY (cuenta_id) REFERENCES public.crm_cuentas(id) ON DELETE CASCADE;

ALTER TABLE "public"."menu_items"
  ADD CONSTRAINT "menu_items_category_id_fkey" FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL;

ALTER TABLE "public"."menu_item_modificador_grupos"
  ADD CONSTRAINT "menu_item_modificador_grupos_menu_item_id_fkey" FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;

ALTER TABLE "public"."menu_item_modificador_precios"
  ADD CONSTRAINT "menu_item_modificador_precios_menu_item_id_fkey" FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;

ALTER TABLE "public"."menu_item_precios_menu"
  ADD CONSTRAINT "menu_item_precios_menu_menu_item_id_fkey" FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;

ALTER TABLE "public"."menu_item_traducciones"
  ADD CONSTRAINT "menu_item_traducciones_menu_item_id_fkey" FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;

ALTER TABLE "public"."menu_item_precios_menu"
  ADD CONSTRAINT "menu_item_precios_menu_menu_id_fkey" FOREIGN KEY (menu_id) REFERENCES public.menus(id) ON DELETE CASCADE;

ALTER TABLE "public"."menu_item_modificador_grupos"
  ADD CONSTRAINT "menu_item_modificador_grupos_grupo_id_fkey" FOREIGN KEY (grupo_id) REFERENCES public.modificador_grupos(id) ON DELETE CASCADE;

ALTER TABLE "public"."modificador_grupo_traducciones"
  ADD CONSTRAINT "modificador_grupo_traducciones_grupo_id_fkey" FOREIGN KEY (grupo_id) REFERENCES public.modificador_grupos(id) ON DELETE CASCADE;

ALTER TABLE "public"."modificador_opciones"
  ADD CONSTRAINT "modificador_opciones_grupo_id_fkey" FOREIGN KEY (grupo_id) REFERENCES public.modificador_grupos(id) ON DELETE CASCADE;

ALTER TABLE "public"."menu_item_modificador_precios"
  ADD CONSTRAINT "menu_item_modificador_precios_opcion_id_fkey" FOREIGN KEY (opcion_id) REFERENCES public.modificador_opciones(id) ON DELETE CASCADE;

ALTER TABLE "public"."modificador_opcion_traducciones"
  ADD CONSTRAINT "modificador_opcion_traducciones_opcion_id_fkey" FOREIGN KEY (opcion_id) REFERENCES public.modificador_opciones(id) ON DELETE CASCADE;

ALTER TABLE "public"."modulos"
  ADD CONSTRAINT "modulos_requiere_fkey" FOREIGN KEY (requiere) REFERENCES public.modulos(key);

ALTER TABLE "public"."order_item_modificadores"
  ADD CONSTRAINT "order_item_modificadores_grupo_id_fkey" FOREIGN KEY (grupo_id) REFERENCES public.modificador_grupos(id) ON DELETE SET NULL;

ALTER TABLE "public"."order_item_modificadores"
  ADD CONSTRAINT "order_item_modificadores_opcion_id_fkey" FOREIGN KEY (opcion_id) REFERENCES public.modificador_opciones(id) ON DELETE SET NULL;

ALTER TABLE "public"."order_items"
  ADD CONSTRAINT "order_items_menu_item_id_fkey" FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE SET NULL;

ALTER TABLE "public"."order_item_modificadores"
  ADD CONSTRAINT "order_item_modificadores_order_item_id_fkey" FOREIGN KEY (order_item_id) REFERENCES public.order_items(id) ON DELETE CASCADE;

ALTER TABLE "public"."clientes_movimientos"
  ADD CONSTRAINT "clientes_movimientos_order_id_fkey" FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE SET NULL;

ALTER TABLE "public"."order_deliveries"
  ADD CONSTRAINT "order_deliveries_order_id_fkey" FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;

ALTER TABLE "public"."order_items"
  ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;

ALTER TABLE "public"."order_sector_confirmaciones"
  ADD CONSTRAINT "order_sector_confirmaciones_order_id_fkey" FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;

ALTER TABLE "public"."orders"
  ADD CONSTRAINT "orders_tomado_por_fkey" FOREIGN KEY (tomado_por) REFERENCES public.camareros(id) ON DELETE SET NULL;

ALTER TABLE "public"."crm_cuentas"
  ADD CONSTRAINT "crm_cuentas_plan_interes_fkey" FOREIGN KEY (plan_interes) REFERENCES public.planes(key);

ALTER TABLE "public"."modulos"
  ADD CONSTRAINT "modulos_plan_fkey" FOREIGN KEY (plan) REFERENCES public.planes(key);

ALTER TABLE "public"."premios_fidelizacion"
  ADD CONSTRAINT "premios_fidelizacion_menu_item_id_fkey" FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;

ALTER TABLE "public"."premios_fidelizacion"
  ADD CONSTRAINT "premios_fidelizacion_nivel_minimo_id_fkey" FOREIGN KEY (nivel_minimo_id) REFERENCES public.niveles_fidelizacion(id) ON DELETE SET NULL;

ALTER TABLE "public"."order_items"
  ADD CONSTRAINT "order_items_premio_canjeado_id_fkey" FOREIGN KEY (premio_canjeado_id) REFERENCES public.premios_fidelizacion(id) ON DELETE SET NULL;

ALTER TABLE "public"."clientes_sellos"
  ADD CONSTRAINT "clientes_sellos_promo_id_fkey" FOREIGN KEY (promo_id) REFERENCES public.promos_sellos(id) ON DELETE CASCADE;

ALTER TABLE "public"."order_items"
  ADD CONSTRAINT "order_items_promo_sello_id_fkey" FOREIGN KEY (promo_sello_id) REFERENCES public.promos_sellos(id) ON DELETE SET NULL;

ALTER TABLE "public"."promos_sellos"
  ADD CONSTRAINT "promos_sellos_producto_objetivo_id_fkey" FOREIGN KEY (producto_objetivo_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;

ALTER TABLE "public"."promos_sellos"
  ADD CONSTRAINT "promos_sellos_producto_premio_id_fkey" FOREIGN KEY (producto_premio_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;

ALTER TABLE "public"."receta_items"
  ADD CONSTRAINT "receta_items_ingrediente_id_fkey" FOREIGN KEY (ingrediente_id) REFERENCES public.ingredientes(id) ON DELETE CASCADE;

ALTER TABLE "public"."receta_items"
  ADD CONSTRAINT "receta_items_menu_item_id_fkey" FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;

ALTER TABLE "public"."restaurant_modulos"
  ADD CONSTRAINT "restaurant_modulos_modulo_key_fkey" FOREIGN KEY (modulo_key) REFERENCES public.modulos(key);

ALTER TABLE "public"."camareros"
  ADD CONSTRAINT "camareros_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."categories"
  ADD CONSTRAINT "categories_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."clientes"
  ADD CONSTRAINT "clientes_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."condiciones_aceptaciones"
  ADD CONSTRAINT "condiciones_aceptaciones_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."crm_comisiones"
  ADD CONSTRAINT "crm_comisiones_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE SET NULL;

ALTER TABLE "public"."crm_cuentas"
  ADD CONSTRAINT "crm_cuentas_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE SET NULL;

ALTER TABLE "public"."ingredientes"
  ADD CONSTRAINT "ingredientes_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."limpieza_pasos"
  ADD CONSTRAINT "limpieza_pasos_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."menu_items"
  ADD CONSTRAINT "menu_items_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."menus"
  ADD CONSTRAINT "menus_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."modificador_grupos"
  ADD CONSTRAINT "modificador_grupos_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."niveles_fidelizacion"
  ADD CONSTRAINT "niveles_fidelizacion_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."order_deliveries"
  ADD CONSTRAINT "order_deliveries_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id);

ALTER TABLE "public"."order_items"
  ADD CONSTRAINT "order_items_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id);

ALTER TABLE "public"."orders"
  ADD CONSTRAINT "orders_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."premios_fidelizacion"
  ADD CONSTRAINT "premios_fidelizacion_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."promos_sellos"
  ADD CONSTRAINT "promos_sellos_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."resenas"
  ADD CONSTRAINT "resenas_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."reservations"
  ADD CONSTRAINT "reservations_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."restaurant_billing"
  ADD CONSTRAINT "restaurant_billing_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."restaurant_info"
  ADD CONSTRAINT "restaurant_info_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."restaurant_modulos"
  ADD CONSTRAINT "restaurant_modulos_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."restaurants"
  ADD CONSTRAINT "restaurants_plan_fkey" FOREIGN KEY (plan) REFERENCES public.planes(key);

ALTER TABLE "public"."restaurants"
  ADD CONSTRAINT "restaurants_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id);

ALTER TABLE "public"."menu_items"
  ADD CONSTRAINT "menu_items_sector_cocina_id_fkey" FOREIGN KEY (sector_cocina_id) REFERENCES public.sectores_cocina(id) ON DELETE SET NULL;

ALTER TABLE "public"."order_sector_confirmaciones"
  ADD CONSTRAINT "order_sector_confirmaciones_sector_cocina_id_fkey" FOREIGN KEY (sector_cocina_id) REFERENCES public.sectores_cocina(id) ON DELETE CASCADE;

ALTER TABLE "public"."sectores_cocina"
  ADD CONSTRAINT "sectores_cocina_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."stock_movimientos"
  ADD CONSTRAINT "stock_movimientos_ingrediente_id_fkey" FOREIGN KEY (ingrediente_id) REFERENCES public.ingredientes(id) ON DELETE CASCADE;

ALTER TABLE "public"."stock_movimientos"
  ADD CONSTRAINT "stock_movimientos_order_id_fkey" FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE SET NULL;

ALTER TABLE "public"."stock_movimientos"
  ADD CONSTRAINT "stock_movimientos_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."superadmins"
  ADD CONSTRAINT "superadmins_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."table_session_payments"
  ADD CONSTRAINT "table_session_payments_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."table_sessions"
  ADD CONSTRAINT "table_sessions_camarero_id_fkey" FOREIGN KEY (camarero_id) REFERENCES public.camareros(id) ON DELETE SET NULL;

ALTER TABLE "public"."clientes_movimientos"
  ADD CONSTRAINT "clientes_movimientos_table_session_id_fkey" FOREIGN KEY (table_session_id) REFERENCES public.table_sessions(id) ON DELETE SET NULL;

ALTER TABLE "public"."orders"
  ADD CONSTRAINT "orders_table_session_id_fkey" FOREIGN KEY (table_session_id) REFERENCES public.table_sessions(id) ON DELETE SET NULL;

ALTER TABLE "public"."resenas"
  ADD CONSTRAINT "resenas_table_session_id_fkey" FOREIGN KEY (table_session_id) REFERENCES public.table_sessions(id) ON DELETE SET NULL;

ALTER TABLE "public"."table_session_payments"
  ADD CONSTRAINT "table_session_payments_table_session_id_fkey" FOREIGN KEY (table_session_id) REFERENCES public.table_sessions(id) ON DELETE CASCADE;

ALTER TABLE "public"."table_sessions"
  ADD CONSTRAINT "table_sessions_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."orders"
  ADD CONSTRAINT "orders_table_id_fkey" FOREIGN KEY (table_id) REFERENCES public.tables(id) ON DELETE SET NULL;

ALTER TABLE "public"."table_sessions"
  ADD CONSTRAINT "table_sessions_table_id_fkey" FOREIGN KEY (table_id) REFERENCES public.tables(id) ON DELETE CASCADE;

ALTER TABLE "public"."tables"
  ADD CONSTRAINT "tables_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."upsell_rules"
  ADD CONSTRAINT "upsell_rules_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."upsell_rules"
  ADD CONSTRAINT "upsell_rules_sugerida_categoria_id_fkey" FOREIGN KEY (sugerida_categoria_id) REFERENCES public.categories(id) ON DELETE CASCADE;

ALTER TABLE "public"."upsell_rules"
  ADD CONSTRAINT "upsell_rules_trigger_item_id_fkey" FOREIGN KEY (trigger_item_id) REFERENCES public.menu_items(id) ON DELETE CASCADE;

ALTER TABLE "public"."upsell_traducciones"
  ADD CONSTRAINT "upsell_traducciones_upsell_rule_id_fkey" FOREIGN KEY (upsell_rule_id) REFERENCES public.upsell_rules(id) ON DELETE CASCADE;

ALTER TABLE "public"."vale_movimientos"
  ADD CONSTRAINT "vale_movimientos_order_id_fkey" FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE SET NULL;

ALTER TABLE "public"."vale_movimientos"
  ADD CONSTRAINT "vale_movimientos_table_session_id_fkey" FOREIGN KEY (table_session_id) REFERENCES public.table_sessions(id) ON DELETE SET NULL;

ALTER TABLE "public"."vale_movimientos"
  ADD CONSTRAINT "vale_movimientos_vale_id_fkey" FOREIGN KEY (vale_id) REFERENCES public.vales_regalo(id) ON DELETE CASCADE;

ALTER TABLE "public"."vales_regalo"
  ADD CONSTRAINT "vales_regalo_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."crm_comisiones"
  ADD CONSTRAINT "crm_comisiones_vendedor_id_fkey" FOREIGN KEY (vendedor_id) REFERENCES public.vendedores(id);

ALTER TABLE "public"."crm_cuentas"
  ADD CONSTRAINT "crm_cuentas_vendedor_id_fkey" FOREIGN KEY (vendedor_id) REFERENCES public.vendedores(id) ON DELETE SET NULL;

ALTER TABLE "public"."vendedores"
  ADD CONSTRAINT "vendedores_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE "public"."waiter_calls"
  ADD CONSTRAINT "waiter_calls_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."waiter_calls"
  ADD CONSTRAINT "waiter_calls_table_id_fkey" FOREIGN KEY (table_id) REFERENCES public.tables(id) ON DELETE CASCADE;

ALTER TABLE "public"."webhook_entregas"
  ADD CONSTRAINT "webhook_entregas_webhook_id_fkey" FOREIGN KEY (webhook_id) REFERENCES public.webhooks(id) ON DELETE CASCADE;

ALTER TABLE "public"."webhooks"
  ADD CONSTRAINT "webhooks_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

ALTER TABLE "public"."whatsapp_sessions"
  ADD CONSTRAINT "whatsapp_sessions_restaurant_id_fkey" FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;

CREATE INDEX categories_restaurant_id_idx ON public.categories USING btree (restaurant_id);

CREATE INDEX crm_actividades_cuenta_idx ON public.crm_actividades USING btree (cuenta_id, fecha DESC);

CREATE INDEX crm_busquedas_created_idx ON public.crm_busquedas USING btree (created_at);

CREATE INDEX crm_comisiones_vendedor_idx ON public.crm_comisiones USING btree (vendedor_id, periodo);

CREATE INDEX crm_cuentas_etapa_idx ON public.crm_cuentas USING btree (etapa);

CREATE UNIQUE INDEX crm_cuentas_google_place_id_key ON public.crm_cuentas USING btree (google_place_id);

CREATE INDEX crm_cuentas_vendedor_idx ON public.crm_cuentas USING btree (vendedor_id);

CREATE INDEX crm_historial_cuenta_idx ON public.crm_historial USING btree (cuenta_id, created_at);

CREATE INDEX crm_tareas_cuenta_idx ON public.crm_tareas USING btree (cuenta_id);

CREATE INDEX idx_orders_table_session ON public.orders USING btree (table_session_id);

CREATE INDEX idx_table_session_payments_restaurant ON public.table_session_payments USING btree (restaurant_id);

CREATE INDEX idx_table_session_payments_session ON public.table_session_payments USING btree (table_session_id);

CREATE INDEX idx_table_sessions_restaurant ON public.table_sessions USING btree (restaurant_id);

CREATE INDEX idx_table_sessions_table_estado ON public.table_sessions USING btree (table_id, estado);

CREATE INDEX menu_items_category_id_idx ON public.menu_items USING btree (category_id);

CREATE INDEX menu_items_restaurant_id_idx ON public.menu_items USING btree (restaurant_id);

CREATE INDEX order_items_order_id_idx ON public.order_items USING btree (order_id);

CREATE INDEX orders_created_at_idx ON public.orders USING btree (created_at);

CREATE INDEX orders_estado_idx ON public.orders USING btree (estado);

CREATE INDEX orders_restaurant_hora_recogida_idx ON public.orders USING btree (restaurant_id, hora_recogida)
  WHERE (hora_recogida IS NOT NULL);

CREATE INDEX orders_restaurant_id_idx ON public.orders USING btree (restaurant_id);

CREATE INDEX reservations_fecha_idx ON public.reservations USING btree (fecha);

CREATE INDEX reservations_restaurant_id_idx ON public.reservations USING btree (restaurant_id);

CREATE INDEX restaurant_info_restaurant_idx ON public.restaurant_info USING btree (restaurant_id, orden);

CREATE UNIQUE INDEX restaurants_subdominio_unique ON public.restaurants USING btree (lower(subdominio))
  WHERE (subdominio IS NOT NULL);

CREATE UNIQUE INDEX restaurants_whatsapp_phone_number_id_unique ON public.restaurants USING btree (whatsapp_phone_number_id)
  WHERE (whatsapp_phone_number_id IS NOT NULL);

CREATE INDEX superadmins_user_id_idx ON public.superadmins USING btree (user_id);

CREATE INDEX tables_restaurant_id_idx ON public.tables USING btree (restaurant_id);

CREATE UNIQUE INDEX uniq_una_sesion_abierta_por_mesa ON public.table_sessions USING btree (table_id)
  WHERE (estado = 'abierta'::text);

CREATE INDEX waiter_calls_estado_idx ON public.waiter_calls USING btree (estado);

CREATE INDEX waiter_calls_restaurant_id_idx ON public.waiter_calls USING btree (restaurant_id);

CREATE INDEX whatsapp_mensajes_procesados_recibido_idx ON public.whatsapp_mensajes_procesados USING btree (recibido_at);

CREATE INDEX whatsapp_sessions_restaurant_id_telefono_idx ON public.whatsapp_sessions USING btree (restaurant_id, telefono);

CREATE UNIQUE INDEX idx_clientes_cache_telefono ON router.clientes_cache USING btree (telefono);

CREATE TRIGGER trg_normalizar_telefono
  BEFORE INSERT OR UPDATE OF telefono ON public.clientes
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trg_normalizar_telefono_cliente();

CREATE TRIGGER trg_crm_actividades_antes
  BEFORE INSERT ON public.crm_actividades
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_crm_actividades_antes();

CREATE TRIGGER trg_crm_actividades_despues
  AFTER INSERT ON public.crm_actividades
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_crm_actividades_despues();

CREATE TRIGGER trg_crm_cuentas_antes
  BEFORE INSERT OR UPDATE ON public.crm_cuentas
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_crm_cuentas_antes();

CREATE TRIGGER trg_crm_cuentas_despues
  AFTER INSERT OR UPDATE ON public.crm_cuentas
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_crm_cuentas_despues();

CREATE TRIGGER trg_asegurar_sector_confirmacion
  AFTER INSERT ON public.order_items
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_asegurar_sector_confirmacion();

CREATE TRIGGER trg_recalc_order_total
  AFTER INSERT OR DELETE OR UPDATE ON public.order_items
  FOR EACH ROW
  EXECUTE FUNCTION public.recalc_order_total();

CREATE TRIGGER trg_restaurante_inactivo
  BEFORE INSERT ON public.order_items
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bloquear_si_restaurante_inactivo();

CREATE TRIGGER orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_force_zero_total
  BEFORE INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.force_zero_total_on_mesa_insert();

CREATE TRIGGER trg_marcar_timestamp_estado_pedido
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_marcar_timestamp_estado_pedido();

CREATE TRIGGER trg_normalizar_telefono
  BEFORE INSERT OR UPDATE OF cliente_telefono ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trg_normalizar_telefono_cliente();

CREATE TRIGGER trg_otorgar_puntos_fidelizacion
  AFTER UPDATE OF estado ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_otorgar_puntos_fidelizacion();

CREATE TRIGGER trg_restaurante_inactivo
  BEFORE INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bloquear_si_restaurante_inactivo();

CREATE TRIGGER trg_validar_modulo_pedido
  BEFORE INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_validar_modulo_pedido();

CREATE TRIGGER trg_webhook_order_placed
  AFTER INSERT ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trigger_webhook_order_placed();

CREATE TRIGGER trg_restaurante_inactivo
  BEFORE INSERT ON public.reservations
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bloquear_si_restaurante_inactivo();

CREATE TRIGGER trg_webhook_reservation_created
  AFTER INSERT ON public.reservations
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trigger_webhook_reservation_created();

CREATE TRIGGER trg_activar_modulo_nucleo
  AFTER INSERT ON public.restaurants
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_activar_modulo_nucleo();

CREATE TRIGGER trg_restaurants_permanencia_alta
  BEFORE INSERT ON public.restaurants
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_restaurants_permanencia_alta();

CREATE TRIGGER trg_restaurants_proteger_comercial_alta
  BEFORE INSERT ON public.restaurants
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_restaurants_proteger_comercial_alta();

CREATE TRIGGER trg_restaurants_proteger_comercial
  BEFORE UPDATE ON public.restaurants
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_restaurants_proteger_comercial();

CREATE TRIGGER trg_restaurante_inactivo
  BEFORE INSERT ON public.table_session_payments
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bloquear_si_restaurante_inactivo();

CREATE TRIGGER trg_webhook_payment_received
  AFTER INSERT ON public.table_session_payments
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trigger_webhook_payment_received();

CREATE TRIGGER trg_normalizar_telefono
  BEFORE INSERT OR UPDATE OF cliente_telefono ON public.table_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trg_normalizar_telefono_cliente();

CREATE TRIGGER trg_otorgar_puntos_mesa
  AFTER UPDATE OF estado ON public.table_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_otorgar_puntos_mesa();

CREATE TRIGGER trg_restaurante_inactivo
  BEFORE INSERT OR UPDATE ON public.table_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bloquear_si_restaurante_inactivo();

CREATE TRIGGER trg_restaurante_inactivo
  BEFORE INSERT ON public.waiter_calls
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bloquear_si_restaurante_inactivo();

CREATE TRIGGER trg_webhook_waiter_call
  AFTER INSERT ON public.waiter_calls
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trigger_webhook_waiter_call();

CREATE TRIGGER sessions_updated_at
  BEFORE UPDATE ON public.whatsapp_sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY "camareros_dueno" ON "public"."camareros"
  FOR ALL
  TO PUBLIC
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "categoria_traducciones_dueno" ON "public"."categoria_traducciones"
  FOR ALL
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM (public.categories c
     JOIN public.restaurants r ON ((r.id = c.restaurant_id)))
  WHERE ((c.id = categoria_traducciones.category_id) AND ((r.user_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM public.superadmins s
          WHERE (s.user_id = auth.uid()))))))));

CREATE POLICY "categoria_traducciones_select_publico" ON "public"."categoria_traducciones"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "anon_select_categories" ON "public"."categories"
  FOR SELECT
  TO "anon"
  USING ((activa = true));

CREATE POLICY "owner_all_categories" ON "public"."categories"
  FOR ALL
  TO "authenticated"
  USING (public.is_restaurant_owner(restaurant_id))
  WITH CHECK (public.is_restaurant_owner(restaurant_id));

CREATE POLICY "clientes_dueno" ON "public"."clientes"
  FOR ALL
  TO PUBLIC
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "clientes_movimientos_dueno" ON "public"."clientes_movimientos"
  FOR ALL
  TO PUBLIC
  USING (((cliente_id IN ( SELECT c.id
   FROM (public.clientes c
     JOIN public.restaurants r ON ((r.id = c.restaurant_id)))
  WHERE (r.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "clientes_sellos_dueno" ON "public"."clientes_sellos"
  FOR SELECT
  TO "authenticated"
  USING (((cliente_id IN ( SELECT c.id
   FROM (public.clientes c
     JOIN public.restaurants r ON ((r.id = c.restaurant_id)))
  WHERE (r.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "condiciones_aceptaciones_select" ON "public"."condiciones_aceptaciones"
  FOR SELECT
  TO "authenticated"
  USING ((public.fn_es_superadmin() OR (EXISTS ( SELECT 1
   FROM public.restaurants r
  WHERE ((r.id = condiciones_aceptaciones.restaurant_id) AND (r.user_id = auth.uid()))))));

CREATE POLICY "crm_actividades_insert" ON "public"."crm_actividades"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (public.fn_crm_cuenta_puede_ver(cuenta_id));

CREATE POLICY "crm_actividades_select" ON "public"."crm_actividades"
  FOR SELECT
  TO "authenticated"
  USING (public.fn_crm_cuenta_puede_ver(cuenta_id));

CREATE POLICY "crm_busquedas_select" ON "public"."crm_busquedas"
  FOR SELECT
  TO "authenticated"
  USING (public.fn_es_superadmin());

CREATE POLICY "crm_comisiones_select" ON "public"."crm_comisiones"
  FOR SELECT
  TO "authenticated"
  USING ((public.fn_es_superadmin() OR (vendedor_id = public.fn_mi_vendedor_id())));

CREATE POLICY "crm_comisiones_superadmin_write" ON "public"."crm_comisiones"
  FOR ALL
  TO "authenticated"
  USING (public.fn_es_superadmin())
  WITH CHECK (public.fn_es_superadmin());

CREATE POLICY "crm_config_select" ON "public"."crm_config"
  FOR SELECT
  TO "authenticated"
  USING ((public.fn_es_superadmin() OR (public.fn_mi_vendedor_id() IS NOT NULL)));

CREATE POLICY "crm_config_update" ON "public"."crm_config"
  FOR UPDATE
  TO "authenticated"
  USING (public.fn_es_superadmin())
  WITH CHECK (public.fn_es_superadmin());

CREATE POLICY "crm_cuentas_delete" ON "public"."crm_cuentas"
  FOR DELETE
  TO "authenticated"
  USING (public.fn_es_superadmin());

CREATE POLICY "crm_cuentas_insert" ON "public"."crm_cuentas"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((public.fn_es_superadmin() OR (vendedor_id = public.fn_mi_vendedor_id())));

CREATE POLICY "crm_cuentas_select" ON "public"."crm_cuentas"
  FOR SELECT
  TO "authenticated"
  USING ((public.fn_es_superadmin() OR (vendedor_id = public.fn_mi_vendedor_id())));

CREATE POLICY "crm_cuentas_update" ON "public"."crm_cuentas"
  FOR UPDATE
  TO "authenticated"
  USING ((public.fn_es_superadmin() OR (vendedor_id = public.fn_mi_vendedor_id())))
  WITH CHECK ((public.fn_es_superadmin() OR (vendedor_id = public.fn_mi_vendedor_id())));

CREATE POLICY "crm_historial_select" ON "public"."crm_historial"
  FOR SELECT
  TO "authenticated"
  USING (public.fn_crm_cuenta_puede_ver(cuenta_id));

CREATE POLICY "crm_tareas_all" ON "public"."crm_tareas"
  FOR ALL
  TO "authenticated"
  USING (public.fn_crm_cuenta_puede_ver(cuenta_id))
  WITH CHECK (public.fn_crm_cuenta_puede_ver(cuenta_id));

CREATE POLICY "ingredientes_dueno" ON "public"."ingredientes"
  FOR ALL
  TO PUBLIC
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "limpieza_pasos_dueno" ON "public"."limpieza_pasos"
  FOR ALL
  TO "authenticated"
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "limpieza_pasos_select_publico" ON "public"."limpieza_pasos"
  FOR SELECT
  TO PUBLIC
  USING ((activo = true));

CREATE POLICY "menu_item_modificador_grupos_dueno" ON "public"."menu_item_modificador_grupos"
  FOR ALL
  TO "authenticated"
  USING (((menu_item_id IN ( SELECT mi.id
   FROM (public.menu_items mi
     JOIN public.restaurants r ON ((r.id = mi.restaurant_id)))
  WHERE (r.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "menu_item_modificador_grupos_select_publico" ON "public"."menu_item_modificador_grupos"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "menu_item_modificador_precios_dueno" ON "public"."menu_item_modificador_precios"
  FOR ALL
  TO "authenticated"
  USING (((menu_item_id IN ( SELECT mi.id
   FROM (public.menu_items mi
     JOIN public.restaurants r ON ((r.id = mi.restaurant_id)))
  WHERE (r.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "menu_item_modificador_precios_select_publico" ON "public"."menu_item_modificador_precios"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "menu_item_precios_menu_dueno" ON "public"."menu_item_precios_menu"
  FOR ALL
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.menus m
  WHERE ((m.id = menu_item_precios_menu.menu_id) AND ((m.restaurant_id IN ( SELECT restaurants.id
           FROM public.restaurants
          WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
           FROM public.superadmins s
          WHERE (s.user_id = auth.uid()))))))));

CREATE POLICY "menu_item_precios_menu_select_publico" ON "public"."menu_item_precios_menu"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "menu_item_traducciones_dueno" ON "public"."menu_item_traducciones"
  FOR ALL
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM (public.menu_items mi
     JOIN public.restaurants r ON ((r.id = mi.restaurant_id)))
  WHERE ((mi.id = menu_item_traducciones.menu_item_id) AND ((r.user_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM public.superadmins s
          WHERE (s.user_id = auth.uid()))))))));

CREATE POLICY "menu_item_traducciones_select_publico" ON "public"."menu_item_traducciones"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "anon_select_menu_items" ON "public"."menu_items"
  FOR SELECT
  TO "anon"
  USING ((disponible = true));

CREATE POLICY "owner_all_menu_items" ON "public"."menu_items"
  FOR ALL
  TO "authenticated"
  USING (public.is_restaurant_owner(restaurant_id))
  WITH CHECK (public.is_restaurant_owner(restaurant_id));

CREATE POLICY "menus_dueno" ON "public"."menus"
  FOR ALL
  TO "authenticated"
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "menus_select_publico" ON "public"."menus"
  FOR SELECT
  TO PUBLIC
  USING ((activo = true));

CREATE POLICY "modificador_grupo_traducciones_dueno" ON "public"."modificador_grupo_traducciones"
  FOR ALL
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM (public.modificador_grupos g
     JOIN public.restaurants r ON ((r.id = g.restaurant_id)))
  WHERE ((g.id = modificador_grupo_traducciones.grupo_id) AND ((r.user_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM public.superadmins s
          WHERE (s.user_id = auth.uid()))))))));

CREATE POLICY "modificador_grupo_traducciones_select_publico" ON "public"."modificador_grupo_traducciones"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "modificador_grupos_dueno" ON "public"."modificador_grupos"
  FOR ALL
  TO "authenticated"
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "modificador_grupos_select_publico" ON "public"."modificador_grupos"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "modificador_opcion_traducciones_dueno" ON "public"."modificador_opcion_traducciones"
  FOR ALL
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM ((public.modificador_opciones o
     JOIN public.modificador_grupos g ON ((g.id = o.grupo_id)))
     JOIN public.restaurants r ON ((r.id = g.restaurant_id)))
  WHERE ((o.id = modificador_opcion_traducciones.opcion_id) AND ((r.user_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM public.superadmins s
          WHERE (s.user_id = auth.uid()))))))));

CREATE POLICY "modificador_opcion_traducciones_select_publico" ON "public"."modificador_opcion_traducciones"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "modificador_opciones_dueno" ON "public"."modificador_opciones"
  FOR ALL
  TO "authenticated"
  USING (((grupo_id IN ( SELECT mg.id
   FROM (public.modificador_grupos mg
     JOIN public.restaurants r ON ((r.id = mg.restaurant_id)))
  WHERE (r.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "modificador_opciones_select_publico" ON "public"."modificador_opciones"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "modulos_select_publico" ON "public"."modulos"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "niveles_fidelizacion_dueno" ON "public"."niveles_fidelizacion"
  FOR ALL
  TO PUBLIC
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "order_deliveries_by_restaurant" ON "public"."order_deliveries"
  FOR ALL
  TO PUBLIC
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "order_item_modificadores_por_restaurante" ON "public"."order_item_modificadores"
  FOR ALL
  TO PUBLIC
  USING (((order_item_id IN ( SELECT oi.id
   FROM ((public.order_items oi
     JOIN public.orders o ON ((o.id = oi.order_id)))
     JOIN public.restaurants r ON ((r.id = o.restaurant_id)))
  WHERE (r.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "anon_insert_order_items" ON "public"."order_items"
  FOR INSERT
  TO "anon"
  WITH CHECK ((public.order_is_valid_for_items(order_id) AND (menu_item_id IS NOT NULL) AND ((cantidad >= 1) AND (cantidad <= 50)) AND (EXISTS ( SELECT 1
   FROM public.menu_items mi
  WHERE ((mi.id = order_items.menu_item_id) AND (mi.disponible = true) AND (mi.precio = order_items.precio_snapshot))))));

CREATE POLICY "owner_all_order_items" ON "public"."order_items"
  FOR ALL
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.orders o
  WHERE ((o.id = order_items.order_id) AND public.is_restaurant_owner(o.restaurant_id)))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.orders o
  WHERE ((o.id = order_items.order_id) AND public.is_restaurant_owner(o.restaurant_id)))));

CREATE POLICY "order_sector_confirmaciones_por_restaurante" ON "public"."order_sector_confirmaciones"
  FOR ALL
  TO PUBLIC
  USING (((order_id IN ( SELECT o.id
   FROM (public.orders o
     JOIN public.restaurants r ON ((r.id = o.restaurant_id)))
  WHERE (r.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "anon_insert_orders_mesa" ON "public"."orders"
  FOR INSERT
  TO "anon"
  WITH CHECK (((tipo = 'mesa'::text) AND (estado = 'pendiente'::text) AND (table_session_id IS NOT NULL) AND (table_id IS NOT NULL) AND (restaurant_id IS
    NOT NULL) AND (EXISTS ( SELECT 1
   FROM public.table_sessions ts
  WHERE ((ts.id = orders.table_session_id) AND (ts.table_id = orders.table_id) AND (ts.restaurant_id = orders.restaurant_id) AND (ts.estado = 'abierta'::text))))));

CREATE POLICY "owner_all_orders" ON "public"."orders"
  FOR ALL
  TO "authenticated"
  USING (public.is_restaurant_owner(restaurant_id))
  WITH CHECK (public.is_restaurant_owner(restaurant_id));

CREATE POLICY "planes_select" ON "public"."planes"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "planes_superadmin_write" ON "public"."planes"
  FOR ALL
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid()))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid()))));

CREATE POLICY "premios_fidelizacion_dueno" ON "public"."premios_fidelizacion"
  FOR ALL
  TO PUBLIC
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "promos_sellos_dueno" ON "public"."promos_sellos"
  FOR ALL
  TO "authenticated"
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "receta_items_dueno" ON "public"."receta_items"
  FOR ALL
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM (public.menu_items mi
     JOIN public.restaurants r ON ((r.id = mi.restaurant_id)))
  WHERE ((mi.id = receta_items.menu_item_id) AND ((r.user_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM public.superadmins s
          WHERE (s.user_id = auth.uid()))))))));

CREATE POLICY "resenas_dueno" ON "public"."resenas"
  FOR SELECT
  TO PUBLIC
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "reservations_dueno" ON "public"."reservations"
  FOR ALL
  TO PUBLIC
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "restaurant_billing_superadmin_only" ON "public"."restaurant_billing"
  FOR ALL
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid()))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid()))));

CREATE POLICY "restaurant_info_dueno" ON "public"."restaurant_info"
  FOR ALL
  TO "authenticated"
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))))
  WITH CHECK ((((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) AND (EXISTS ( SELECT 1
   FROM public.restaurant_modulos rm
  WHERE ((rm.restaurant_id = restaurant_info.restaurant_id) AND (rm.modulo_key = 'info_restaurante'::text) AND (rm.activo = true))))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "restaurant_modulos_select" ON "public"."restaurant_modulos"
  FOR SELECT
  TO PUBLIC
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "restaurant_modulos_update" ON "public"."restaurant_modulos"
  FOR UPDATE
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid()))));

CREATE POLICY "restaurant_modulos_write" ON "public"."restaurant_modulos"
  FOR INSERT
  TO PUBLIC
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid()))));

CREATE POLICY "anon_select_restaurants" ON "public"."restaurants"
  FOR SELECT
  TO "anon"
  USING (true);

CREATE POLICY "owner_all_restaurants" ON "public"."restaurants"
  FOR ALL
  TO "authenticated"
  USING (public.is_restaurant_owner(id))
  WITH CHECK (public.is_restaurant_owner(id));

CREATE POLICY "restaurants_select_publico" ON "public"."restaurants"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "superadmin_insert_restaurants" ON "public"."restaurants"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid()))));

CREATE POLICY "sectores_cocina_dueno" ON "public"."sectores_cocina"
  FOR ALL
  TO PUBLIC
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "sectores_cocina_select_publico" ON "public"."sectores_cocina"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "stock_movimientos_dueno" ON "public"."stock_movimientos"
  FOR ALL
  TO PUBLIC
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "self_select_superadmins" ON "public"."superadmins"
  FOR SELECT
  TO "authenticated"
  USING ((user_id = auth.uid()));

CREATE POLICY "owner_all_table_session_payments" ON "public"."table_session_payments"
  FOR ALL
  TO "authenticated"
  USING (public.is_restaurant_owner(restaurant_id))
  WITH CHECK (public.is_restaurant_owner(restaurant_id));

CREATE POLICY "owner_all_table_sessions" ON "public"."table_sessions"
  FOR ALL
  TO "authenticated"
  USING (public.is_restaurant_owner(restaurant_id))
  WITH CHECK (public.is_restaurant_owner(restaurant_id));

CREATE POLICY "anon_select_tables" ON "public"."tables"
  FOR SELECT
  TO "anon"
  USING (true);

CREATE POLICY "owner_all_tables" ON "public"."tables"
  FOR ALL
  TO "authenticated"
  USING (public.is_restaurant_owner(restaurant_id))
  WITH CHECK (public.is_restaurant_owner(restaurant_id));

CREATE POLICY "upsell_rules_dueno" ON "public"."upsell_rules"
  FOR ALL
  TO "authenticated"
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "upsell_rules_select_publico" ON "public"."upsell_rules"
  FOR SELECT
  TO PUBLIC
  USING ((activa = true));

CREATE POLICY "upsell_traducciones_dueno" ON "public"."upsell_traducciones"
  FOR ALL
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM (public.upsell_rules u
     JOIN public.restaurants r ON ((r.id = u.restaurant_id)))
  WHERE ((u.id = upsell_traducciones.upsell_rule_id) AND ((r.user_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM public.superadmins s
          WHERE (s.user_id = auth.uid()))))))));

CREATE POLICY "upsell_traducciones_select_publico" ON "public"."upsell_traducciones"
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY "vale_movimientos_dueno" ON "public"."vale_movimientos"
  FOR ALL
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM (public.vales_regalo v
     JOIN public.restaurants r ON ((r.id = v.restaurant_id)))
  WHERE ((v.id = vale_movimientos.vale_id) AND ((r.user_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM public.superadmins s
          WHERE (s.user_id = auth.uid()))))))));

CREATE POLICY "vales_regalo_dueno" ON "public"."vales_regalo"
  FOR ALL
  TO PUBLIC
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "vendedores_select" ON "public"."vendedores"
  FOR SELECT
  TO "authenticated"
  USING ((public.fn_es_superadmin() OR (user_id = auth.uid())));

CREATE POLICY "vendedores_superadmin_write" ON "public"."vendedores"
  FOR ALL
  TO "authenticated"
  USING (public.fn_es_superadmin())
  WITH CHECK (public.fn_es_superadmin());

CREATE POLICY "anon_insert_waiter_calls" ON "public"."waiter_calls"
  FOR INSERT
  TO "anon"
  WITH CHECK (((estado = 'pendiente'::text) AND (EXISTS ( SELECT 1
   FROM public.tables t
  WHERE ((t.id = waiter_calls.table_id) AND (t.restaurant_id = waiter_calls.restaurant_id) AND (t.activa = true))))));

CREATE POLICY "owner_all_waiter_calls" ON "public"."waiter_calls"
  FOR ALL
  TO "authenticated"
  USING (public.is_restaurant_owner(restaurant_id))
  WITH CHECK (public.is_restaurant_owner(restaurant_id));

CREATE POLICY "webhook_entregas_dueno" ON "public"."webhook_entregas"
  FOR ALL
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM (public.webhooks w
     JOIN public.restaurants r ON ((r.id = w.restaurant_id)))
  WHERE ((w.id = webhook_entregas.webhook_id) AND ((r.user_id = auth.uid()) OR (EXISTS ( SELECT 1
           FROM public.superadmins s
          WHERE (s.user_id = auth.uid()))))))));

CREATE POLICY "webhooks_dueno" ON "public"."webhooks"
  FOR ALL
  TO PUBLIC
  USING (((restaurant_id IN ( SELECT restaurants.id
   FROM public.restaurants
  WHERE (restaurants.user_id = auth.uid()))) OR (EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid())))));

CREATE POLICY "actualizacion autenticada menu-images" ON "storage"."objects"
  FOR UPDATE
  TO PUBLIC
  USING (((bucket_id = 'menu-images'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "eliminacion autenticada menu-images" ON "storage"."objects"
  FOR DELETE
  TO PUBLIC
  USING (((bucket_id = 'menu-images'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "subida autenticada menu-images" ON "storage"."objects"
  FOR INSERT
  TO PUBLIC
  WITH CHECK (((bucket_id = 'menu-images'::text) AND (auth.role() = 'authenticated'::text)));

CREATE POLICY "owner_delete_menu_images" ON "storage"."objects"
  FOR DELETE
  TO "authenticated"
  USING (((bucket_id = 'menu-images'::text) AND public.is_restaurant_owner(((storage.foldername(name))[1])::uuid)));

CREATE POLICY "owner_update_menu_images" ON "storage"."objects"
  FOR UPDATE
  TO "authenticated"
  USING (((bucket_id = 'menu-images'::text) AND public.is_restaurant_owner(((storage.foldername(name))[1])::uuid)));

CREATE POLICY "owner_upload_menu_images" ON "storage"."objects"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((bucket_id = 'menu-images'::text) AND public.is_restaurant_owner(((storage.foldername(name))[1])::uuid)));

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."categories";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."menu_items";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."order_deliveries";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."order_items";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."order_sector_confirmaciones";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."orders";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."reservations";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."table_session_payments";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."table_sessions";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."tables";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."waiter_calls";

COMMENT ON EXTENSION "pg_net" IS 'Async HTTP';

GRANT EXECUTE ON FUNCTION "public"."fn_aceptar_condiciones"(uuid, text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_aceptar_condiciones"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_aceptar_condiciones"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_aceptar_condiciones"(uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_activar_modulo_nucleo"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_activar_modulo_nucleo"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_activar_modulo_nucleo"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_activar_modulo_nucleo"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_actualizar_precio_contrato"(uuid, numeric) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_actualizar_precio_contrato"(uuid, numeric) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_actualizar_precio_contrato"(uuid, numeric) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_actualizar_precio_contrato"(uuid, numeric) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_ahora_madrid"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_ahora_madrid"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_ahora_madrid"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_ahora_madrid"() TO "service_role";

REVOKE ALL ON FUNCTION "public"."fn_aplicar_descuento"(uuid, numeric, integer) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."fn_aplicar_descuento"(uuid, numeric, integer) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_aplicar_descuento"(uuid, numeric, integer) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_aplicar_descuento"(uuid, numeric, integer) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_aplicar_descuento"(uuid, numeric, integer) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_asegurar_sector_confirmacion"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_asegurar_sector_confirmacion"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_asegurar_sector_confirmacion"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_asegurar_sector_confirmacion"() TO "service_role";

REVOKE ALL ON FUNCTION "public"."fn_asignar_modulo_a_plan"(text, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."fn_asignar_modulo_a_plan"(text, text) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_asignar_modulo_a_plan"(text, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_asignar_modulo_a_plan"(text, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_asignar_modulo_a_plan"(text, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_asignar_plan"(uuid, text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_asignar_plan"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_asignar_plan"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_asignar_plan"(uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_bloquear_si_restaurante_inactivo"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_bloquear_si_restaurante_inactivo"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_bloquear_si_restaurante_inactivo"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_bloquear_si_restaurante_inactivo"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_abrir_mesa"(uuid, uuid, uuid, integer) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_camarero_abrir_mesa"(uuid, uuid, uuid, integer) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_abrir_mesa"(uuid, uuid, uuid, integer) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_abrir_mesa"(uuid, uuid, uuid, integer) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_editar_cliente_sesion"(uuid, uuid, uuid, text, text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_camarero_editar_cliente_sesion"(uuid, uuid, uuid, text, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_editar_cliente_sesion"(uuid, uuid, uuid, text, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_editar_cliente_sesion"(uuid, uuid, uuid, text, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_listar_pedidos_sesion"(uuid, uuid, uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_camarero_listar_pedidos_sesion"(uuid, uuid, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_listar_pedidos_sesion"(uuid, uuid, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_listar_pedidos_sesion"(uuid, uuid, uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_listar_sesiones"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_camarero_listar_sesiones"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_listar_sesiones"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_listar_sesiones"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_toggle_limpieza"(uuid, uuid, uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_camarero_toggle_limpieza"(uuid, uuid, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_toggle_limpieza"(uuid, uuid, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_toggle_limpieza"(uuid, uuid, uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_tomar_mesa"(uuid, uuid, uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_camarero_tomar_mesa"(uuid, uuid, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_tomar_mesa"(uuid, uuid, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_camarero_tomar_mesa"(uuid, uuid, uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_canjear_vale_regalo"(uuid, text, numeric) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_canjear_vale_regalo"(uuid, text, numeric) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_canjear_vale_regalo"(uuid, text, numeric) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_canjear_vale_regalo"(uuid, text, numeric) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_carta_takeaway"(uuid, timestamp WITH time zone) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_carta_takeaway"(uuid, timestamp WITH time zone) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_carta_takeaway"(uuid, timestamp WITH time zone) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_carta_takeaway"(uuid, timestamp WITH time zone) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_condiciones_pendientes"(uuid, text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_condiciones_pendientes"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_condiciones_pendientes"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_condiciones_pendientes"(uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_consultar_vale"(uuid, text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_consultar_vale"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_consultar_vale"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_consultar_vale"(uuid, text) TO "service_role";

REVOKE ALL ON FUNCTION "public"."fn_crear_camarero"(uuid, text, text, text[]) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."fn_crear_camarero"(uuid, text, text, text[]) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crear_camarero"(uuid, text, text, text[]) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crear_camarero"(uuid, text, text, text[]) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crear_camarero"(uuid, text, text, text[]) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crear_reserva_web"(uuid, text, text, date, time WITHOUT time zone, integer, text, text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crear_reserva_web"(uuid, text, text, date, time WITHOUT time zone, integer, text, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crear_reserva_web"(uuid, text, text, date, time WITHOUT time zone, integer, text, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crear_reserva_web"(uuid, text, text, date, time WITHOUT time zone, integer, text, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_actividades_antes"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_actividades_antes"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_actividades_antes"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_actividades_antes"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_actividades_despues"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_actividades_despues"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_actividades_despues"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_actividades_despues"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_busqueda_cargar"(uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_busqueda_cargar"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_busqueda_cargar"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_busqueda_cargar"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_busquedas_recientes"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_busquedas_recientes"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_busquedas_recientes"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_busquedas_recientes"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_cuenta_puede_ver"(uuid) TO PUBLIC, "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_cuenta_puede_ver"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_cuenta_puede_ver"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_cuenta_puede_ver"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_cuentas_antes"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_cuentas_antes"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_cuentas_antes"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_cuentas_antes"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_cuentas_despues"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_cuentas_despues"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_cuentas_despues"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_cuentas_despues"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_cuota_restaurante"(uuid, date) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_cuota_restaurante"(uuid, date) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_cuota_restaurante"(uuid, date) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_cuota_restaurante"(uuid, date) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_duplicados"(jsonb) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_duplicados"(jsonb) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_duplicados"(jsonb) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_duplicados"(jsonb) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_generar_comisiones"(date) TO PUBLIC, "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_generar_comisiones"(date) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_generar_comisiones"(date) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_generar_comisiones"(date) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_importar_restaurantes"() TO PUBLIC, "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_importar_restaurantes"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_importar_restaurantes"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_importar_restaurantes"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_permanencias"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_permanencias"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_permanencias"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_permanencias"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_puede_buscar"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_puede_buscar"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_puede_buscar"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_puede_buscar"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_registrar_busqueda"(jsonb, integer, integer, jsonb) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_registrar_busqueda"(jsonb, integer, integer, jsonb) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_registrar_busqueda"(jsonb, integer, integer, jsonb) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_registrar_busqueda"(jsonb, integer, integer, jsonb) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_restaurantes_cuentas"() TO PUBLIC, "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_restaurantes_cuentas"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_restaurantes_cuentas"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_restaurantes_cuentas"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_uso_places"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_uso_places"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_uso_places"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_uso_places"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_vendedor_cambiar_password"(uuid, text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_crm_vendedor_cambiar_password"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_vendedor_cambiar_password"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_crm_vendedor_cambiar_password"(uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_dar_baja_restaurante"(uuid, text, boolean) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_dar_baja_restaurante"(uuid, text, boolean) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_dar_baja_restaurante"(uuid, text, boolean) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_dar_baja_restaurante"(uuid, text, boolean) TO "service_role";

REVOKE ALL ON FUNCTION "public"."fn_disparar_webhooks"(uuid, text, jsonb) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_disparar_webhooks"(uuid, text, jsonb) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_disparar_webhooks"(uuid, text, jsonb) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_es_superadmin"() TO PUBLIC, "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_es_superadmin"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_es_superadmin"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_es_superadmin"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_estado_fidelizacion"(uuid, text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_estado_fidelizacion"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_estado_fidelizacion"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_estado_fidelizacion"(uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_estado_sesion_mesa"(uuid, text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_estado_sesion_mesa"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_estado_sesion_mesa"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_estado_sesion_mesa"(uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_hora_madrid"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_hora_madrid"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_hora_madrid"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_hora_madrid"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_hoy_madrid"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_hoy_madrid"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_hoy_madrid"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_hoy_madrid"() TO "service_role";

REVOKE ALL ON FUNCTION "public"."fn_info_restaurante_publica"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."fn_info_restaurante_publica"(uuid) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_info_restaurante_publica"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_info_restaurante_publica"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_info_restaurante_publica"(uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."fn_iniciar_trial"(uuid, integer) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."fn_iniciar_trial"(uuid, integer) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_iniciar_trial"(uuid, integer) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_iniciar_trial"(uuid, integer) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_iniciar_trial"(uuid, integer) TO "service_role";

REVOKE ALL ON FUNCTION "public"."fn_limpiar_descuento"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."fn_limpiar_descuento"(uuid) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_limpiar_descuento"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_limpiar_descuento"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_limpiar_descuento"(uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."fn_limpiar_trial"(uuid) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."fn_limpiar_trial"(uuid) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_limpiar_trial"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_limpiar_trial"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_limpiar_trial"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_listar_camareros_nombres"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_listar_camareros_nombres"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_listar_camareros_nombres"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_listar_camareros_nombres"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_marcar_timestamp_estado_pedido"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_marcar_timestamp_estado_pedido"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_marcar_timestamp_estado_pedido"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_marcar_timestamp_estado_pedido"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_menu_activo"(uuid, text, timestamp WITH time zone, boolean) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_menu_activo"(uuid, text, timestamp WITH time zone, boolean) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_menu_activo"(uuid, text, timestamp WITH time zone, boolean) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_menu_activo"(uuid, text, timestamp WITH time zone, boolean) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_mi_restaurante"() TO PUBLIC, "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_mi_restaurante"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_mi_restaurante"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_mi_restaurante"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_mi_vendedor_id"() TO PUBLIC, "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_mi_vendedor_id"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_mi_vendedor_id"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_mi_vendedor_id"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_normalizar_telefono"(text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_normalizar_telefono"(text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_normalizar_telefono"(text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_normalizar_telefono"(text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_otorgar_puntos_fidelizacion"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_otorgar_puntos_fidelizacion"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_otorgar_puntos_fidelizacion"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_otorgar_puntos_fidelizacion"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_otorgar_puntos_mesa"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_otorgar_puntos_mesa"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_otorgar_puntos_mesa"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_otorgar_puntos_mesa"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_permanencia_penalizacion"(uuid, date) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_permanencia_penalizacion"(uuid, date) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_permanencia_penalizacion"(uuid, date) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_permanencia_penalizacion"(uuid, date) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_procesar_sellos"(uuid, uuid, jsonb) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_procesar_sellos"(uuid, uuid, jsonb) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_procesar_sellos"(uuid, uuid, jsonb) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_procesar_sellos"(uuid, uuid, jsonb) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_registrar_cliente_sesion"(uuid, text, text, text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_registrar_cliente_sesion"(uuid, text, text, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_registrar_cliente_sesion"(uuid, text, text, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_registrar_cliente_sesion"(uuid, text, text, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_registrar_pedido"(uuid, jsonb, text, uuid, jsonb, text, numeric) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_registrar_pedido"(uuid, jsonb, text, uuid, jsonb, text, numeric) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_registrar_pedido"(uuid, jsonb, text, uuid, jsonb, text, numeric) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_registrar_pedido"(uuid, jsonb, text, uuid, jsonb, text, numeric) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_registrar_resena"(uuid, text, integer, text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_registrar_resena"(uuid, text, integer, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_registrar_resena"(uuid, text, integer, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_registrar_resena"(uuid, text, integer, text) TO "service_role";

REVOKE ALL ON FUNCTION "public"."fn_reserva_cliente_bloquear"(uuid, text, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_cliente_bloquear"(uuid, text, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_cliente_bloquear"(uuid, text, uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."fn_reserva_cliente_cancelar"(uuid, text, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_cliente_cancelar"(uuid, text, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_cliente_cancelar"(uuid, text, uuid) TO "service_role";

REVOKE ALL ON FUNCTION "public"."fn_reserva_cliente_modificar"(uuid, text, uuid, date, time WITHOUT time zone, integer, text, integer, boolean) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_cliente_modificar"(uuid, text, uuid, date, time WITHOUT time zone, integer, text, integer, boolean) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_cliente_modificar"(uuid, text, uuid, date, time WITHOUT time zone, integer, text, integer, boolean) TO "service_role";

REVOKE ALL ON FUNCTION "public"."fn_reserva_contexto_cliente"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_contexto_cliente"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_contexto_cliente"(uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_fuera_de_horario"(uuid, date, time WITHOUT time zone) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_reserva_fuera_de_horario"(uuid, date, time WITHOUT time zone) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_fuera_de_horario"(uuid, date, time WITHOUT time zone) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_fuera_de_horario"(uuid, date, time WITHOUT time zone) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_hay_mesa"(uuid, date, time WITHOUT time zone, integer, text, integer) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_reserva_hay_mesa"(uuid, date, time WITHOUT time zone, integer, text, integer) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_hay_mesa"(uuid, date, time WITHOUT time zone, integer, text, integer) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_hay_mesa"(uuid, date, time WITHOUT time zone, integer, text, integer) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_whatsapp_crear"(uuid, text, text, date, time WITHOUT time zone, integer, text, text, integer) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_reserva_whatsapp_crear"(uuid, text, text, date, time WITHOUT time zone, integer, text, text, integer) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_whatsapp_crear"(uuid, text, text, date, time WITHOUT time zone, integer, text, text, integer) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_reserva_whatsapp_crear"(uuid, text, text, date, time WITHOUT time zone, integer, text, text, integer) TO "service_role";

REVOKE ALL ON FUNCTION "public"."fn_resetear_pin_camarero"(uuid, uuid, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION "public"."fn_resetear_pin_camarero"(uuid, uuid, text) TO "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_resetear_pin_camarero"(uuid, uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_resetear_pin_camarero"(uuid, uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_resetear_pin_camarero"(uuid, uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurante_accesible"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_restaurante_accesible"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurante_accesible"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurante_accesible"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurante_activo"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_restaurante_activo"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurante_activo"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurante_activo"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurants_permanencia_alta"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_restaurants_permanencia_alta"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurants_permanencia_alta"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurants_permanencia_alta"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurants_proteger_comercial"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_restaurants_proteger_comercial"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurants_proteger_comercial"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurants_proteger_comercial"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurants_proteger_comercial_alta"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_restaurants_proteger_comercial_alta"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurants_proteger_comercial_alta"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_restaurants_proteger_comercial_alta"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_sesion_abierta_por_token"(text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_sesion_abierta_por_token"(text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_sesion_abierta_por_token"(text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_sesion_abierta_por_token"(text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_cambiar_estado_pedido"(uuid, uuid, uuid, text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_staff_cambiar_estado_pedido"(uuid, uuid, uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_cambiar_estado_pedido"(uuid, uuid, uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_cambiar_estado_pedido"(uuid, uuid, uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_cambiar_estado_reserva"(uuid, uuid, uuid, text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_staff_cambiar_estado_reserva"(uuid, uuid, uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_cambiar_estado_reserva"(uuid, uuid, uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_cambiar_estado_reserva"(uuid, uuid, uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_canjear_puntos"(uuid, uuid, uuid, integer, text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_staff_canjear_puntos"(uuid, uuid, uuid, integer, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_canjear_puntos"(uuid, uuid, uuid, integer, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_canjear_puntos"(uuid, uuid, uuid, integer, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_contar_alertas"(uuid, uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_staff_contar_alertas"(uuid, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_contar_alertas"(uuid, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_contar_alertas"(uuid, uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_crear_reserva_manual"(uuid, uuid, text, text, date, time WITHOUT time zone, integer, text, text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_staff_crear_reserva_manual"(uuid, uuid, text, text, date, time WITHOUT time zone, integer, text, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_crear_reserva_manual"(uuid, uuid, text, text, date, time WITHOUT time zone, integer, text, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_crear_reserva_manual"(uuid, uuid, text, text, date, time WITHOUT time zone, integer, text, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_historial_cliente"(uuid, uuid, uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_staff_historial_cliente"(uuid, uuid, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_historial_cliente"(uuid, uuid, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_historial_cliente"(uuid, uuid, uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_listar_clientes"(uuid, uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_staff_listar_clientes"(uuid, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_listar_clientes"(uuid, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_listar_clientes"(uuid, uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_listar_llamadas"(uuid, uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_staff_listar_llamadas"(uuid, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_listar_llamadas"(uuid, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_listar_llamadas"(uuid, uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_listar_pedidos_cocina"(uuid, uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_staff_listar_pedidos_cocina"(uuid, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_listar_pedidos_cocina"(uuid, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_listar_pedidos_cocina"(uuid, uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_listar_reservas"(uuid, uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_staff_listar_reservas"(uuid, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_listar_reservas"(uuid, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_listar_reservas"(uuid, uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_marcar_llamada_atendida"(uuid, uuid, uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_staff_marcar_llamada_atendida"(uuid, uuid, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_marcar_llamada_atendida"(uuid, uuid, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_marcar_llamada_atendida"(uuid, uuid, uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_tiene_permiso"(uuid, uuid, text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_staff_tiene_permiso"(uuid, uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_tiene_permiso"(uuid, uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_staff_tiene_permiso"(uuid, uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_trg_normalizar_telefono_cliente"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_trg_normalizar_telefono_cliente"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_trg_normalizar_telefono_cliente"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_trg_normalizar_telefono_cliente"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_trigger_webhook_order_placed"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_trigger_webhook_order_placed"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_trigger_webhook_order_placed"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_trigger_webhook_order_placed"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_trigger_webhook_payment_received"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_trigger_webhook_payment_received"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_trigger_webhook_payment_received"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_trigger_webhook_payment_received"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_trigger_webhook_reservation_created"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_trigger_webhook_reservation_created"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_trigger_webhook_reservation_created"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_trigger_webhook_reservation_created"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_trigger_webhook_waiter_call"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_trigger_webhook_waiter_call"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_trigger_webhook_waiter_call"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_trigger_webhook_waiter_call"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_validar_modulo_pedido"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_validar_modulo_pedido"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_validar_modulo_pedido"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_validar_modulo_pedido"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."fn_verificar_camarero_pin"(uuid, uuid, text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."fn_verificar_camarero_pin"(uuid, uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_verificar_camarero_pin"(uuid, uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_verificar_camarero_pin"(uuid, uuid, text) TO "service_role";

REVOKE ALL ON FUNCTION "public"."fn_whatsapp_mensaje_nuevo"(text, uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_whatsapp_mensaje_nuevo"(text, uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."fn_whatsapp_mensaje_nuevo"(text, uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."force_zero_total_on_mesa_insert"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."force_zero_total_on_mesa_insert"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."force_zero_total_on_mesa_insert"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."force_zero_total_on_mesa_insert"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."get_session_orders"(uuid, text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."get_session_orders"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."get_session_orders"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."get_session_orders"(uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."get_table_by_qr"(text) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."get_table_by_qr"(text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."get_table_by_qr"(text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."get_table_by_qr"(text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."is_restaurant_owner"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."is_restaurant_owner"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_restaurant_owner"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."is_restaurant_owner"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."order_is_valid_for_items"(uuid) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."order_is_valid_for_items"(uuid) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."order_is_valid_for_items"(uuid) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."order_is_valid_for_items"(uuid) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."recalc_order_total"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."recalc_order_total"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."recalc_order_total"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."recalc_order_total"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."set_updated_at"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."set_updated_at"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."set_updated_at"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."set_updated_at"() TO "service_role";

GRANT USAGE ON SCHEMA "router" TO "anon", "authenticated", "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."camarero_pin_intentos" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."camarero_pin_intentos" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."camarero_pin_intentos" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."camarero_pin_intentos" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."camareros" TO "authenticated";

REVOKE ALL ON TABLE "public"."camareros" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."camareros" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."camareros" TO "service_role";

REVOKE ALL ON TABLE "public"."categoria_traducciones" FROM "anon";

GRANT SELECT ON TABLE "public"."categoria_traducciones" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."categoria_traducciones" TO "authenticated";

REVOKE ALL ON TABLE "public"."categoria_traducciones" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."categoria_traducciones" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."categoria_traducciones" TO "service_role";

REVOKE ALL ON TABLE "public"."categories" FROM "anon";

GRANT SELECT ON TABLE "public"."categories" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."categories" TO "authenticated";

REVOKE ALL ON TABLE "public"."categories" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."categories" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."categories" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."clientes" TO "authenticated";

REVOKE ALL ON TABLE "public"."clientes" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."clientes" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."clientes" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."clientes_movimientos" TO "authenticated";

REVOKE ALL ON TABLE "public"."clientes_movimientos" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."clientes_movimientos" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."clientes_movimientos" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."clientes_sellos" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."clientes_sellos" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."clientes_sellos" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."clientes_sellos" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."condiciones_aceptaciones" TO "authenticated";

REVOKE ALL ON TABLE "public"."condiciones_aceptaciones" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."condiciones_aceptaciones" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."condiciones_aceptaciones" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_actividades" TO "authenticated";

REVOKE ALL ON TABLE "public"."crm_actividades" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_actividades" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_actividades" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_busquedas" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."crm_busquedas" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_busquedas" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_busquedas" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_comisiones" TO "authenticated";

REVOKE ALL ON TABLE "public"."crm_comisiones" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_comisiones" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_comisiones" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_config" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."crm_config" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_config" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_config" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_cuentas" TO "authenticated";

REVOKE ALL ON TABLE "public"."crm_cuentas" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_cuentas" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_cuentas" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_historial" TO "authenticated";

REVOKE ALL ON TABLE "public"."crm_historial" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_historial" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_historial" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_tareas" TO "authenticated";

REVOKE ALL ON TABLE "public"."crm_tareas" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_tareas" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."crm_tareas" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."ingredientes" TO "authenticated";

REVOKE ALL ON TABLE "public"."ingredientes" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."ingredientes" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."ingredientes" TO "service_role";

REVOKE ALL ON TABLE "public"."limpieza_pasos" FROM "anon";

GRANT SELECT ON TABLE "public"."limpieza_pasos" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."limpieza_pasos" TO "authenticated";

REVOKE ALL ON TABLE "public"."limpieza_pasos" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."limpieza_pasos" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."limpieza_pasos" TO "service_role";

REVOKE ALL ON TABLE "public"."menu_item_modificador_grupos" FROM "anon";

GRANT SELECT ON TABLE "public"."menu_item_modificador_grupos" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_item_modificador_grupos" TO "authenticated";

REVOKE ALL ON TABLE "public"."menu_item_modificador_grupos" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_item_modificador_grupos" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_item_modificador_grupos" TO "service_role";

REVOKE ALL ON TABLE "public"."menu_item_modificador_precios" FROM "anon";

GRANT SELECT ON TABLE "public"."menu_item_modificador_precios" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_item_modificador_precios" TO "authenticated";

REVOKE ALL ON TABLE "public"."menu_item_modificador_precios" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_item_modificador_precios" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_item_modificador_precios" TO "service_role";

REVOKE ALL ON TABLE "public"."menu_item_precios_menu" FROM "anon";

GRANT SELECT ON TABLE "public"."menu_item_precios_menu" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_item_precios_menu" TO "authenticated";

REVOKE ALL ON TABLE "public"."menu_item_precios_menu" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_item_precios_menu" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_item_precios_menu" TO "service_role";

REVOKE ALL ON TABLE "public"."menu_item_traducciones" FROM "anon";

GRANT SELECT ON TABLE "public"."menu_item_traducciones" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_item_traducciones" TO "authenticated";

REVOKE ALL ON TABLE "public"."menu_item_traducciones" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_item_traducciones" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_item_traducciones" TO "service_role";

REVOKE ALL ON TABLE "public"."menu_items" FROM "anon";

GRANT SELECT ON TABLE "public"."menu_items" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_items" TO "authenticated";

REVOKE ALL ON TABLE "public"."menu_items" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_items" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menu_items" TO "service_role";

REVOKE ALL ON TABLE "public"."menus" FROM "anon";

GRANT SELECT ON TABLE "public"."menus" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menus" TO "authenticated";

REVOKE ALL ON TABLE "public"."menus" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menus" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."menus" TO "service_role";

REVOKE ALL ON TABLE "public"."modificador_grupo_traducciones" FROM "anon";

GRANT SELECT ON TABLE "public"."modificador_grupo_traducciones" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modificador_grupo_traducciones" TO "authenticated";

REVOKE ALL ON TABLE "public"."modificador_grupo_traducciones" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modificador_grupo_traducciones" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modificador_grupo_traducciones" TO "service_role";

REVOKE ALL ON TABLE "public"."modificador_grupos" FROM "anon";

GRANT SELECT ON TABLE "public"."modificador_grupos" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modificador_grupos" TO "authenticated";

REVOKE ALL ON TABLE "public"."modificador_grupos" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modificador_grupos" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modificador_grupos" TO "service_role";

REVOKE ALL ON TABLE "public"."modificador_opcion_traducciones" FROM "anon";

GRANT SELECT ON TABLE "public"."modificador_opcion_traducciones" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modificador_opcion_traducciones" TO "authenticated";

REVOKE ALL ON TABLE "public"."modificador_opcion_traducciones" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modificador_opcion_traducciones" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modificador_opcion_traducciones" TO "service_role";

REVOKE ALL ON TABLE "public"."modificador_opciones" FROM "anon";

GRANT SELECT ON TABLE "public"."modificador_opciones" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modificador_opciones" TO "authenticated";

REVOKE ALL ON TABLE "public"."modificador_opciones" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modificador_opciones" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modificador_opciones" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modulos" TO "authenticated";

REVOKE ALL ON TABLE "public"."modulos" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modulos" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."modulos" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."niveles_fidelizacion" TO "authenticated";

REVOKE ALL ON TABLE "public"."niveles_fidelizacion" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."niveles_fidelizacion" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."niveles_fidelizacion" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."order_deliveries" TO "authenticated";

REVOKE ALL ON TABLE "public"."order_deliveries" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."order_deliveries" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."order_deliveries" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."order_item_modificadores" TO "authenticated";

REVOKE ALL ON TABLE "public"."order_item_modificadores" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."order_item_modificadores" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."order_item_modificadores" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."order_items" TO "authenticated";

REVOKE ALL ON TABLE "public"."order_items" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."order_items" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."order_items" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."order_sector_confirmaciones" TO "authenticated";

REVOKE ALL ON TABLE "public"."order_sector_confirmaciones" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."order_sector_confirmaciones" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."order_sector_confirmaciones" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."orders" TO "authenticated";

REVOKE ALL ON TABLE "public"."orders" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."orders" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."orders" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."planes" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."planes" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."planes" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."planes" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."premios_fidelizacion" TO "authenticated";

REVOKE ALL ON TABLE "public"."premios_fidelizacion" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."premios_fidelizacion" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."premios_fidelizacion" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."promos_sellos" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."promos_sellos" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."promos_sellos" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."promos_sellos" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."receta_items" TO "authenticated";

REVOKE ALL ON TABLE "public"."receta_items" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."receta_items" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."receta_items" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."resenas" TO "authenticated";

REVOKE ALL ON TABLE "public"."resenas" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."resenas" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."resenas" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."reservations" TO "authenticated";

REVOKE ALL ON TABLE "public"."reservations" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."reservations" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."reservations" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."restaurant_billing" TO "authenticated";

REVOKE ALL ON TABLE "public"."restaurant_billing" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."restaurant_billing" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."restaurant_billing" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."restaurant_info" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."restaurant_info" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."restaurant_info" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."restaurant_info" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."restaurant_modulos" TO "authenticated";

REVOKE ALL ON TABLE "public"."restaurant_modulos" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."restaurant_modulos" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."restaurant_modulos" TO "service_role";

REVOKE ALL ON TABLE "public"."restaurants" FROM "anon";

REVOKE ALL ("activo") ON TABLE "public"."restaurants" FROM "anon";

GRANT SELECT ("activo") ON TABLE "public"."restaurants" TO "anon";

REVOKE ALL ("config") ON TABLE "public"."restaurants" FROM "anon";

GRANT SELECT ("config") ON TABLE "public"."restaurants" TO "anon";

REVOKE ALL ("direccion") ON TABLE "public"."restaurants" FROM "anon";

GRANT SELECT ("direccion") ON TABLE "public"."restaurants" TO "anon";

REVOKE ALL ("id") ON TABLE "public"."restaurants" FROM "anon";

GRANT SELECT ("id") ON TABLE "public"."restaurants" TO "anon";

REVOKE ALL ("logo_url") ON TABLE "public"."restaurants" FROM "anon";

GRANT SELECT ("logo_url") ON TABLE "public"."restaurants" TO "anon";

REVOKE ALL ("moneda") ON TABLE "public"."restaurants" FROM "anon";

GRANT SELECT ("moneda") ON TABLE "public"."restaurants" TO "anon";

REVOKE ALL ("nombre") ON TABLE "public"."restaurants" FROM "anon";

GRANT SELECT ("nombre") ON TABLE "public"."restaurants" TO "anon";

REVOKE ALL ("slug") ON TABLE "public"."restaurants" FROM "anon";

GRANT SELECT ("slug") ON TABLE "public"."restaurants" TO "anon";

REVOKE ALL ("subdominio") ON TABLE "public"."restaurants" FROM "anon";

GRANT SELECT ("subdominio") ON TABLE "public"."restaurants" TO "anon";

REVOKE ALL ("whatsapp") ON TABLE "public"."restaurants" FROM "anon";

GRANT SELECT ("whatsapp") ON TABLE "public"."restaurants" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."restaurants" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."restaurants" TO "authenticated";

REVOKE ALL ON TABLE "public"."restaurants" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."restaurants" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."restaurants" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."sectores_cocina" TO "authenticated";

REVOKE ALL ON TABLE "public"."sectores_cocina" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."sectores_cocina" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."sectores_cocina" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."stock_movimientos" TO "authenticated";

REVOKE ALL ON TABLE "public"."stock_movimientos" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."stock_movimientos" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."stock_movimientos" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."superadmins" TO "authenticated";

REVOKE ALL ON TABLE "public"."superadmins" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."superadmins" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."superadmins" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."table_session_payments" TO "authenticated";

REVOKE ALL ON TABLE "public"."table_session_payments" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."table_session_payments" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."table_session_payments" TO "service_role";

REVOKE ALL ("cliente_nombre") ON TABLE "public"."table_sessions" FROM "authenticated";

GRANT SELECT ("cliente_nombre"), UPDATE ("cliente_nombre") ON TABLE "public"."table_sessions" TO "authenticated";

REVOKE ALL ("cliente_telefono") ON TABLE "public"."table_sessions" FROM "authenticated";

GRANT SELECT ("cliente_telefono"), UPDATE ("cliente_telefono") ON TABLE "public"."table_sessions" TO "authenticated";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."table_sessions" TO "authenticated";

REVOKE ALL ON TABLE "public"."table_sessions" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."table_sessions" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."table_sessions" TO "service_role";

REVOKE ALL ON TABLE "public"."tables" FROM "anon";

REVOKE ALL ("activa") ON TABLE "public"."tables" FROM "anon";

GRANT SELECT ("activa") ON TABLE "public"."tables" TO "anon";

REVOKE ALL ("capacidad") ON TABLE "public"."tables" FROM "anon";

GRANT SELECT ("capacidad") ON TABLE "public"."tables" TO "anon";

REVOKE ALL ("id") ON TABLE "public"."tables" FROM "anon";

GRANT SELECT ("id") ON TABLE "public"."tables" TO "anon";

REVOKE ALL ("limpieza_progreso") ON TABLE "public"."tables" FROM "anon";

GRANT SELECT ("limpieza_progreso") ON TABLE "public"."tables" TO "anon";

REVOKE ALL ("necesita_limpieza") ON TABLE "public"."tables" FROM "anon";

GRANT SELECT ("necesita_limpieza") ON TABLE "public"."tables" TO "anon";

REVOKE ALL ("numero") ON TABLE "public"."tables" FROM "anon";

GRANT SELECT ("numero") ON TABLE "public"."tables" TO "anon";

REVOKE ALL ("restaurant_id") ON TABLE "public"."tables" FROM "anon";

GRANT SELECT ("restaurant_id") ON TABLE "public"."tables" TO "anon";

REVOKE ALL ("zona") ON TABLE "public"."tables" FROM "anon";

GRANT SELECT ("zona") ON TABLE "public"."tables" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."tables" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."tables" TO "authenticated";

REVOKE ALL ON TABLE "public"."tables" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."tables" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."tables" TO "service_role";

REVOKE ALL ON TABLE "public"."upsell_rules" FROM "anon";

GRANT SELECT ON TABLE "public"."upsell_rules" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."upsell_rules" TO "authenticated";

REVOKE ALL ON TABLE "public"."upsell_rules" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."upsell_rules" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."upsell_rules" TO "service_role";

REVOKE ALL ON TABLE "public"."upsell_traducciones" FROM "anon";

GRANT SELECT ON TABLE "public"."upsell_traducciones" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."upsell_traducciones" TO "authenticated";

REVOKE ALL ON TABLE "public"."upsell_traducciones" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."upsell_traducciones" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."upsell_traducciones" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."vale_movimientos" TO "authenticated";

REVOKE ALL ON TABLE "public"."vale_movimientos" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."vale_movimientos" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."vale_movimientos" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."vales_regalo" TO "authenticated";

REVOKE ALL ON TABLE "public"."vales_regalo" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."vales_regalo" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."vales_regalo" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."vendedores" TO "authenticated";

REVOKE ALL ON TABLE "public"."vendedores" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."vendedores" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."vendedores" TO "service_role";

REVOKE ALL ON TABLE "public"."waiter_calls" FROM "anon";

GRANT INSERT ON TABLE "public"."waiter_calls" TO "anon";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."waiter_calls" TO "authenticated";

REVOKE ALL ON TABLE "public"."waiter_calls" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."waiter_calls" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."waiter_calls" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."webhook_entregas" TO "authenticated";

REVOKE ALL ON TABLE "public"."webhook_entregas" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."webhook_entregas" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."webhook_entregas" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."webhooks" TO "authenticated";

REVOKE ALL ON TABLE "public"."webhooks" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."webhooks" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."webhooks" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."whatsapp_mensajes_procesados" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."whatsapp_mensajes_procesados" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."whatsapp_mensajes_procesados" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."whatsapp_mensajes_procesados" TO "service_role";

REVOKE ALL ON TABLE "public"."whatsapp_sessions" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."whatsapp_sessions" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."whatsapp_sessions" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "router"."clientes_cache" TO "anon", "authenticated";

REVOKE ALL ON TABLE "router"."clientes_cache" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "router"."clientes_cache" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "router"."clientes_cache" TO "service_role";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "router" GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLES TO "anon";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "router" GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLES TO "authenticated";

ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "router" GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLES TO "service_role";

CREATE POLICY "crm_actividades_delete" ON "public"."crm_actividades"
  FOR DELETE
  TO "authenticated"
  USING ((public.fn_es_superadmin() OR ((autor_user_id = auth.uid()) AND public.fn_crm_cuenta_puede_ver(cuenta_id))));

CREATE POLICY "crm_actividades_update" ON "public"."crm_actividades"
  FOR UPDATE
  TO "authenticated"
  USING ((public.fn_es_superadmin() OR ((autor_user_id = auth.uid()) AND public.fn_crm_cuenta_puede_ver(cuenta_id))))
  WITH CHECK ((public.fn_es_superadmin() OR ((autor_user_id = auth.uid()) AND public.fn_crm_cuenta_puede_ver(cuenta_id))));

ALTER TABLE "public"."crm_tareas"
  ADD COLUMN "vence_en" date NOT NULL DEFAULT public.fn_hoy_madrid();

CREATE INDEX crm_tareas_pendientes_idx ON public.crm_tareas USING btree (vence_en)
  WHERE (NOT completada);

