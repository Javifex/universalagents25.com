const multiplierScene = document.querySelector('.multiplier-scene');
const motionToggle = document.getElementById('motion-toggle');
const motionLabel = document.getElementById('motion-label');
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
let userPaused = false;

function renderMotion() {
  const paused = userPaused || reducedMotion.matches;
  multiplierScene.dataset.paused = String(paused);
  motionToggle.hidden = false;
  motionToggle.disabled = reducedMotion.matches;
  motionToggle.setAttribute('aria-pressed', String(paused));
  motionLabel.textContent = reducedMotion.matches ? 'Movimiento reducido'
    : paused ? 'Reanudar animación' : 'Pausar animación';
}
motionToggle.addEventListener('click', () => {
  userPaused = !userPaused;
  renderMotion();
});
reducedMotion.addEventListener('change', renderMotion);
renderMotion();
