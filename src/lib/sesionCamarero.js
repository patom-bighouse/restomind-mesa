import { supabase } from './supabase'

// Sesión de camarero con PIN (docs/specs/2026-11-12-pin-camarero.md).
// fn_verificar_camarero_pin devuelve un token al acertar el PIN; las funciones
// del camarero lo reciben como p_token (p_camarero_token en fn_registrar_pedido)
// y, si la sesión ya no vale (caducada, cerrada, PIN cambiado, camarero dado de
// baja…), fallan con el código RM401.

export const CODIGO_SESION_CADUCADA = 'RM401'
export const AVISO_SESION_CADUCADA = 'Tu sesión ha caducado. Vuelve a introducir tu PIN.'

export function esSesionCamareroCaducada(error) {
  return !!error && error.code === CODIGO_SESION_CADUCADA
}

// Llama a una función del camarero añadiendo su token. Si la sesión ya no
// vale, avisa con onSesionCaducada(tokenEnviado) y devuelve el error igual,
// para que quien llama no lo trate como un fallo normal. Se pasa el token con
// el que salió la petición: quien recibe el aviso solo debe cerrar la sesión
// si ese token sigue siendo el actual (una respuesta tardía con el token de
// otra persona, o de una sesión anterior, no debe echar a quien acaba de entrar).
export async function rpcCamarero(fn, params, camarero, onSesionCaducada, parametroToken = 'p_token') {
  const tokenEnviado = camarero?.token ?? null
  const res = await supabase.rpc(fn, { ...params, [parametroToken]: tokenEnviado })
  if (esSesionCamareroCaducada(res.error) && onSesionCaducada) onSesionCaducada(tokenEnviado)
  return res
}
