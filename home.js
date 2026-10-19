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
