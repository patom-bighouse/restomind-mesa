// Traduce la carta de un restaurante a uno o varios idiomas usando la
// API de Anthropic (clave de la plataforma, nunca del restaurante — se
// guarda como secreto de esta función, jamás llega al navegador). Se
// llama una vez desde AdminCarta.jsx, no en cada visita de un
// comensal: el resultado queda guardado en menu_item_traducciones y
// Mesa.jsx solo lo lee.
//
// Body esperado: { restaurant_id: string, idiomas: string[] }

import { createClient } from 'npm:@supabase/supabase-js@2'

const IDIOMA_NOMBRE: Record<string, string> = {
  en: 'inglés', fr: 'francés', de: 'alemán', it: 'italiano', pt: 'portugués', ar: 'árabe',
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { restaurant_id, idiomas } = await req.json()
    if (!restaurant_id || !Array.isArray(idiomas) || idiomas.length === 0) {
      return json({ error: 'Faltan restaurant_id o idiomas.' }, 400)
    }
    const idiomasValidos = idiomas.filter((i: string) => IDIOMA_NOMBRE[i])
    if (idiomasValidos.length === 0) {
      return json({ error: 'Ningún idioma reconocido.' }, 400)
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // RLS ya filtra: si no es el dueño (ni superadmin), esto no
    // devuelve nada — no hace falta una verificación aparte.
    const { data: restaurant, error: restErr } = await supabase
      .from('restaurants').select('id, nombre').eq('id', restaurant_id).single()
    if (restErr || !restaurant) return json({ error: 'No autorizado.' }, 403)

    const { data: modulo } = await supabase
      .from('restaurant_modulos').select('activo')
      .eq('restaurant_id', restaurant_id).eq('modulo_key', 'multiidioma').eq('activo', true)
      .maybeSingle()
    if (!modulo) return json({ error: 'Este restaurante no tiene activo el módulo de carta multiidioma.' }, 403)

    const { data: items, error: itemsErr } = await supabase
      .from('menu_items').select('id, nombre, descripcion').eq('restaurant_id', restaurant_id)
    if (itemsErr) return json({ error: itemsErr.message }, 500)
    if (!items || items.length === 0) return json({ ok: true, traducidos: {} })

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!apiKey) return json({ error: 'Falta configurar ANTHROPIC_API_KEY en los secretos de la función.' }, 500)

    const resumen: Record<string, number> = {}

    for (const idioma of idiomasValidos) {
      const traducciones = await traducirLote(apiKey, items, idioma)
      const filas = traducciones
        .map((t) => {
          const original = items.find((i) => i.id === t.id)
          if (!original) return null
          return {
            menu_item_id: t.id,
            idioma,
            nombre: t.nombre,
            descripcion: t.descripcion ?? null,
            nombre_origen: original.nombre,
            descripcion_origen: original.descripcion ?? null,
            generado_en: new Date().toISOString(),
          }
        })
        .filter(Boolean)

      if (filas.length) {
        const { error: upsertErr } = await supabase
          .from('menu_item_traducciones')
          .upsert(filas, { onConflict: 'menu_item_id,idioma' })
        if (upsertErr) return json({ error: upsertErr.message }, 500)
      }
      resumen[idioma] = filas.length
    }

    // Guarda qué idiomas tienen traducción disponible, para que
    // Mesa.jsx sepa cuáles ofrecer en el selector.
    const { data: restConfig } = await supabase
      .from('restaurants').select('config').eq('id', restaurant_id).single()
    const idiomasPrevios: string[] = restConfig?.config?.idiomas_carta || []
    const idiomasNuevos = [...new Set([...idiomasPrevios, ...idiomasValidos])]
    await supabase
      .from('restaurants')
      .update({ config: { ...(restConfig?.config || {}), idiomas_carta: idiomasNuevos } })
      .eq('id', restaurant_id)

    return json({ ok: true, traducidos: resumen })
  } catch (e) {
    return json({ error: String(e?.message || e) }, 500)
  }
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

async function traducirLote(
  apiKey: string,
  items: { id: string; nombre: string; descripcion: string | null }[],
  idioma: string
): Promise<{ id: string; nombre: string; descripcion: string | null }[]> {
  const nombreIdioma = IDIOMA_NOMBRE[idioma]
  const entrada = items.map((i) => ({ id: i.id, nombre: i.nombre, descripcion: i.descripcion || '' }))

  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 8000,
      system:
        `Eres un traductor especializado en cartas de restaurante. Traduce el nombre y la ` +
        `descripción de cada plato al ${nombreIdioma}, conservando el tono gastronómico y sin ` +
        `inventar contenido que no esté en el original. Si la descripción llega vacía, devuélvela ` +
        `vacía. Responde ÚNICAMENTE con un array JSON válido, sin texto adicional ni bloques de ` +
        `código, con este formato exacto: [{"id":"...","nombre":"...","descripcion":"..."}]`,
      messages: [{ role: 'user', content: JSON.stringify(entrada) }],
    }),
  })

  if (!res.ok) throw new Error(`Anthropic API: ${res.status} ${await res.text()}`)
  const data = await res.json()
  const texto = data.content?.[0]?.text?.trim() || '[]'
  const limpio = texto.replace(/^```json\s*/i, '').replace(/^```\s*/, '').replace(/```\s*$/, '')
  return JSON.parse(limpio)
}
