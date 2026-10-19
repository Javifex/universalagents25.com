const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const vm = require('node:vm');

const root = join(__dirname, '..');
const script = readFileSync(join(root, 'home.js'), 'utf8');
const intentEnd = script.indexOf('const menuButton');
assert.ok(intentEnd > 0, 'The intent block must precede the menu');
const intentScript = script.slice(0, intentEnd);
const copyKeys = [...readFileSync(join(root, 'index.html'), 'utf8')
  .matchAll(/data-intent-copy="([^"]+)"/g)].map(match => match[1]);

function node(dataset = {}) {
  return {
    dataset,
    attributes: {},
    listeners: {},
    setAttribute(key, value) { this.attributes[key] = value; },
    removeAttribute(key) { delete this.attributes[key]; },
    addEventListener(type, listener) { this.listeners[type] = listener; },
  };
}

function page(path = '/') {
  const copies = copyKeys.map(intentCopy => node({ intentCopy }));
  const panels = ['contratar', 'ofrecer'].map(intentPanel => node({ intentPanel }));
  const links = ['contratar', 'ofrecer'].map(intentLink => node({ intentLink }));
  const body = node();
  const status = node();
  const theme = node();
  const contact = node();
  const scrolls = [];
  const area = { scrollIntoView(options) { scrolls.push(options); } };
  const pushes = [];
  const document = {
    body,
    querySelectorAll(selector) {
      return {
        '[data-intent-copy]': copies,
        '[data-intent-panel]': panels,
        '[data-intent-link]': links,
      }[selector];
    },
    querySelector(selector) {
      return {
        'meta[name="theme-color"]': theme,
        '[data-intent-contact]': contact,
      }[selector];
    },
    getElementById(id) {
      return { 'intent-status': status, 'elegir-area': area }[id];
    },
  };
  const window = {
    location: new URL(path, 'https://universalagents25.com'),
    listeners: {},
    addEventListener(type, listener) { this.listeners[type] = listener; },
    history: {
      pushState(state, title, url) {
        pushes.push(url.href);
        window.location = new URL(url);
      },
    },
  };
  const context = vm.createContext({ document, window, URL, URLSearchParams });
  const content = vm.runInContext(intentScript + '\nintentContent;', context);
  return { copies, panels, links, body, status, theme, contact, scrolls, pushes,
    document, window, content };
}

function expectIntent(page, intent) {
  assert.equal(page.body.dataset.intent, intent);
  assert.equal(page.theme.content, intent === 'ofrecer' ? '#173e35' : '#0d4b3d');
  assert.ok(page.document.title.includes('Multiplicador'));
  assert.ok(page.document.title.toLowerCase().includes(intent));
  assert.ok(page.status.textContent.includes(intent));
  for (const copy of page.copies) {
    assert.equal(copy.textContent, page.content[intent][copy.dataset.intentCopy]);
  }
  for (const panel of page.panels) {
    assert.equal(panel.hidden, panel.dataset.intentPanel !== intent);
  }
  for (const link of page.links) {
    assert.equal(link.attributes['aria-current'],
      link.dataset.intentLink === intent ? 'page' : undefined);
  }
  const mail = new URL(page.contact.href);
  assert.equal(mail.protocol, 'mailto:');
  assert.equal(mail.pathname, 'soporte@universalagents25.com');
  assert.ok(mail.searchParams.get('subject').includes(intent));
}

function click(link, overrides = {}) {
  let prevented = false;
  link.listeners.click({
    button: 0,
    preventDefault() { prevented = true; },
    ...overrides,
  });
  return prevented;
}

test('both areas provide every copy key used by the page', () => {
  const { content } = page();
  assert.ok(copyKeys.length > 0);
  for (const intent of ['contratar', 'ofrecer']) {
    assert.deepEqual(Object.keys(content[intent]).sort(), [...new Set(copyKeys)].sort());
    for (const key of copyKeys) {
      assert.equal(typeof content[intent][key], 'string');
      assert.ok(content[intent][key].trim());
    }
  }
});

test('missing and unknown intentions default to contratar without changing the URL', () => {
  for (const path of ['/', '/?intencion=desconocida']) {
    const current = page(path);
    expectIntent(current, 'contratar');
    assert.equal(current.pushes.length, 0);
    assert.equal(current.window.location.pathname + current.window.location.search, path);
  }
});

test('a direct ofrecer link renders its palette, panels and contact destination', () => {
  const current = page('/?intencion=ofrecer');
  expectIntent(current, 'ofrecer');
  assert.equal(current.pushes.length, 0);
});

test('a normal selection updates the URL and all intent-dependent state', () => {
  const current = page('/?preview=desktop#contacto');
  assert.equal(click(current.links[1]), true);
  expectIntent(current, 'ofrecer');
  assert.equal(current.window.location.searchParams.get('intencion'), 'ofrecer');
  assert.equal(current.window.location.searchParams.get('preview'), 'desktop');
  assert.equal(current.window.location.hash, '');
  assert.equal(current.pushes.length, 1);
  assert.equal(current.scrolls.length, 1);
  assert.equal(current.scrolls[0].block, 'start');

  assert.equal(click(current.links[0]), true);
  expectIntent(current, 'contratar');
  assert.equal(current.window.location.searchParams.get('intencion'), 'contratar');
  assert.equal(current.pushes.length, 2);
  click(current.links[0]);
  assert.equal(current.pushes.length, 2, 'Reselecting an area must not add history');
});

test('popstate restores the area without creating history or moving the page', () => {
  const current = page('/?intencion=ofrecer');
  current.window.location = new URL('https://universalagents25.com/?intencion=contratar');
  current.window.listeners.popstate();
  expectIntent(current, 'contratar');
  current.window.location = new URL('https://universalagents25.com/?intencion=ofrecer');
  current.window.listeners.popstate();
  expectIntent(current, 'ofrecer');
  assert.equal(current.pushes.length, 0);
  assert.equal(current.scrolls.length, 0);
});

test('modified and already handled clicks retain native navigation', () => {
  const current = page('/?preview=desktop');
  for (const modifier of [
    { ctrlKey: true }, { metaKey: true }, { shiftKey: true }, { altKey: true },
    { button: 1 }, { defaultPrevented: true },
  ]) {
    assert.equal(click(current.links[1], modifier), false);
    expectIntent(current, 'contratar');
  }
  assert.equal(current.window.location.search, '?preview=desktop');
  assert.equal(current.pushes.length, 0);
  assert.equal(current.scrolls.length, 0);
});
