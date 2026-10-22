# Universal Agents 25

Plataforma en desarrollo para contratar agentes o profesionales con IA y ofrecer servicios o crear agentes.

Sitio: https://universalagents25.com/

## Estado

La web publicada es una presentación estática. La base Supabase está preparada en código; todavía no existe un proyecto remoto conectado, ni están habilitados registro, contratación o ejecución real de agentes.

## Base de datos

Supabase será la fuente común de identidad, datos y archivos privados. El esquema contempla una cuenta con ambas intenciones y dos reputaciones independientes: contratante y ejecutor.

- `supabase/migrations/`: tablas, relaciones, políticas y funciones.
- `supabase/seed.sql`: catálogo inicial como borradores desactivados.
- [Guía de preparación y conexión](docs/SUPABASE.md).

## Verificación

Con Node.js 22+ y Python 3:

```powershell
npm ci
npm run check
npm test
```

Los tests de PostgreSQL en memoria son efímeros y no requieren Supabase remoto. CI ejecuta además las comprobaciones SQL sobre Supabase local. Los archivos de backend, pruebas y documentación se excluyen de GitHub Pages.
