# Backlog del proyecto

Los issues viven en el repositorio de documentación. Los de la **Fase 1** están
completamente especificados; los de las fases 2 a 4 se refinarán al llegar a
ellas.

Etiquetas: `fase:1..4` · `svc:auth|pricing|gateway|fr|frontend` ·
`tipo:contrato|seguridad|test|infra|feature` · `prio:bloqueante`

---

# FASE 1 — Cerrar Auth y la cadena de identidad

> Los issues A1 a A5 forman **una sola pieza**. Tocar uno sin los otros deja el
> sistema sin arrancar: la pasarela enruta con el prefijo antiguo y los
> servicios responderían con el nuevo. Planifícalos como un único cambio
> coordinado y fusiónalos juntos.

## A1 · Unificar la convención de rutas a `/v1/{servicio}/`

**Etiquetas:** `fase:1` `svc:auth` `svc:pricing` `svc:gateway` `tipo:contrato` `prio:bloqueante`

Los tres componentes montan hoy `/api/v1/...`. La convención acordada en
`CLAUDE.md` §2 y en las tres especificaciones es `/v1/{servicio}/...`.

### Alcance
- `auth-microservice`: `src/routes/index.js` — montar en `/v1/auth`.
- `pricing-microservice`: `src/routes/index.js` y el montaje del webhook en
  `src/app.js` — montar en `/v1/pricing`.
- `api-gateway`: `kong.yml` — actualizar los `paths` de `auth-route` y
  `pricing-route`, y el `auth_endpoint` por defecto de
  `plugins/space-auth/schema.lua`.

### Renombrados adicionales
- `POST /auth/rotate-api-key` → `POST /v1/auth/rotate-key`
- `POST /auth/internal/validate-api-key` → `POST /v1/auth/validate-key`
  (el cambio de contrato va en A3; aquí solo la ruta)

### Criterios de aceptación
- [ ] Ninguna ruta del proyecto contiene el segmento `/api/`.
- [ ] `grep -rn "/api/v1" --include=*.js --include=*.lua --include=*.yml`
      no devuelve resultados en código productivo.
- [ ] Con los tres servicios levantados, `POST /v1/auth/login` a través de Kong
      responde `200`.
- [ ] `GET /health` se mantiene fuera del versionado (es una sonda, no
      contrato).

---

## A2 · Introducir `accountId` en el modelo de Auth

**Etiquetas:** `fase:1` `svc:auth` `tipo:contrato` `prio:bloqueante`

`CLAUDE.md` §3: todo se vincula a `accountId`, nunca a `userId`. Hoy el modelo
es `AuthUser` con `id` y la palabra `accountId` no aparece en ningún fichero
del servicio.

La relación cuenta–usuario es **1:1 en esta versión**, pero se modela contra
`accountId` para permitir cuentas multiusuario sin migrar datos. Esta decisión
está justificada en la memoria y no debe revertirse por simplicidad.

### Alcance
- Renombrar la entidad `AuthUser` → `Account` y la colección a `accounts`
  (`CLAUDE.md` §7: plural, `snake_case`).
- Exponer `accountId` en todas las respuestas donde hoy se expone `id`.
- Roles: `enum: ['CUSTOMER', 'ADMIN']`. Eliminar `user` y `researcher`.
  `RESEARCHER` pertenece a la solución de investigación, que no se implementa.
- Estado: `enum: ['active', 'suspended']`. Eliminar `inactive`, que no existe
  en el contrato.

### Criterios de aceptación
- [ ] `GET /v1/auth/me` devuelve el objeto `Account` del contrato con
      `accountId`, sin envoltorio `{status, data}`.
- [ ] No queda ninguna referencia a `researcher` ni a `inactive` en código ni
      en tests.
- [ ] Existe un script o nota de migración para los documentos ya creados en
      desarrollo (o se documenta que la base se recrea).

---

## A3 · Adecuar `validate-key` al contrato

**Etiquetas:** `fase:1` `svc:auth` `tipo:contrato` `prio:bloqueante`

**Es la discrepancia bloqueante del proyecto.** Sin ella la pasarela no tiene
identidad que propagar y `fr-commercial` no puede determinar la propiedad de
las galerías.

### Cambios de contrato

| Aspecto | Hoy | Debe ser |
|---|---|---|
| Ruta | `/api/v1/auth/internal/validate-api-key` | `/v1/auth/validate-key` |
| Credencial | Cuerpo JSON `{apiKey}` + `x-internal-secret` | Cabecera `X-API-Key` |
| Respuesta | `{status, data:{user:{id, email, role}}}` | `{valid, accountId, status, role?}` |
| Códigos | `200`, `401`, `403` | `200`, `401` |

### Notas de diseño
- **La clave va en cabecera, no en el cuerpo.** Con `morgan('dev')` activo, el
  cuerpo acaba en trazas de depuración.
- **No devolver `email`.** Es un canal máquina a máquina; la pasarela no
  necesita datos personales.
- **El `403` desaparece.** La cuenta suspendida se comunica con `200` y
  `status: "suspended"`; es la pasarela quien decide qué hacer con esa
  información. Devolver `403` obligaba al plugin a distinguir códigos y hoy los
  colapsa todos en `401`.

### Criterios de aceptación
- [ ] Responde exactamente el esquema del contrato, verificado con
      `jest-openapi` (ver C1).
- [ ] Una clave válida de cuenta suspendida devuelve `200` con
      `status: "suspended"`, no `401` ni `403`.
- [ ] Una clave inválida devuelve `401` con cuerpo `ErrorReport`.
- [ ] La clave no aparece en los registros de la aplicación.

---

## A4 · Plugin de Kong: dos credenciales, cabeceras correctas y saneado

**Etiquetas:** `fase:1` `svc:gateway` `tipo:seguridad` `prio:bloqueante`

El plugin `space-auth` no puede funcionar hoy: exige `auth_body.pricing_token`,
campo que `auth` nunca ha devuelto, y sale con `500`. Solo pasa desapercibido
porque no está aplicado a ninguna ruta activa, es decir, **la pasarela no
autentica nada**.

### Alcance

**1. Aceptar las dos credenciales.** `CLAUDE.md` §1 exige dos esquemas de
seguridad sobre los mismos endpoints. Hoy el plugin exige `X-API-Key` y
responde `401` si falta, lo que excluye estructuralmente al canal web.

- `Authorization: Bearer <jwt>` → validar **por firma**, sin llamar a `auth`.
  Extraer `accountId` y `role` del propio token. Canal `frontend`.
- `X-API-Key` → llamar a `POST /v1/auth/validate-key`. Canal `api`.
- Ninguna de las dos → `401`.

**2. Propagar las cabeceras correctas.** Hoy inyecta `X-User-Id`,
`X-Space-Limits` y `X-Space-Features`. Deben ser:

```
X-Account-Id     identificador de la cuenta
X-Auth-Channel   "frontend" | "api"
X-Role           "CUSTOMER" | "ADMIN"
```

**3. Sanear las cabeceras de entrada.** Es el punto crítico de seguridad.
`kong.service.request.clear_header()` sobre las tres **antes** de establecer
los valores propios, y de forma incondicional: hoy `X-Space-Limits` solo se
escribe `if payload.limits`, de modo que si el token no la trae, la cabecera
enviada por el cliente pasa intacta al backend.

**4. Cachear el resultado** de `validate-key` unos 60 segundos. Hoy hay una
llamada HTTP a `auth` en cada petición, lo que lo convierte en punto único de
fallo.

**5. Rechazar la cuenta suspendida** con `403`, distinguiéndola de la
credencial inválida (`401`). `CLAUDE.md` §6.

### Criterios de aceptación
- [ ] Una petición con JWT válido atraviesa el plugin sin que se invoque a
      `auth`.
- [ ] Una petición con API KEY válida atraviesa el plugin e invoca a `auth`
      como mucho una vez por minuto para la misma clave.
- [ ] El plugin está aplicado a las rutas activas, no solo en bloques
      comentados.
- [ ] Una cuenta suspendida recibe `403`; una credencial inválida, `401`.
- [ ] `X-Account-Id` enviada por el cliente **nunca** llega al backend
      (verificado en A5).

---

## A5 · Test de integración del saneado de cabeceras

**Etiquetas:** `fase:1` `svc:gateway` `tipo:test` `prio:bloqueante`

El saneado de cabeceras es un control de seguridad **cuyo fallo es
silencioso**: si deja de funcionar, todo sigue pareciendo correcto hasta que
alguien suplanta una cuenta. Sin un test que lo verifique, una regresión futura
pasaría inadvertida.

Es el único test que hay que escribir a mano; el resto se generan desde el
contrato (C1).

### Montaje
Un servicio de eco detrás de Kong que devuelva las cabeceras que recibe.
Bastan unas líneas con `http.createServer` en un contenedor de pruebas.

### Casos
- [ ] Petición autenticada correctamente → el backend recibe `X-Account-Id`
      con la cuenta real.
- [ ] Petición autenticada **más** `X-Account-Id: <cuenta ajena>` → el backend
      recibe la cuenta real, **no** la enviada por el cliente.
- [ ] Ídem con `X-Role: ADMIN` inyectada → el backend recibe el rol real.
- [ ] Ídem con `X-Auth-Channel: api` sobre una sesión JWT → el backend recibe
      `frontend`.
- [ ] Petición sin credencial → `401`, y el backend no recibe nada.

---

## B1 · Eliminar `role` del registro público

**Etiquetas:** `fase:1` `svc:auth` `tipo:seguridad` `prio:bloqueante`

`POST /v1/auth/register` acepta `role` en el cuerpo. `{"role":"admin"}` crea un
administrador desde un endpoint público sin ninguna comprobación.

### Criterios de aceptación
- [ ] `role` no figura en `registerSchema`.
- [ ] El rol se asigna siempre `CUSTOMER` en el servicio.
- [ ] Test: `POST /v1/auth/register` con `{"role":"ADMIN"}` crea una cuenta
      `CUSTOMER`.

---

## B2 · `forgot-password` uniforme

**Etiquetas:** `fase:1` `svc:auth` `tipo:seguridad`

Hoy responde `200` si el correo existe y `404` con el mensaje *«There is no
account associated with this email address»* si no. Es exactamente el oráculo
de enumeración de usuarios que el contrato dice querer evitar.

### Criterios de aceptación
- [ ] Devuelve `202` con el mismo cuerpo exista o no la cuenta.
- [ ] El tiempo de respuesta no permite distinguir ambos casos de forma
      trivial (no cortocircuitar antes de la comprobación).
- [ ] Test que verifica idéntica respuesta para un correo registrado y uno no
      registrado.

---

## C1 · Tests de contrato generados desde el OpenAPI

**Etiquetas:** `fase:1` `svc:auth` `svc:pricing` `tipo:test` `prio:bloqueante`

`CLAUDE.md` exige tests de contrato antes de refactorizar. Los existentes fijan
el contrato **equivocado** (rutas `/api/v1/`, rol `researcher`, envoltorio
`{status, data}`), de modo que al corregir el código fallarán *por estar bien
corregido*. No sirven de red de seguridad.

**No los arregles: genéralos desde la especificación.**

### Montaje

```bash
npm install --save-dev jest-openapi
```

```js
// tests/setup.js
const jestOpenAPI = require('jest-openapi').default;
const path = require('path');
jestOpenAPI(path.join(__dirname, '../../openapi/auth.yaml'));
```

```js
// jest.config.js
setupFilesAfterEach: ['<rootDir>/tests/setup.js']
```

A partir de ahí, cada aserción es una línea:

```js
const res = await request(app)
  .post('/v1/auth/register')
  .send({ email: 'a@b.com', password: 'secret123' });

expect(res.status).toBe(201);
expect(res).toSatisfyApiSpec();   // valida contra auth.yaml
```

`toSatisfyApiSpec()` comprueba que la ruta existe en el contrato, que el código
de estado está declarado y que el cuerpo satisface el esquema. **El contrato no
se repite en el test**: si cambia el `.yaml`, los tests lo reflejan solos.

### Alcance
- [ ] Configurar `jest-openapi` en `auth` y en `pricing`.
- [ ] Un test `toSatisfyApiSpec()` por cada operación del contrato, incluido el
      camino de error (`400`, `401`, `403`, `409`).
- [ ] **`validate-key` con cobertura**: hoy el endpoint del issue A3 no tiene
      un solo test.
- [ ] Mover los tests actuales a `tests/legacy/`, excluidos de la ejecución.
      No borrarlos: documentan qué hacía el sistema antes, que es material para
      la memoria.
- [ ] Añadir `coverageThreshold` a `jest.config.js` para que la cobertura no
      pueda bajar.

> Para `fr-commercial` (Python) el equivalente es **Schemathesis**, que además
> genera casos límite automáticamente desde el OpenAPI. Se valorará en la
> Fase 2.

---

## C2 · Servir el `.yaml` como documentación única

**Etiquetas:** `fase:1` `svc:auth` `svc:pricing` `tipo:contrato`

Ambos servicios publican Swagger UI a partir de anotaciones `@swagger` en el
código que **describen un contrato distinto** del de los `.yaml`. Es una
tercera fuente de verdad, junto a la especificación y los tests.

La mayoría de los hallazgos de la auditoría no son errores de programación:
son consecuencia de que nada obligaba a que las tres coincidieran. Reducir a
una fuente evita que el problema se reproduzca.

### Cómo hacerlo

Sustituir `swagger-jsdoc` por la carga directa del fichero:

```js
// src/config/swagger.js
const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

const spec = yaml.load(
  fs.readFileSync(path.join(__dirname, '../../../openapi/auth.yaml'), 'utf8')
);

module.exports = spec;
```

```js
// src/app.js
const swaggerUi = require('swagger-ui-express');
const spec = require('./config/swagger');
app.use('/docs', swaggerUi.serve, swaggerUi.setup(spec));
app.get('/openapi.json', (req, res) => res.json(spec));
```

> El `.yaml` vive fuera del repositorio del microservicio. Opciones: copiarlo en
> el build de Docker, publicarlo como paquete npm interno, o incluirlo como
> submódulo de git. **Para el alcance de este TFM, copiarlo en el `Dockerfile`
> es suficiente** — pero documenta la decisión, porque introduce un paso de
> sincronización.

### Criterios de aceptación
- [ ] No queda ninguna anotación `@swagger` ni `@openapi` en el código.
- [ ] `swagger-jsdoc` fuera de `package.json`.
- [ ] `GET /docs` muestra exactamente el contenido del `.yaml`.
- [ ] `GET /openapi.json` devuelve la especificación, para poder compararla
      automáticamente.

---

# FASE 2 — FR Commercial

> Terreno nuevo y el grueso del trabajo. Estos issues se refinarán al abordar
> la fase; el detalle del contrato está en `openapi/fr-commercial.yaml`.

## F1 · Bootstrap del servicio
`fase:2` `svc:fr` — Estructura desde `python-template`, FastAPI, conexión a
MongoDB y Redis, sonda de salud, documentación servida desde el `.yaml`.
Lectura de `X-Account-Id`, `X-Auth-Channel` y `X-Role`; **no** revalidar
credenciales (es responsabilidad de la pasarela).

## F2 · Modelos de dominio e índices
`fase:2` `svc:fr` — `galleries`, `identities`, `faces` conforme al modelo de
`CLAUDE.md`. Índice `{galleryId}` en `faces` (crítico para 1:N) e índice único
disperso `{galleryId, externalId}` en `identities`. Contadores desnormalizados
`identityCount` y `faceCount`.

## F3 · CRUD de galerías
`fase:2` `svc:fr` — Modelo inmutable tras la creación. `status` no es campo de
entrada. Paginación acotada a 100.

## F4 · CRUD de identidades y rostros
`fase:2` `svc:fr` — Incluye `409 LAST_FACE_OF_IDENTITY` al borrar el único
rostro y `409` por `externalId` duplicado.

## F5 · Carga de modelos e inferencia sin estado
`fase:2` `svc:fr` — `detection`, `verification`, `extract-embeddings`. Los tres
modelos (`xs`, `s`, `base`) con su versión en la respuesta.

## F6 · Almacenamiento binarizado de embeddings
`fase:2` `svc:fr` — Formato nativo del índice: 64 B frente a 2 KB. Comparación
por distancia de Hamming. Documentar la decisión.

## F7 · Token de procedencia de embeddings
`fase:2` `svc:fr` `tipo:seguridad` — Firma que codifica modelo, versión y hash
del vector. Validación al enrolar desde vector.

## F8 · Verificación contra identidad e identificación 1:N
`fase:2` `svc:fr` — `/identities/{id}/verify` y `/galleries/{id}/search`.
**`search` no acepta token de enrolamiento** (devolvería el nombre de la
identidad).

## F9 · Cálculo de unidades de consumo
`fase:2` `svc:fr` — `u = n_inferencias × peso_modelo [+ f(tamaño_galería)]`.
Pesos como configuración, no constantes en el código: se recalibrarán con la
campaña de medición.

## F10 · Aplicación de límites
`fase:2` `svc:fr` — `QUOTA_EXCEEDED`, `MODEL_NOT_IN_PLAN`,
`INDEXED_FACES_LIMIT_REACHED`, `GALLERY_FROZEN_MODEL_NOT_IN_PLAN`,
`FEATURE_NOT_IN_PLAN`. Todos como `403` con `ErrorReport`.

## F11 · Tokens de enrolamiento en Redis
`fase:2` `svc:fr` `tipo:seguridad` — TTL, un solo uso vía `GETDEL` atómico,
clave construida con el hash del token. Ámbitos `enroll` y `verify`.

## F12 · Prueba de vida
`fase:2` `svc:fr` — Reto generado por el servidor, un solo uso, `410 Gone` al
caducar. `livenessToken` para vincular con la operación siguiente.

## F13 · Puntos de notificación e histórico de entregas
`fase:2` `svc:fr` — CRUD de webhooks, rotación de secreto y consulta de
entregas. **Secreto cifrado, no hasheado**: hay que recuperarlo en claro para
firmar.

---

# FASE 3 — Pricing

## P1 · `GET /subscription/status`
`fase:3` `svc:pricing` `prio:bloqueante` — Es la fuente del **derecho** de la
cuenta. Puede empezar devolviendo el plan `free` fijo mientras SPACE no esté
integrado: eso desbloquea la Fase 2 sin esperar a P6.

## P2 · `GET /subscription/usage`
`fase:3` `svc:pricing` — Con desglose por canal y por modelo. Requiere que
`fr-commercial` reporte esas dimensiones (F9).

## P3 · Complementos con cantidad
`fase:3` `svc:pricing` — `POST` y `DELETE` de `/subscription/addons/{addonId}`.
`400 QUANTITY_NOT_APPLICABLE` en booleanos, `409 ADDON_MAX_QUANTITY_EXCEEDED`
al superar el máximo. Almacenar como `{addOnId, quantity}`.

## P4 · Cambio de plan y baja
`fase:3` `svc:pricing` — `PATCH /subscription/update` y
`DELETE /subscription`. Mejora inmediata prorrateada, reducción al cierre del
periodo.

## P5 · Mapeo de plan a identificador de Stripe
`fase:3` `svc:pricing` — Hoy `planId` se pasa tal cual a Stripe como Price ID.
El contrato define `enum: [free, pro, business]`: la API no debe filtrar
identificadores de la pasarela de pago. Requiere una tabla de correspondencia
en el servidor.

## P6 · Integración con SPACE
`fase:3` `svc:pricing` — Cliente HTTP, sincronización de límites y obtención
del *pricing token*.

## P7 · Portal de facturación
`fase:3` `svc:pricing` — `POST /billing/portal`.

---

# FASE 4 — Integración

## I1 · Interfaz de publicación de eventos
`fase:4` `tipo:infra` `prio:bloqueante` — **Este issue va antes de Kafka.**
Definir un `EventPublisher` en `auth`, `pricing` y `fr-commercial` con una
implementación HTTP directa. Kafka se sustituye después sin tocar la lógica de
negocio. Lo que no puede aplazarse es la interfaz: si `auth` no tiene a quién
llamar, introducirlo más tarde obliga a tocar todo.

## I2 · Migración a Kafka
`fase:4` `tipo:infra` — Sustituir la implementación HTTP. Eventos:
`account.deleted`, `subscription.plan_changed`, consumo.

## I3 · Propagación del borrado de cuenta
`fase:4` `tipo:seguridad` — `auth` publica; `pricing` cancela la suscripción de
Stripe; `fr-commercial` purga galerías, identidades, rostros y webhooks.
**Hoy al borrar una cuenta Stripe sigue cobrando.** Tiene lectura legal: las
plantillas biométricas son datos de categoría especial.

## I4 · Congelación y descongelación de galerías
`fase:4` `svc:fr` — Consumo de `subscription.plan_changed` **en ambos
sentidos**. La descongelación cubre la mejora de plan y la contratación del
complemento de modelo.

## I5 · Webhooks salientes con firma y reintentos
`fase:4` `svc:fr` — HMAC-SHA256 sobre `timestamp + "." + cuerpo_crudo`.
Reintentos con espera exponencial. Validación de URL contra SSRF.

## I6 · Límite de tasa segmentado
`fase:4` `svc:gateway` — Por segundo, por plan, separando inferencia de
gestión (3/10, 5/50, 20/200). Cambiar `policy: local` por `redis`: con varias
réplicas de Kong el límite efectivo se multiplica.

## I7 · Red Docker compartida
`fase:4` `tipo:infra` — Kong vive en `tfm-network` y cada microservicio crea la
suya: **Kong no puede resolver `auth-service` ni `pricing-service`**. El
conjunto no arranca como sistema.

## I8 · Frontend
`fase:4` `svc:frontend` — Evaluación **y panel de administración**: galerías,
identidades, consumo, webhooks, credenciales.

## I9 · Tests extremo a extremo
`fase:4` `tipo:test` — Kong → Auth → Pricing → FR Commercial.

## I10 · Campaña de medición de capacidad
`fase:4` — Aplicación del marco SCALE. Nueve perfiles: tres modelos × tres
operaciones. Sustituye los pesos hipotéticos por los medidos.
