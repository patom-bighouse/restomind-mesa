// Traduce toda la carta de un restaurante (platos, categorías,
// modificadores y mensajes de upsell) a uno o varios idiomas usando la
// API de Anthropic (clave de la plataforma, nunca del restaurante — se
// guarda como secreto de esta función, jamás llega al navegador). Se
// llama una vez desde AdminCarta.jsx, no en cada visita de un
// comensal: el resultado queda guardado en las tablas *_traducciones y
// Mesa.jsx solo las lee. Los alérgenos NO pasan por acá — son un
// catálogo fijo por ley, se traducen como texto estático en el código
// (src/lib/idiomas.js).
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

type Texto = { id: string; nombre?: string; descripcion?: string; mensaje?: string }
type Entrada = {
  platos: Texto[]
  categorias: Texto[]
  modificador_grupos: Texto[]
  modificador_opciones: Texto[]
  upsells: Texto[]
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

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!apiKey) return json({ error: 'Falta configurar ANTHROPIC_API_KEY en los secretos de la función.' }, 500)

    const [platosRes, categoriasRes, gruposRes, upsellsRes] = await Promise.all([
      supabase.from('menu_items').select('id, nombre, descripcion').eq('restaurant_id', restaurant_id),
      supabase.from('categories').select('id, nombre').eq('restaurant_id', restaurant_id),
      supabase.from('modificador_grupos').select('id, nombre').eq('restaurant_id', restaurant_id),
      supabase.from('upsell_rules').select('id, mensaje').eq('restaurant_id', restaurant_id).not('mensaje', 'is', null),
    ])
    for (const r of [platosRes, categoriasRes, gruposRes, upsellsRes]) {
      if (r.error) return json({ error: r.error.message }, 500)
    }
    const platos = platosRes.data || []
    const categorias = categoriasRes.data || []
    const grupos = gruposRes.data || []
    const upsells = upsellsRes.data || []

    const grupoIds = grupos.map((g) => g.id)
    const { data: opciones, error: opcErr } = grupoIds.length
      ? await supabase.from('modificador_opciones').select('id, nombre').in('grupo_id', grupoIds)
      : { data: [], error: null }
    if (opcErr) return json({ error: opcErr.message }, 500)

    if (!platos.length && !categorias.length && !grupos.length && !opciones!.length && !upsells.length) {
      return json({ ok: true, traducidos: {} })
    }

    const entrada: Entrada = {
      platos: platos.map((i) => ({ id: i.id, nombre: i.nombre, descripcion: i.descripcion || '' })),
      categorias: categorias.map((c) => ({ id: c.id, nombre: c.nombre })),
      modificador_grupos: grupos.map((g) => ({ id: g.id, nombre: g.nombre })),
      modificador_opciones: (opciones || []).map((o) => ({ id: o.id, nombre: o.nombre })),
      upsells: upsells.map((u) => ({ id: u.id, mensaje: u.mensaje })),
    }

    const resumen: Record<string, number> = {}

    for (const idioma of idiomasValidos) {
      const traducido = await traducirTodo(apiKey, entrada, idioma)
      let total = 0

      total += await guardar(supabase, 'menu_item_traducciones', 'menu_item_id', idioma, traducido.platos, platos, ['nombre', 'descripcion'])
      total += await guardar(supabase, 'categoria_traducciones', 'category_id', idioma, traducido.categorias, categorias, ['nombre'])
      total += await guardar(supabase, 'modificador_grupo_traducciones', 'grupo_id', idioma, traducido.modificador_grupos, grupos, ['nombre'])
      total += await guardar(supabase, 'modificador_opcion_traducciones', 'opcion_id', idioma, traducido.modificador_opciones, opciones || [], ['nombre'])
      total += await guardar(supabase, 'upsell_traducciones', 'upsell_rule_id', idioma, traducido.upsells, upsells, ['mensaje'])

      resumen[idioma] = total
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

// Guarda las traducciones de un tipo (platos/categorías/...) en su
// tabla correspondiente, junto a un snapshot del texto original para
// poder detectar más adelante cuándo quedó desactualizada.
async function guardar(
  supabase: ReturnType<typeof createClient>,
  tabla: string,
  columnaId: string,
  idioma: string,
  traducidos: Texto[],
  originales: Texto[],
  campos: ('nombre' | 'descripcion' | 'mensaje')[]
): Promise<number> {
  if (!traducidos?.length) return 0
  const filas = traducidos
    .map((t) => {
      const original = originales.find((o) => o.id === t.id)
      if (!original) return null
      const fila: Record<string, unknown> = {
        [columnaId]: t.id,
        idioma,
        generado_en: new Date().toISOString(),
      }
      for (const campo of campos) {
        fila[campo] = t[campo] ?? null
        fila[`${campo}_origen`] = original[campo] ?? null
      }
      return fila
    })
    .filter(Boolean)
  if (!filas.length) return 0
  const { error } = await supabase.from(tabla).upsert(filas, { onConflict: `${columnaId},idioma` })
  if (error) throw new Error(`${tabla}: ${error.message}`)
  return filas.length
}

async function traducirTodo(apiKey: string, entrada: Entrada, idioma: string): Promise<Entrada> {
  const nombreIdioma = IDIOMA_NOMBRE[idioma]

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
        `Eres un traductor especializado en cartas de restaurante. Traduce al ${nombreIdioma} todos ` +
        `los textos del JSON de entrada, conservando el tono gastronómico y sin inventar contenido ` +
        `que no esté en el original. "platos" tiene nombre y descripción de cada plato; ` +
        `"categorias" y "modificador_grupos"/"modificador_opciones" solo tienen nombre (ej. de grupo: ` +
        `"Punto de cocción", de opción: "Poco hecho"); "upsells" tiene un mensaje corto sugiriendo ` +
        `un producto. Si una descripción o mensaje llega vacío, devuélvelo vacío. Responde ` +
        `ÚNICAMENTE con un JSON válido, sin texto adicional ni bloques de código, con EXACTAMENTE ` +
        `la misma forma que la entrada (mismos arrays, mismos "id", mismos campos presentes por ` +
        `elemento), solo con los textos traducidos.`,
      messages: [{ role: 'user', content: JSON.stringify(entrada) }],
    }),
  })

  if (!res.ok) throw new Error(`Anthropic API: ${res.status} ${await res.text()}`)
  const data = await res.json()
  const texto = data.content?.[0]?.text?.trim() || '{}'
  const limpio = texto.replace(/^```json\s*/i, '').replace(/^```\s*/, '').replace(/```\s*$/, '')
  const parsed = JSON.parse(limpio)
  return {
    platos: parsed.platos || [],
    categorias: parsed.categorias || [],
    modificador_grupos: parsed.modificador_grupos || [],
    modificador_opciones: parsed.modificador_opciones || [],
    upsells: parsed.upsells || [],
  }
}
