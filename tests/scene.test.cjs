const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const vm = require('node:vm');

const script = readFileSync(join(__dirname, '..', 'multiplier-scene.js'), 'utf8');

test('the scene remains static if its control script is unavailable', () => {
  const html = readFileSync(join(__dirname, '..', 'index.html'), 'utf8');
  assert.match(html, /<figure class="multiplier-scene"[^>]*data-paused="true"/);
  assert.match(html, /<button class="motion-toggle"[^>]*hidden/);
});

function scene(reduce = false) {
  const visual = { dataset: {} };
  const label = {};
  const control = {
    hidden: true,
    attributes: {},
    setAttribute(name, value) { this.attributes[name] = value; },
    addEventListener(type, callback) {
      assert.equal(type, 'click');
      this.click = callback;
    },
  };
  const preference = {
    matches: reduce,
    addEventListener(type, callback) {
      assert.equal(type, 'change');
      this.change = callback;
    },
  };
  vm.runInNewContext(script, {
    document: {
      querySelector(selector) {
        assert.equal(selector, '.multiplier-scene');
        return visual;
      },
      getElementById(id) {
        return { 'motion-toggle': control, 'motion-label': label }[id];
      },
    },
    window: {
      matchMedia(query) {
        assert.equal(query, '(prefers-reduced-motion: reduce)');
        return preference;
      },
    },
  });
  return { visual, control, label, preference };
}

function expectMotion(current, paused, disabled, label) {
  assert.equal(current.visual.dataset.paused, String(paused));
  assert.equal(current.control.attributes['aria-pressed'], String(paused));
  assert.equal(current.control.hidden, false);
  assert.equal(current.control.disabled, disabled);
  assert.equal(current.label.textContent, label);
}

test('animation starts active when reduced motion is not requested', () => {
  expectMotion(scene(), false, false, 'Pausar animación');
});

test('the control pauses and resumes animation with the matching accessible state', () => {
  const current = scene();
  current.control.click();
  expectMotion(current, true, false, 'Reanudar animación');
  current.control.click();
  expectMotion(current, false, false, 'Pausar animación');
});

test('reduced motion pauses animation and disables the control', () => {
  const current = scene(true);
  expectMotion(current, true, true, 'Movimiento reducido');
  current.preference.matches = false;
  current.preference.change();
  expectMotion(current, false, false, 'Pausar animación');
});

test('preference changes preserve a manual pause', () => {
  const current = scene();
  current.control.click();
  current.preference.matches = true;
  current.preference.change();
  expectMotion(current, true, true, 'Movimiento reducido');
  current.preference.matches = false;
  current.preference.change();
  expectMotion(current, true, false, 'Reanudar animación');
});
