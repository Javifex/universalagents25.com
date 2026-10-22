-- Ideas for the general catalog only: no published agents, executions, costs or user data.
insert into public.offerings (owner_id, slug, title, description, kind, audience, visibility, is_enabled)
values
  (null, 'cv-adaptado', 'CV adaptado a la oferta',
    'Sistema multiagente del fundador para adaptar un CV a una oferta. Integración y costos pendientes de validar.',
    'multiagent', 'general', 'draft', false),
  (null, 'entrevista', 'Preparación de entrevistas',
    'Propuesta de agente general: practicar preguntas y recibir retroalimentación según la oferta.',
    'agent', 'general', 'draft', false),
  (null, 'redaccion-profesional', 'Redacción profesional',
    'Propuesta de agente general: ayudar a redactar correos, mensajes y propuestas profesionales.',
    'agent', 'general', 'draft', false)
on conflict (slug) do nothing;
