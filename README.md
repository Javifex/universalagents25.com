# Universal Agents 25

Plataforma en desarrollo para contratar agentes o profesionales con IA y ofrecer servicios o crear agentes.

Sitio: https://universalagents25.com/

## Estado

La web incluye registro, inicio de sesión, confirmación por correo, recuperación de contraseña y edición del perfil en `cuenta.html`, conectados a Supabase `PrimerTestUniversalAgents25` (`ylyjlxpfbxdxebukdezt`). La contratación y la ejecución real de agentes siguen en desarrollo; los tres agentes iniciales están en borrador.

El funcionamiento del correo requiere configurar SMTP y las URLs de Auth en el proyecto remoto. Los ajustes y la prueba de aceptación se describen en [la guía de Supabase](docs/SUPABASE.md#registro-web-020).

## Base de datos

Supabase será la fuente común de identidad, datos y archivos privados. El esquema contempla una cuenta con ambas intenciones y dos reputaciones independientes: contratante y ejecutor.

- `supabase/migrations/`: tablas, relaciones, políticas y funciones.
- `supabase/seed.sql`: catálogo inicial como borradores desactivados.
- [Guía de preparación y conexión](docs/SUPABASE.md).
- [Registro de la estructura de la base de datos](docs/DATABASE_STRUCTURE.md): campos, relaciones, permisos e historial de cambios.

## Verificación

Con Node.js 22+ y Python 3:

```powershell
npm ci
npm run check
npm test
```

Los tests de PostgreSQL en memoria son efímeros y no requieren Supabase remoto. CI ejecuta además las comprobaciones SQL sobre Supabase local. Los archivos de backend, pruebas y documentación se excluyen de GitHub Pages.

El SDK oficial `@supabase/supabase-js@2.118.0` se sirve desde `vendor/`, con licencia y hash de integridad comprobados contra el paquete bloqueado. No se carga un CDN externo en la página de cuenta. Al actualizarlo, copiar su distribución UMD y actualizar su nombre, la integridad HTML y la comprobación en `tests/check_site.py`.
