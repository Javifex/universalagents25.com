'use strict';

const accountReady = (async () => {
  const byId = id => document.getElementById(id);
  const status = byId('account-status');
  const form = byId('auth-form');
  const fields = byId('auth-fields');
  const email = byId('email');
  const password = byId('password');
  const name = byId('display-name');
  const profileFields = byId('profile-fields');
  const modeButtons = [...document.querySelectorAll('[data-mode]')];
  const callback = new URLSearchParams(window.location.hash.slice(1));
  const callbackError = callback.has('error');
  const recoveryCallback = callback.get('type') === 'recovery';
  let recovering = recoveryCallback;
  let mode = new URLSearchParams(window.location.search).get('modo') === 'login' ? 'login' : 'signup';
  let user = null;
  let profileLoaded = false;
  let revision = 0;
  let busy = false;
  let client;
  const redirectTo = new URL('cuenta.html', window.location.href).href;
  profileFields.disabled = true;

  function message(text, kind = 'success') {
    status.textContent = text;
    status.dataset.kind = kind;
  }

  function errorMessage(error) {
    if (error?.status === 429 || ['over_email_send_rate_limit', 'over_request_rate_limit'].includes(error?.code)) {
      return 'Has realizado varios intentos. Espera unos minutos antes de volver a intentarlo.';
    }
    return ({
      invalid_credentials: 'El correo o la contraseña no son correctos.',
      email_not_confirmed: 'Confirma tu correo antes de iniciar sesión. Puedes reenviar la confirmación.',
      email_address_invalid: 'Revisa que el correo sea válido.',
      email_address_not_authorized: 'El envío de correo aún no está habilitado para esta dirección. Contacta con soporte.',
      signup_disabled: 'El registro no está disponible en este momento. Contacta con soporte.',
      weak_password: 'Elige una contraseña más segura, con al menos 12 caracteres.',
      same_password: 'Elige una contraseña diferente de la anterior.',
      otp_expired: 'El enlace ha caducado. Solicita uno nuevo.',
    })[error?.code] || 'No pudimos completar la solicitud. Revisa tu conexión y vuelve a intentarlo. Si continúa, escribe a soporte@universalagents25.com.';
  }

  function sessionError(error) {
    if (!user) {
      recovering = false;
      setMode('login');
      byId('auth-area').hidden = false;
    }
    message(errorMessage(error), 'error');
  }

  function setMode(next) {
    mode = next;
    const texts = {
      signup: ['Crea tu cuenta', 'Una cuenta para contratar y ofrecer. Confirma tu correo para empezar.', 'Crear cuenta'],
      login: ['Bienvenido de nuevo', 'Entra con el correo y la contraseña de tu cuenta.', 'Iniciar sesión'],
      forgot: ['Recupera tu acceso', 'Te enviaremos un enlace para elegir una nueva contraseña.', 'Enviar enlace'],
      recovery: ['Elige una contraseña', 'Guarda tu nueva contraseña para recuperar el acceso.', 'Guardar contraseña'],
    }[mode];
    byId('auth-title').textContent = texts[0];
    byId('auth-intro').textContent = texts[1];
    byId('auth-submit').textContent = texts[2];
    byId('name-field').hidden = mode !== 'signup';
    name.disabled = mode !== 'signup';
    byId('email-field').hidden = mode === 'recovery';
    email.disabled = mode === 'recovery';
    byId('password-field').hidden = mode === 'forgot';
    password.disabled = mode === 'forgot';
    password.minLength = mode === 'login' ? 1 : 12;
    password.autocomplete = mode === 'login' ? 'current-password' : 'new-password';
    password.value = '';
    byId('password-help').textContent = mode === 'login'
      ? 'Usa la contraseña que elegiste al crear tu cuenta.' : 'Usa al menos 12 caracteres. Puedes pegar una contraseña de tu gestor.';
    byId('resend-confirmation').hidden = mode !== 'login';
    modeButtons.forEach(button => {
      button.setAttribute('aria-pressed', String(button.dataset.mode === mode));
      button.hidden = mode === 'recovery';
    });
  }

  async function showSession(session) {
    const request = ++revision;
    user = null;
    profileLoaded = false;
    profileFields.disabled = true;
    byId('profile-area').hidden = true;
    byId('auth-area').hidden = Boolean(session) && !recovering;
    byId('account-email').textContent = '';
    byId('profile-form').reset();
    if (!session) {
      if (recovering) {
        recovering = false;
        setMode('forgot');
        message('El enlace no es válido o ha caducado. Solicita uno nuevo.', 'error');
      }
      return;
    }
    const verified = await client.auth.getUser();
    if (request !== revision) return;
    if (verified.error || !verified.data.user) throw verified.error || new Error('Missing user');
    user = verified.data.user;
    if (recovering) {
      byId('auth-area').hidden = false;
      setMode('recovery');
      message('Enlace verificado. Elige tu nueva contraseña.');
      return;
    }
    byId('profile-area').hidden = false;
    byId('account-email').textContent = user.email;
    const profile = await client.from('profiles').select('display_name,bio,is_public').eq('id', user.id).single();
    if (request !== revision) return;
    if (profile.error || !profile.data) throw profile.error || new Error('Missing profile');
    byId('profile-name').value = profile.data.display_name;
    byId('profile-bio').value = profile.data.bio;
    byId('profile-public').checked = profile.data.is_public;
    profileLoaded = true;
    profileFields.disabled = false;
    message('Tu cuenta está lista. Puedes revisar tu perfil.');
  }

  async function perform(action) {
    if (busy) return;
    busy = true;
    fields.disabled = true;
    profileFields.disabled = true;
    modeButtons.forEach(button => { button.disabled = true; });
    byId('resend-confirmation').disabled = true;
    byId('sign-out').disabled = true;
    message('Procesando…');
    try {
      await action();
    } catch (error) {
      message(errorMessage(error), 'error');
    } finally {
      busy = false;
      fields.disabled = false;
      // A failed profile load must not enable a form containing empty values.
      profileFields.disabled = !profileLoaded;
      modeButtons.forEach(button => { button.disabled = false; });
      byId('resend-confirmation').disabled = false;
      byId('sign-out').disabled = false;
    }
  }

  modeButtons.forEach(button => button.addEventListener('click', () => {
    if (busy) return;
    setMode(button.dataset.mode);
    message('');
  }));

  form.addEventListener('submit', event => {
    event.preventDefault();
    email.value = email.value.trim();
    if (!form.reportValidity()) return;
    const credentials = { email: email.value, password: password.value };
    const displayName = name.value.trim();
    if (mode === 'signup' && !displayName) {
      message('Escribe el nombre que quieres usar en tu perfil.', 'error');
      name.focus();
      return;
    }
    void perform(async () => {
      if (mode === 'signup') {
        const result = await client.auth.signUp({ ...credentials, options: { emailRedirectTo: redirectTo, data: { display_name: displayName } } });
        if (result.error) throw result.error;
        password.value = '';
        if (result.data.session) await showSession(result.data.session);
        else {
          setMode('login');
          message('Revisa tu correo y abre el enlace de confirmación. Si ya tenías una cuenta, puedes iniciar sesión o recuperar tu contraseña.');
        }
      } else if (mode === 'login') {
        const result = await client.auth.signInWithPassword(credentials);
        if (result.error) throw result.error;
        password.value = '';
        await showSession(result.data.session);
      } else if (mode === 'forgot') {
        const result = await client.auth.resetPasswordForEmail(credentials.email, { redirectTo });
        if (result.error) throw result.error;
        message('Si existe una cuenta con ese correo, recibirás un enlace para recuperar el acceso.');
      } else if (mode === 'recovery' && user) {
        const result = await client.auth.updateUser({ password: credentials.password });
        if (result.error) throw result.error;
        recovering = false;
        password.value = '';
        await showSession((await client.auth.getSession()).data.session);
        message('Contraseña actualizada. Ya puedes usar tu cuenta.');
      }
    });
  });

  byId('resend-confirmation').addEventListener('click', () => {
    email.value = email.value.trim();
    if (!email.reportValidity()) return;
    void perform(async () => {
      const result = await client.auth.resend({ type: 'signup', email: email.value, options: { emailRedirectTo: redirectTo } });
      if (result.error) throw result.error;
      message('Si tu cuenta necesita confirmación, recibirás un nuevo enlace por correo.');
    });
  });

  byId('profile-form').addEventListener('submit', event => {
    event.preventDefault();
    if (!user || !event.currentTarget.reportValidity()) return;
    const displayName = byId('profile-name').value.trim();
    if (!displayName) return message('Escribe un nombre para tu perfil.', 'error');
    const owner = user.id;
    void perform(async () => {
      const result = await client.from('profiles').update({
        display_name: displayName,
        bio: byId('profile-bio').value.trim(),
        is_public: byId('profile-public').checked,
      }).eq('id', owner).select('id').single();
      if (result.error || !result.data) throw result.error || new Error('Profile not updated');
      message('Perfil guardado.');
    });
  });

  byId('sign-out').addEventListener('click', () => {
    void perform(async () => {
      const result = await client.auth.signOut({ scope: 'local' });
      if (result.error) throw result.error;
      recovering = false;
      setMode('login');
      await showSession(null);
      message('Has cerrado sesión en este navegador.');
    });
  });

  setMode(mode);
  try {
    if (!window.supabase) throw new Error('SDK unavailable');
    client = window.supabase.createClient('https://ylyjlxpfbxdxebukdezt.supabase.co', 'sb_publishable__ehY-RFRzyfUBbgMeh6K1A_A0p1ozJ_', {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: 'implicit' },
    });
    client.auth.onAuthStateChange((event, session) => {
      if (!['SIGNED_OUT', 'SIGNED_IN', 'PASSWORD_RECOVERY'].includes(event)) return;
      if (event === 'PASSWORD_RECOVERY') recovering = true;
      // Supabase callbacks run under the Auth lock; API calls must happen after it is released.
      setTimeout(() => {
        if (event === 'SIGNED_IN' && user?.id === session?.user.id) return;
        if (event === 'SIGNED_OUT') {
          recovering = false;
          setMode('login');
          message('Has cerrado sesión en este navegador.');
        }
        void showSession(session).catch(sessionError);
      }, 0);
    });
    const result = await client.auth.getSession();
    window.history.replaceState(null, '', window.location.pathname + window.location.search);
    if (result.error) throw result.error;
    await showSession(result.data.session);
    fields.disabled = false;
    if (!result.data.session && !callbackError && !recoveryCallback) message('Crea tu cuenta o inicia sesión para continuar.');
    if (callbackError) message('El enlace no es válido o ha caducado. Solicita uno nuevo.', 'error');
  } catch (error) {
    fields.disabled = !client;
    sessionError(error);
  }
})();
