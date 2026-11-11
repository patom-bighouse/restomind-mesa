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

## Consecuencias
- Más pasos y algo más de consumo por tarea; a cambio, criterios claros antes de programar y una revisión real antes de cada PR.
- Las especificaciones aprobadas quedan como historial de por qué se hizo cada cosa.
