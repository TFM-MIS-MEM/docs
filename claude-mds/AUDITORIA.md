# Auditoría del workspace contra las especificaciones OpenAPI y CLAUDE.md

> **Foto fechada del código heredado, congelada.** Refleja el estado del
> repositorio en el momento de auditarlo y **no se actualiza**: se cita. Los
> hallazgos que se van cerrando se siguen en los issues de `TFM-MIS-MEM/docs`,
> no aquí. Un documento de auditoría que se edita a medida que se arregla lo
> que denuncia deja de poder usarse como línea base.

**Fecha:** 2026-08-26
**Alcance auditado:** `auth-microservice/` (contra `openapi/auth.yaml`),
`pricing-microservice/` (contra `openapi/pricing.yaml`), `api-gateway/`
(contra las reglas de pasarela de `CLAUDE.md`).
**Fuera de alcance:** `node-template/`, `python-template/`, `fr-commercial`
(no existe).

**No se ha modificado ningún fichero.** Este documento es solo el informe.

## Resumen ejecutivo

| Servicio | Bloqueantes | Importantes | Menores |
|---|---:|---:|---:|
| auth-microservice | 6 | 11 | 6 |
| pricing-microservice | 5 | 10 | 5 |
| api-gateway | 6 | 7 | 4 |
| Entre servicios | 7 | 4 | 1 |

Tres hallazgos condicionan todo lo demás:

1. **Ningún servicio usa la convención `/v1/{servicio}/...`.** Los tres montan
   `/api/v1/...`. La pasarela enruta con el prefijo antiguo, de modo que
   corregir un servicio sin corregir Kong lo deja inalcanzable.
2. **El plugin `space-auth` no puede funcionar hoy contra el `auth` actual.**
   Espera un campo `pricing_token` que `auth` nunca ha devuelto: toda petición
   que pasara por el plugin terminaría en `500`. Además el plugin no está
   aplicado a ninguna ruta activa, luego **ahora mismo la pasarela no autentica
   nada**.
3. **No existe ninguna integración de Kafka ni de SPACE** en ninguno de los dos
   microservicios Node. Los tres eventos del diseño (`account.deleted`,
   `subscription.plan_changed`, consumo) no se publican ni se consumen.

---

# 1. auth-microservice

Especificación: `openapi/auth.yaml`.
Prefijo implementado: `/api/v1/auth` (`src/routes/index.js:11`).
Prefijo especificado: `/v1/auth`.

## 1.1 Endpoints implementados que NO están en la especificación

| Severidad | Endpoint implementado | Observación |
|---|---|---|
| 🔴 Bloqueante | `POST /api/v1/auth/internal/validate-api-key` | La especificación define `POST /v1/auth/validate-key`. No es solo un cambio de ruta: cambia el transporte de la credencial (cuerpo JSON frente a cabecera `X-API-Key`), el esquema de seguridad (`x-internal-secret` compartido frente a `apiKeyAuth`) y la respuesta. Ver §1.3. |
| 🔴 Bloqueante | `POST /api/v1/auth/rotate-api-key` | La especificación la llama `rotate-key`. La ruta implementada no existe en el contrato. |
| 🟡 Importante | Los 9 endpoints, por el prefijo `/api/v1/` | Ninguna ruta implementada coincide literalmente con la especificación. Se detalla una sola vez aquí y no se repite en cada fila de §1.3. |
| 🟢 Menor | `GET /health` (`src/routes/index.js:9`) | Sonda operativa, no forma parte del contrato de negocio. Admisible, pero conviene documentarlo o excluirlo explícitamente. |
| 🟢 Menor | `GET /api/v1/docs` (Swagger UI) | Documentación autogenerada a partir de anotaciones `@swagger` que **describen un contrato distinto del de `auth.yaml`**. Publica una segunda fuente de verdad contradictoria. |

## 1.2 Endpoints de la especificación que NO están implementados

| Severidad | Endpoint especificado | Impacto |
|---|---|---|
| 🔴 Bloqueante | `POST /v1/auth/suspend` | No existe ninguna vía para suspender la propia cuenta. El ciclo de vida de la cuenta está incompleto. |
| 🔴 Bloqueante | `PATCH /v1/auth/accounts/{accountId}/status` | No existe. Es la **única** vía de reactivación prevista en el diseño, y la única operación con rol `ADMIN` del servicio. Sin ella, una cuenta suspendida es irrecuperable. |

Nota sobre el hoja de ruta: `CLAUDE.md` (Issue 8) dice «Separar `PATCH /auth/status`
en `POST /auth/suspend` y `PATCH /auth/accounts/{accountId}/status`». **`PATCH
/auth/status` no existe en el código**: no hay nada que separar, hay que crear
las dos operaciones desde cero. Conviene corregir el enunciado del issue.

## 1.3 Endpoints en ambos pero con contrato distinto

### 🔴 `POST /v1/auth/validate-key` → `POST /api/v1/auth/internal/validate-api-key`

**Es la discrepancia bloqueante del proyecto (Issue 7).**

| Aspecto | Especificación | Implementación (`auth.service.js:...validateApiKey`, `auth.controller.js`) |
|---|---|---|
| Ruta | `/v1/auth/validate-key` | `/api/v1/auth/internal/validate-api-key` |
| Credencial | Cabecera `X-API-Key` (`apiKeyAuth`) | Cuerpo JSON `{apiKey}` + cabecera `x-internal-secret` |
| Respuesta 200 | `{valid, accountId, status, role?}`, con `valid`, `accountId` y `status` **obligatorios** | `{status:'success', data:{user:{id, email, role}}}` |
| `accountId` | Obligatorio | **Ausente** (existe `id`, anidado y con otro nombre) |
| `status` | Obligatorio | **Ausente** |
| `valid` | Obligatorio | **Ausente** (se infiere del código HTTP) |
| Códigos | `200`, `401` | `200`, `401`, **`403`** (cuenta no activa) |
| Fuga de datos | No devuelve `email` | Devuelve `email` a la pasarela: PII innecesaria en un canal M2M |

Consecuencia: la pasarela no tiene identidad que propagar en `X-Account-Id` y
`fr-commercial` no podrá determinar la propiedad de las galerías. Además, el
`403` extra rompe el contrato: la especificación solo contempla `200`/`401`,
y el plugin actual trata cualquier respuesta distinta de `200` como `401`,
perdiendo la distinción entre «clave inválida» y «cuenta suspendida».

Riesgo adicional: la clave viaja **en el cuerpo**, justo lo que la
especificación quiere evitar («para reducir su exposición en registros y
trazas»). Con `morgan('dev')` activo y `express.json({limit:'10mb'})`, la clave
es susceptible de acabar en trazas de depuración.

### 🔴 `POST /v1/auth/register`

| Aspecto | Especificación | Implementación |
|---|---|---|
| Cuerpo | `{email, password}` — **`role` no es un campo de entrada** | `{email, password, role}` con `role ∈ {user, admin, researcher}` (`auth.routes.js`, `registerSchema`) |
| Rol asignado | Siempre `CUSTOMER`; «ningún usuario externo puede crear una cuenta con rol `ADMIN`» | El cliente elige el rol, **incluido `admin`** |
| Respuesta 201 | `{accountId, email, apiKey}` en el nivel superior | `{status, message, data:{user, apiKey}}`; el identificador es `user.id`, no `accountId` |
| Cuerpo del 409 | `ErrorReport` `{code, message}` en `application/problem+json` | `{status:'fail', message}` en `application/json`, sin `code` |

**Escalada de privilegios**: `POST /api/v1/auth/register` con
`{"role":"admin"}` crea un administrador sin ninguna comprobación. Es un
endpoint público (`security: []`). Bloqueante por seguridad, no solo por
contrato.

### 🔴 `POST /v1/auth/forgot-password`

| Aspecto | Especificación | Implementación |
|---|---|---|
| Código de éxito | `202` **tanto si el correo existe como si no** | `200` si existe, **`404` si no existe** (`auth.service.js`, `forgotPassword`) |
| Motivo declarado | «para impedir la enumeración de usuarios registrados» | El `404` con el mensaje *«There is no account associated with this email address»* **es precisamente el oráculo de enumeración que el diseño prohíbe** |
| `429` | Especificado | No implementado (solo el limitador global por IP) |

### 🟡 `POST /v1/auth/reset-password`

| Aspecto | Especificación | Implementación |
|---|---|---|
| Cuerpo | `{token, newPassword}` | `{token, password}` — **nombre de campo distinto** |
| `429` | Especificado | No implementado |

Con `stripUnknown: true` en el middleware `validate`, un cliente que siga la
especificación y envíe `newPassword` recibirá un `400` por «password is
required». Rompe al frontend en silencio.

### 🟡 `POST /v1/auth/rotate-key`

| Aspecto | Especificación | Implementación |
|---|---|---|
| Ruta | `/v1/auth/rotate-key` | `/api/v1/auth/rotate-api-key` |
| Cuerpo | `{password}` **obligatorio** | Sin cuerpo, sin reconfirmación de contraseña |
| Código de éxito | `201` | `200` |
| Respuesta | `{apiKey}` | `{status, message, data:{apiKey}}` |
| Códigos | `201`, `401`, `403` | `200`, `401` |

La ausencia de reconfirmación de contraseña convierte un JWT robado en una
toma de control del canal API: el atacante rota la clave, invalida la del
titular y se queda con la nueva.

### 🟡 `DELETE /v1/auth/account`

| Aspecto | Especificación | Implementación |
|---|---|---|
| Cuerpo | `{password}` **obligatorio** | Sin cuerpo, sin reconfirmación |
| Evento | Publica `account.deleted` en Kafka | **No publica nada** (no hay cliente de Kafka en el proyecto) |
| Código | `204` | `204`, pero con `res.status(204).json({...})`: se construye un cuerpo que Express descarta. Confuso, aunque inocuo. |

La no publicación de `account.deleted` es bloqueante y tiene lectura legal: el
diseño advierte que «la propagación del borrado no es una mejora opcional: las
plantillas biométricas son datos personales de categoría especial». Hoy el
borrado no se propaga a `pricing` (la suscripción de Stripe sobrevive) ni
podrá propagarse a `fr-commercial`.

### 🟡 `POST /v1/auth/login`

| Aspecto | Especificación | Implementación |
|---|---|---|
| Respuesta 200 | `{token, expiresIn}` **obligatorios** | `{status, message, data:{user, token}}` — **falta `expiresIn`** |
| Códigos | `200`, `401`, `429` | `200`, `401`, **`403`** (cuenta no activa) |
| `429` | Especificado (Issue 9) | No implementado: solo el limitador global de 100 peticiones/15 min por IP sobre `/api`, que no es un límite de fuerza bruta sobre credenciales |

El `403` distingue «contraseña incorrecta» de «cuenta suspendida», lo que
reintroduce enumeración de cuentas por otra vía, precisamente lo que el
`invalidCredentialsError` genérico de las líneas anteriores intenta evitar.

### 🟡 `GET /v1/auth/me`

| Aspecto | Especificación (`Account`) | Implementación |
|---|---|---|
| Campos obligatorios | `accountId`, `email`, `status`, `role`, `createdAt` | `id` (no `accountId`), `email`, `status`, `role`, `createdAt`, `updatedAt` |
| Envoltorio | Objeto `Account` directo | `{status, data:{user}}` |
| Enum `status` | `active`, `suspended` | `active`, `inactive`, `suspended` — `inactive` no existe en el contrato |
| Enum `role` | `CUSTOMER`, `ADMIN` | `user`, `admin`, `researcher` |

### 🟢 `POST /v1/auth/change-password`

Único endpoint cuyo cuerpo de petición coincide (`{oldPassword, newPassword}`).
Difieren solo el prefijo de ruta y el envoltorio de la respuesta.

## 1.4 Reglas de CLAUDE.md que el código incumple

| Severidad | Regla | Incumplimiento |
|---|---|---|
| 🔴 | §2 Versionado: `/v1/{servicio}/...` | Todo el servicio monta `/api/v1/auth` (`src/routes/index.js:11`) |
| 🔴 | §3 Propiedad: «todo se vincula a `accountId`, nunca a `userId`» | El modelo es `AuthUser` con `id`. La palabra `accountId` no aparece en ningún fichero del servicio. Ninguna respuesta la expone |
| 🔴 | §3 Roles: solo `ADMIN` y `CUSTOMER`; «`RESEARCHER` pertenece a la solución de investigación, que no se implementa» | `user.model.js` define `enum: ['user','admin','researcher']`. Hay incluso un test que verifica la asignación del rol `researcher` |
| 🔴 | Seguridad: registro sin escalada | `role` es un campo de entrada público en `register` |
| 🟡 | §6 Error Report: cuerpo con `code` | `errorHandler.js` devuelve `{status, message, stack?}`. **Ningún error del servicio incluye `code`**, ni usa `application/problem+json`. Los códigos previstos (`EMAIL_ALREADY_REGISTERED`, etc.) no existen |
| 🟡 | §6 Códigos: `201` en creación | `rotate-key` devuelve `200` donde el contrato pide `201` |
| 🟡 | §7 Nomenclatura: colecciones en plural `snake_case` | Mongoose deriva `authusers` de `AuthUser`. Debería ser la colección `accounts` con la entidad `Account` |
| 🟡 | «Cero secretos en el código» | `src/config/index.js`: `internalApiSecret: process.env.INTERNAL_API_SECRET \|\| 'dev_internal_secret_key_789'`. Si la variable falta en producción, el servicio arranca aceptando un secreto público |
| 🟡 | «Los microservicios solo son alcanzables a través de la pasarela» | `docker-compose.yml` publica `${PORT}:${PORT}` al host y MongoDB en `27017:27017`. Ambos son alcanzables sin pasar por Kong |
| 🟡 | §4 Cabeceras de Kong | El servicio no lee ni `X-Account-Id`, ni `X-Auth-Channel`, ni `X-Role`. Revalida el JWT por su cuenta (`middlewares/auth.js`), duplicando la responsabilidad de la pasarela |
| 🟡 | Eventos Kafka: `auth` publica `account.deleted` | No hay dependencia de Kafka en `package.json` ni productor alguno |
| 🟢 | §5 Patrones de responsabilidad | `auth.controller.js` anota `POST /login` como *Computation Function*; el contrato y `CLAUDE.md` §5 lo clasifican como **RETRIEVAL OPERATION** (lee la BBDD). `auth.service.js` repite el error. Es documentación equivocada dentro del código |
| 🟢 | Fuera del servicio pero relacionado | `user-example-apikey` en la raíz del workspace contiene una API KEY real y **no está en `.gitignore`** (sí lo están `resend-apikey.txt`, `stripe-secret-key.txt` y `stripe-webhook-secret.txt`) |
| 🟢 | Compose incompleto | `docker-compose.yml` no propaga `JWT_SECRET`, `RESEND_API_KEY` ni `INTERNAL_API_SECRET` al contenedor: `signJwt` lanzaría `500` y el secreto interno caería al valor por defecto |
| 🟢 | Caducidad del JWT | `jwtExpiresIn` por defecto `'1h'` = 60 min, correcto, pero no se expone `expiresIn` en la respuesta de login |

> **Corrección (sesión 5).** La última fila de esta tabla dice que
> `user-example-apikey` **no está en `.gitignore`** y que `resend-apikey.txt`,
> `stripe-secret-key.txt` y `stripe-webhook-secret.txt` **sí** lo están. Esa
> distinción no es una foto que haya envejecido: es un error de observación, y
> lo era ya el día de la auditoría. El único `.gitignore` que nombra a los
> cuatro es el de la raíz del workspace, y **la raíz del workspace no es un
> repositorio git**: los seis repositorios tienen su raíz en
> `repos/<nombre>`, y ninguno rastrea ese fichero ---`git log -- ../.gitignore`
> devuelve cero commits en los seis---. Ese `.gitignore` no gobierna nada. Ni
> excluía `user-example-apikey`, ni excluía a los otros tres: los cuatro quedan
> fuera de todo árbol de trabajo, de modo que ninguno podía llegar a
> committearse a ninguno de los repositorios, con `.gitignore` o sin él.
>
> Lo que el hallazgo sí acertaba, y se mantiene: había una **API KEY real en
> claro en el disco**. Eso era cierto en esta fecha y siguió siéndolo.
>
> **Desde cuándo, sin determinar.** El `.gitignore` de la raíz nació el
> 2026-04-21 y se modificó por última vez el **2026-08-26 a las 14:08:54**, el
> mismo día de esta auditoría. Al no estar bajo control de versiones en ningún
> sitio, no hay manera de saber si la línea `user-example-apikey` ya estaba
> cuando se redactó el informe o se añadió esa misma tarde. La corrección de
> arriba no depende de esa fecha: el reproche no es que la línea faltara, sino
> que el fichero que la contiene no protege a nadie.
>
> **Que no hubiera riesgo es un accidente, no un control.** No lo había porque
> la raíz del workspace está *fuera* de todos los árboles de trabajo, no porque
> nada la protegiera. La protección real del proyecto es la otra, la que este
> mismo anexo describe en su segundo punto: `auth-microservice/.env` y
> `pricing-microservice/.env` los cubre el `.gitignore` **de su propio
> repositorio**, verificado con `git check-ignore -q .env`, que responde
> afirmativamente en los dos. Ese es el mecanismo que funciona.
>
> El de la raíz es decorativo, y solo mientras la raíz no sea un repositorio.
> Deja de serlo en dos supuestos nada rebuscados: si el workspace pasa a estar
> versionado ---agrupando los servicios en un monorepo, por ejemplo---, o si
> alguien copia uno de esos cuatro ficheros dentro de `repos/<servicio>/`. En el
> segundo caso el `.gitignore` de la raíz **no lo cubre**, porque no gobierna ese
> árbol, y el del servicio tampoco lo nombra: el fichero quedaría rastreable
> desde el primer `git add`. La conclusión práctica del hallazgo, por tanto, no
> cambia; cambia el motivo por el que se sostenía.

## 1.5 Cobertura de tests actual

Marco: Jest + `supertest` + `mongodb-memory-server`. 3 ficheros, 44 casos.

| Fichero | Casos | Cubre |
|---|---:|---|
| `tests/auth.routes.test.js` | 16 | Solo `register` (8) y `login` (7) |
| `tests/user.model.test.js` | 25 | Esquema, hook de bcrypt, `comparePassword`, `toJSON`, token de reseteo |
| `tests/health.test.js` | 3 | Sonda de salud |

**Sin ningún test:**

- `POST /forgot-password`, `POST /reset-password` — incluido el fallo de
  enumeración descrito en §1.3.
- `POST /change-password`.
- `POST /rotate-api-key`.
- `GET /me`.
- `DELETE /account`.
- `POST /internal/validate-api-key` — **el endpoint bloqueante del Issue 7 no
  tiene un solo test**.
- `middlewares/auth.js` (`protect`) y `middlewares/internal.middleware.js`
  (`requireInternalSecret`): sin cobertura directa.
- `services/auth.service.js`: cubierto solo de forma indirecta y parcial.

**Problema añadido**: los tests existentes fijan el contrato **equivocado**.
Afirman rutas `/api/v1/...`, el envoltorio `{status, data}` y la asignación del
rol `researcher`. Al corregir el servicio, esos tests fallarán *por estar
bien corregido el código*. No sirven como red de seguridad.

`CLAUDE.md` exige: «Antes de refactorizar `auth` o `pricing`, tener tests de
contrato mínimos». **Esa precondición no se cumple para ninguno de los
endpoints que hay que refactorizar.** Los únicos dos con cobertura
(`register`, `login`) son también los dos que hay que cambiar.

`jest.config.js` recoge cobertura pero **no define `coverageThreshold`**: nada
impide que la cobertura baje.

---

# 2. pricing-microservice

Especificación: `openapi/pricing.yaml`.
Prefijo implementado: `/api/v1/pricing`.
Prefijo especificado: `/v1/pricing`.

## 2.1 Endpoints implementados que NO están en la especificación

| Severidad | Endpoint | Observación |
|---|---|---|
| 🟡 Importante | Los 2 endpoints, por el prefijo `/api/v1/` | `src/routes/index.js:10` y `src/app.js` (montaje del webhook) |
| 🟢 Menor | `GET /health` | Sonda operativa, admisible |
| 🟢 Menor | Swagger UI | Anotaciones `@openapi` que describen un contrato distinto del de `pricing.yaml`; segunda fuente de verdad |

No hay endpoints de negocio inventados: el problema es de **defecto**, no de
exceso.

## 2.2 Endpoints de la especificación que NO están implementados

**7 de los 9 endpoints del contrato no existen.**

| Severidad | Endpoint | Impacto |
|---|---|---|
| 🔴 Bloqueante | `GET /v1/pricing/subscription/status` | Es la fuente del **derecho** de la cuenta: `plan`, `addOns`, `limits`. Sin él, la pasarela no puede evaluar `apiChannel` ni el límite de tasa por plan, el frontend no puede pintar el panel y `fr-commercial` no puede fundamentar `MODEL_NOT_IN_PLAN`, `FEATURE_NOT_IN_PLAN` ni `QUOTA_EXCEEDED` |
| 🔴 Bloqueante | `GET /v1/pricing/subscription/usage` | El consumo real no se expone. Issue 19 completo |
| 🔴 Bloqueante | `POST /v1/pricing/subscription/addons/{addonId}` | Los complementos no existen. Toda la lógica de `quantity`, `400 QUANTITY_NOT_APPLICABLE`, `409 ADDON_MAX_QUANTITY_EXCEEDED` y `409 ADDON_ALREADY_CONTRACTED` está sin implementar. Issue 18 |
| 🔴 Bloqueante | `DELETE /v1/pricing/subscription/addons/{addonId}` | Ídem, con reducción parcial de unidades |
| 🟡 Importante | `PATCH /v1/pricing/subscription/update` | No hay cambio de plan. Sin él no hay mejora/reducción, ni `pendingPlan`, ni por tanto `subscription.plan_changed` |
| 🟡 Importante | `DELETE /v1/pricing/subscription` | No hay baja voluntaria ni cancelación inmediata |
| 🟡 Importante | `POST /v1/pricing/billing/portal` | No hay portal de autoservicio |

## 2.3 Endpoints en ambos pero con contrato distinto

### 🔴 `POST /v1/pricing/checkout/create-session`

| Aspecto | Especificación | Implementación (`checkout.routes.js`, `checkout.controller.js`, `stripe.service.js`) |
|---|---|---|
| Ruta | `/v1/pricing/checkout/create-session` | `/api/v1/pricing/checkout/create-session` |
| `planId` | `enum: [free, pro, business]` | `Joi.string()` libre; se documenta como **Stripe Price ID** (`price_xxx`) y se pasa tal cual a `line_items[0].price` |
| `addOnIds` | Array opcional de `AddOnId` | **No soportado**. `stripUnknown: true` lo descarta en silencio |
| Respuesta 201 | `{sessionId, url}`, ambos **obligatorios** | `{status:'success', data:{url}}` — **falta `sessionId`** |
| Códigos | `201`, `400`, `401`, `404` | `201`, `400`, `401`, `500` |
| Persistencia | «este servicio persiste su referencia» (por eso es *State Creation*) | **No se persiste nada.** La sesión no se guarda; solo se devuelve la URL. Sin `sessionId` almacenado no hay trazabilidad de la sesión hasta el webhook |
| Identidad | `accountId` | `req.user.id` extraído de un JWT verificado localmente |

Exponer el Stripe Price ID en el contrato público filtra un detalle de
implementación de la pasarela de pago al cliente y hace imposible validar el
plan contra la tabla de precios del TFM.

### 🟡 `POST /v1/pricing/webhooks/stripe`

| Aspecto | Especificación | Implementación |
|---|---|---|
| Ruta | `/v1/pricing/webhooks/stripe` | `/api/v1/pricing/webhooks/stripe` |
| Firma sobre cuerpo crudo | Obligatorio | ✅ **Correcto**: `express.raw()` montado antes de `express.json()` (`app.js`) |
| Idempotencia | Colección `idempotence_keys` | ✅ Implementada, pero la colección real es `idempotencykeys` (Mongoose sobre `IdempotencyKey`), no `idempotence_keys` ni `snake_case` |
| Código firma inválida | `401` | `400` (`stripe.service.js`, `constructWebhookEvent`) |
| Publicación de `subscription.plan_changed` | «Es el punto donde se detecta que un cambio de plan se ha hecho efectivo y, en consecuencia, donde se publica `subscription.plan_changed`» | **No se publica nada.** El dispatcher solo maneja `checkout.session.completed`, `customer.subscription.deleted` e `invoice.payment_failed` |
| `customer.subscription.updated` | Necesario para detectar el cambio de plan efectivo | **No se maneja**: los cambios de plan son invisibles para el servicio |

La ausencia de `subscription.plan_changed` es bloqueante: sin ese evento no hay
congelación ni descongelación de galerías en `fr-commercial`, que es una de las
decisiones de diseño centrales del TFM.

### Modelos de datos frente al contrato

| Severidad | Modelo | Discrepancia |
|---|---|---|
| 🔴 | `SubscriptionRecord` | Clave por `userId`, no `accountId` (`CLAUDE.md` §3) |
| 🔴 | `SubscriptionRecord` | **No persiste `planId` ni `addOns`.** El comentario dice que los límites «son propiedad de la plataforma SPACE y viajan en el Pricing Token», pero **SPACE no está integrado en ninguna parte del proyecto** (no hay dependencia, ni cliente, ni token). El derecho de la cuenta no está en ningún sitio, luego `GET /subscription/status` es hoy irrealizable |
| 🟡 | `SubscriptionRecord.status` | Enum de Stripe en crudo (`trialing`, `unpaid`, `incomplete`, `incomplete_expired`). El contrato define `active`, `past_due`, `canceled`, **`pending_downgrade`**. `pending_downgrade` no es representable, luego el flujo de reducción al cierre de periodo (y el campo `pendingPlan`) no se puede modelar |
| 🟡 | `UsageLog` | Solo tiene `userId`, `endpoint`, `timestamp`, `metadata`. **Faltan las dimensiones obligatorias**: unidades consumidas, `channel` y `model`. Los desgloses `byChannel` y `byModel` de `GET /usage` no se pueden construir |
| 🟡 | `UsageLog` | TTL fijo de 90 días. La retención por plan es 7/90/365 días: **la retención de 365 días del plan Business es imposible**, y la de 7 días del Free no se aplica |
| 🟡 | Ninguno | `indexedFaces` es una **métrica de estado**, no acumulativa. No existe campo ni colección donde alojarla; `GET /usage` la declara obligatoria |
| 🟢 | `UsageLog` | Nadie escribe en esta colección: no hay consumidor de eventos de consumo ni ningún punto que la alimente |

## 2.4 Reglas de CLAUDE.md que el código incumple

| Severidad | Regla | Incumplimiento |
|---|---|---|
| 🔴 | §2 Versionado | `/api/v1/pricing` en lugar de `/v1/pricing` |
| 🔴 | §3 Propiedad: `accountId` | `SubscriptionRecord.userId`, `UsageLog.userId`, `client_reference_id: userId`. `accountId` no aparece en el servicio |
| 🔴 | Eventos Kafka | No hay dependencia de Kafka. No se publica `subscription.plan_changed` ni se consume `account.deleted`. Issue 20 sin empezar |
| 🔴 | Stack: «Feature toggling: SPACE» | SPACE aparece solo en comentarios. No hay integración |
| 🟡 | §4 Cabeceras de Kong | `auth.middleware.js` **verifica el JWT por su cuenta** con `config.jwtSecret`, en vez de confiar en `X-Account-Id`/`X-Role` de la pasarela. Obliga a **compartir `JWT_SECRET` entre `auth` y `pricing`** (mismo valor literal en ambos `.env`), lo que acopla los dos servicios y hace que una rotación en `auth` rompa `pricing` en silencio |
| 🟡 | §4 Canal | La dimensión `channel` no se deriva ni se almacena en ningún punto. `GET /usage` la exige |
| 🟡 | §6 Error Report con `code` | `errorHandler.js` devuelve `{status, message}`. Los códigos del contrato (`QUANTITY_NOT_APPLICABLE`, `ADDON_MAX_QUANTITY_EXCEEDED`, `HISTORY_NOT_IN_PLAN`, `FEATURE_NOT_IN_PLAN`…) no existen |
| 🟡 | §6 `application/problem+json` | Todos los errores salen como `application/json` |
| 🟡 | §7 Nomenclatura de colecciones | `subscriptionrecords`, `usagelogs`, `idempotencykeys`. Deberían ser plurales en `snake_case` |
| 🟡 | «Solo alcanzables a través de la pasarela» | `docker-compose.yml` publica el puerto del servicio y MongoDB `27017:27017` |
| 🟡 | Add-ons como `{addOnId, quantity}` | Estructura inexistente: no hay complementos |
| 🟢 | §5 Patrones | La documentación del contrato dice que `create-session` escribe estado; la implementación no persiste nada, luego hoy es de facto una `COMPUTATION FUNCTION`. El patrón declarado y el comportamiento real no coinciden |
| 🟢 | Nomenclatura de entidad | `SubscriptionRecord` frente a la entidad de dominio `Subscription` de la especificación |
| 🟢 | Pesos y unidades | El cálculo de unidades vive en `fr-commercial`, correcto, pero `pricing` no tiene ningún punto de entrada para recibirlas |

## 2.5 Cobertura de tests actual

Marco: Jest + `supertest` + `mongodb-memory-server`. 6 ficheros, 35 casos.

> **Corrección (sesión 4).** Este apartado decía «~28 casos» con tres recuentos
> sin rellenar. El número exacto, tomado de la salida en JSON del ejecutor, es
> **35 en 6 ficheros** en la fecha de esta auditoría. La suite que se retiró a
> `tests/legacy/` en la sesión 4 tenía **37 en 7**: la diferencia es
> `tests/securityHeaders.test.js`, con 2 casos, añadido después ---en la sesión
> 3, al acotar la exención de CSP--- y por tanto ausente de esta foto. De ahí
> que `ESTADO.md` hablara de 35 y el cierre de la sesión 4 hable de 37: ambas
> cifras eran correctas en su momento.

| Fichero | Casos | Cubre |
|---|---:|---|
| `tests/models/subscriptionRecord.test.js` | 10 | Validaciones del esquema |
| `tests/controllers/checkout.controller.test.js` | 6 | Ruta de creación de sesión |
| `tests/models/usageLog.test.js` | 6 | Validaciones del esquema |
| `tests/controllers/webhook.controller.test.js` | 5 | Ruta del webhook |
| `tests/models/idempotencyKey.test.js` | 5 | Validaciones del esquema |
| `tests/health.test.js` | 3 | Sonda |

**Sin ningún test:**

- Los 7 endpoints no implementados, evidentemente.
- 🟡 **`src/services/webhook.service.js` tiene cobertura cero.** El test del
  controlador hace `jest.mock('../../src/services/webhook.service')`: se
  verifica que el controlador devuelve `200`, no que la idempotencia funcione,
  ni que `handleCheckoutCompleted` cree el `SubscriptionRecord`, ni que
  `handleInvoicePaymentFailed` marque `past_due`. **Toda la lógica de negocio
  del servicio está mockeada en sus propios tests.**
- 🟡 `src/services/stripe.service.js`: también mockeado por completo en ambos
  ficheros de test. La validación de firma sobre cuerpo crudo —el punto
  delicado del webhook— nunca se ejerce de verdad.
- `src/middlewares/auth.middleware.js`: probado solo indirectamente, con
  `jsonwebtoken` mockeado.

`jest.config.js` tampoco define `coverageThreshold`.

Igual que en `auth`, `CLAUDE.md` exige tests de contrato mínimos antes de
refactorizar `pricing`. **Los tests existentes fijan el contrato equivocado**
(rutas `/api/v1/`, `planId` como Stripe Price ID, respuesta sin `sessionId`) y
no cubren nada de la lógica que hay que conservar.

---

# 3. api-gateway

Referencia: reglas de pasarela de `CLAUDE.md` (§1, §2, §4) y los esquemas de
seguridad de `auth.yaml` / `pricing.yaml`. No hay una especificación OpenAPI
propia de la pasarela.

## 3.1 Rutas configuradas frente a las esperadas

| Severidad | Elemento | Estado |
|---|---|---|
| 🔴 Bloqueante | `auth-route` → `/api/v1/auth` | Debería ser `/v1/auth` (`kong.yml`). Con `strip_path: false`, corregir el servicio sin corregir Kong lo deja inalcanzable, y viceversa |
| 🔴 Bloqueante | `pricing-route` → `/api/v1/pricing` | Debería ser `/v1/pricing` |
| 🔴 Bloqueante | `/api/v1/auth/internal/validate-api-key` alcanzable desde fuera | El contrato dice explícitamente: «**Endpoint de acceso exclusivamente interno. No debe exponerse a través de la pasarela.**» La ruta `auth-route` casa con el prefijo `/api/v1/auth` y **no excluye la subruta interna**. Lo único que la protege es el secreto compartido `x-internal-secret`, presente en tres ficheros `.env` |
| 🟡 Importante | `commercial-api` comentado | Además, la ruta prevista es `/api/v1/commercial`; debería ser `/v1/fr/commercial` |
| 🟢 Menor | `research-api` comentado | Pertenece a la **solución de investigación, que `CLAUDE.md` declara trabajo futuro y prohíbe implementar**. Debería eliminarse del fichero, no dejarse comentada |

## 3.2 Plugin `space-auth`: contrato

| Severidad | Hallazgo | Detalle |
|---|---|---|
| 🔴 Bloqueante | **El plugin no puede funcionar contra el `auth` actual** | `handler.lua` exige `auth_body.pricing_token` y hace `kong.response.exit(500, …)` si falta. `auth` devuelve `{status, data:{user}}` y **nunca ha devuelto `pricing_token`**. Toda petición que atravesara el plugin terminaría en `500` |
| 🔴 Bloqueante | **El plugin no está aplicado a ninguna ruta activa** | Solo aparece en los bloques comentados de `commercial-api` y `research-api`. `auth-route` y `pricing-route` no lo llevan: **hoy la pasarela no autentica absolutamente nada** |
| 🔴 Bloqueante | **No hay validación de JWT: el canal web no puede pasar** | `handler.lua` empieza exigiendo `X-API-Key` y responde `401` si falta. `CLAUDE.md` §1 exige **dos** esquemas de seguridad sobre los mismos endpoints (JWT = web, API KEY = api). El canal web está estructuralmente excluido |
| 🔴 Bloqueante | **Cabeceras propagadas incorrectas** | El plugin inyecta `X-User-Id`, `X-Space-Limits`, `X-Space-Features`. `CLAUDE.md` §4 exige `X-Account-Id`, `X-Auth-Channel` y `X-Role`. **Ninguna de las tres se establece.** `fr-commercial` no recibirá la identidad que necesita |
| 🔴 Bloqueante | **No se sanean las cabeceras de entrada** | `CLAUDE.md` §4: «Kong DEBE borrar o sobrescribir estas cabeceras si vienen en la petición original. Si no, cualquiera suplanta otra cuenta enviándolas a mano». El plugin **nunca limpia** `X-Account-Id`, `X-Auth-Channel` ni `X-Role`. Además `X-Space-Limits` y `X-Space-Features` solo se escriben `if payload.limits`/`if payload.features`: si el token no las trae, **una cabecera enviada por el cliente pasa intacta al backend** |
| 🟡 Importante | Sin caché de validación | El contrato pide caché de ~60 s del resultado de `validate-key`. El plugin hace una llamada HTTP a `auth` **en cada petición**: `auth` se convierte en punto único de fallo y en cuello de botella de latencia |
| 🟡 Importante | Ruta interna acoplada al contrato antiguo | `schema.lua`, `auth_endpoint` por defecto: `http://auth-service:3000/api/v1/auth/internal/validate-api-key`, con la clave **en el cuerpo**. Al corregir el Issue 7 (`POST /v1/auth/validate-key`, clave en `X-API-Key`) hay que cambiar plugin y esquema a la vez |
| 🟡 Importante | Pérdida de la distinción 401/403 | `if res.status ~= 200 then exit(401)`: la respuesta `403` de cuenta suspendida se convierte en `401`. `CLAUDE.md` §6 separa ambos significados |
| 🟡 Importante | SPACE no integrado | El plugin verifica la firma de un «Pricing Token de SPACE» con `jwt_secret .. jwt_salt`, secretos que en la configuración comentada son literales `"pricing_secret_placeholder"` / `"pricing_salt_placeholder"`. No hay ninguna instancia de SPACE en el proyecto |
| 🟢 Menor | `local jwt_obj, err = jwt_decoder:new(token)` redeclara `err` | Ya declarado en el `request_uri`. Funciona por sombreado, pero es fuente de errores |
| 🟢 Menor | Sin control de `apiChannel` | El plugin no comprueba que el plan permita el canal API (el plan Free es solo web). `CLAUDE.md` §1: «la disponibilidad del canal API es una feature del plan, **evaluada en la pasarela**» |

## 3.3 Configuración de Kong

| Severidad | Hallazgo | Detalle |
|---|---|---|
| 🟡 Importante | Límite de tasa único y global | `rate-limiting` con `minute: 100` para todo el mundo. El pricing exige límites **por segundo, por plan y separando inferencia de gestión** (3/10, 5/50, 20/200). Ni la unidad temporal, ni la segmentación por plan, ni la distinción inferencia/gestión existen |
| 🟡 Importante | `policy: local` | El contador vive en memoria de cada nodo: con más de una réplica de Kong el límite efectivo se multiplica por el número de réplicas. No es válido para un despliegue en Kubernetes |
| 🟡 Importante | CORS `origins: ["*"]` con `credentials: true` | Combinación inválida por especificación y rechazada por los navegadores; además es una configuración permisiva para un servicio de datos biométricos |
| 🟡 Importante | API de administración de Kong publicada al host | `docker-compose.yml` expone `8001` y `8444`. Cualquiera con acceso al host puede reconfigurar la pasarela |
| 🟢 Menor | Redes Docker incompatibles | Kong vive en `tfm-network`; `auth-microservice` crea `auth-network` y `pricing-microservice` la suya. **Kong no puede resolver `auth-service` ni `pricing-service`**: el conjunto no arranca como sistema sin una red compartida |
| 🟢 Menor | Sin plugin `request-transformer` | Sanear cabeceras podría resolverse declarativamente además de en el plugin, como defensa en profundidad |

## 3.4 Cobertura de tests actual

**Cero.** No existe ningún test en `api-gateway/`: ni pruebas unitarias de Lua
(`busted`), ni tests de integración que arranquen Kong y verifiquen el
enrutado, la propagación de cabeceras o —lo más importante— **el saneado de
`X-Account-Id` enviada por el cliente**.

Es la ausencia más grave del proyecto en materia de pruebas: el saneado de
cabeceras es un control de seguridad cuyo fallo es silencioso. Sin un test que
envíe `X-Account-Id: <cuenta ajena>` y compruebe que el backend no la recibe,
una regresión futura pasaría inadvertida.

---

# 4. Discrepancias entre servicios

Desajustes en los que **lo que un servicio produce no encaja con lo que otro
espera**.

## 🔴 Bloqueantes

### D1. Kong espera `pricing_token`; `auth` devuelve `{status, data:{user}}`

- **Produce** `auth-microservice/src/controllers/auth.controller.js`,
  `validateApiKey`: `{status:'success', data:{user:{id, email, role}}}`.
- **Espera** `api-gateway/plugins/space-auth/handler.lua`:
  `auth_body.pricing_token`.
- **Consecuencia**: el plugin sale con `500 "Error en la propagación de
  identidad"` en **todas** las peticiones. El sistema integrado no funciona
  hoy. Solo pasa desapercibido porque el plugin no está aplicado a ninguna ruta
  activa.

### D2. `auth` no devuelve `accountId` ni `status`; Kong no tiene identidad que propagar

- **Produce** `auth`: `{user:{id, email, role}}`, sin `accountId` ni `status`.
- **Espera** el contrato `auth.yaml`: `{valid, accountId, status, role?}`.
- **Consecuencia**: es la discrepancia bloqueante del Issue 7.
  `fr-commercial` no podrá determinar la propiedad de las galerías. Todo el
  modelo de dominio se vincula a `accountId` y **ese identificador no existe en
  ningún punto de la cadena**.

### D3. Kong propaga `X-User-Id`; el resto del sistema espera `X-Account-Id`

- **Produce** el plugin: `X-User-Id`, `X-Space-Limits`, `X-Space-Features`.
- **Espera** `CLAUDE.md` §4 y `fr-commercial`: `X-Account-Id`, `X-Auth-Channel`,
  `X-Role`.
- **Consecuencia**: ningún consumidor recibe lo que necesita. Además nadie
  consume `X-User-Id` hoy: `pricing` lo ignora y revalida el JWT por su cuenta.

### D4. `auth` no publica `account.deleted`; `pricing` no lo consume

- **Produce** `auth`: `DELETE /account` borra el documento y **no emite nada**.
- **Espera** `pricing.yaml`: «La cancelación inmediata se reserva al consumo del
  evento `account.deleted`».
- **Consecuencia**: al borrar la cuenta, la suscripción de Stripe **sigue
  cobrando**. Y cuando exista `fr-commercial`, las plantillas biométricas —datos
  personales de categoría especial— sobrevivirían al ejercicio del derecho de
  supresión. Riesgo legal, no solo técnico.

### D5. `pricing` no publica `subscription.plan_changed`

- **Produce** `pricing`: nada. El webhook no maneja `customer.subscription.updated`
  y no hay productor de Kafka.
- **Espera** `fr-commercial`: congelar y descongelar galerías.
- **Consecuencia**: la congelación de galerías —decisión de diseño central del
  TFM— no puede ocurrir en ninguno de los dos sentidos.

### D6. `UsageLog` no puede recibir los eventos de consumo de `fr-commercial`

- **Produce** `fr-commercial` (Issue 15): unidades con dimensiones cuenta,
  canal, modelo y endpoint.
- **Espera** `UsageLog`: solo `userId`, `endpoint`, `metadata`. Sin campo de
  unidades, sin `channel`, sin `model`.
- **Consecuencia**: los eventos de consumo no tienen dónde aterrizar.
  `byChannel` y `byModel` de `GET /usage` son irrealizables. Bloquea los
  Issues 15 y 19.

### D7. Nadie publica los límites del plan

- **Produce**: nada. `SubscriptionRecord` no guarda `planId` ni `addOns`; SPACE
  no está integrado; `GET /subscription/status` no existe.
- **Esperan**: Kong (para `apiChannel` y el límite de tasa por plan),
  `fr-commercial` (para `MODEL_NOT_IN_PLAN`, `FEATURE_NOT_IN_PLAN`,
  `QUOTA_EXCEEDED`, umbral configurable, 1:N, webhooks) y el frontend.
- **Consecuencia**: **la mitad económica del sistema no tiene fuente de datos.**
  El pricing como artefacto de diseño —el objeto declarado del TFM— no está
  representado en ningún esquema persistente.

## 🟡 Importantes

### D8. `JWT_SECRET` compartido literalmente entre `auth` y `pricing`

`pricing/src/middlewares/auth.middleware.js` verifica el JWT con
`config.jwtSecret`, cuyo valor es **el mismo literal** que en
`auth-microservice/.env`. Efectos: (a) acopla dos servicios que deberían
comunicarse solo por contrato; (b) una rotación del secreto en `auth` rompe
`pricing` sin aviso; (c) contradice `CLAUDE.md` §4, donde la validación del JWT
es responsabilidad de la pasarela; (d) `pricing` es plenamente operable sin
pasar por Kong. Lo mismo aplica a `INTERNAL_API_SECRET`, replicado en tres
ficheros `.env`, con **valor por defecto público** codificado en
`auth/src/config/index.js`.

### D9. Vocabulario de roles incompatible en tres capas

`auth` emite `user | admin | researcher`; `CLAUDE.md` §4 define
`X-Role: CUSTOMER | ADMIN`; `pricing` lee `decoded.role` y no lo usa para nada.
Cualquier comprobación futura de `ADMIN` fallará en silencio, porque el valor
que llega es `admin`. Y `researcher` pertenece a una solución que el proyecto
declara no implementar.

### D10. Identificador de plan incompatible

`pricing` recibe y usa el **Stripe Price ID** (`price_xxx`) como `planId`;
`pricing.yaml`, `CLAUDE.md` y la tabla de precios usan `free | pro | business`.
El frontend no puede pedir un plan por su nombre y `fr-commercial` no puede
derivar límites a partir de lo que `pricing` almacena.

### D11. Dos convenciones de ruta conviviendo

Todo el código usa `/api/v1/...`; las tres especificaciones usan `/v1/...`
(`/v1/auth`, `/v1/pricing`, `/v1/fr/commercial`). Como `fr-commercial` es
terreno nuevo y se escribirá contra la especificación, nacerá en `/v1/` y
**convivirá con dos servicios en `/api/v1/`**, con una Kong configurada para el
prefijo antiguo. La corrección debe ser simultánea en los tres repositorios.

## 🟢 Menores

### D12. Dos fuentes de verdad de la documentación

`auth` y `pricing` generan Swagger UI desde anotaciones `@swagger`/`@openapi`
incrustadas en el código, que describen el contrato **actual y erróneo**.
Conviven con `openapi/*.yaml`, que `CLAUDE.md` designa fuente de verdad. Un
lector de la documentación publicada verá el contrato equivocado. Conviene
decidir explícitamente: o se genera desde el YAML, o se elimina el Swagger
embebido, o se añade una comprobación de diferencias en CI —como la que
`CLAUDE.md` ya prevé para FastAPI.

---

# 5. Orden de ataque sugerido

Derivado de las dependencias entre hallazgos, no de la numeración de los issues.

1. **Tests de contrato mínimos** para `register`, `login`, `validate-key`,
   `create-session` y el webhook de Stripe, escritos **contra el YAML**
   (fallarán al principio). `CLAUDE.md` lo exige antes de tocar `auth` o
   `pricing`, y hoy esa precondición no se cumple.
2. **D2 / Issue 7**: `POST /v1/auth/validate-key` con `accountId` y `status`.
   Desbloquea todo lo demás.
3. **Escalada de privilegios en `register`** y **enumeración en
   `forgot-password`**: son fallos de seguridad explotables hoy, baratos de
   corregir y ya cubiertos por el contrato.
4. **Prefijo `/v1/`** simultáneamente en `auth`, `pricing` y `kong.yml`.
5. **D1 / D3 / Issue 10**: reescribir `space-auth` — doble credencial, caché,
   `X-Account-Id`/`X-Auth-Channel`/`X-Role` y **saneado** de esas cabeceras,
   con un test de integración que verifique el saneado.
6. **`accountId` en lugar de `userId`** en ambos microservicios, antes de que
   `fr-commercial` se construya sobre el nombre equivocado.
7. **Modelo de derecho en `pricing`** (`planId`, `addOns`, `limits`) y
   `GET /subscription/status`: sin eso, D7 bloquea la Fase 2 completa.
8. **Kafka** (Issue 20) y el rediseño de `UsageLog` con las dimensiones
   `units`, `channel` y `model`.

## Anexo: higiene de secretos

Fuera del alcance estricto pero detectado durante la auditoría, en la raíz del
workspace:

- `user-example-apikey` contiene una API KEY real y **no figura en
  `.gitignore`**, a diferencia de `resend-apikey.txt`, `stripe-secret-key.txt` y
  `stripe-webhook-secret.txt`, que sí están excluidos.
- `auth-microservice/.env` y `pricing-microservice/.env` contienen claves
  operativas reales (Resend, Stripe en modo test, `JWT_SECRET`,
  `INTERNAL_API_SECRET`). Están correctamente excluidos por los `.gitignore` de
  cada servicio.
- `auth-microservice/src/config/index.js` codifica el valor por defecto
  `'dev_internal_secret_key_789'` para `INTERNAL_API_SECRET`, en contra de la
  regla «Cero secretos en el código». Debería fallar al arrancar si la variable
  no está definida.

> **Corrección (sesión 5).** El primer punto de este anexo repite el error
> corregido en §1.4: el `.gitignore` de la raíz del workspace no pertenece a
> ningún repositorio, así que ni `user-example-apikey` quedaba «sin excluir» ni
> los otros tres estaban «excluidos» por él. Ninguno de los cuatro es
> committeable a ninguno de los repositorios, por estar fuera de todos los
> árboles de trabajo. El segundo punto, en cambio, es exacto y sigue siéndolo:
> `auth-microservice/.env` y `pricing-microservice/.env` sí están cubiertos por
> el `.gitignore` de su propio repositorio, verificado con `git check-ignore`.
>
> El fichero `user-example-apikey` se borró del workspace en la sesión 5. De sus
> dos claves, la primera ya no validaba y **la segunda seguía viva**, ligada a la
> cuenta `user@example.com`. Que la clave estuviera viva en el disco era cierto
> en la fecha de esta auditoría y no se reescribe: es el hallazgo, y se cierra
> en los issues, no aquí.
