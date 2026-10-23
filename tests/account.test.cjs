const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const vm = require('node:vm');

const root = join(__dirname, '..');
const script = readFileSync(join(root, 'cuenta.js'), 'utf8');
const html = readFileSync(join(root, 'cuenta.html'), 'utf8');
const USER = { id: 'user-a', email: 'persona@example.com' };
const SESSION = { user: USER, access_token: 'test-access-token' };
const PROFILE = { display_name: 'Persona', bio: 'Presentación privada', is_public: false };
const plain = value => JSON.parse(JSON.stringify(value));

async function settle() {
  for (let turn = 0; turn < 12; turn++) await Promise.resolve();
}

function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return { promise, resolve };
}

function element(attributes = '') {
  return {
    dataset: {}, attributes: {}, listeners: {}, value: '', checked: false,
    textContent: '', disabled: /\sdisabled\b/.test(attributes),
    hidden: /\shidden\b/.test(attributes), valid: true,
    setAttribute(key, value) { this.attributes[key] = value; },
    addEventListener(type, listener) { this.listeners[type] = listener; },
    reportValidity() { return this.valid; },
    focus() { this.focused = true; },
    reset() {},
  };
}

function account(options = {}) {
  const nodes = new Map([...html.matchAll(/<[^>]+\bid="([^"]+)"[^>]*>/g)]
    .map(match => [match[1], element(match[0])]));
  const get = id => {
    assert.ok(nodes.has(id), `Unknown account element: ${id}`);
    return nodes.get(id);
  };
  const modes = [...html.matchAll(/<button\b[^>]*data-mode="([^"]+)"[^>]*>/g)]
    .map(match => Object.assign(element(match[0]), { dataset: { mode: match[1] } }));
  for (const [form, controls] of [
    ['auth-form', ['display-name', 'email', 'password']],
    ['profile-form', ['profile-name', 'profile-bio', 'profile-public']],
  ]) {
    get(form).reset = () => controls.forEach(id => {
      get(id).value = '';
      get(id).checked = false;
    });
  }
  const calls = { auth: [], queries: [], clients: [], history: [] };
  const timers = [];
  let session = options.session || null;
  let authListener;
  const auth = {};
  const defaults = {
    getSession: () => ({ data: { session }, error: null }),
    getUser: () => ({ data: { user: USER }, error: null }),
    signUp: () => ({ data: { user: USER, session: null }, error: null }),
    signInWithPassword: () => ({ data: { user: USER, session: SESSION }, error: null }),
    resetPasswordForEmail: () => ({ data: {}, error: null }),
    updateUser: () => ({ data: { user: USER }, error: null }),
    resend: () => ({ data: {}, error: null }),
    signOut: () => ({ error: null }),
  };
  for (const method of Object.keys(defaults)) {
    auth[method] = async (...args) => {
      calls.auth.push({ method, args: plain(args) });
      const response = options[method] || defaults[method];
      const result = await (typeof response === 'function' ? response(...args) : response);
      if (!result.error && ['signUp', 'signInWithPassword'].includes(method)) session = result.data.session;
      if (!result.error && method === 'signOut') session = null;
      return result;
    };
  }
  auth.onAuthStateChange = listener => {
    authListener = listener;
    return { data: { subscription: { unsubscribe() {} } } };
  };
  const client = {
    auth,
    from(table) {
      const call = { table, operation: null, filters: [], single: false };
      calls.queries.push(call);
      const query = {
        select(columns) {
          if (!call.operation) { call.operation = 'select'; call.columns = columns; }
          else call.returning = columns;
          return query;
        },
        eq(column, value) { call.filters.push([column, value]); return query; },
        update(values) { call.operation = 'update'; call.values = plain(values); return query; },
        insert(values) { call.operation = 'insert'; call.values = plain(values); return query; },
        upsert(values) { call.operation = 'upsert'; call.values = plain(values); return query; },
        async single() {
          call.single = true;
          const response = call.operation === 'select' ? options.loadProfile : options.saveProfile;
          if (response) return typeof response === 'function' ? response(call) : response;
          return { data: call.operation === 'select' ? { ...PROFILE } : { id: USER.id }, error: null };
        },
      };
      return query;
    },
  };
  const window = {
    location: new URL(options.path || '/cuenta.html', 'https://universalagents25.com'),
    history: {
      replaceState(state, title, path) {
        calls.history.push(path);
        window.location = new URL(path, window.location);
      },
    },
    supabase: options.sdk === false ? undefined : {
      createClient(...args) {
        calls.clients.push(plain(args));
        if (options.sdkError) throw options.sdkError;
        return client;
      },
    },
  };
  const document = {
    getElementById: get,
    querySelectorAll(selector) {
      assert.equal(selector, '[data-mode]');
      return modes;
    },
  };
  const context = vm.createContext({ document, window, URL, URLSearchParams,
    setTimeout(callback) { timers.push(callback); return timers.length; } });
  const ready = vm.runInContext(script + '\n; accountReady;', context);
  return {
    get, calls, window, ready,
    authCalls: method => calls.auth.filter(call => call.method === method),
    async click(id) { get(id).listeners.click({ currentTarget: get(id) }); await settle(); },
    async mode(mode) {
      modes.find(button => button.dataset.mode === mode).listeners.click();
      await settle();
    },
    async submit(id = 'auth-form') {
      let prevented = false;
      get(id).listeners.submit({ currentTarget: get(id), preventDefault() { prevented = true; } });
      assert.equal(prevented, true, 'Forms must not navigate with credentials');
      await settle();
    },
    emit(event, nextSession) { session = nextSession; authListener(event, nextSession); },
    async runTimers() { while (timers.length) { timers.shift()(); await settle(); } },
  };
}

async function start(options) {
  const page = account(options);
  await page.ready;
  return page;
}

function credentials(page) {
  page.get('display-name').value = '  Nueva persona  ';
  page.get('email').value = '  persona@example.com  ';
  page.get('password').value = 'Una contraseña segura';
}

test('signup sends the display name and clean callback without inventing a session or writing a profile', async () => {
  const page = await start({ path: '/cuenta.html?intencion=ofrecer#unused-fragment' });
  credentials(page);
  await page.submit();
  assert.deepEqual(page.authCalls('signUp')[0].args[0], {
    email: USER.email, password: 'Una contraseña segura',
    options: { emailRedirectTo: 'https://universalagents25.com/cuenta.html', data: { display_name: 'Nueva persona' } },
  });
  assert.equal(page.authCalls('getUser').length, 0);
  assert.equal(page.calls.queries.length, 0);
  assert.equal(page.get('profile-area').hidden, true);
  assert.equal(page.get('auth-area').hidden, false);
  assert.equal(page.get('password').value, '');
  assert.match(page.get('account-status').textContent, /correo.*confirmación/);
});

test('login verifies the user and loads only their profile before enabling edits', async () => {
  const cachedUser = { ...USER, id: 'untrusted-local-id' };
  const page = await start({ path: '/cuenta.html?modo=login', signInWithPassword: {
    data: { user: cachedUser, session: { ...SESSION, user: cachedUser } }, error: null,
  } });
  credentials(page);
  await page.submit();
  assert.deepEqual(page.authCalls('signInWithPassword')[0].args[0], {
    email: USER.email, password: 'Una contraseña segura',
  });
  assert.equal(page.authCalls('getUser').length, 1);
  assert.deepEqual(page.calls.queries[0], {
    table: 'profiles', operation: 'select', filters: [['id', USER.id]],
    columns: 'display_name,bio,is_public', single: true,
  });
  assert.equal(page.get('profile-name').value, PROFILE.display_name);
  assert.equal(page.get('profile-bio').value, PROFILE.bio);
  assert.equal(page.get('profile-public').checked, false);
  assert.equal(page.get('account-email').textContent, USER.email);
  assert.equal(page.get('auth-area').hidden, true);
  assert.equal(page.get('profile-fields').disabled, false);
});

test('authentication errors stay actionable without exposing backend diagnostics', async () => {
  for (const [error, expected] of [
    [{ code: 'invalid_credentials', message: 'password_hash=secret internal SQL' }, /correo o la contraseña/],
    [{ status: 429, message: 'rate-limit secret internal SQL' }, /Espera unos minutos/],
    [{ message: 'service_role=secret internal SQL' }, /conexión/],
  ]) {
    const page = await start({ path: '/cuenta.html?modo=login', signInWithPassword: { data: {}, error } });
    credentials(page);
    await page.submit();
    assert.match(page.get('account-status').textContent, expected);
    assert.doesNotMatch(page.get('account-status').textContent, /secret|internal SQL|service_role/);
    assert.equal(page.get('account-status').dataset.kind, 'error');
    assert.equal(page.calls.queries.length, 0);
    assert.equal(page.get('auth-fields').disabled, false);
  }
});

test('forgotten-password requests use a clean callback and do not reveal whether an account exists', async () => {
  const page = await start({ path: '/cuenta.html?modo=login#old-token' });
  await page.mode('forgot');
  page.get('email').value = '  persona@example.com ';
  await page.submit();
  assert.deepEqual(page.authCalls('resetPasswordForEmail')[0].args, [USER.email,
    { redirectTo: 'https://universalagents25.com/cuenta.html' }]);
  assert.equal(page.get('password').disabled, true);
  assert.match(page.get('account-status').textContent, /Si existe una cuenta/);
  assert.equal(page.authCalls('updateUser').length, 0);
  assert.equal(page.calls.queries.length, 0);
});

test('password recovery updates credentials only after verification of the recovery session', async () => {
  const page = await start({ path: '/cuenta.html#type=recovery&access_token=private-token', session: SESSION });
  assert.equal(page.authCalls('getUser').length, 1);
  assert.equal(page.calls.queries.length, 0);
  assert.equal(page.get('email').disabled, true);
  assert.equal(page.window.location.hash, '', 'Remove credentials from the address bar');
  page.get('password').value = 'Nueva contraseña segura';
  await page.submit();
  assert.deepEqual(page.authCalls('updateUser')[0].args, [{ password: 'Nueva contraseña segura' }]);
  assert.equal(page.get('password').value, '');
  assert.equal(page.get('profile-area').hidden, false);
  assert.match(page.get('account-status').textContent, /Contraseña actualizada/);

  const rejected = await start({ path: '/cuenta.html#type=recovery', session: SESSION,
    getUser: { data: { user: null }, error: { message: 'invalid private-token' } } });
  assert.equal(rejected.authCalls('updateUser').length, 0);
  assert.equal(rejected.calls.queries.length, 0);
  assert.equal(rejected.get('profile-fields').disabled, true);
  assert.equal(rejected.get('account-status').dataset.kind, 'error');
});

test('resending confirmation requires a valid email and sends a normalized address', async () => {
  const page = await start({ path: '/cuenta.html?modo=login' });
  page.get('email').value = 'not an email';
  page.get('email').valid = false;
  await page.click('resend-confirmation');
  assert.equal(page.authCalls('resend').length, 0);
  page.get('email').value = '  persona@example.com  ';
  page.get('email').valid = true;
  await page.click('resend-confirmation');
  assert.deepEqual(page.authCalls('resend')[0].args[0], { type: 'signup', email: USER.email,
    options: { emailRedirectTo: 'https://universalagents25.com/cuenta.html' } });
  assert.match(page.get('account-status').textContent, /Si tu cuenta necesita confirmación/);
});

test('profile editing sends only editable columns, checks ownership and requires one returned row', async () => {
  const page = await start({ session: SESSION });
  page.get('profile-name').value = '  Nombre nuevo ';
  page.get('profile-bio').value = '  Biografía nueva  ';
  page.get('profile-public').checked = true;
  await page.submit('profile-form');
  assert.deepEqual(page.calls.queries[1], {
    table: 'profiles', operation: 'update', filters: [['id', USER.id]], single: true,
    values: { display_name: 'Nombre nuevo', bio: 'Biografía nueva', is_public: true }, returning: 'id',
  });
  assert.equal(page.get('account-status').textContent, 'Perfil guardado.');
});

test('an update returning no profile never reports a successful save', async () => {
  for (const response of [
    { data: null, error: null },
    { data: null, error: { code: 'PGRST116', message: 'private database detail' } },
  ]) {
    const page = await start({ session: SESSION, saveProfile: response });
    await page.submit('profile-form');
    assert.equal(page.calls.queries[1].single, true);
    assert.equal(page.get('account-status').dataset.kind, 'error');
    assert.doesNotMatch(page.get('account-status').textContent, /Perfil guardado|private database detail/);
  }
});

test('signout removes profile values and prevents subsequent profile writes', async () => {
  const page = await start({ session: SESSION });
  page.get('profile-public').checked = true;
  await page.click('sign-out');
  assert.deepEqual(page.authCalls('signOut')[0].args, [{ scope: 'local' }]);
  assert.equal(page.get('profile-area').hidden, true);
  assert.equal(page.get('auth-area').hidden, false);
  assert.equal(page.get('account-email').textContent, '');
  assert.equal(page.get('profile-name').value, '');
  assert.equal(page.get('profile-bio').value, '');
  assert.equal(page.get('profile-public').checked, false);
  assert.equal(page.get('profile-fields').disabled, true);
  await page.submit('profile-form');
  assert.equal(page.calls.queries.length, 1);
});

test('expired callback links show an error instead of claiming that access is ready', async () => {
  for (const fragment of [
    '#error=access_denied&error_code=otp_expired&error_description=private-diagnostic',
    '#type=recovery',
  ]) {
    const page = await start({ path: '/cuenta.html' + fragment });
    assert.equal(page.get('account-status').dataset.kind, 'error', fragment);
    assert.match(page.get('account-status').textContent, /caducado|nuevo/);
    assert.doesNotMatch(page.get('account-status').textContent, /private-diagnostic/);
    assert.equal(page.get('profile-fields').disabled, true);
    assert.equal(page.authCalls('updateUser').length, 0);
    assert.equal(page.window.location.hash, '');
  }
});

test('unavailable SDK, network errors and profile failures keep profile saving disabled', async () => {
  const missing = await start({ sdk: false });
  assert.equal(missing.get('auth-fields').disabled, true);
  assert.equal(missing.get('profile-area').hidden, true);
  assert.equal(missing.get('account-status').dataset.kind, 'error');
  await missing.submit('profile-form');
  assert.equal(missing.calls.queries.length, 0);

  for (const options of [
    { getSession: () => Promise.reject(new Error('private network diagnostic')) },
    { session: SESSION, loadProfile: { data: null, error: { message: 'private database diagnostic' } } },
    { session: SESSION, loadProfile: () => Promise.reject(new Error('private network diagnostic')) },
  ]) {
    const page = await start(options);
    assert.ok(page.get('profile-fields').disabled || page.get('profile-area').hidden,
      'A profile that did not load must not offer editable fields');
    assert.equal(page.get('account-status').dataset.kind, 'error');
    assert.doesNotMatch(page.get('account-status').textContent, /private .*diagnostic/);
    assert.equal(page.calls.queries.filter(call => call.operation === 'update').length, 0);
  }
});

test('a profile response arriving after signout cannot restore private data', async () => {
  const pending = deferred();
  const page = account({ session: SESSION, loadProfile: () => pending.promise });
  await settle();
  assert.equal(page.calls.queries.length, 1);
  page.emit('SIGNED_OUT', null);
  await page.runTimers();
  pending.resolve({ data: PROFILE, error: null });
  await page.ready;
  await settle();
  assert.equal(page.get('profile-area').hidden, true);
  assert.equal(page.get('auth-area').hidden, false);
  assert.equal(page.get('profile-name').value, '');
  assert.equal(page.get('profile-bio').value, '');
  assert.equal(page.get('account-email').textContent, '');
  assert.equal(page.get('profile-fields').disabled, true);
});
