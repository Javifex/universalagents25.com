# Estructura de la base de datos de Universal Agents 25

Registro de referencia 1.0.0. Fecha de corte: 22 de octubre de 2026. Código de referencia 0.1.1.

Este registro documenta la estructura instalada en Supabase y conserva el historial necesario para revisarla con cada migración. Reúne tablas, campos, relaciones, índices, permisos y reglas de trabajo. La base está instalada; el registro, la contratación y la ejecución de agentes desde la web siguen pendientes.

## 1 Identidad y alcance

| Dato | Valor |
| --- | --- |
| Proyecto | PrimerTestUniversalAgents25 |
| Referencia | `ylyjlxpfbxdxebukdezt` |
| Región | us-east-1 |
| Motor verificado | PostgreSQL 17.11 |
| Esquemas propios | public y private |
| Autenticación | Supabase Auth |
| Archivos | Supabase Storage privado |

Los recuentos siguientes cubren las tablas de la aplicación y sus auxiliares. No representan todas las tablas internas de Auth, Storage u otros servicios administrados de Supabase. No se incluyen contraseñas, claves API ni contenidos de usuarios.

| Elemento | Cantidad |
| --- | --- |
| Tablas de aplicación | 10 |
| Campos | 70 |
| Relaciones por clave foránea | 18 |
| Índices incluidos los de claves | 29 |
| Políticas de aplicación | 25 |
| Políticas de archivos | 8 |
| Espacios privados de archivos | 2 |
| Triggers propios de fila | 3 |
| Funciones propias y administrada relacionada | 11 |
| Migraciones aplicadas | 2 |

Los 29 índices incluyen 16 explícitos, diez asociados a claves primarias y tres a reglas de unicidad. Las diez tablas de aplicación tienen RLS habilitado.

Una clave primaria identifica una fila. Una clave foránea relaciona una fila con otra tabla. RLS limita qué filas puede consultar o cambiar cada cuenta; los permisos de columnas limitan qué campos puede escribir. En el diccionario, Nulo indica si el campo puede quedar sin valor; timestamptz es el alias de timestamp with time zone.

## 2 Relaciones entre las entidades

Una identidad Auth tiene un perfil. Ese perfil puede crear ofertas, contratar encargos y ejecutar trabajo para otros. Cada proyecto vincula sus tareas, reseñas y permisos. Las ejecuciones, autoevaluaciones y propuestas pueden guardar una referencia opcional al proyecto.

| Campo de origen | Referencia | Nulo |
| --- | --- | --- |
| `profiles.id` | `auth.users.id` | No |
| `offerings.owner_id` | `public.profiles.id` | Sí |
| `offering_versions.offering_id` | `public.offerings.id` | No |
| `projects.contractor_id` | `public.profiles.id` | No |
| `projects.executor_id` | `public.profiles.id` | Sí |
| `project_tasks.project_id` | `public.projects.id` | No |
| `reviews.project_id` | `public.projects.id` | No |
| `reviews.reviewed_id` | `public.profiles.id` | No |
| `reviews.reviewer_id` | `public.profiles.id` | No |
| `agent_runs.offering_id` | `public.offerings.id` | No |
| `agent_runs.owner_id` | `public.profiles.id` | No |
| `agent_runs.project_id` | `public.projects.id` | Sí |
| `project_consents.project_id` | `public.projects.id` | No |
| `project_consents.user_id` | `public.profiles.id` | No |
| `self_evaluations.owner_id` | `public.profiles.id` | No |
| `self_evaluations.project_id` | `public.projects.id` | Sí |
| `learning_proposals.owner_id` | `public.profiles.id` | No |
| `learning_proposals.project_id` | `public.projects.id` | Sí |

La relación profiles.id con auth.users.id tiene ON DELETE CASCADE. Las otras 17 relaciones usan NO ACTION: una cuenta o entidad referenciada puede quedar bloqueada frente a un borrado directo. La retención y anonimización deben definirse antes de habilitar la eliminación de cuentas.

## 3 Diccionario de tablas

### Perfiles

Tabla `public.profiles`. 5 campos. Perfil de una cuenta de Supabase Auth. La misma identidad puede contratar y ofrecer servicios; no tiene un rol exclusivo.

| Campo | Tipo | Nulo | Descripción y valor inicial |
| --- | --- | --- | --- |
| `id` | `uuid` | No | Identidad vinculada a auth.users. Inicial: `auth.uid()`. |
| `display_name` | `text` | No | Nombre visible de la persona o empresa. Inicial: `''`. |
| `bio` | `text` | No | Presentación del perfil. Inicial: `''`. |
| `is_public` | `boolean` | No | Decisión de publicar el perfil. Inicial: `false`. |
| `created_at` | `timestamptz` | No | Fecha y hora de creación. Inicial: `now()`. |

Clave primaria: `PRIMARY KEY (id)`.

Nombre hasta 100 caracteres y biografía hasta 2000. El perfil empieza privado. El correo y las credenciales pertenecen a Auth, no a esta tabla.

Índices: `profiles_pkey`.

### Ofertas del catálogo

Tabla `public.offerings`. 10 campos. Catálogo de servicios, agentes, multiagentes y habilidades. Separa las ofertas generales de la plataforma y las especializadas de un creador.

| Campo | Tipo | Nulo | Descripción y valor inicial |
| --- | --- | --- | --- |
| `id` | `uuid` | No | Identificador del registro. Inicial: `gen_random_uuid()`. |
| `owner_id` | `uuid` | Sí | Creador de la oferta; vacío para el catálogo general. Inicial: `auth.uid()`. |
| `slug` | `text` | No | Nombre único para identificar la oferta. Sin valor automático. |
| `title` | `text` | No | Título visible. Sin valor automático. |
| `description` | `text` | No | Descripción del alcance o contenido. Inicial: `''`. |
| `kind` | `text` | No | Tipo de capacidad ofrecida. Sin valor automático. |
| `audience` | `text` | No | Catálogo general o especializado. Inicial: `'specialized'`. |
| `visibility` | `text` | No | Visibilidad de los metadatos. Inicial: `'draft'`. |
| `is_enabled` | `boolean` | No | Activación reservada al servidor. Inicial: `false`. |
| `created_at` | `timestamptz` | No | Fecha y hora de creación. Inicial: `now()`. |

Clave primaria: `PRIMARY KEY (id)`. Unicidad adicional: `UNIQUE (slug)`.

Tipos service, agent, multiagent o skill. Audiencia general o specialized. Visibilidad draft, private o public. El catálogo general exige owner_id vacío; el especializado exige un propietario. Slug único de hasta 120 caracteres, con minúsculas, números y guiones. Título de 1 a 200 y descripción de hasta 10000 caracteres.

Índices: `offerings_owner_idx`, `offerings_pkey`, `offerings_public_idx`, `offerings_slug_key`.

### Versiones de las ofertas

Tabla `public.offering_versions`. 5 campos. Definiciones JSON privadas de cada oferta, conservadas como versiones que pueden consultarse y añadirse.

| Campo | Tipo | Nulo | Descripción y valor inicial |
| --- | --- | --- | --- |
| `id` | `uuid` | No | Identificador del registro. Inicial: `gen_random_uuid()`. |
| `offering_id` | `uuid` | No | Oferta a la que pertenece la versión. Sin valor automático. |
| `version` | `integer` | No | Número de versión de esa oferta. Sin valor automático. |
| `definition` | `jsonb` | No | Definición privada en un objeto JSON. Inicial: `'{}'`. |
| `created_at` | `timestamptz` | No | Fecha y hora de creación. Inicial: `now()`. |

Clave primaria: `PRIMARY KEY (id)`. Unicidad adicional: `UNIQUE (offering_id, version)`.

Versión mayor que cero, única dentro de cada oferta. La definición debe ser un objeto JSON. Cliente y service_role pueden añadir versiones, pero no sobrescribirlas ni borrarlas; la administración de base conserva privilegios superiores.

Índices: `offering_versions_offering_id_version_key`, `offering_versions_pkey`.

### Proyectos

Tabla `public.projects`. 7 campos. Encargo acordado entre una cuenta contratante y una ejecutora. Organiza el alcance y el estado del trabajo.

| Campo | Tipo | Nulo | Descripción y valor inicial |
| --- | --- | --- | --- |
| `id` | `uuid` | No | Identificador del registro. Inicial: `gen_random_uuid()`. |
| `contractor_id` | `uuid` | No | Cuenta que contrata el encargo. Inicial: `auth.uid()`. |
| `executor_id` | `uuid` | Sí | Cuenta responsable de ejecutarlo. Sin valor automático. |
| `title` | `text` | No | Título visible. Sin valor automático. |
| `description` | `text` | No | Descripción del alcance o contenido. Inicial: `''`. |
| `status` | `text` | No | Estado del encargo. Inicial: `'draft'`. |
| `created_at` | `timestamptz` | No | Fecha y hora de creación. Inicial: `now()`. |

Clave primaria: `PRIMARY KEY (id)`.

Estados draft, active, completed o cancelled. Las dos partes deben ser distintas; active y completed requieren ejecutor. Los participantes solo cambian en borrador y ese cambio revoca los consentimientos anteriores. Active no vuelve a draft; completed y cancelled son terminales. El título y la descripción siguen siendo editables por el contratante.

Índices: `projects_contractor_idx`, `projects_executor_idx`, `projects_pkey`, `projects_storage_path_idx`.

### Tareas de los proyectos

Tabla `public.project_tasks`. 6 campos. Tareas que pertenecen a un encargo y que sus participantes pueden consultar y actualizar.

| Campo | Tipo | Nulo | Descripción y valor inicial |
| --- | --- | --- | --- |
| `id` | `uuid` | No | Identificador del registro. Inicial: `gen_random_uuid()`. |
| `project_id` | `uuid` | No | Proyecto al que pertenece el registro. Sin valor automático. |
| `title` | `text` | No | Título visible. Sin valor automático. |
| `description` | `text` | No | Descripción del alcance o contenido. Inicial: `''`. |
| `status` | `text` | No | Estado de la tarea. Inicial: `'todo'`. |
| `created_at` | `timestamptz` | No | Fecha y hora de creación. Inicial: `now()`. |

Clave primaria: `PRIMARY KEY (id)`.

Estados todo, in_progress, review o done. Título de 1 a 200 y descripción de hasta 10000 caracteres. El cliente no puede trasladar la tarea a otro proyecto cambiando project_id. No hay un bloqueo general de tareas al completar el encargo.

Índices: `project_tasks_pkey`, `project_tasks_project_idx`.

### Reseñas por rol

Tabla `public.reviews`. 8 campos. Reseñas sobre la contraparte de un encargo completado. El rol evaluado determina a cuál de las dos reputaciones contribuye.

| Campo | Tipo | Nulo | Descripción y valor inicial |
| --- | --- | --- | --- |
| `id` | `uuid` | No | Identificador del registro. Inicial: `gen_random_uuid()`. |
| `project_id` | `uuid` | No | Proyecto al que pertenece el registro. Sin valor automático. |
| `reviewer_id` | `uuid` | No | Cuenta que escribe la reseña. Inicial: `auth.uid()`. |
| `reviewed_id` | `uuid` | No | Cuenta que recibe la evaluación. Sin valor automático. |
| `reviewed_role` | `text` | No | Rol de la cuenta evaluada en ese encargo. Sin valor automático. |
| `score` | `smallint` | No | Nota entera de 1 a 5. Sin valor automático. |
| `comment` | `text` | No | Comentario de la evaluación. Inicial: `''`. |
| `created_at` | `timestamptz` | No | Fecha y hora de creación. Inicial: `now()`. |

Clave primaria: `PRIMARY KEY (id)`. Unicidad adicional: `UNIQUE (project_id, reviewer_id)`.

Una reseña por autor y proyecto, sin autoevaluación, sobre la contraparte correcta de un proyecto completado. Roles contractor o executor. Nota de 1 a 5 y comentario de hasta 2000 caracteres. Las reseñas no se editan ni borran desde el cliente.

Índices: `reviews_pkey`, `reviews_project_id_reviewer_id_key`, `reviews_reputation_idx`, `reviews_reviewer_idx`.

### Ejecuciones de agentes

Tabla `public.agent_runs`. 11 campos. Registro de estados, rutas de archivos y consumo de una ejecución. Esta tabla no ejecuta IA por sí sola.

| Campo | Tipo | Nulo | Descripción y valor inicial |
| --- | --- | --- | --- |
| `id` | `uuid` | No | Identificador del registro. Inicial: `gen_random_uuid()`. |
| `owner_id` | `uuid` | No | Cuenta titular del registro. Sin valor automático. |
| `offering_id` | `uuid` | No | Oferta utilizada; no referencia una versión concreta. Sin valor automático. |
| `project_id` | `uuid` | Sí | Proyecto al que pertenece el registro. Sin valor automático. |
| `status` | `text` | No | Estado registrado de la ejecución. Inicial: `'queued'`. |
| `input_path` | `text` | Sí | Referencia al archivo de entrada. Sin valor automático. |
| `output_path` | `text` | Sí | Referencia al archivo de salida. Sin valor automático. |
| `cost_usd` | `numeric(16,8)` | Sí | Costo registrado en USD; puede quedar pendiente. Sin valor automático. |
| `input_tokens` | `bigint` | Sí | Cantidad registrada de tokens de entrada. Sin valor automático. |
| `output_tokens` | `bigint` | Sí | Cantidad registrada de tokens de salida. Sin valor automático. |
| `created_at` | `timestamptz` | No | Fecha y hora de creación. Inicial: `now()`. |

Clave primaria: `PRIMARY KEY (id)`.

Estados queued, running, succeeded o failed. El servidor escribe las ejecuciones y el cliente solo consulta las propias. Costos no negativos y distintos de NaN; tokens no negativos. Registrar un costo no implementa cobros, presupuestos ni límites de consumo.

Índices: `agent_runs_offering_idx`, `agent_runs_owner_idx`, `agent_runs_pkey`, `agent_runs_project_idx`.

### Consentimientos por proyecto

Tabla `public.project_consents`. 5 campos. Decisión de cada participante sobre compartir contexto o permitir aprendizaje en un proyecto.

| Campo | Tipo | Nulo | Descripción y valor inicial |
| --- | --- | --- | --- |
| `project_id` | `uuid` | No | Proyecto al que pertenece el registro. Sin valor automático. |
| `user_id` | `uuid` | No | Participante que toma la decisión. Inicial: `auth.uid()`. |
| `purpose` | `text` | No | Contexto de trabajo o aprendizaje. Sin valor automático. |
| `granted` | `boolean` | No | Permiso concedido o retirado. Inicial: `false`. |
| `updated_at` | `timestamptz` | No | Fecha de la última actualización del permiso. Inicial: `now()`. |

Clave primaria: `PRIMARY KEY (project_id, user_id, purpose)`.

Finalidades context y learning. La clave primaria combina proyecto, persona y finalidad. Solo el titular modifica su permiso. Concederlo requiere un estado distinto de draft, también puede ser completed o cancelled; retirarlo sigue permitido siendo miembro. Los archivos ajenos de un borrador no se comparten.

Índices: `project_consents_pkey`, `project_consents_user_idx`.

### Autoevaluaciones privadas

Tabla `public.self_evaluations`. 5 campos. Notas privadas de autoevaluación de una persona, vinculadas opcionalmente a un proyecto.

| Campo | Tipo | Nulo | Descripción y valor inicial |
| --- | --- | --- | --- |
| `id` | `uuid` | No | Identificador del registro. Inicial: `gen_random_uuid()`. |
| `owner_id` | `uuid` | No | Cuenta titular del registro. Inicial: `auth.uid()`. |
| `project_id` | `uuid` | Sí | Proyecto al que pertenece el registro. Sin valor automático. |
| `notes` | `text` | No | Contenido de la autoevaluación privada. Sin valor automático. |
| `created_at` | `timestamptz` | No | Fecha y hora de creación. Inicial: `now()`. |

Clave primaria: `PRIMARY KEY (id)`.

Notas de 1 a 10000 caracteres. El titular puede consultar y modificar sus notas. Si vincula un proyecto al crearlas, debe participar en él. El cliente no cambia posteriormente el propietario ni el proyecto.

Índices: `self_evaluations_owner_idx`, `self_evaluations_pkey`, `self_evaluations_project_idx`.

### Propuestas de aprendizaje

Tabla `public.learning_proposals`. 8 campos. Propuestas de agentes o habilidades generadas por el servidor, junto con la decisión de su titular.

| Campo | Tipo | Nulo | Descripción y valor inicial |
| --- | --- | --- | --- |
| `id` | `uuid` | No | Identificador del registro. Inicial: `gen_random_uuid()`. |
| `owner_id` | `uuid` | No | Cuenta titular del registro. Sin valor automático. |
| `project_id` | `uuid` | Sí | Proyecto al que pertenece el registro. Sin valor automático. |
| `kind` | `text` | No | Tipo de ayuda propuesta. Sin valor automático. |
| `explanation` | `text` | No | Motivo y utilidad de la propuesta. Sin valor automático. |
| `definition` | `jsonb` | No | Definición privada en un objeto JSON. Inicial: `'{}'`. |
| `decision` | `text` | No | Decisión del titular sobre la propuesta. Inicial: `'pending'`. |
| `created_at` | `timestamptz` | No | Fecha y hora de creación. Inicial: `now()`. |

Clave primaria: `PRIMARY KEY (id)`.

Tipos agent, multiagent o skill. Explicación de 1 a 10000 caracteres y definición como objeto JSON. Decisiones pending, approved o rejected. El servidor crea la propuesta y el cliente solo modifica su decisión; puede revisarla nuevamente. Aprobarla no publica ni ejecuta un agente.

Índices: `learning_proposals_owner_idx`, `learning_proposals_pkey`, `learning_proposals_project_idx`.

## 4 Permisos y reglas de trabajo

Los accesos siguientes describen los clientes de la aplicación. El servidor tiene privilegios adicionales y debe autenticar a quien solicita una acción, comprobar sus permisos y aplicar límites antes de usar su clave secreta. Esa clave omite RLS.

| Tabla | Lectura desde cliente | Escritura desde cliente |
| --- | --- | --- |
| `profiles` | Propio o expresamente público. | Crear o editar datos descriptivos y visibilidad del perfil propio. |
| `offerings` | Propio o metadatos públicos. | Crear o editar metadatos especializados propios; activar es función del servidor. |
| `offering_versions` | Solo el propietario de la oferta. | Añadir versiones propias, sin actualizar ni borrar las anteriores. |
| `projects` | Solo sus participantes. | Contratante crea borradores y edita título o descripción; servidor asigna y cambia estado. |
| `project_tasks` | Solo participantes del proyecto. | Las partes crean y editan título, descripción y estado de las tareas. |
| `reviews` | Autor o destinatario. | Insertar la reseña permitida sobre un encargo completado. |
| `agent_runs` | Solo el titular. | Sin escrituras de cliente; el servidor registra los resultados y consumos. |
| `project_consents` | Participantes del proyecto. | Cada persona inserta o actualiza exclusivamente su propia decisión. |
| `self_evaluations` | Solo el titular. | Crear una autoevaluación propia y editar sus notas. |
| `learning_proposals` | Solo el titular. | Modificar la decisión; contenido y generación reservados al servidor. |

### Calificaciones independientes

El contratante califica al ejecutor como executor y el ejecutor califica al contratante como contractor. get_reputation devuelve dos filas con average_score y review_count; no calcula una nota global entre ambos roles. Sin reseñas, el promedio es nulo y la cantidad es cero. La consulta solo admite un perfil propio o expresamente público, y no expone comentarios ni proyectos privados.

### Estados y consentimiento

Las partes pueden cambiar mientras el encargo sea un borrador. Al salir de draft, los participantes quedan fijos. Active puede continuar o pasar a completed o cancelled; estos dos estados son terminales. El título, la descripción y las tareas no se congelan íntegramente al completar un encargo.

Compartir contexto y permitir aprendizaje son decisiones distintas. Los permisos solo se conceden en estados distintos de draft, cuando las partes ya no pueden cambiar. Cada persona puede retirarlos siendo miembro. Reasignar un borrador revoca sus permisos anteriores. Las autoevaluaciones y propuestas permanecen privadas.

## 5 Funciones y automatismos

Hay nueve funciones propias en private, una RPC propia en public y una función administrada de Supabase relacionada con RLS. Las funciones propias privilegiadas fijan search_path vacío y validan la identidad o se usan como triggers. Private no es un esquema expuesto por la API.

| Función | Responsabilidad | Ejecución por cliente |
| --- | --- | --- |
| `private.can_create_review` | Valida autor, contraparte, rol evaluado y proyecto completado. | Autenticado |
| `private.can_read_project_file` | Valida miembro actual, titular del archivo y consentimiento vigente para compartir. | Autenticado |
| `private.can_set_project_consent` | Permite conceder consentimiento con participantes fijos y retirarlo siendo miembro. | Autenticado |
| `private.handle_new_user` | Crea el perfil al registrarse una identidad Auth. Solo usa el nombre de los metadatos, no permisos. | Ninguna |
| `private.is_project_member` | Comprueba que la cuenta sea contratante o ejecutora del proyecto. | Autenticado |
| `private.is_project_path_member` | Comprueba pertenencia usando la carpeta del archivo del proyecto. | Autenticado |
| `private.owns_offering` | Comprueba que la oferta pertenezca a la cuenta actual. | Autenticado |
| `private.protect_project_workflow` | Protege estados y participantes; revoca permisos al reasignar un borrador. | Ninguna |
| `private.stamp_consent_update` | Actualiza la fecha al cambiar un consentimiento. | Ninguna |
| `public.get_reputation` | Devuelve promedio y número de reseñas por cada rol para un perfil propio o público. | Anónimo o autenticado |
| `public.rls_auto_enable` | Función administrada de Supabase para activar RLS mediante un evento de base. | Ninguna |

| Trigger | Tabla | Efecto |
| --- | --- | --- |
| `ua25_auth_user_created` | `auth.users` | Tras insertar una identidad, crea el perfil privado. |
| `ua25_protect_project_workflow` | `public.projects` | Antes de actualizar, protege estados y participantes. |
| `ua25_consent_updated` | `public.project_consents` | Antes de actualizar, registra la nueva fecha del permiso. |

El evento administrado que llama a rls_auto_enable sigue habilitado; la segunda migración retira su ejecución directa a los roles de cliente. El asesor de Supabase mantiene dos avisos revisados sobre la RPC privilegiada get_reputation, para anónimos y autenticados. Su uso público es intencional y está limitado por la validación interna del perfil y por la ausencia de detalles de reseñas.

## 6 Archivos privados

| Espacio | Carpeta de acceso | Regla |
| --- | --- | --- |
| `account-files` | `<id de cuenta>/<archivo>` | Propietario y carpeta deben corresponder a la cuenta actual. |
| `project-files` | `<id de proyecto>/<archivo>` | Se exige pertenencia actual. Leer archivos de otra parte requiere su consentimiento de contexto y un estado distinto de draft. |

Ambos espacios son privados y admiten hasta 10 MiB por archivo. Formatos permitidos: PDF, DOCX, texto, JSON, CSV, PNG y JPEG. La base conserva referencias a los archivos; no almacena sus bytes dentro de agent_runs.

Revocar un consentimiento bloquea nuevas lecturas autorizadas por RLS. No recupera copias descargadas ni invalida enlaces firmados ya emitidos. El backend deberá emitir enlaces de corta duración y comprobar de nuevo la autorización. Una subida administrativa no asigna automáticamente el archivo al titular de un encargo.

## 7 Historial y mantenimiento

| Versión remota | Migración | Cambio |
| --- | --- | --- |
| 20261022142753 | initial_schema | Estructura inicial, permisos, reputación y espacios privados. |
| 20261022143223 | restrict_event_trigger_execution | Retira a clientes la ejecución directa del helper de eventos cuando existe. |

| Documento | Fecha | Recuento registrado |
| --- | --- | --- |
| 1.0.0 | 22 de octubre de 2026 | Primera edición contrastada con Supabase: 10 tablas, 70 campos y 18 relaciones. |

Esta edición corresponde a una fecha de corte; no se actualiza automáticamente cuando cambia la base. La fuente canónica es docs/DATABASE_STRUCTURE.md, conservada junto al código del proyecto. Cada edición posterior debe añadir una fila al historial y regenerar el documento de lectura.

1. Después de aplicar una migración, contrastar el esquema remoto y el archivo SQL versionado.

2. Actualizar campos, tipos, claves, índices, políticas y funciones afectados; recalcular el inventario.

3. Registrar versión de migración, fecha, motivo y efecto sobre los datos o permisos existentes.

4. Revisar especialmente las dos reputaciones, la separación de clientes y los consentimientos.

5. Comprobar la nueva edición y publicar un archivo con versión distinta, conservando el historial.

### Estado de la plataforma

Los tres casos generales del catálogo son CV adaptado a la oferta, preparación de entrevistas y redacción profesional. Permanecen como borradores desactivados. El registro web, los correos, los archivos reales, la contratación y la ejecución de IA siguen pendientes de integración o prueba. No hay pagos, equipos empresariales, facturación ni aprendizaje periódico ejecutándose por el solo hecho de existir estas tablas.

### Fuentes de referencia

El inventario se obtuvo del catálogo de PostgreSQL, las políticas, funciones, triggers, buckets y el historial de migraciones del proyecto indicado, mediante consultas de solo lectura el 22 de octubre de 2026. Los significados y reglas se contrastaron con las migraciones del repositorio.

[Proyecto Supabase](https://supabase.com/dashboard/project/ylyjlxpfbxdxebukdezt).

[Migración inicial](https://github.com/Javifex/universalagents25.com/blob/main/supabase/migrations/20261022142753_initial_schema.sql).

[Permisos del helper de eventos](https://github.com/Javifex/universalagents25.com/blob/main/supabase/migrations/20261022143223_restrict_event_trigger_execution.sql).

[Guía de Supabase del proyecto](https://github.com/Javifex/universalagents25.com/blob/main/docs/SUPABASE.md).
