// Extrae categorías y platos de una o varias fotos de una carta
// impresa, usando la API de Anthropic (clave de la plataforma). Solo
// EXTRAE y devuelve la estructura — nunca escribe en la base de
// datos: AdminCarta.jsx muestra el resultado en una pantalla de
// revisión editable y el dueño decide qué importar de verdad.
//
// Body esperado: { restaurant_id: string, imagenes: string[] }
// (cada imagen como data URI: "data:image/jpeg;base64,...")

import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { restaurant_id, imagenes } = await req.json()
    if (!restaurant_id || !Array.isArray(imagenes) || imagenes.length === 0) {
      return json({ error: 'Faltan restaurant_id o imágenes.' }, 400)
    }
    if (imagenes.length > 6) {
      return json({ error: 'Máximo 6 fotos por importación.' }, 400)
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
      .eq('restaurant_id', restaurant_id).eq('modulo_key', 'importador_carta').eq('activo', true)
      .maybeSingle()
    if (!modulo) return json({ error: 'Este restaurante no tiene activo el módulo de importador de carta.' }, 403)

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!apiKey) return json({ error: 'Falta configurar ANTHROPIC_API_KEY en los secretos de la función.' }, 500)

    const bloquesImagen = imagenes.map((dataUri: string) => {
      const match = /^data:(image\/[a-z]+);base64,(.+)$/.exec(dataUri)
      if (!match) throw new Error('Formato de imagen inválido.')
      return { type: 'image', source: { type: 'base64', media_type: match[1], data: match[2] } }
    })

    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-5',
        max_tokens: 8000,
        system:
          'Eres un asistente que digitaliza cartas de restaurante a partir de fotos. Lee todas las ' +
          'imágenes (pueden ser varias páginas de la misma carta) y extrae cada plato con su ' +
          'categoría, nombre, descripción (si la hay) y precio. El precio es siempre un número, sin ' +
          'símbolo de moneda (ej. 12.50, nunca "12,50€"). Si no hay descripción, deja el campo vacío. ' +
          'Agrupa los platos bajo el nombre de categoría tal como aparece impreso (ej. "Entrantes", ' +
          '"Primeros", "Postres") — si no hay categorías visibles, usa "Carta". No inventes platos ' +
          'que no estén en la foto. Responde ÚNICAMENTE con un JSON válido, sin texto adicional ni ' +
          'bloques de código, con este formato exacto: ' +
          '{"categorias":[{"nombre":"...","platos":[{"nombre":"...","descripcion":"...","precio":0}]}]}',
        messages: [{ role: 'user', content: [...bloquesImagen, { type: 'text', text: 'Extrae la carta de estas fotos.' }] }],
      }),
    })

    if (!res.ok) return json({ error: `Anthropic API: ${res.status} ${await res.text()}` }, 500)
    const data = await res.json()
    const texto = data.content?.[0]?.text?.trim() || '{}'
    const limpio = texto.replace(/^```json\s*/i, '').replace(/^```\s*/, '').replace(/```\s*$/, '')
    const extraido = JSON.parse(limpio)

    return json({ ok: true, categorias: extraido.categorias || [] })
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
