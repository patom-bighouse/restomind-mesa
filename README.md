# Restomind

Plataforma de gestión para restaurantes: pedidos en mesa por QR, camarero, cocina, reservas, take away, fidelización, CRM comercial y agente de WhatsApp.

## Arrancar en local
```bash
npm install
cp .env.example .env    # rellenar con las claves del proyecto de Supabase TEST
npm run dev
```

## Documentación
- `CLAUDE.md` — reglas y contexto del proyecto (para Claude y para humanos)
- `docs/ARQUITECTURA.md` — cómo encajan las piezas
- `docs/FLUJO_DE_TRABAJO.md` — de la idea a producción, con checklist de "terminado"
- `docs/MIGRACIONES.md` — cambios de base de datos
- `docs/BACKLOG.md` — qué viene
- `docs/decisiones/` — decisiones de arquitectura

## Ramas
`feature/*` → `staging` (Supabase Test + preview de Vercel) → `main` (producción).
