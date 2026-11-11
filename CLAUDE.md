# Restomind — instrucciones para Claude

Plataforma SaaS multi-tenant de gestión de restaurantes (pedidos en mesa por QR, camarero, cocina, reservas, take away, fidelización, CRM comercial y agente de WhatsApp).
Idioma del producto y de la documentación: **español de España**.

## Stack
- Front: React 18 + Vite 5 + react-router 6. Estilos inline (sin Tailwind en este repo). Gráficas con recharts.
- Back: Supabase (Postgres 17, RLS, RPC `SECURITY DEFINER`, Realtime, Storage, Edge Functions en `supabase/functions/`).
- Automatización: n8n (agente de WhatsApp: take away y reservas). Workflows exportados en `n8n/` (cuando existan).
- Hosting: Vercel (SPA, `vercel.json`).

## Entornos
| Entorno | Rama git | Supabase | Vercel |
|---|---|---|---|
| Test | `staging` | `Restomind Test` (`sfkwbhzelrestmrmptql`) | preview de `staging` |
| Producción | `main` | `restomind` (`mfxrluanpawfjncpqrvu`) | producción |

## Reglas fijas (no negociables)
1. **Nunca** ejecutar SQL que modifique datos o esquema en Producción desde una sesión de trabajo. Todo cambio de esquema es una migración en `supabase/migrations/`, se aplica primero en Test y solo después en Producción.
2. **Nunca** commitear claves (`.env`, service_role, tokens de Meta/WhatsApp, API keys). Si aparece una en un diff, parar.
3. Trabajo siempre en rama `feature/...` o `fix/...` desde `staging` → PR a `staging` → validar en la preview → PR `staging` → `main`.
4. Toda tabla nueva:
   - `enable row level security` + política del dueño (`restaurant_id in (select id from restaurants where user_id = auth.uid())`) + SELECT público solo si la carta/mesa lo necesita.
   - `grant` explícitos y mínimos a `anon` / `authenticated` (no confiar en los grants por defecto).
   - Si la UI la escucha en tiempo real: `alter publication supabase_realtime add table ...` dentro de la migración.
5. Toda función `SECURITY DEFINER`: `set search_path = public`, comprobación de permisos dentro (`fn_es_superadmin()`, `auth.uid()`, PIN de camarero…), y `revoke execute ... from public, anon` salvo que la llame la mesa/web pública.
6. Dinero: siempre `formatMoney()` / `getCurrencySymbol()` de `src/lib/money.js`. Nunca un "€" escrito a mano.
7. Fechas y horas de negocio: hora de España con `src/lib/fechas.js` en el front y `fn_ahora_madrid()` / `fn_hoy_madrid()` / `fn_hora_madrid()` en SQL.
8. Funcionalidades de pago: comprobar el módulo con `useRestaurantModulos(restaurantId).tieneModulo(key)` (front) y con la validación en BD cuando aplique.
9. Tras escribir en BD, actualizar el estado local al momento; no esperar al eco de Realtime.

## Comandos
```bash
npm install
npm run dev        # Vite en local (necesita .env, ver .env.example)
npm run build      # build de producción; debe pasar antes de cualquier PR
npx supabase migration new <nombre>   # crear migración
```

## Mapa del código
- `src/pages/` — una página por ruta (rutas en `src/main.jsx`). Las grandes: `Camarero.jsx`, `Mesa.jsx`, `AdminCarta.jsx`, `AdminDashboard.jsx`.
- `src/components/` — piezas compartidas; `components/crm/` es el CRM comercial (superadmin y vendedores).
- `src/lib/` — utilidades: `supabase.js`, `money.js`, `fechas.js`, `modulos.js`, `menus.js`, `delivery/` (patrón adaptador de repartos).
- `supabase/functions/` — Edge Functions (`importar-carta`, `traducir-carta`, `crm-buscar-restaurantes`).
- `supabase/migrations/` — **única** fuente de cambios de esquema desde nov-2026.
- `sql/historico/` — scripts aplicados a mano antes de las migraciones. Solo lectura, como referencia.
- `docs/` — arquitectura, flujo de trabajo, decisiones y backlog.

## Cómo trabajar una tarea
Seguir `docs/FLUJO_DE_TRABAJO.md`. Resumen: mini especificación → plan → rama → código + migración → `npm run build` → PR a `staging` → checklist de "terminado".
Al terminar un cambio, dar siempre a Patricio los comandos git para revisarlo o subirlo.
