# CLAUDE.md — TFM: SaaS multicanal de reconocimiento facial

Convenciones de ingeniería del proyecto y decisiones de diseño acordadas en el
documento de diseño (DoD) y en las especificaciones OpenAPI.

## Visión general

Servicio SaaS de reconocimiento facial con **dos canales de consumo** (web y
API), gobernado por un pricing explícito. El objeto del TFM no son las
capacidades de reconocimiento facial ---se apoyan en modelos preentrenados---
sino **el pricing como artefacto de diseño**: cómo se derivan sus límites de la
capacidad medida y cómo condiciona la arquitectura.

> **La solución de investigación (ONNX, Triton, S3, evaluación de modelos de
> terceros) es TRABAJO FUTURO y NO se implementa.** Está documentada en la DoD
> como línea de evolución. No generes código para ella.

## Fuente de verdad

La especificación canónica de cada servicio vive **dentro de su repositorio**:

| Contrato | Fichero canónico |
|---|---|
| Auth | `auth-microservice/openapi/auth.yaml` |
| Pricing | `pricing-microservice/openapi/pricing.yaml` |
| FR Commercial | `fr-commercial-microservice/openapi/fr-commercial.yaml` |

Es la única copia versionada, se revisa en el mismo diff que el código que la
implementa y el `COPY . .` de los `Dockerfile` la mete en la imagen.

Lo que hay en `openapi/` del workspace son **enlaces simbólicos de
conveniencia** hacia esos ficheros, para que la ruta corta siga funcionando sin
que existan dos copias que puedan divergir. **El contrato se edita siempre por
su ruta canónica, nunca a través del enlace**, y la regla vale igual para las
personas que para los agentes: un editor que guarda sustituyendo el fichero
convierte el enlace en una copia sin avisar. Pasó con `fr-commercial.yaml`,
editado a mano por la ruta de la raíz el 01/10, que fue un fichero real hasta
el 06/10 (detectado en #34). Se comprueba con `ls -l openapi/`: los tres
tienen que ser enlaces.

Si el código y la especificación discrepan, **se corrige el código** ---o se
pregunta. Toda modificación de contrato empieza por la especificación.

---

## Stack — no desviarse

| Componente | Tecnología |
|---|---|
| Pasarela | Kong (con plugin a medida para validación de credenciales) |
| Microservicios Node.js | Express/Fastify, seguir `node-template` |
| Microservicios Python | FastAPI, seguir `python-template` |
| Base de datos | MongoDB — **una BD por microservicio**, nunca compartida |
| Almacén efímero | Redis |
| Mensajería | Kafka |
| Pasarela de pago | Stripe |
| Feature toggling | SPACE |
| Frontend | React + Vite + Tailwind + Shadcn/UI |
| Infraestructura | Docker + Kubernetes |

## Microservicios

| Servicio | Stack | Responsabilidad |
|---|---|---|
| **Kong** | Kong | Punto de entrada único. Validación de credenciales, rate limit, propagación de metadatos |
| **Auth** | Node.js + MongoDB | Cuentas, credenciales de ambos canales, ciclo de vida de la cuenta |
| **Pricing** | Node.js + MongoDB | Suscripciones, Stripe, SPACE, consumo acumulado |
| **FR Commercial** | Python/FastAPI + MongoDB + Redis | Galerías, identidades, rostros e inferencia |
| **Frontend** | React | Evaluación **y panel de administración** |

> **FR Commercial SÍ tiene base de datos propia.** Persiste galerías,
> identidades, rostros, puntos de notificación y sus entregas. La v1 de este
> fichero decía lo contrario.

## Estructura de directorios (respetar siempre)

```
/src/api o /src/routes   → endpoints y enrutamiento
/src/controllers         → lógica de gestión de peticiones HTTP
/src/core o /src/utils   → configuración, middlewares, excepciones
/src/models              → esquemas MongoDB (Node) · modelos de la API (fr)
/src/documents           → esquemas MongoDB (fr)
/tests                   → pruebas automatizadas
```

**En `fr-commercial`, `src/models` son los modelos Pydantic de la API**,
cerrados con `extra="forbid"`, y la persistencia vive en `src/documents`, cada
fichero con su `COLLECTION`, sus `INDEXES` y sus `CONFLICTS`. Se decidió así en
#34 para no mover los modelos de la API, a los que remiten los comentarios de
#36, #37, #40 y #44.

### Convenciones de Express

**`/docs` va exento de la política de seguridad de contenido de `helmet`, en
todos los servicios.** La CSP por defecto declara `default-src 'self'` y ningún
`connect-src`, de modo que el navegador solo permite peticiones al mismo origen
que sirve la página. Swagger UI apunta a **la pasarela**, que es otro origen, y
sin la exención cada «Try it out» muere **dentro del navegador**, antes de
emitir nada:

```js
app.use((req, res, next) => {
  if (req.path.startsWith('/docs')) {
    helmet({ contentSecurityPolicy: false, crossOriginEmbedderPolicy: false })(req, res, next);
  } else {
    helmet()(req, res, next);
  }
});
```

El relajo se acota a `/docs`; el resto de rutas conserva las cabeceras
completas, y hay un test por servicio que lo comprueba en los dos sentidos ---
que `/docs` sale sin la cabecera y que `/health` sale con ella---. Sin el
segundo, nada impide que la exención se desborde a todo el servicio.

El síntoma es engañoso y conviene reconocerlo: Swagger informa de **«Failed to
fetch»** y enumera CORS entre las causas posibles. **No es CORS.** La forma de
distinguirlo es mirar el registro de acceso del servidor: si la petición no
aparece ahí ---ni siquiera el `OPTIONS` del preflight---, nunca salió del
navegador y el problema no está en el servidor.

---

## Reglas que no se negocian

### 1. El canal NO va en la URL

Ambos canales usan **los mismos endpoints**. El canal se manifiesta solo en:

- **Autenticación**: dos security schemes sobre el mismo recurso
  (JWT = web, API KEY = api).
- **Pricing**: la disponibilidad del canal API es una feature del plan,
  evaluada en la pasarela.
- **Analítica**: dimensión `channel` en los eventos de consumo, derivada del
  tipo de credencial validada.

Criterio: se separan endpoints por canal **solo si el contrato difiere**. En
este proyecto nunca difiere (el contrato de API es como mucho un superconjunto
del de web, con campos opcionales extra).

❌ `/fr/commercial/frontend/verification` y `/fr/commercial/api/verification`
✅ `/v1/fr/commercial/verification` con dos security schemes

### 2. Versionado de rutas

Convención única: **`/v1/{servicio}/...`**

```
/v1/auth/register
/v1/pricing/subscription/status
/v1/fr/commercial/galleries/{galleryId}
```

### 3. Propiedad de los recursos

Todo se vincula a **`accountId`**, nunca a `userId`. Hoy la relación cuenta-usuario
es 1:1, pero modelarlo así permite cuentas multiusuario sin migración futura.

`fr-commercial` **no modela la entidad Account**: recibe el `accountId` ya
validado en cabecera desde Kong.

Roles: **`ADMIN`** y **`CUSTOMER`**. (`RESEARCHER` pertenece a la solución de
investigación, que no se implementa.)

### 4. Cabeceras que propaga Kong

```
X-Account-Id     identificador de la cuenta
X-Auth-Channel   "frontend" | "api"
X-Role           "CUSTOMER" | "ADMIN"
```

**Kong DEBE borrar o sobrescribir estas cabeceras si vienen en la petición
original.** Si no, cualquiera suplanta otra cuenta enviándolas a mano. Los
microservicios solo son alcanzables a través de la pasarela.

Cómo se impone, porque el saneado es propiedad de la pasarela y no de un plugin
concreto:

| Ruta | Mecanismo |
|---|---|
| Con `space-auth` | El plugin llama a `clear_header()` sobre las tres **incondicionalmente**, antes de cualquier bifurcación, de modo que ningún camino de salida ---tampoco los que terminan en error--- puede dejar pasar la del cliente |
| Sin `space-auth` (operaciones públicas de `auth`, receptor de Stripe) | Plugin `request-transformer` declarativo con `remove.headers` sobre las tres |

**Toda ruta que llegue a un backend tiene que sanearlas**, la autentique quien
la autentique. Escribirlas solo cuando hay valor que escribir es el error
concreto que tenía la versión anterior del plugin: si el dato faltaba, la
cabecera del cliente pasaba intacta.

`Authorization` y `X-API-Key` **no se tocan**: son credenciales del cliente, no
identidad ya resuelta, y el servicio de destino puede necesitarlas.

### 5. Patrones de responsabilidad (Zimmermann et al.)

El criterio es **el acceso al estado del servidor**, no el verbo HTTP ni la
forma de la respuesta:

| Patrón | Lee estado | Escribe estado |
|---|---|---|
| `COMPUTATION FUNCTION` | No | No |
| `RETRIEVAL OPERATION` | Sí | No |
| `STATE CREATION OPERATION` | No | Sí |
| `STATE TRANSITION OPERATION` | Sí | Sí |

> ⚠️ La regla «POST → State Creation, GET → Retrieval» de la v1 **es
> incorrecta**. Casos reales de este proyecto:
> - `POST /search` → `RETRIEVAL OPERATION` (es POST por el tamaño del payload)
> - `POST /auth/login` → `RETRIEVAL OPERATION` (lee la BBDD)
> - `POST /identities/{id}/verify` → `RETRIEVAL OPERATION` (depende de las
>   caras enroladas)
> - `POST /verification` con dos imágenes → `COMPUTATION FUNCTION`

### 6. Códigos de estado

- `201` en creación, devolviendo el recurso creado.
- `204` en borrado.
- `401` credencial ausente o inválida · `403` credencial válida sin permiso.
- `403` con código en el cuerpo (patrón **Error Report**): `QUOTA_EXCEEDED`,
  `GALLERY_FROZEN_MODEL_NOT_IN_PLAN`, `FEATURE_NOT_IN_PLAN`,
  `MODEL_NOT_IN_PLAN`.
- `409` con código en el cuerpo: `LAST_FACE_OF_IDENTITY`,
  `GALLERY_NAME_ALREADY_EXISTS`, `EXTERNAL_ID_ALREADY_EXISTS`. **Todo índice
  único lleva su `409` declarado en cada operación que escribe sus campos, y
  se declara antes de crear el índice**: sin él, un valor repetido es un error
  que el contrato no declara. Lo vigila `test_uniqueness.py`, que cruza
  `INDEXES` con los cuerpos de petición del contrato (#34).
- `429` **solo** para rate limit: es operacional, no económico. La cuota
  agotada es `403`.
- `410 Gone` para retos de liveness caducados.

#### Qué se declara (issue #68, decidido)

**Se declara lo que es una decisión, no lo que es un fallo.**

- Toda operación **alcanzable a través de la pasarela** declara `429`.
- Toda operación con `security` declara además `401`.
- Toda operación que admite `apiKeyAuth` declara además `503` y `403`.
- Se declara `403` también en las operaciones que pueden denegarse por plan,
  cuota o estado del recurso, con los códigos de dominio de la lista de arriba.
- **No** se declaran las respuestas accidentales (`500`, `502`, `504`) ni las
  de plataforma (`404` de ruta inexistente, `413`, *preflight* de CORS).
- Las respuestas originadas en la pasarela cumplen `ErrorReport` igual que las
  del servicio.

El `403 ACCOUNT_SUSPENDED` y el `503 AUTH_UNAVAILABLE` los emite la pasarela y
**solo pueden darse en el canal de API**: dependen de validar la API KEY contra
`auth`, mientras que el JWT del canal web se verifica por firma sin salir de la
pasarela. OpenAPI no sabe atar una respuesta a un esquema de seguridad concreto,
de modo que esa restricción se escribe en prosa dentro de la `description` de la
respuesta. Se usan `$ref` a componentes compartidos; nunca se duplica la
descripción por operación.

Lo que determina el `429` **no es que la operación esté protegida, sino que la
pasarela la alcance**: el limitador es global y no mira credenciales. Por eso lo
declaran también las rutas públicas ---`register`, `login`, la recuperación de
contraseña y el receptor de eventos de Stripe---, donde además cuenta desde la
primera petición.

`POST /v1/auth/validate-key` es la única operación fuera de la regla: no es
alcanzable a través de la pasarela ---es ella quien la corta con un `404`--- y
su `apiKeyAuth` es la clave *a validar*, no una credencial de acceso. El motivo
se detalla en la `description` de la propia operación, no solo en la cabecera
del fichero.

> ⚠️ **Excepción conocida, y es la que queda abierta.** El `429` lo emite el
> plugin `rate-limiting` de Kong con un cuerpo `{message, request_id}` **sin
> `code`**, de modo que hoy no cumple `ErrorReport`. Se declara `ErrorReport`
> igualmente ---es el contrato que debe cumplir--- y la divergencia se sigue en
> el issue #82. `request_id` es un detalle de Kong y deliberadamente **no** se
> ha metido en el esquema de los tres contratos.
>
> El alcance del `429` tampoco es uniforme: `space-auth` tiene `PRIORITY 1000` y
> el limitador 910, así que en rutas protegidas el `429` solo alcanza a un
> llamante **ya autenticado**, mientras que en las rutas públicas de `auth`
> cuenta desde la primera petición. Issue #83.

### 7. Nomenclatura

- Colecciones MongoDB: plural, `snake_case` → `webhook_endpoints`
- Entidades en diagramas/clases: singular, `PascalCase` → `WebhookEndpoint`
- Rutas: sustantivos en plural, parámetros entre llaves → `{galleryId}`
- Nunca verbos en la ruta. Excepción justificada: `/search`, `/verify`,
  `/suspend` — acciones sin recurso propio.

---

## Modelo de dominio (FR Commercial)

```
Gallery   accountId, name, description, model(enum), status(enum),
          frozenReason(enum?), identityCount, faceCount, timestamps
          índices: {accountId, name} único (comparación exacta)

Identity  galleryId, fullName, externalId?, faceCount, timestamps
          índices: {galleryId}, {galleryId, externalId} único parcial
                   (solo si externalId es una cadena)

Face      identityId, galleryId, embedding(Binary), isBinarized,
          source, createdAt
          índices: {galleryId}  ← crítico para 1:N, {identityId}
```

**Criterio de denormalización**: se replica un campo solo si elimina una
consulta del camino caliente.
- ✅ `galleryId` en `Face`: permite resolver 1:N con una sola consulta
  proyectada, sin un `$in` de miles de identificadores.
- ❌ `accountId` en `Identity`: la galería hay que cargarla igualmente para
  comprobar `status` y `model`.

**Contadores desnormalizados** (`identityCount`, `faceCount`): el límite de
rostros indexados es de **estado**, no acumulativo — se evalúa consultando el
valor actual. Prever reconciliación periódica.

**Índices (medido en #34).** Un índice compuesto **disperso** no admite dos
documentos sin el campo opcional si el otro campo está siempre: los indexa
igual, como `null`. Por eso el de `externalId` es **parcial**
(`$type: "string"`), `externalId` se guarda ausente, nunca `null` ni vacío, y
el contrato le exige `minLength: 1`. El planificador no usa el parcial sin su
predicado, así que `{galleryId}` suelto **no** es redundante; `{accountId}` sí
lo era, porque lo sirve el prefijo del compuesto. Si un índice no se puede
crear, el servicio no arranca, y **cambiar la forma de un índice exige una
migración explícita**. Las operaciones escriben sin comprobar antes y
traducen `DuplicateKeyError` a `409` según el índice que saltó (`keyPattern`),
no solo por el código 11000.

**`faceCount` de la identidad empieza en 0**, y el `$inc` va después de
insertar el rostro: así el contador nunca dice más de lo que hay, y una
identidad huérfana tras una caída es la que tiene `faceCount` 0.

**Contadores y borrados sin transacciones (#36).** Ninguna alta deja un
contador por encima de lo que hay, y ninguna baja deja por encima el
`faceCount` de la identidad: `deleteFace` lo decrementa ANTES de borrar,
condicionado a `faceCount > 1` (de ahí sale el `409 LAST_FACE_OF_IDENTITY`,
no de una lectura previa). Los contadores de la galería pueden quedar cortos
en las altas y largos en las bajas; los corrige la reconciliación.
`deleteGallery` y `deleteIdentity` empiezan escribiendo una marca interna
(`deletingAt`); las altas filtran la marca al leer la cadena y al hacer el
`$inc`, y si el `$inc` no encuentra el documento deshacen lo insertado y
responden `404`. La marca nunca sale en una respuesta.

**Sin límite de rostros por identidad.** El límite económico ya existe: cada
rostro computa sobre la cuota.

---

## Embeddings

- **Se almacenan binarizados con LSSC**: 192 B frente a 2 KB en float32
  (9,6 MB frente a 100 MB en una galería de 50.000). Cada una de las 512 dimensiones del vector, sin normalizar, se asigna a uno de 4 intervalos con
  tres cortes fijos por modelo y se codifica en 3 bits como termómetro. Los
  cortes forman parte de la versión del modelo (`xs-v1`…): cambiarlos invalida
  los códigos guardados. Comparación por distancia de Hamming; la similitud
  es 1 − d/1536, en [0, 1], la misma en todas las operaciones que comparan.
- **Los pesos de EdgeFace son CC BY-NC-SA 4.0** (el código, BSD-3-Clause), y
  están entrenados con WebFace260M, de uso no comercial. Valen para el TFM; un
  despliegue comercial necesitaría otros pesos.
- El cuello de botella de 1:N **no es la inferencia, es la recuperación de
  vectores**. De ahí el término `f(n_galería)` en la fórmula de unidades.
- El modelo es **atributo inmutable de la galería**. Vectores de modelos
  distintos no son comparables.
- El enrolamiento desde vector exige un **token de procedencia** firmado
  (modelo + versión + hash del vector) emitido por `/extract-embeddings`.

---

## Pricing

| | Free | Pro (19 €) | Business (59 €) |
|---|---|---|---|
| Canal | Solo web | Web + API | Web + API |
| Rostros | 100 | 5.000 | 50.000 |
| Unidades/mes | 500 | 50.000 | 500.000 |
| Galerías | 1 | 5 | Ilimitadas |
| Rate (inferencia/gestión) | 3/10 | 5/50 | 20/200 |
| Modelos | `xs` | `xs`,`s` (+`base` con add-on) | `xs`,`s`,`base` |
| 1:N | ✗ | ✓ | ✓ |
| Umbral configurable | ✗ | ✓ | ✓ |
| Webhooks | ✗ | ✓ | ✓ |
| White-label widget | ✗ | ✗ | ✓ |

Add-ons: Liveness (booleano, 9 €, Pro+) · Modelo `base` (booleano, 29 €, Pro) ·
Pack de ampliación (**cuantitativo**, 5 €, máx. 3, +5.000 rostros y
+25.000 unidades).

Los cuantitativos requieren `quantity` y devuelven `409` al superar el máximo;
enviar `quantity` en uno booleano es `400`. Se almacenan como
`{addOnId, quantity}`, no como lista de identificadores.

### Unidades de consumo

```
u = n_inferencias × peso_modelo  [+ f(tamaño_galería) en búsquedas]
```

Pesos (**hipótesis pendiente de medición empírica**): detector 1, `xs` 1,
`s` 3, `base` 10. Operaciones sin inferencia: 0,1. Gestión: 0.

**Medición parcial (sesión 14, #120): esos pesos no se sostienen.** Con
imágenes de 480 × 640, los tres modelos cuestan lo mismo dentro del error del
método (~10 %), y una verificación cuesta unas tres detecciones con cualquiera
de ellos: MTCNN es la mayor parte del coste. Los pesos definitivos salen de
`analyze.py` al cerrar la campaña (#62). Hasta entonces, no implementar nada
que dependa de 1 / 3 / 10.

Se calcula en `fr-commercial` (único que conoce modelo, número de inferencias y
tamaño de galería) y se reporta **asíncronamente** a `pricing` con las
dimensiones cuenta, canal, modelo y endpoint. Consistencia eventual aceptada y
documentada.

### Congelación de galerías

Al bajar de plan, las galerías cuyo modelo ya no está disponible pasan a
`frozen`: solo lectura y borrado; se rechazan enrolamiento, verificación y
búsqueda con `403 GALLERY_FROZEN_MODEL_NOT_IN_PLAN`. **Nunca se borran.**

Se dispara con `subscription.plan_changed` y se procesa **en ambos sentidos**:
congelar y descongelar. La descongelación cubre la mejora de plan y la
contratación del add-on de modelo.

---

## Seguridad

- **Contraseñas y API KEY**: hasheadas, nunca reversibles.
- **JWT**: validado por firma **y por emisor** en Kong, sin consultar a `auth`.
  La vigencia sale de `JWT_EXPIRES_IN`, dentro del rango [5 min, 2 h] que impone
  la guarda de arranque de `auth`; no es una constante de 60 minutos. Ventana de
  revocación asumida y documentada más abajo.
- **API KEY**: validada contra `auth`, con caché de ~60 s del veredicto positivo
  en la pasarela. Un veredicto negativo se cachea 10 s ---optimización de
  latencia y disponibilidad, **no** un control de seguridad: la inundación con
  claves inventadas la cubre el límite de peticiones---. Si `auth` no responde,
  la pasarela devuelve `503` y **no cachea nada**: servir un veredicto caducado
  sería alargar en silencio la ventana de revocación.
- **Secreto de firma de webhooks**: almacenado **cifrado, no hasheado** — hay
  que recuperarlo en claro para calcular el HMAC saliente. Es la excepción a la
  regla anterior.
- **Tokens de enrolamiento**: Redis, TTL corto, un solo uso vía `GETDEL`
  atómico, clave construida con el hash del token.
  Ámbitos: `enroll` y `verify`. **Nunca `search`**: devolvería el nombre de la
  identidad y permitiría identificar a desconocidos.
- **URLs de webhook**: rechazar `http://`, IP privadas, `localhost` y
  direcciones de metadatos de nube (SSRF).
- **`X-API-Key` NO va en las cabeceras permitidas del CORS de la pasarela.** Es
  deliberado, y es la decisión más fácil de revertir por conveniencia el día que
  una llamada desde el navegador falle en el *preflight*. El canal de API es
  máquina a máquina: una API KEY en el navegador es una API KEY en el código del
  cliente, legible por cualquiera que abra las herramientas de desarrollo. El
  caso del navegador ---el widget--- son los **tokens de enrolamiento**, que
  existen justamente para no repartir la credencial permanente. Ese mismo plugin
  arrastra además `origins:["*"]` con `credentials: true` (issue #69).
- **Paginación**: máximo 100 elementos por página. Sin tope,
  `GET /identities` sobre 50.000 registros es un vector de denegación de
  servicio.
- **Cero secretos en el código.**

### Ventana de revocación, por canal

Que la pasarela no consulte a `auth` en cada petición tiene un precio, y no es
el mismo en los dos canales. **Suspender una cuenta no surte efecto inmediato:**

| Canal | Credencial | Retardo hasta que deja de pasar |
|---|---|---|
| Web | JWT | hasta su caducidad: `JWT_EXPIRES_IN`, entre 5 min y 2 h |
| API | API KEY | hasta 60 s, la vigencia del veredicto cacheado en la pasarela |

El freno inmediato es otro: **`POST /v1/auth/login` rechaza con `403` a las
cuentas suspendidas**, de modo que no se emiten JWT nuevos. Lo que sigue
circulando es lo ya emitido.

La asimetría es deliberada y se sostiene sola: el canal web compra
disponibilidad ---con `auth` caído, un JWT válido sigue pasando--- a cambio de
una ventana más larga, y el canal de API compra una ventana corta a cambio de
depender de `auth`, que con `auth` caído responde `503`. Cerrar la ventana del
canal web exigiría consultar a `auth` en cada petición, que es exactamente lo
que el diseño evita.

Si hiciera falta revocación inmediata, la vía es una lista de revocación en
Redis consultada por la pasarela, con el coste de latencia y de acoplamiento
que eso supone. No se implementa.

### Estructura del JWT

Contrato entre `auth` (emisor) y Kong (verificador). No cabe en OpenAPI:
para la especificación, un bearer token es opaco. Si cambia, hay que tocar
el plugin de la pasarela.

| Claim | Contenido |
|---|---|
| `sub` | `accountId` |
| `role` | `CUSTOMER` \| `ADMIN` |
| `iss` | `auth-microservice` |
| `iat` | emisión |
| `exp` | `iat` + `JWT_EXPIRES_IN` |

La pasarela verifica **firma e `iss`**, sin consultar a `auth`. Verificar
`iss` impide que un token firmado con la misma clave para otro propósito
sea aceptado como sesión. Los claims `sub` y `role` se propagan tal cual
en `X-Account-Id` y `X-Role`.

La vigencia procede de `JWT_EXPIRES_IN`, no de una constante. El servicio
**rechaza arrancar** con un valor fuera del rango de 5 minutos a 2 horas:
por debajo el panel resulta inusable, por encima deja de sostenerse el
argumento de la ventana de revocación documentado en la memoria.

---

## Eventos Kafka

| Evento | Publica | Consume |
|---|---|---|
| `account.deleted` | `auth` | `fr-commercial` (purga en cascada), `pricing` (cancela Stripe) |
| `subscription.plan_changed` | `pricing` | `fr-commercial` (congela/descongela) |
| consumo | `fr-commercial` | `pricing` |

`subscription.plan_changed` se publica cuando el cambio **se hace efectivo**
(cierre de periodo en las bajadas), no cuando se solicita.

Webhooks salientes: firma HMAC-SHA256 sobre `timestamp + "." + cuerpo_crudo`
(firmar el cuerpo **crudo**, no el JSON reserializado). Entrega
*at-least-once* con `eventId` único; reintentos con espera exponencial.

---

## Testing y documentación (obligatorio)

- Por cada controlador o servicio, su test correspondiente.
  Node.js: **Jest** · Python: **pytest**.
- **Antes de refactorizar `auth` o `pricing`, tener tests de contrato
  mínimos.** Sin ellos no se puede distinguir «lo ha arreglado» de «lo ha roto
  de otra manera».
- Todo endpoint nuevo se refleja primero en la especificación OpenAPI.
- En FastAPI: define los modelos con Pydantic y compara el `/openapi.json`
  generado contra la especificación. Ese diff es el informe de discrepancias
  continuo.
- **En OpenAPI 3.1, un esquema no se cierra con hermanos de `$ref`.**
  `{"$ref": ..., "unevaluatedProperties": false}` es la forma idiomática y **no
  cierra nada con openapi-core, que ignora los hermanos de `$ref` y calla**:
  medido en `fr-commercial` (#33), un campo de más pasa. Se cierra envolviendo:
  `{"allOf": [{"$ref": ...}], "unevaluatedProperties": false}`. Rige desde el
  día en que un contrato se migre a 3.1; hoy los tres son 3.0.3.
- **En OpenAPI 3.0.3, un esquema que otro compone se cierra así:** una base
  abierta con las definiciones; cada envoltorio con `allOf: [Base]`, sus nombres
  vacíos en `properties` y `additionalProperties: false`; y una guardia estática
  que compara las listas con la base en los dos sentidos. Un nombre que falta
  rechaza respuestas legítimas, pero solo si alguna prueba emite ese campo; uno
  que sobra se admite con cualquier valor y ningún validador avisa. Lo vigila
  `fr-commercial-microservice/tests/contract/test_closure.py` (#103).
- **Un cuerpo multipart se cierra con un modelo `extra="forbid"` anotado con
  `File()`, no con `Form()`.** Con `Form()` también rechaza las partes de más,
  pero publica `application/x-www-form-urlencoded`, que es falso frente al
  contrato. Con parámetros `File()`/`Form()` sueltos, la parte de más se ignora
  (`200`). Si se lee el flujo a mano, el cierre es una lista explícita de las
  partes declaradas. Requiere `python-multipart`, en el árbol fijado desde F5 (#37).
- **En los contratos, ninguna clave es un escalar sin comillas que YAML 1.1 lea
  como booleano o nulo, y ningún valor es `y`, `n`, `yes`, `no`, `on` ni `off`
  sin comillas.** Los lectores discrepan (PyYAML no aplica `y`/`n`; js-yaml es
  1.2), y con los esquemas cerrados una clave mal leída rechaza respuestas
  legítimas. Por eso el componente nulo se llama `NullValue` y no `Null`. Lo
  vigila `test_closure.py`.
- **El `model_serializer` de Pydantic no lleva `-> Any`.** Pydantic deriva de la
  anotación de retorno el esquema de SERIALIZACIÓN, y FastAPI publica ese
  esquema. Con `Any` el esquema publicado sale `{}` y las respuestas siguen
  saliendo bien, así que ninguna prueba de extremo a extremo lo ve; lo cazó la
  comparación estática en #33. «Anotarlo con el tipo concreto» **tampoco
  sirve**, medido: `-> dict` o `-> dict[str, Any]` publica un objeto abierto
  (`additionalProperties: true`), y `-> "Gallery"` revienta al generar el
  esquema. Lo que publica el esquema del modelo es **no anotarlo**. Anotarlo con
  un `TypedDict` también funciona, pero declara los campos por segunda vez.
  **Dónde vive la garantía:** que Pydantic, ante un serializador sin anotar,
  caiga en el esquema del modelo es comportamiento inferido, no una promesa
  documentada. Lo que protege la regla es
  `fr-commercial-microservice/tests/contract/test_shape.py`: si una versión
  futura de Pydantic cambia de criterio, su rojo se lee como **«la regla
  caducó»**, no como «el modelo está mal».

---

## Estado del proyecto

La planificación vive en los **issues del repositorio de documentación**.
**Este fichero no duplica esa lista**: consúltala con `gh issue list`.

Duplicarla fue la causa del desajuste anterior entre GitHub y este documento:
dos listas de lo mismo divergen en cuanto una se mueve.

**Cerrar issues desde un PR.** Cuando un PR resuelve un issue del todo, la
descripción lo cierra con la palabra clave en inglés y la referencia completa,
`Closes TFM-MIS-MEM/docs#N`: los issues viven en `docs` y los PR en otros
repositorios, «Cierra» no cierra nada y `#N` a secas apunta al repositorio del
propio PR. Los que el PR resuelve solo en parte se referencian con
`Refs TFM-MIS-MEM/docs#N`, que no los cierra. Antes de fusionar,
`gh pr view <N> --json closingIssuesReferences` tiene que coincidir exactamente
con los issues que el PR resuelve del todo; si no coincide, se corrige la
descripción antes de fusionar. Una lista vacía es correcta cuando el PR no
resuelve ninguno del todo.

Fases de trabajo, en este orden:

1. **Auditar y cerrar Auth.** Va primero porque desbloquea todo lo demás:
   hasta que `POST /v1/auth/validate-key` no devuelva `accountId` y la pasarela
   no lo propague, `fr-commercial` no puede determinar la propiedad de las
   galerías.
2. **FR Commercial.** Terreno nuevo y el grueso del trabajo.
3. **Pricing.** Cantidad en complementos, endpoint de consumo, Kafka.
4. **Integración.** Webhooks salientes, frontend, pruebas extremo a extremo,
   campaña de medición de capacidad.

Los issues de la implementación anterior se cerraron por obsoletos: se
crearon contra una versión previa del diseño.

> ⚠️ Los microservicios `auth` y `pricing` se implementaron contra la
> **versión anterior** del diseño. Requieren auditoría contra las
> especificaciones antes de darlos por buenos.

---

## Instrucciones de trabajo

1. **Acotar al issue indicado.** No proponer cambios en otros microservicios
   salvo que el issue lo requiera explícitamente.
2. **Antes de generar código**, confirmar qué microservicio y qué plantilla
   base aplica.
3. **Ante una decisión de diseño no cubierta aquí, preguntar.** Este proyecto
   es un TFM: cada decisión tiene que poder justificarse por escrito, así que
   una decisión silenciosa tomada por conveniencia es un problema.
4. **Al cambiar algo que aparezca en este fichero o en las especificaciones,
   avisar**, porque implica actualizar también la memoria.
5. **El código de salida no se toma a través de un tubo.** En `orden | tail`, el
   `$?` es el de `tail`, casi siempre 0. Pasó dos veces antes de escribirlo aquí
   ---la segunda, en #33, una prueba de alcanzabilidad por la IP de LAN imprimió
   `exit=0` y era el de `tail`---. Se ejecuta la orden sin tubería, o se guarda
   su salida en un fichero y se imprime después, o se lee `PIPESTATUS`.

## Modo entrega (desde la sesión 12, hasta el 29/10)

El objetivo hasta la entrega es funcionalidad visible y la campaña de
medición. Prioridades por etiqueta: `prio:1-medicion`, luego `prio:2-demo`,
luego `prio:3-si-da-tiempo`. Lo etiquetado `alcance:futuro` no se toca.

- Cada operación nueva lleva sus pruebas de contrato contra el `.yaml`. No se
  escriben guardianes nuevos sobre el propio instrumento de pruebas.
- Lo que se encuentre fuera del encargo se registra como issue de una línea
  con `alcance:futuro` y no se trabaja, salvo que bloquee la tarea en curso.
- Un PR puede cerrar varios issues si van juntos.
- Se mide lo que sostiene un resultado; no se mide cada afirmación de paso.
- La CI se mantiene en verde; un rojo ajeno al cambio que no bloquee se
  registra y no se arregla en la sesión.
- ESTADO.md, una entrada breve por sesión: qué se hizo, qué se fusionó, qué
  queda.
- **Mediciones de carga (`fr-commercial-microservice/load/`).** Configuración
  fijada para toda la campaña: `WEB_CONCURRENCY=1`, `TORCH_NUM_THREADS=1`,
  `INFERENCE_CONCURRENCY=8`. El instrumento está congelado en `b6fff3d`: si 
  cambian `criteria.py`, `most.py` o `k6/profile.js`, se repite la calibración. 
  Única excepción (sesión 17): añadir `searchGallery` a `k6/profile.js`, porque 
  hasta 50.000 rostros la búsqueda sigue limitada por la inferencia, para la que 
  se calibró, y la fórmula de unidades solo compara operaciones medidas sobre el 
  mismo despliegue.
- **Antes de medir, el agente para y avisa**, y Miguel prepara el Mac: solo
  Docker, VS Code y el chat abiertos; enchufado y sin bajo consumo;
  `caffeinate -i`; `docker ps` vacío, con la pila de desarrollo y el `fr` de
  desarrollo parados. Las mediciones las lanza Miguel desde una terminal con
  `nohup caffeinate -i … < /dev/null`, sin el `< /dev/null` el proceso se
  suspende. Mientras miden, el agente no hace ninguna llamada, ni de estado.
  Si una medición sale rara, primero se descartan las condiciones de la
  máquina y después se mira el servicio.
