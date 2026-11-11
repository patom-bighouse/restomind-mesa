# 0002 — Trabajo con 4 agentes

- **Fecha:** 2026-11-11
- **Estado:** aceptada

## Contexto
Patricio quiere un sistema de trabajo estable con Claude, con papeles separados para que una misma "mente" no especifique, implemente y se dé el visto bueno a sí misma.

## Decisión
Cuatro papeles: orquestador, `spec`, `implementador` y `revisor`.
- El orquestador es la sesión principal de Claude, porque en Claude Code un subagente no puede lanzar otros subagentes.
- `spec`, `implementador` y `revisor` son subagentes definidos en `.claude/agents/`.
- El `revisor` no puede editar archivos y trabaja sin el contexto de la implementación: su valor está en la independencia.
- Las especificaciones se guardan en `docs/specs/` y Patricio las aprueba antes de implementar.
- Tareas pequeñas: se puede saltar `spec`, nunca `revisor`.

## Pruebas
No hay un agente de pruebas propio. Se reparten:
- `spec` define cómo se prueba cada criterio de aceptación (auto, sql, conversación o manual).
- `implementador` escribe y ejecuta esas pruebas.
- `revisor` las vuelve a ejecutar por su cuenta y bloquea si algún criterio no tiene prueba.
- Patricio valida solo lo marcado como manual.

## Cuándo añadir un quinto agente (`tester`)
Se descartó de momento por coste y lentitud. Reconsiderarlo cuando ocurra alguna de estas cosas:
- Llegan a producción fallos que las pruebas del `implementador` no detectaron (señal de que quien programa prueba "a favor" de su código).
- Hacen falta pruebas de extremo a extremo (Playwright sobre la preview) o baterías grandes de conversaciones del agente de WhatsApp.
- Entra más gente a desarrollar o el número de clientes en producción hace que un fallo cueste mucho más.

El `tester` escribiría las pruebas a partir de la especificación, sin ver el código, y las ejecutaría contra Test.

## Consecuencias
- Más pasos y algo más de consumo por tarea; a cambio, criterios claros antes de programar y una revisión real antes de cada PR.
- Las especificaciones aprobadas quedan como historial de por qué se hizo cada cosa.
