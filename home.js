const intentContent = {
  "contratar": {
    "heroKicker": "PARA EMPRESAS Y PERSONAS QUE CONTRATAN",
    "heroLine1": "Talento humano.",
    "heroLine2": "Agentes de IA.",
    "heroLine3": "La ayuda que buscas.",
    "heroDescription": "Un espacio pensado para encontrar profesionales potenciados con IA y agentes especializados. Cuéntanos qué necesitas resolver y descubre dos formas de llevar tu proyecto más lejos.",
    "heroAction": "Explora cómo contratar",
    "platformKicker": "01 / EL ÁREA PARA CONTRATAR",
    "platformTitle": "Encuentra la ayuda que necesita tu proyecto.",
    "platformDescription": "Tanto si representas a una empresa como si contratas por tu cuenta, el punto de partida es el mismo: qué quieres conseguir.",
    "feature1Title": "Personas con experiencia e IA.",
    "feature1Description": "Para proyectos que requieren criterio profesional, comunicación y una persona responsable de la entrega.",
    "mini1": "Un objetivo definido",
    "mini1State": "Tu necesidad",
    "mini2": "Un alcance acordado",
    "mini2State": "El encargo",
    "mini3": "Una entrega revisable",
    "mini3State": "El resultado",
    "feature2Title": "Agentes para tareas concretas.",
    "feature2Description": "Para procesos repetibles: define qué debe hacer el agente, con qué información y cuándo necesita supervisión.",
    "learningInput": "Una necesidad concreta",
    "learningOutput": "Un agente especializado",
    "feature3Title": "Un encargo bajo tu control.",
    "feature3Description": "Comparte solo lo necesario, acuerda las condiciones y conserva la revisión sobre las acciones importantes.",
    "processKicker": "02 / DEL OBJETIVO AL ENCARGO",
    "processTitle": "Empieza contando qué necesitas resolver.",
    "processDescription": "Queremos que contratar sea comprensible: desde expresar una necesidad hasta revisar un resultado, con pasos claros.",
    "processAction": "Cuéntanos qué necesitas",
    "conversation": "“Necesito responder consultas de clientes y organizar los casos que requieren atención.”",
    "conversationReply": "Definamos qué puede resolver un agente y qué revisará una persona.",
    "step1Title": "Describe tu necesidad",
    "step1Description": "Explica el objetivo, el contexto y el resultado que esperas.",
    "step2Title": "Elige el tipo de ayuda",
    "step2Description": "Un profesional con IA, un agente especializado o una combinación de ambos.",
    "step3Title": "Acuerda alcance y acceso",
    "step3Description": "Define entregables, criterios de revisión y la información que vas a compartir.",
    "step4Title": "Revisa el resultado",
    "step4Description": "Comprueba la entrega y comparte lo que puede mejorar.",
    "contactTitle": "¿Qué necesitas resolver?",
    "contactDescription": "Cuéntanos tu proyecto y si buscas una persona, un agente o ayuda para elegir.",
    "contactAction": "Cuéntanos tu necesidad"
  },
  "ofrecer": {
    "heroKicker": "PARA PROFESIONALES Y CREADORES DE AGENTES",
    "heroLine1": "Tu conocimiento.",
    "heroLine2": "Tus agentes.",
    "heroLine3": "Más oportunidades.",
    "heroDescription": "Un espacio pensado para ofrecer tus servicios potenciados con IA o crear agentes especializados. Convierte lo que sabes hacer en soluciones claras para otras personas y empresas.",
    "heroAction": "Explora cómo ofrecer",
    "platformKicker": "01 / EL ÁREA PARA OFRECER Y CREAR",
    "platformTitle": "Convierte lo que sabes en nuevas posibilidades.",
    "platformDescription": "Tu experiencia es el punto de partida: presenta tus servicios, desarrolla agentes y organiza los proyectos que quieras llevar adelante.",
    "feature1Title": "Ofrece tus servicios con IA.",
    "feature1Description": "Da forma a tu propuesta profesional: qué sabes resolver, cómo te ayuda la IA y qué revisarás antes de entregar.",
    "mini1": "Estudio creativo",
    "mini1State": "Revisar borrador",
    "mini2": "Informe mensual",
    "mini2State": "Organizar datos",
    "mini3": "Nueva propuesta",
    "mini3State": "Definir alcance",
    "feature2Title": "Crea agentes y habilidades.",
    "feature2Description": "Convierte los procesos que funcionan en asistentes reutilizables. Comprueba sus resultados y mejora con cada corrección.",
    "learningInput": "Tu forma de trabajar",
    "learningOutput": "Una nueva habilidad",
    "feature3Title": "Organiza varios proyectos.",
    "feature3Description": "Un lugar para tus entregas, permisos y revisiones. Mantén separado el contexto de cada cliente y tu criterio al frente.",
    "processKicker": "02 / DE TU EXPERIENCIA A UNA SOLUCIÓN",
    "processTitle": "Empieza por lo que sabes hacer.",
    "processDescription": "Queremos acompañarte desde la definición de tu servicio o agente hasta la revisión del resultado, desde el teléfono o el computador.",
    "processAction": "Cuéntanos qué quieres ofrecer",
    "conversation": "“Sé organizar la atención al cliente y quiero convertir ese proceso en un agente.”",
    "conversationReply": "Definamos la tarea, el alcance y los casos que necesitarán tu revisión.",
    "step1Title": "Define tu propuesta",
    "step1Description": "Explica tu experiencia y qué resolvería tu servicio o agente.",
    "step2Title": "Prepara tu forma de trabajar",
    "step2Description": "Organiza herramientas, información autorizada y pasos que puedas repetir.",
    "step3Title": "Revisa y entrega",
    "step3Description": "Comprueba los resultados y conserva tu responsabilidad profesional.",
    "step4Title": "Aprende de cada proyecto",
    "step4Description": "Usa correcciones y evaluaciones periódicas para mejorar tus agentes y habilidades.",
    "contactTitle": "¿Qué te gustaría ofrecer?",
    "contactDescription": "Cuéntanos tu experiencia, los servicios que ofreces o el agente que te gustaría crear.",
    "contactAction": "Presenta tu idea"
  }
};

function readIntent() {
  return new URLSearchParams(window.location.search).get('intencion') === 'ofrecer'
    ? 'ofrecer' : 'contratar';
}

function renderIntent() {
  const intent = readIntent();
  const copy = intentContent[intent];
  document.body.dataset.intent = intent;
  document.querySelectorAll('[data-intent-copy]').forEach(node => {
    node.textContent = copy[node.dataset.intentCopy];
  });
  document.querySelectorAll('[data-intent-panel]').forEach(panel => {
    panel.hidden = panel.dataset.intentPanel !== intent;
  });
  document.querySelectorAll('[data-intent-link]').forEach(link => {
    if (link.dataset.intentLink === intent) link.setAttribute('aria-current', 'page');
    else link.removeAttribute('aria-current');
  });
  document.getElementById('intent-status').textContent = intent === 'ofrecer'
    ? 'Estás en el área para ofrecer servicios y crear agentes.'
    : 'Estás en el área para contratar agentes y profesionales.';
  document.querySelector('meta[name="theme-color"]').content =
    intent === 'ofrecer' ? '#173e35' : '#173e68';
  document.title = (intent === 'ofrecer' ? 'Ofrecer servicios y crear agentes' : 'Contratar talento y agentes')
    + ' | Multiplicador · Universal Agents';
  const subject = intent === 'ofrecer'
    ? 'Quiero ofrecer servicios o crear agentes con Multiplicador'
    : 'Quiero contratar con Multiplicador';
  document.querySelector('[data-intent-contact]').href =
    'mailto:soporte@universalagents25.com?subject=' + encodeURIComponent(subject);
}

document.querySelectorAll('[data-intent-link]').forEach(link => {
  link.addEventListener('click', event => {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    const url = new URL(window.location.href);
    const intent = link.dataset.intentLink;
    if (url.searchParams.get('intencion') !== intent) {
      url.searchParams.set('intencion', intent);
      url.hash = '';
      window.history.pushState(null, '', url);
    }
    renderIntent();
    document.getElementById('elegir-area').scrollIntoView({ block: 'start' });
  });
});
window.addEventListener('popstate', renderIntent);
renderIntent();

const menuButton = document.querySelector('.menu-toggle');
const navigation = document.querySelector('.nav-panel');

function closeMenu() {
  menuButton.setAttribute('aria-expanded', 'false');
  menuButton.setAttribute('aria-label', 'Abrir menú');
  navigation.classList.remove('is-open');
}

menuButton.addEventListener('click', () => {
  const open = menuButton.getAttribute('aria-expanded') !== 'true';
  menuButton.setAttribute('aria-expanded', String(open));
  menuButton.setAttribute('aria-label', open ? 'Cerrar menú' : 'Abrir menú');
  navigation.classList.toggle('is-open', open);
});
navigation.querySelectorAll('a').forEach(link => link.addEventListener('click', closeMenu));
document.addEventListener('keydown', event => {
  if (event.key === 'Escape' && menuButton.getAttribute('aria-expanded') === 'true') {
    closeMenu();
    menuButton.focus();
  }
});
document.addEventListener('click', event => {
  if (!event.target.closest('.navigation')) closeMenu();
});

const examples = {
  contenido: {
    category: 'ESTUDIO CREATIVO · EJEMPLO',
    title: 'Las ideas de la semana, en un solo lugar.',
    description: 'Convierte tus notas en una propuesta de publicaciones para revisar con tu cliente.',
    input: 'Notas y referencias del proyecto',
    task: 'Propuesta de calendario editorial',
    result: 'Ejemplo de borrador: lunes, presenta un servicio; miércoles, comparte un consejo; viernes, responde una pregunta frecuente. Tú ajustarías el contenido antes de entregarlo.'
  },
  informes: {
    category: 'CONSULTORÍA · EJEMPLO',
    title: 'Un informe claro para el próximo paso.',
    description: 'Reúne avances, decisiones y pendientes en un documento fácil de revisar.',
    input: 'Notas de seguimiento del proyecto',
    task: 'Resumen de avances y próximos pasos',
    result: 'Ejemplo de borrador: avances de la semana, decisiones pendientes y próximos pasos con responsables. Tú confirmarías la información antes de compartirla.'
  },
  propuestas: {
    category: 'SERVICIOS PROFESIONALES · EJEMPLO',
    title: 'De una conversación a una propuesta.',
    description: 'Da forma a los objetivos y entregables de tu siguiente proyecto.',
    input: 'Necesidades y contexto del cliente',
    task: 'Primer borrador del alcance',
    result: 'Ejemplo de borrador: objetivo del proyecto, entregables, información necesaria y criterios de aceptación. Tú acordarías el alcance y las condiciones con el cliente.'
  }
};
const projectButtons = document.querySelectorAll('[data-project]');
const result = document.getElementById('demo-result');
let selectedProject = 'contenido';

projectButtons.forEach(button => button.addEventListener('click', () => {
  selectedProject = button.dataset.project;
  const example = examples[selectedProject];
  projectButtons.forEach(item => {
    const selected = item === button;
    item.classList.toggle('active', selected);
    item.setAttribute('aria-pressed', String(selected));
  });
  for (const field of ['category', 'title', 'description', 'input', 'task']) {
    document.getElementById('demo-' + field).textContent = example[field];
  }
  result.hidden = true;
  result.textContent = '';
}));
document.getElementById('demo-action').addEventListener('click', () => {
  result.textContent = examples[selectedProject].result;
  result.hidden = false;
});
document.getElementById('year').textContent = new Date().getFullYear();
