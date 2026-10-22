# Supabase · Base común de Universal Agents 25

## Evaluación y alcance

La revisión del 22 de octubre de 2026 encontró una web de presentación: no había base de datos, usuarios, sesiones, APIs, almacenamiento persistente ni datos operativos que migrar. Las demos de la portada son ilustrativas y el contacto abre correo.

Se prepara una base nueva en Supabase. El proyecto remoto todavía no existe. Las migraciones y las pruebas se pueden revisar y ejecutar localmente; esto no habilita registro, contratación ni ejecución de agentes en la web publicada. El diseño y los scripts de la landing se conservan.

Supabase es la fuente común para los datos de la plataforma:

| Servicio | Responsabilidad |
| --- | --- |
| Auth | Identidad de la cuenta. Contratar y ofrecer son papeles de la misma identidad. |
| PostgreSQL | Perfiles, catálogo, proyectos, tareas, ejecuciones, permisos, evaluaciones, propuestas de aprendizaje y reseñas por rol. |
| Storage privado | CV, documentos de clientes, entradas y resultados. PostgreSQL conserva las referencias, no archivos codificados dentro de las filas. |
| Backend de confianza, pendiente | Validar encargos, asignaciones, cierres, presupuestos y permisos antes de ejecutar IA o modificar campos reservados. Puede usar funciones de Supabase y un worker cuando la duración del trabajo lo requiera. |

PGlite es solo el motor PostgreSQL efímero de las pruebas locales. No es una segunda base de datos de la aplicación ni se carga en el navegador.

## Modelo inicial

| Tabla | Qué conserva | Acceso del cliente |
| --- | --- | --- |
| `profiles` | Perfil de una identidad Auth; nombre y biografía, sin email ni secretos. | Propio; lectura pública solo cuando su titular publica el perfil. |
| `offerings` | Servicios, agentes, multiagentes y habilidades; metadatos del catálogo. | Propio o metadatos publicados. Catálogo general y activación gestionados por servidor. |
| `offering_versions` | Versiones y definiciones privadas de las ofertas. | Su propietario puede consultar y añadir versiones; las existentes no se sobrescriben. Publicar una oferta no publica su definición. |
| `projects` | Contratante, cuenta ejecutora, alcance y estado del encargo. | Solo sus partes; el cliente crea borradores, no asigna ni cierra encargos. |
| `project_tasks` | Trabajo de cada proyecto. | Sus partes; una tarea no se mueve entre clientes mediante una actualización. |
| `reviews` | Una reseña por autor y encargo, con el rol evaluado. | Solo autor y destinatario; no se editan ni borran desde el cliente. |
| `agent_runs` | Estados, referencias de archivos y costos/tokens registrados por el servidor. | Su titular puede consultar; no puede fingir ejecuciones ni costos. |
| `project_consents` | Permisos de contexto o aprendizaje por proyecto y persona. | Las partes consultan; cada persona modifica únicamente su permiso. |
| `self_evaluations` | Autoevaluación privada, opcionalmente vinculada a un proyecto propio. | Su titular. |
| `learning_proposals` | Propuestas de agentes o habilidades y la decisión de su titular. | Su titular consulta y decide; la generación corresponde al servidor. |

No se introducen pagos, equipos empresariales ni facturación hasta definir sus flujos. Las credenciales de modelos y herramientas pertenecen al entorno del backend o a un almacén de secretos; no a los perfiles, las definiciones públicas ni los archivos del cliente.

Las partes del encargo quedan fijas al activarlo. Un cambio de participantes en un borrador revoca sus consentimientos anteriores. Los estados completado y cancelado son terminales. Las relaciones conservan el historial: antes de habilitar la eliminación de cuentas habrá que definir retención, anonimización y retirada de archivos; borrar directamente una identidad con encargos u ofertas relacionados puede quedar bloqueado.

## Calificaciones separadas

- El contratante evalúa a la cuenta ejecutora como `executor`.
- El ejecutor evalúa a la cuenta contratante como `contractor`.
- Solo se admite una reseña por autor y encargo completado, sobre la contraparte correcta. El cliente no puede declararse ejecutor, completar su propio borrador para generar reseñas ni cambiar las partes de un encargo cerrado.
- La escala inicial propuesta es de 1 a 5. La moderación y las políticas de publicación siguen por definir.
- `get_reputation(p_profile_id)` devuelve dos filas: `contractor` y `executor`, cada una con `average_score` y `review_count`. Nunca devuelve un promedio combinado. Sin reseñas, el promedio es `null` y el conteo es cero: la interfaz deberá mostrar «Sin calificaciones».
- Los promedios completos solo se consultan sobre el propio perfil o un perfil expresamente público. El agregado no expone comentarios ni proyectos privados. La valoración independiente de una herramienta no se convierte automáticamente en reputación de su creador.

## Archivos y permisos

Los buckets `account-files` y `project-files` son privados, con límite inicial de 10 MiB por archivo. Se admiten PDF, DOCX, texto, JSON, CSV, PNG y JPEG.

- Archivo propio: `account-files/<id-de-cuenta>/<archivo>`.
- Archivo de un encargo: `project-files/<id-de-proyecto>/<archivo>`.
- El propietario conserva acceso a sus archivos mientras corresponda al ámbito permitido. El acceso de la otra parte a documentos del proyecto requiere el consentimiento de contexto del titular que los subió.
- Revocar ese consentimiento bloquea nuevas lecturas autorizadas por RLS. No recupera copias descargadas ni invalida URLs firmadas ya emitidas: el backend deberá emitirlas con duración corta y comprobar consentimiento antes de emitir otras.
- El consentimiento para trabajar con contexto y el consentimiento para aprendizaje son decisiones diferentes. El worker futuro deberá comprobar la autorización vigente antes de leer material para aprender o proponer una ayuda. Aprobar una propuesta no publica ni ejecuta un agente automáticamente.

RLS y los permisos de columnas protegen las operaciones de los clientes. La clave secreta del servidor omite RLS: por eso las operaciones privilegiadas deberán autenticar al solicitante, comprobar sus permisos y aplicar límites antes de usarla. Una clave pública no sustituye estas políticas.

## Preparación local

Requisitos: Node.js 22 o posterior y Python 3. Para levantar Supabase local también se necesita Docker en funcionamiento. Los tests de PostgreSQL en memoria no necesitan Docker ni credenciales.

```powershell
npm ci
npm run check
npm test
```

La prueba en memoria crea identidades, roles y un esquema mínimo de Auth/Storage exclusivamente como fixture. Ejecuta las migraciones reales, los datos iniciales y las comprobaciones SQL con varios usuarios. No valida correo, OAuth ni las APIs HTTP de Auth/Storage. La integración de esquema con Supabase real se comprueba adicionalmente en CI.

Para una base local nueva y desechable:

```powershell
npm run db:start
npm run db:reset
npm run db:lint
```

`db:reset` reconstruye únicamente la base local del proyecto; borra sus datos locales. No se debe usar sobre un entorno con información que se necesite conservar. El archivo `supabase/config.toml` está preparado para desarrollo local, no para sobrescribir indiscriminadamente la configuración Auth de producción.

Los tres registros iniciales del catálogo —CV adaptado, entrevista y redacción profesional— se crean como borradores desactivados. No representan agentes integrados o disponibles para ejecutar.

## Cuando se cree el proyecto remoto

1. Crear el proyecto en Supabase y conservar su referencia. Definir las URLs Auth de producción y el envío de correo según el flujo que se vaya a habilitar.
2. Autenticarse y vincular esta carpeta desde la CLI, sin escribir contraseñas en comandos versionados:

```powershell
npx supabase login
npx supabase link --project-ref TU_REFERENCIA
npm run db:plan
```

3. Revisar el plan. Aplicar las migraciones con `npx supabase db push`. El seed no se envía por defecto; `npx supabase db push --include-seed` lo incluye una vez revisados sus borradores.
4. Copiar `.env.example` a `.env` y completar URL y clave publicable para el futuro cliente. La clave secreta es exclusivamente del backend. `.env` está ignorado por Git y no forma parte de los paquetes de publicación.
5. Implementar y probar el flujo de acceso y las APIs privilegiadas antes de conectar formularios o habilitar escrituras en la portada. Una landing estática no lee `.env` ni protege operaciones usando solo JavaScript.

No ejecutar `db reset --linked` sobre producción. Para cambios posteriores, crear nuevas migraciones y revisar el plan antes de aplicarlo; no editar una migración ya desplegada.

## Referencias técnicas

- [Migraciones y desarrollo local de Supabase](https://supabase.com/docs/guides/local-development/database-migrations)
- [RLS, permisos y agregados seguros](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Permisos de Supabase Storage](https://supabase.com/docs/guides/storage/security/access-control)
- [PGlite: PostgreSQL efímero para pruebas](https://pglite.dev/docs/)
