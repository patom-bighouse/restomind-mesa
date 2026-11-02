// Buscador de restaurantes del CRM: consulta Google Places (Text Search,
// API "New") y devuelve los locales encontrados para importarlos como
// prospectos. La clave de Google es un secreto de esta función
// (GOOGLE_PLACES_API_KEY), jamás llega al navegador.
//
// Permisos: fn_crm_puede_buscar() (superadmin, o vendedores si el
// superadmin lo habilita en crm_config). Cada llamada a Google se cuenta
// en crm_busquedas para el contador de consultas gratis del mes.
//
// Body esperado: { zona: string, tipo: string, pais?: string,
//                  valoracion_min?: number, paginas?: 1|2|3 }

import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Debe coincidir con TIPOS_BUSQUEDA de src/lib/crm.js.
const TIPOS: Record<string, { texto: string; includedType?: string }> = {
  restaurante: { texto: 'restaurantes', includedType: 'restaurant' },
  bar: { texto: 'bares', includedType: 'bar' },
  tapas: { texto: 'bares de tapas' },
  cafeteria: { texto: 'cafeterías', includedType: 'cafe' },
  pizzeria: { texto: 'pizzerías', includedType: 'pizza_restaurant' },
  hamburgueseria: { texto: 'hamburgueserías', includedType: 'hamburger_restaurant' },
  comida_rapida: { texto: 'comida rápida', includedType: 'fast_food_restaurant' },
  espanol: { texto: 'restaurantes españoles', includedType: 'spanish_restaurant' },
  italiano: { texto: 'restaurantes italianos', includedType: 'italian_restaurant' },
  japones: { texto: 'restaurantes japoneses y sushi', includedType: 'japanese_restaurant' },
  chino: { texto: 'restaurantes chinos', includedType: 'chinese_restaurant' },
  mexicano: { texto: 'restaurantes mexicanos', includedType: 'mexican_restaurant' },
  marisqueria: { texto: 'marisquerías', includedType: 'seafood_restaurant' },
  asador: { texto: 'asadores y parrillas', includedType: 'steak_house' },
  vegetariano: { texto: 'restaurantes vegetarianos', includedType: 'vegetarian_restaurant' },
  brunch: { texto: 'brunch', includedType: 'brunch_restaurant' },
}

// Con teléfono, web, valoración y reseñas, Google factura cada página como
// "Text Search Enterprise".
const CAMPOS = [
  'places.id', 'places.displayName', 'places.formattedAddress', 'places.addressComponents',
  'places.nationalPhoneNumber', 'places.internationalPhoneNumber', 'places.websiteUri',
  'places.rating', 'places.userRatingCount', 'places.priceLevel', 'places.googleMapsUri',
  'places.businessStatus', 'places.primaryTypeDisplayName', 'nextPageToken',
].join(',')

const NIVEL_PRECIO: Record<string, number> = {
  PRICE_LEVEL_FREE: 0, PRICE_LEVEL_INEXPENSIVE: 1, PRICE_LEVEL_MODERATE: 2,
  PRICE_LEVEL_EXPENSIVE: 3, PRICE_LEVEL_VERY_EXPENSIVE: 4,
}

// deno-lint-ignore no-explicit-any
function componente(p: any, tipo: string): string | null {
  // deno-lint-ignore no-explicit-any
  return p.addressComponents?.find((c: any) => c.types?.includes(tipo))?.longText ?? null
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const body = await req.json()
    const zona = String(body.zona || '').trim()
    const tipo = TIPOS[body.tipo] ? body.tipo : 'restaurante'
    const pais = /^[A-Z]{2}$/.test(body.pais || '') ? body.pais : 'ES'
    const valoracionMin = Math.min(Math.max(Number(body.valoracion_min) || 0, 0), 5)
    const paginas = Math.min(Math.max(parseInt(body.paginas, 10) || 3, 1), 3)
    if (zona.length < 2 || zona.length > 120) return json({ error: 'Indica una zona (barrio, ciudad o código postal).' }, 400)

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const { data: puede, error: permErr } = await supabase.rpc('fn_crm_puede_buscar')
    if (permErr) return json({ error: permErr.message }, 500)
    if (!puede) return json({ error: 'No tienes permiso para buscar restaurantes.' }, 403)

    const apiKey = Deno.env.get('GOOGLE_PLACES_API_KEY')
    if (!apiKey) return json({ error: 'Falta configurar GOOGLE_PLACES_API_KEY en los secretos de Edge Functions de Supabase.' }, 500)

    const t = TIPOS[tipo]
    const peticion: Record<string, unknown> = {
      textQuery: `${t.texto} en ${zona}`,
      languageCode: 'es',
      regionCode: pais,
      pageSize: 20,
    }
    if (t.includedType) {
      peticion.includedType = t.includedType
      peticion.strictTypeFiltering = true
    }
    if (valoracionMin > 0) peticion.minRating = valoracionMin

    // deno-lint-ignore no-explicit-any
    const encontrados = new Map<string, any>()
    let consultas = 0
    let pageToken: string | undefined
    let errorGoogle: string | null = null

    for (let i = 0; i < paginas; i++) {
      const res = await fetch('https://places.googleapis.com/v1/places:searchText', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': apiKey, 'X-Goog-FieldMask': CAMPOS },
        body: JSON.stringify(pageToken ? { ...peticion, pageToken } : peticion),
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok) {
        errorGoogle = data?.error?.message || `Google respondió ${res.status}`
        break
      }
      consultas++ // Google solo factura las respuestas correctas
      for (const p of data.places || []) encontrados.set(p.id, p)
      pageToken = data.nextPageToken
      if (!pageToken) break
    }

    const locales = [...encontrados.values()].map(p => ({
      place_id: p.id,
      nombre: p.displayName?.text || '(sin nombre)',
      direccion: p.formattedAddress || null,
      ciudad: componente(p, 'locality') || componente(p, 'administrative_area_level_2'),
      codigo_postal: componente(p, 'postal_code'),
      telefono: p.nationalPhoneNumber || p.internationalPhoneNumber || null,
      telefono_internacional: p.internationalPhoneNumber || null,
      web: p.websiteUri || null,
      valoracion: p.rating ?? null,
      num_resenas: p.userRatingCount ?? 0,
      nivel_precio: p.priceLevel in NIVEL_PRECIO ? NIVEL_PRECIO[p.priceLevel] : null,
      maps_url: p.googleMapsUri || null,
      estado: p.businessStatus || 'OPERATIONAL',
      tipo_google: p.primaryTypeDisplayName?.text || null,
      duplicado: null as string | null,
    }))

    if (locales.length) {
      const { data: dups, error: dupErr } = await supabase.rpc('fn_crm_duplicados', {
        p_locales: locales.map(l => ({ place_id: l.place_id, telefono: l.telefono_internacional || l.telefono })),
      })
      if (dupErr) return json({ error: dupErr.message }, 500)
      const motivo = new Map((dups || []).map((d: { place_id: string; motivo: string }) => [d.place_id, d.motivo]))
      for (const l of locales) l.duplicado = (motivo.get(l.place_id) as string) ?? null
    }

    // Se registra aunque Google haya fallado a mitad: las páginas que sí
    // respondieron ya cuentan para la facturación. Los locales se guardan
    // (sin "duplicado", que se recalcula al reabrir) para "Búsquedas
    // recientes".
    let busquedaId: string | null = null
    if (consultas > 0) {
      const { data: id, error: regErr } = await supabase.rpc('fn_crm_registrar_busqueda', {
        p_parametros: { zona, tipo, pais, valoracion_min: valoracionMin, paginas },
        p_consultas: consultas,
        p_resultados: locales.length,
        p_locales: locales.map(({ duplicado: _d, ...l }) => l),
      })
      if (regErr) return json({ error: regErr.message }, 500)
      busquedaId = id
    }

    const { data: uso } = await supabase.rpc('fn_crm_uso_places')

    if (errorGoogle && locales.length === 0) return json({ error: `Google Places: ${errorGoogle}`, uso: uso?.[0] ?? null }, 502)
    return json({ locales, consultas, busqueda_id: busquedaId, aviso: errorGoogle ? `Google cortó la búsqueda: ${errorGoogle}` : null, uso: uso?.[0] ?? null })
  } catch (e) {
    return json({ error: (e as Error).message }, 500)
  }
})

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
}
