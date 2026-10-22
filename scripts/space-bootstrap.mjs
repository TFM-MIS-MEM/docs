// ===========================================================
// space-bootstrap.mjs — deja SPACE listo para el SaaS. Idempotente.
//
// Se ejecuta DENTRO del contenedor space-server (lo lanza space-bootstrap.sh
// con `docker exec -i space-server node -`): SPACE no publica puertos, y así no
// hace falta nada en la máquina salvo Docker. Usa el `node` y el `fetch` del
// propio contenedor.
//
// Entrada (entorno):
//   ADMIN_USER, ADMIN_PASSWORD     los del contenedor: los fija space/.env
//   SPHERE_PRICING_URL             enlace permanente de la tarifa en SPHERE
//   SPHERE_PRICING_VERSION_ID      versión fijada (pricing/sphere.env)
//   SPHERE_PRICING_CONTENT_HASH    su huella funcional
//   FR_SPACE_API_KEY, PRICING_SPACE_API_KEY   claves ya emitidas, si las hay
//
// Salida (stdout): líneas CLAVE=valor que space-bootstrap.sh escribe en los
// .env. Todo lo demás va a stderr.
//
// Qué hace:
//   1. Una clave de organización MANAGEMENT para fr-commercial y otra para
//      pricing. EVALUATION no sirve: no puede evaluar ni pedir el token de
//      pricing (POST /features/** solo admite ALL y MANAGEMENT), y
//      fr-commercial además crea los contratos Free. Una clave ya emitida que
//      sigue en la organización se reutiliza.
//   2. El servicio `frsaas` desde SPHERE, con la política all_pick y la versión
//      fijada. Con pick, una versión nueva en SPHERE no entra hasta cambiar la
//      selección; las dos primeras versiones tienen el mismo createdAt y nadie
//      ha comprobado cómo desempata SPACE «la última».
//   3. Comprueba que la tarifa aplicada es la fijada, por versionId y por huella.
// ===========================================================

const BASE = 'http://localhost:3000/api/v1';
const SERVICE = 'frsaas';
const env = process.env;

const log = (...args) => console.error('  ', ...args);

async function api(method, path, key, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'x-api-key': key, ...(body ? { 'content-type': 'application/json' } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = text;
  }
  return { status: res.status, data };
}

function fail(message) {
  console.error(`[ERROR] ${message}`);
  process.exit(1);
}

async function login() {
  const res = await fetch(`${BASE}/users/authenticate`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ username: env.ADMIN_USER, password: env.ADMIN_PASSWORD }),
  });
  if (res.status !== 200) fail(`no se pudo iniciar sesión como ${env.ADMIN_USER} (HTTP ${res.status})`);
  return (await res.json()).apiKey;
}

async function ensureKeys(userKey) {
  const orgs = await api('GET', '/organizations', userKey);
  const org = orgs.data?.data?.find((o) => o.default) ?? orgs.data?.data?.[0];
  if (!org) fail(`sin organización por omisión (HTTP ${orgs.status})`);

  const keys = {};
  for (const [name, current] of [
    ['FR_SPACE_API_KEY', env.FR_SPACE_API_KEY],
    ['PRICING_SPACE_API_KEY', env.PRICING_SPACE_API_KEY],
  ]) {
    const fresh = await api('GET', `/organizations/${org.id}`, userKey);
    const existing = fresh.data?.apiKeys?.find((k) => k.key === current && k.scope === 'MANAGEMENT');
    if (existing) {
      log(`${name}: reutilizada`);
      keys[name] = current;
      continue;
    }
    const before = new Set((fresh.data?.apiKeys ?? []).map((k) => k.key));
    const created = await api('POST', `/organizations/${org.id}/api-keys`, userKey, { scope: 'MANAGEMENT' });
    const key = created.data?.apiKeys?.find((k) => !before.has(k.key) && k.scope === 'MANAGEMENT')?.key;
    if (!key) fail(`no se pudo crear la clave ${name} (HTTP ${created.status})`);
    log(`${name}: creada`);
    keys[name] = key;
  }
  return keys;
}

async function ensureService(orgKey) {
  const wanted = {
    source: 'sphere',
    permanentUrl: env.SPHERE_PRICING_URL,
    policy: 'all_pick',
    selectedVersionId: env.SPHERE_PRICING_VERSION_ID,
  };

  let sync = await api('GET', `/services/${SERVICE}/synchronization`, orgKey);
  if (sync.status === 404) {
    const created = await api('POST', '/services', orgKey, wanted);
    if (created.status !== 201) fail(`no se pudo crear ${SERVICE} desde SPHERE (HTTP ${created.status}): ${JSON.stringify(created.data)}`);
    log(`${SERVICE}: creado desde SPHERE`);
  } else if (sync.status === 200) {
    const conf = sync.data.configuration ?? {};
    if (conf.policy !== wanted.policy || conf.selectedVersionId !== wanted.selectedVersionId) {
      const put = await api('PUT', `/services/${SERVICE}/synchronization`, orgKey, {
        policy: wanted.policy,
        selectedVersionId: wanted.selectedVersionId,
      });
      if (put.status !== 200) fail(`no se pudo fijar la versión (HTTP ${put.status}): ${JSON.stringify(put.data)}`);
      const run = await api('POST', `/services/${SERVICE}/synchronization/run`, orgKey, {});
      if (run.status !== 202) fail(`no se pudo sincronizar (HTTP ${run.status}): ${JSON.stringify(run.data)}`);
      log(`${SERVICE}: versión fijada cambiada; sincronizando`);
    } else {
      log(`${SERVICE}: ya estaba en la versión fijada`);
    }
  } else {
    fail(`GET /services/${SERVICE}/synchronization respondió HTTP ${sync.status}`);
  }

  // La sincronización es asíncrona: se espera a `ready`.
  for (let i = 0; i < 60; i++) {
    sync = await api('GET', `/services/${SERVICE}/synchronization`, orgKey);
    const status = sync.data?.configuration?.status;
    if (status === 'ready') break;
    if (status === 'blocked' || status === 'degraded') fail(`sincronización en estado ${status}: ${sync.data.configuration.error ?? ''}`);
    await new Promise((r) => setTimeout(r, 1000));
  }

  const target = sync.data?.configuration?.target;
  if (target?.versionId !== env.SPHERE_PRICING_VERSION_ID) {
    fail(`la tarifa aplicada es ${target?.versionId}, no la fijada ${env.SPHERE_PRICING_VERSION_ID}`);
  }
  if (target?.contentHash !== env.SPHERE_PRICING_CONTENT_HASH) {
    fail(`la huella aplicada (${target?.contentHash}) no es la fijada (${env.SPHERE_PRICING_CONTENT_HASH})`);
  }
  log(`${SERVICE}: aplicada la versión ${target.version} (${target.versionId}), huella ${target.contentHash.slice(0, 12)}…`);
}

for (const v of ['ADMIN_USER', 'ADMIN_PASSWORD', 'SPHERE_PRICING_URL', 'SPHERE_PRICING_VERSION_ID', 'SPHERE_PRICING_CONTENT_HASH']) {
  if (!env[v]) fail(`falta ${v}`);
}

const userKey = await login();
const keys = await ensureKeys(userKey);
await ensureService(keys.PRICING_SPACE_API_KEY);

for (const [name, value] of Object.entries(keys)) console.log(`${name}=${value}`);
