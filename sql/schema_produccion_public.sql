--
-- PostgreSQL database dump
--

\restrict pyafKXtM3E4opVu7hx0cLlsOjIvbGyY8IdXzPiR5whOuy68DLz5ebna6aSw1xwz

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: force_zero_total_on_mesa_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.force_zero_total_on_mesa_insert() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if NEW.tipo = 'mesa' then
    NEW.total := 0;
  end if;
  return NEW;
end;
$$;


--
-- Name: get_table_by_qr(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_table_by_qr(p_token text) RETURNS TABLE(id uuid, numero integer, zona text, capacidad integer, activa boolean, restaurant_id uuid)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select t.id, t.numero, t.zona, t.capacidad, t.activa, t.restaurant_id
  from tables t
  where t.qr_token = p_token
  limit 1
$$;


--
-- Name: is_restaurant_owner(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_restaurant_owner(rid uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    exists (
      select 1 from restaurants r
      where r.id = rid and r.user_id = auth.uid()
    )
    or exists (
      select 1 from superadmins s
      where s.user_id = auth.uid()
    )
$$;


--
-- Name: order_is_valid_for_items(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.order_is_valid_for_items(p_order_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from orders o
    where o.id = p_order_id
      and o.tipo = 'mesa'
      and o.estado = 'pendiente'
  )
$$;


--
-- Name: recalc_order_total(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.recalc_order_total() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurant_id uuid,
    nombre text NOT NULL,
    orden integer DEFAULT 0,
    activa boolean DEFAULT true
);


--
-- Name: menu_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurant_id uuid,
    category_id uuid,
    nombre text NOT NULL,
    descripcion text,
    precio numeric(8,2) NOT NULL,
    foto_url text,
    emoji text,
    disponible boolean DEFAULT true,
    orden integer DEFAULT 0
);


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    order_id uuid,
    menu_item_id uuid,
    nombre_snapshot text NOT NULL,
    precio_snapshot numeric(8,2) NOT NULL,
    cantidad integer DEFAULT 1 NOT NULL,
    notas text
);


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurant_id uuid,
    table_id uuid,
    tipo text DEFAULT 'mesa'::text,
    estado text DEFAULT 'pendiente'::text,
    cliente_nombre text,
    cliente_telefono text,
    notas text,
    total numeric(8,2) DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    table_session_id uuid,
    CONSTRAINT orders_estado_check CHECK ((estado = ANY (ARRAY['pendiente'::text, 'preparando'::text, 'listo'::text, 'entregado'::text, 'cancelado'::text]))),
    CONSTRAINT orders_tipo_check CHECK ((tipo = ANY (ARRAY['mesa'::text, 'takeaway'::text])))
);


--
-- Name: reservations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurant_id uuid,
    nombre text NOT NULL,
    telefono text NOT NULL,
    fecha date NOT NULL,
    hora time without time zone NOT NULL,
    personas integer NOT NULL,
    estado text DEFAULT 'confirmada'::text,
    notas text,
    origen text DEFAULT 'whatsapp'::text,
    created_at timestamp with time zone DEFAULT now(),
    zona text DEFAULT 'sin preferencia'::text,
    duracion_minutos integer DEFAULT 120,
    CONSTRAINT reservations_estado_check CHECK ((estado = ANY (ARRAY['pendiente'::text, 'confirmada'::text, 'cancelada'::text, 'noshow'::text]))),
    CONSTRAINT reservations_origen_check CHECK ((origen = ANY (ARRAY['whatsapp'::text, 'web'::text, 'telefono'::text, 'manual'::text])))
);


--
-- Name: restaurants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.restaurants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre text NOT NULL,
    slug text NOT NULL,
    logo_url text,
    whatsapp text,
    direccion text,
    config jsonb DEFAULT '{}'::jsonb,
    activo boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    user_id uuid
);


--
-- Name: superadmins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.superadmins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    nombre text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: table_session_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.table_session_payments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    table_session_id uuid NOT NULL,
    restaurant_id uuid NOT NULL,
    monto numeric(10,2) NOT NULL,
    metodo_pago text NOT NULL,
    estado text DEFAULT 'registrado'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT table_session_payments_estado_check CHECK ((estado = ANY (ARRAY['registrado'::text, 'anulado'::text]))),
    CONSTRAINT table_session_payments_metodo_pago_check CHECK ((metodo_pago = ANY (ARRAY['efectivo'::text, 'tarjeta'::text, 'bizum'::text, 'otro'::text]))),
    CONSTRAINT table_session_payments_monto_check CHECK ((monto > (0)::numeric))
);


--
-- Name: table_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.table_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    table_id uuid NOT NULL,
    restaurant_id uuid NOT NULL,
    estado text DEFAULT 'abierta'::text NOT NULL,
    abierta_at timestamp with time zone DEFAULT now() NOT NULL,
    cerrada_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    total numeric(10,2) DEFAULT 0,
    estado_pago text DEFAULT 'pendiente'::text NOT NULL,
    metodo_pago text,
    pagada_at timestamp with time zone,
    motivo_exencion text,
    CONSTRAINT table_sessions_estado_check CHECK ((estado = ANY (ARRAY['abierta'::text, 'cerrada'::text]))),
    CONSTRAINT table_sessions_estado_pago_check CHECK ((estado_pago = ANY (ARRAY['pendiente'::text, 'pagado'::text, 'exento'::text])))
);


--
-- Name: tables; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tables (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurant_id uuid,
    numero integer NOT NULL,
    zona text DEFAULT 'interior'::text,
    capacidad integer DEFAULT 4,
    qr_token text DEFAULT (gen_random_uuid())::text,
    activa boolean DEFAULT true
);


--
-- Name: waiter_calls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.waiter_calls (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurant_id uuid,
    table_id uuid,
    estado text DEFAULT 'pendiente'::text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT waiter_calls_estado_check CHECK ((estado = ANY (ARRAY['pendiente'::text, 'atendido'::text])))
);


--
-- Name: whatsapp_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.whatsapp_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    restaurant_id uuid,
    telefono text NOT NULL,
    contexto jsonb DEFAULT '{}'::jsonb,
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: menu_items menu_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: reservations reservations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT reservations_pkey PRIMARY KEY (id);


--
-- Name: restaurants restaurants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurants
    ADD CONSTRAINT restaurants_pkey PRIMARY KEY (id);


--
-- Name: restaurants restaurants_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurants
    ADD CONSTRAINT restaurants_slug_key UNIQUE (slug);


--
-- Name: superadmins superadmins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.superadmins
    ADD CONSTRAINT superadmins_pkey PRIMARY KEY (id);


--
-- Name: table_session_payments table_session_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_session_payments
    ADD CONSTRAINT table_session_payments_pkey PRIMARY KEY (id);


--
-- Name: table_sessions table_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_sessions
    ADD CONSTRAINT table_sessions_pkey PRIMARY KEY (id);


--
-- Name: tables tables_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT tables_pkey PRIMARY KEY (id);


--
-- Name: tables tables_qr_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT tables_qr_token_key UNIQUE (qr_token);


--
-- Name: waiter_calls waiter_calls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.waiter_calls
    ADD CONSTRAINT waiter_calls_pkey PRIMARY KEY (id);


--
-- Name: whatsapp_sessions whatsapp_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_sessions
    ADD CONSTRAINT whatsapp_sessions_pkey PRIMARY KEY (id);


--
-- Name: whatsapp_sessions whatsapp_sessions_restaurant_id_telefono_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_sessions
    ADD CONSTRAINT whatsapp_sessions_restaurant_id_telefono_key UNIQUE (restaurant_id, telefono);


--
-- Name: categories_restaurant_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX categories_restaurant_id_idx ON public.categories USING btree (restaurant_id);


--
-- Name: idx_orders_table_session; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_orders_table_session ON public.orders USING btree (table_session_id);


--
-- Name: idx_table_session_payments_restaurant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_table_session_payments_restaurant ON public.table_session_payments USING btree (restaurant_id);


--
-- Name: idx_table_session_payments_session; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_table_session_payments_session ON public.table_session_payments USING btree (table_session_id);


--
-- Name: idx_table_sessions_restaurant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_table_sessions_restaurant ON public.table_sessions USING btree (restaurant_id);


--
-- Name: idx_table_sessions_table_estado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_table_sessions_table_estado ON public.table_sessions USING btree (table_id, estado);


--
-- Name: menu_items_category_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX menu_items_category_id_idx ON public.menu_items USING btree (category_id);


--
-- Name: menu_items_restaurant_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX menu_items_restaurant_id_idx ON public.menu_items USING btree (restaurant_id);


--
-- Name: order_items_order_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX order_items_order_id_idx ON public.order_items USING btree (order_id);


--
-- Name: orders_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_created_at_idx ON public.orders USING btree (created_at);


--
-- Name: orders_estado_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_estado_idx ON public.orders USING btree (estado);


--
-- Name: orders_restaurant_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX orders_restaurant_id_idx ON public.orders USING btree (restaurant_id);


--
-- Name: reservations_fecha_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservations_fecha_idx ON public.reservations USING btree (fecha);


--
-- Name: reservations_restaurant_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservations_restaurant_id_idx ON public.reservations USING btree (restaurant_id);


--
-- Name: superadmins_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX superadmins_user_id_idx ON public.superadmins USING btree (user_id);


--
-- Name: tables_restaurant_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tables_restaurant_id_idx ON public.tables USING btree (restaurant_id);


--
-- Name: uniq_una_sesion_abierta_por_mesa; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_una_sesion_abierta_por_mesa ON public.table_sessions USING btree (table_id) WHERE (estado = 'abierta'::text);


--
-- Name: waiter_calls_estado_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX waiter_calls_estado_idx ON public.waiter_calls USING btree (estado);


--
-- Name: waiter_calls_restaurant_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX waiter_calls_restaurant_id_idx ON public.waiter_calls USING btree (restaurant_id);


--
-- Name: whatsapp_sessions_restaurant_id_telefono_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX whatsapp_sessions_restaurant_id_telefono_idx ON public.whatsapp_sessions USING btree (restaurant_id, telefono);


--
-- Name: orders orders_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: whatsapp_sessions sessions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sessions_updated_at BEFORE UPDATE ON public.whatsapp_sessions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: orders trg_force_zero_total; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_force_zero_total BEFORE INSERT ON public.orders FOR EACH ROW EXECUTE FUNCTION public.force_zero_total_on_mesa_insert();


--
-- Name: order_items trg_recalc_order_total; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_recalc_order_total AFTER INSERT OR DELETE OR UPDATE ON public.order_items FOR EACH ROW EXECUTE FUNCTION public.recalc_order_total();


--
-- Name: categories categories_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;


--
-- Name: menu_items menu_items_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE SET NULL;


--
-- Name: menu_items menu_items_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;


--
-- Name: order_items order_items_menu_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_menu_item_id_fkey FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id) ON DELETE SET NULL;


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: orders orders_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;


--
-- Name: orders orders_table_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_table_id_fkey FOREIGN KEY (table_id) REFERENCES public.tables(id) ON DELETE SET NULL;


--
-- Name: orders orders_table_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_table_session_id_fkey FOREIGN KEY (table_session_id) REFERENCES public.table_sessions(id) ON DELETE SET NULL;


--
-- Name: reservations reservations_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT reservations_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;


--
-- Name: restaurants restaurants_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurants
    ADD CONSTRAINT restaurants_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: superadmins superadmins_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.superadmins
    ADD CONSTRAINT superadmins_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: table_session_payments table_session_payments_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_session_payments
    ADD CONSTRAINT table_session_payments_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;


--
-- Name: table_session_payments table_session_payments_table_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_session_payments
    ADD CONSTRAINT table_session_payments_table_session_id_fkey FOREIGN KEY (table_session_id) REFERENCES public.table_sessions(id) ON DELETE CASCADE;


--
-- Name: table_sessions table_sessions_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_sessions
    ADD CONSTRAINT table_sessions_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;


--
-- Name: table_sessions table_sessions_table_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_sessions
    ADD CONSTRAINT table_sessions_table_id_fkey FOREIGN KEY (table_id) REFERENCES public.tables(id) ON DELETE CASCADE;


--
-- Name: tables tables_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT tables_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;


--
-- Name: waiter_calls waiter_calls_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.waiter_calls
    ADD CONSTRAINT waiter_calls_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;


--
-- Name: waiter_calls waiter_calls_table_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.waiter_calls
    ADD CONSTRAINT waiter_calls_table_id_fkey FOREIGN KEY (table_id) REFERENCES public.tables(id) ON DELETE CASCADE;


--
-- Name: whatsapp_sessions whatsapp_sessions_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.whatsapp_sessions
    ADD CONSTRAINT whatsapp_sessions_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE;


--
-- Name: order_items anon_insert_order_items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_insert_order_items ON public.order_items FOR INSERT TO anon WITH CHECK ((public.order_is_valid_for_items(order_id) AND (menu_item_id IS NOT NULL) AND ((cantidad >= 1) AND (cantidad <= 50)) AND (EXISTS ( SELECT 1
   FROM public.menu_items mi
  WHERE ((mi.id = order_items.menu_item_id) AND (mi.disponible = true) AND (mi.precio = order_items.precio_snapshot))))));


--
-- Name: orders anon_insert_orders_mesa; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_insert_orders_mesa ON public.orders FOR INSERT TO anon WITH CHECK (((tipo = 'mesa'::text) AND (estado = 'pendiente'::text) AND (table_session_id IS NOT NULL) AND (table_id IS NOT NULL) AND (restaurant_id IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM public.table_sessions ts
  WHERE ((ts.id = orders.table_session_id) AND (ts.table_id = orders.table_id) AND (ts.restaurant_id = orders.restaurant_id) AND (ts.estado = 'abierta'::text))))));


--
-- Name: waiter_calls anon_insert_waiter_calls; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_insert_waiter_calls ON public.waiter_calls FOR INSERT TO anon WITH CHECK (((estado = 'pendiente'::text) AND (EXISTS ( SELECT 1
   FROM public.tables t
  WHERE ((t.id = waiter_calls.table_id) AND (t.restaurant_id = waiter_calls.restaurant_id) AND (t.activa = true))))));


--
-- Name: categories anon_select_categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_select_categories ON public.categories FOR SELECT TO anon USING ((activa = true));


--
-- Name: menu_items anon_select_menu_items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_select_menu_items ON public.menu_items FOR SELECT TO anon USING ((disponible = true));


--
-- Name: table_sessions anon_select_open_sessions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_select_open_sessions ON public.table_sessions FOR SELECT TO anon USING ((estado = 'abierta'::text));


--
-- Name: restaurants anon_select_restaurants; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_select_restaurants ON public.restaurants FOR SELECT TO anon USING (true);


--
-- Name: tables anon_select_tables; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_select_tables ON public.tables FOR SELECT TO anon USING (true);


--
-- Name: categories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

--
-- Name: menu_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;

--
-- Name: order_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

--
-- Name: orders; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

--
-- Name: categories owner_all_categories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY owner_all_categories ON public.categories TO authenticated USING (public.is_restaurant_owner(restaurant_id)) WITH CHECK (public.is_restaurant_owner(restaurant_id));


--
-- Name: menu_items owner_all_menu_items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY owner_all_menu_items ON public.menu_items TO authenticated USING (public.is_restaurant_owner(restaurant_id)) WITH CHECK (public.is_restaurant_owner(restaurant_id));


--
-- Name: order_items owner_all_order_items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY owner_all_order_items ON public.order_items TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.orders o
  WHERE ((o.id = order_items.order_id) AND public.is_restaurant_owner(o.restaurant_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.orders o
  WHERE ((o.id = order_items.order_id) AND public.is_restaurant_owner(o.restaurant_id)))));


--
-- Name: orders owner_all_orders; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY owner_all_orders ON public.orders TO authenticated USING (public.is_restaurant_owner(restaurant_id)) WITH CHECK (public.is_restaurant_owner(restaurant_id));


--
-- Name: restaurants owner_all_restaurants; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY owner_all_restaurants ON public.restaurants TO authenticated USING (public.is_restaurant_owner(id)) WITH CHECK (public.is_restaurant_owner(id));


--
-- Name: table_session_payments owner_all_table_session_payments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY owner_all_table_session_payments ON public.table_session_payments TO authenticated USING (public.is_restaurant_owner(restaurant_id)) WITH CHECK (public.is_restaurant_owner(restaurant_id));


--
-- Name: table_sessions owner_all_table_sessions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY owner_all_table_sessions ON public.table_sessions TO authenticated USING (public.is_restaurant_owner(restaurant_id)) WITH CHECK (public.is_restaurant_owner(restaurant_id));


--
-- Name: tables owner_all_tables; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY owner_all_tables ON public.tables TO authenticated USING (public.is_restaurant_owner(restaurant_id)) WITH CHECK (public.is_restaurant_owner(restaurant_id));


--
-- Name: waiter_calls owner_all_waiter_calls; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY owner_all_waiter_calls ON public.waiter_calls TO authenticated USING (public.is_restaurant_owner(restaurant_id)) WITH CHECK (public.is_restaurant_owner(restaurant_id));


--
-- Name: restaurants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.restaurants ENABLE ROW LEVEL SECURITY;

--
-- Name: superadmins self_select_superadmins; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY self_select_superadmins ON public.superadmins FOR SELECT TO authenticated USING ((user_id = auth.uid()));


--
-- Name: restaurants superadmin_insert_restaurants; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY superadmin_insert_restaurants ON public.restaurants FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.superadmins s
  WHERE (s.user_id = auth.uid()))));


--
-- Name: superadmins; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.superadmins ENABLE ROW LEVEL SECURITY;

--
-- Name: table_session_payments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.table_session_payments ENABLE ROW LEVEL SECURITY;

--
-- Name: table_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.table_sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: tables; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tables ENABLE ROW LEVEL SECURITY;

--
-- Name: waiter_calls; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.waiter_calls ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict pyafKXtM3E4opVu7hx0cLlsOjIvbGyY8IdXzPiR5whOuy68DLz5ebna6aSw1xwz

