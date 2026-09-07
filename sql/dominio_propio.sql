-- ============================================================================
-- Dominio propio para la carta (#22 del roadmap): cada restaurante
-- puede elegir un subdominio propio (ej. "la-encina" →
-- la-encina.restomind.app) para que el QR/enlace de sus mesas se vea
-- con su marca en vez del dominio compartido de la plataforma.
--
-- Columna aparte (no dentro de config) porque necesita ser única a
-- nivel de toda la plataforma — dos restaurantes no pueden compartir
-- subdominio.
-- ============================================================================

alter table restaurants add column if not exists subdominio text;

alter table restaurants drop constraint if exists restaurants_subdominio_formato;
alter table restaurants add constraint restaurants_subdominio_formato
  check (subdominio is null or subdominio ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$');

-- Único a nivel de toda la plataforma, sin distinguir mayúsculas —
-- permite varios NULL (restaurantes sin subdominio propio todavía).
create unique index if not exists restaurants_subdominio_unique
  on restaurants (lower(subdominio))
  where subdominio is not null;
