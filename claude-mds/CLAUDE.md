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
| FR Commercial | `openapi/fr-commercial.yaml` (fichero real **hasta que exista su repositorio**) |

Es la única copia versionada, se revisa en el mismo diff que el código que la
implementa y el `COPY . .` de los `Dockerfile` la mete en la imagen.

Lo que hay en `openapi/` del workspace son **enlaces simbólicos de
conveniencia** hacia esos ficheros, para que la ruta corta siga funcionando sin
que existan dos copias que puedan divergir. Editar `openapi/pricing.yaml` edita
la del repositorio. `fr-commercial.yaml` seguirá siendo fichero real mientras no
tenga repositorio propio; cuando lo tenga, se mueve y se enlaza igual.

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
/src/models              → esquemas MongoDB
/tests                   → pruebas automatizadas
```

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
          índices: {accountId}, {accountId, name} único

Identity  galleryId, fullName, externalId?, faceCount, timestamps
          índices: {galleryId}, {galleryId, externalId} único disperso

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

**Sin límite de rostros por identidad.** El límite económico ya existe: cada
rostro computa sobre la cuota.

---

## Embeddings

- **Se almacenan binarizados** (64 B frente a 2 KB en float32; 3,2 MB frente a
  100 MB en una galería de 50.000). Comparación por distancia de Hamming.
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
