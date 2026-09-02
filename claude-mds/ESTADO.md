# ESTADO — TFM: SaaS multicanal de reconocimiento facial

> Documento de continuidad. Se actualiza al cerrar cada sesión de trabajo.
> Su función es sustituir a la relectura de conversaciones anteriores.
>
> **Última actualización:** cierre de la sesión 4 (`pricing` conforme a su
> contrato; C2, #65 y #66 cerrados).

---

## De qué va el trabajo

Servicio SaaS de reconocimiento facial con dos canales de consumo (web y API),
gobernado por un pricing explícito. La contribución no son las capacidades de
reconocimiento facial —se apoyan en modelos preentrenados— sino **el pricing
como artefacto de diseño**: cómo se derivan sus límites de la capacidad medida
y cómo condiciona la arquitectura.

Tres aportaciones que sostienen el trabajo:

1. **Unidades de consumo ponderadas** por modelo de inferencia. Es una
   instancia de los límites *response-driven* del metamodelo iPricing aplicada
   a la visión por computador.
2. **Combinación de un límite de flujo con uno de estado** en el mismo pricing
   (unidades por periodo + rostros indexados), que son de naturaleza distinta y
   se evalúan de forma distinta.
3. **Adaptación del marco SCALE** —formulado para modelos de lenguaje— a un
   servicio de visión, con tres diferencias estructurales identificadas: el
   espacio de carga es categórico, el coste se conoce antes de ejecutar, y una
   dimensión del coste (el tamaño de la galería) es estado almacenado y no un
   parámetro de la petición.

---

## Dónde está cada cosa

| Artefacto | Ubicación |
|---|---|
| Decisiones de diseño | `docs/claude-mds/CLAUDE.md` |
| Contratos (fuente de verdad) | `<servicio>/openapi/<servicio>.yaml`. Los de `openapi/` del workspace son enlaces simbólicos |
| Backlog | Issues de `TFM-MIS-MEM/docs` |
| Planificación de la fase 1 | `docs/claude-mds/ISSUES.md` — fechada, no es el backlog |
| Prompts de las sesiones | `docs/claude-mds/PROMPTS-FASE1.md` |
| Estado del código heredado | `docs/claude-mds/AUDITORIA.md` — foto congelada |
| Continuidad entre sesiones | `docs/claude-mds/ESTADO.md`, este fichero |
| Memoria | Overleaf, capítulos 1 a 9 más anexos |
| Documento de diseño | `DoD-TFM.docx` |
| Scripts del entorno local | `docs/scripts/dev-up.sh` y `dev-down.sh` |

> ⚠️ **`repos/CLAUDE.md` no está bajo control de versiones.** Es un *stub* de
> una sola línea ---`@docs/claude-mds/CLAUDE.md`--- que vive en la raíz del
> workspace, que no es un repositorio. Existe porque Claude Code solo carga al
> arrancar el `CLAUDE.md` del directorio de trabajo: los de directorios hijos se
> cargan bajo demanda, mientras que los **imports sí se resuelven al inicio**, y
> su ruta es relativa al fichero que los contiene. Sin ese stub, las decisiones
> de diseño no entran en el contexto de una sesión nueva.
>
> Al clonar el proyecto en otra máquina **hay que recrearlo a mano**. No hay
> forma de versionarlo: el workspace que lo contiene no es un repositorio, y
> ponerlo dentro de uno de los repositorios de servicio lo pondría en el sitio
> equivocado.
>
> Lo mismo vale para **`repos/scripts`**, que es un enlace simbólico a
> `docs/scripts`. Los scripts sí están versionados; el enlace no. Sin él,
> `scripts/dev-up.sh` no existe y hay que invocarlos por su ruta real, que
> funciona igual:
>
> ```sh
> ln -s docs/scripts scripts        # recrear el atajo
> docs/scripts/dev-up.sh            # o invocarlos directamente
> ```
>
> Los scripts localizan la raíz del workspace **buscándola** ---suben
> directorios hasta encontrar el que contiene los tres repositorios de
> servicio--- en lugar de contarla desde su propia ubicación, de modo que
> funcionan tanto por el enlace como por la ruta real. Si los repositorios
> vivieran en otro sitio, `TFM_ROOT=/ruta docs/scripts/dev-up.sh`.

---

## Método de trabajo (por qué se hace así)

**Una sola fuente de verdad, impuesta por un mecanismo.** El desajuste original
del proyecto venía de tener tres contratos conviviendo: las especificaciones,
las anotaciones `@swagger` del código y los tests. Ninguno obligaba a los otros
a coincidir. La corrección no fue arreglar las discrepancias una a una, sino
hacer que la documentación se sirva desde el `.yaml` y que los tests se generen
desde él.

**Contrato primero, código después.** Toda modificación empieza por el `.yaml`,
sigue por la DoD y termina en la memoria. Nunca al revés. Si el código y la
especificación discrepan, se corrige el código.

**Ciclo rojo-verde.** Los tests de contrato se escriben desde la especificación
y quedan en rojo; el código se corrige hasta ponerlos en verde. Resolvió el
bloqueo que señalaba la auditoría: los tests que había fijaban el contrato
equivocado, así que no servían de red de seguridad.

**Informe antes de tocar.** Ante código heredado, primero el informe completo
de discrepancias y después las correcciones. Corregir sobre la marcha hace
perder la visión de conjunto.

**Alcance acotado por issue.** El agente trabaja sobre un issue y no propone
cambios en otros servicios. El desbordamiento de alcance fue lo que produjo el
desajuste anterior entre GitHub y la documentación.

---

## Estado actual

### Completado

**Fase 0 — Contratos.** Tres especificaciones OpenAPI validadas y contrastadas
operación por operación contra la DoD: `auth` (11 operaciones), `pricing` (9),
`fr-commercial` (27).

**Auditoría del código heredado.** `AUDITORIA.md`: 24 bloqueantes, 32
importantes, 16 menores. Los tres hallazgos estructurales fueron que ningún
servicio seguía la convención de rutas, que el plugin de Kong no podía
funcionar contra el `auth` existente, y que no había Kafka ni SPACE en ninguna
parte.

**Sesión 1 — C1.** Tests de contrato en `auth` generados con `jest-openapi`
desde `auth.yaml`. 42 tests, todos en rojo por diseño. Tests anteriores
movidos a `tests/legacy/` con su historia intacta.

**Sesión 2 — A1(auth), A2, A3, B1, B2.** `auth` conforme al contrato. 49 tests
en verde. Cobertura de 46/17/19/48 a 85/70/85/86. Documentación servida desde
el `.yaml`, lo que cierra C2 para `auth`.

**Sesión 3 — A1(pricing y Kong), A4 y, de hecho, A5.** Fusionadas
`pricing-microservice#1` y `api-gateway#1`, a la vez, con las tres ramas
cerradas: `fase1/A4` en ambos repositorios y `feat/stripe-webhook-checkout`, que
quedó contenida en `main` sin nada propio fuera.

- **A1.** Ningún componente monta ya `/api/`. `POST /v1/auth/login` responde
  `200` a través de la pasarela, que era el criterio del issue.
- **A4.** El plugin `space-auth` no autenticaba nada: exigía un `pricing_token`
  que `auth` nunca ha devuelto y no estaba aplicado a ninguna ruta activa. Ahora
  acepta las dos credenciales —JWT por firma **y emisor**, sin consultar a
  `auth`; API KEY contra `validate-key` con caché de 60 s—, propaga las tres
  cabeceras del contrato y distingue `401`, `403` y `503`.
- **A5, sin planificarlo.** El saneado de cabeceras quedó cubierto por
  `api-gateway/tests/identity-headers.sh`, que levanta un servicio de eco,
  publica su ruta por la Admin API y restaura `kong.yml` al salir. Comprueba que
  el cliente no cuela `X-Account-Id` ni por las rutas con plugin ni por las que
  no lo llevan. Se añadió también `tests/cors-preflight.sh`.
- **I7 no era un problema.** Los tres `docker-compose.dev.yml` ya usaban la red
  externa `tfm-network`; Kong resuelve ambos nombres. Lo que sí sigue
  desalineado son los `docker-compose.yml` de producción, con una red por
  repositorio.

Cinco issues abiertos durante la ejecución, ninguno arreglado de paso: **#65** y
**#66** (alineación de `pricing` con su contrato), **#67** (`commitlint` sin
`extends`), **#68** (respuestas que emite la pasarela y el contrato no declara)
y **#69** (CORS con `origins:["*"]` y `credentials`).

**La CI de `pricing` no había estado nunca en verde**, y no por A1: fallaba en
formato, en `pnpm audit` con 32 avisos, y en cuatro suites que ni arrancaban
porque `stripe.service.js` construye el cliente al cargar el módulo y en el
runner no hay `.env`. Las tres cosas quedaron arregladas, más la subida de las
acciones y el alineamiento de la toolchain a Node 22 y pnpm 11.24.0.

**La memoria se actualizó**, en `memoria_tex/v5`: cuatro parches en tres
capítulos, con `parches-memoria-sesion4.tex` recogiendo el reparto y el mismo
criterio de la sesión 3.

| Capítulo | Cambio |
|---|---|
| 4 — Diseño del servicio | `\subsection{Validación de credenciales}` gana la otra mitad del saneado: qué hace con la identidad el servicio que la recibe. La acepta sin volver a verificarla ---hacerlo obligaría a compartir el secreto de firma y dejaría fuera al canal API, cuya credencial no contiene identidad alguna que verificar---, la exige completa y con valores cerrados, sin valores por omisión, y la garantía de que las comprobaciones estrictas nunca se disparan corresponde al despliegue y no al código |
| 6 — Implementación | `\subsection{Consumo de la identidad en el microservicio de destino}`, nueva, junto a la de la pasarela. Los mecanismos, el criterio de que el cambio está completo ---que desaparezca el secreto de firma, no que se lean las cabeceras---, la exposición del puerto y el secreto compartido pasarela-servicio descartado con su motivo |
| 8 — Validación | §8.1 gana dos evidencias más del límite de la especificación ---el vocabulario de códigos queda fuera de lo comprobable, y la comprobación se ejerce sobre la respuesta y no sobre la petición--- y el hallazgo inverso: lo que la especificación calla también obliga. Se añade `\subsection{Primera aplicación del procedimiento}` con la progresión rojo-verde, el caso verde por el motivo equivocado y el argumento de cobertura |

**Sesión 4 — C2 en `pricing`, #65, #66 y la red de seguridad de #64.**
Fusionada `pricing-microservice#2` con sus cinco commits sin aplastar: el orden
---red de seguridad primero, cambios de comportamiento después--- es la
evidencia del ciclo rojo-verde y solo existe si queda registrada.

La batería de contrato se montó **antes** de tocar `src/`, y en rojo: 17 de 18
casos, agrupados en cuatro causas ---el middleware exigía `Authorization:
Bearer` (6), el cuerpo de error no era `ErrorReport` (6), el `200` del webhook
llevaba cuerpo (3) y la firma inválida respondía `400` donde el contrato declara
`401` (2)---. El delta se midió tras cada paso hasta los 24 en verde. El único
caso que empezó en verde lo estaba **por el motivo equivocado**, que mientras no
se cambia la causa es indistinguible de uno correcto: de ahí que la progresión
se registrara paso a paso y no solo al final.

- **C2.** `/docs` y `/openapi.json` se sirven de `openapi/pricing.yaml` con
  `js-yaml`; `swagger-jsdoc` fuera y ni una anotación de bloque en `src/`. Lo
  que la exclusión de las pruebas heredadas dejaba sin red ---el alcance de la
  exención de CSP, en los dos sentidos--- lo recoge `tests/service.test.js`.
- **#66.** El manejador devuelve `{code, message}` con un vocabulario de códigos
  escrito en el propio fichero, porque `ErrorReport` declara `code` como cadena
  libre y ningún test puede protegerlo. La traza de pila **no viaja en el cuerpo
  en ningún entorno**: va al registro, y solo cuando el error no es operacional.
- **#65.** El middleware lee `X-Account-Id`, `X-Auth-Channel` y `X-Role` y no
  verifica ningún token; `JWT_SECRET` y `jsonwebtoken` desaparecen del servicio.
  Las tres cabeceras son obligatorias y con valores cerrados, decisión razonada
  en el propio fichero: por el camino legítimo esas comprobaciones son
  inalcanzables ---la guarda única del plugin corta antes---, así que solo
  disparan ante quien se salta la pasarela.

Al dejar de morir en `401`, la batería destapó lo que el `401` tapaba, y entró
en la misma sesión: `planId` pasa a ser el enum del contrato con la
correspondencia a Price ID en `src/config/plans.js` ---sin valor por defecto: el
servicio no arranca si faltan las variables, porque un precio inventado no falla
al arrancar sino en la primera compra real---, la respuesta `201` pasa a ser el
recurso plano `{sessionId, url}`, y `SubscriptionRecord.userId` se renombra a
`accountId`. Eso cerró de paso **#50**, que pedía exactamente ese mapeo.

**El canal de API funciona de extremo a extremo por primera vez.** Con una API
KEY válida a través de Kong, `create-session` responde `400` con `ErrorReport`
ante un `planId` fuera del enum, `400 PLAN_NOT_PURCHASABLE` ante el plan
gratuito y `201` con una sesión real de Stripe contra el precio del Plan Pro. La
salida literal de los tres quedó en el cuerpo del PR: no se verifica en la CI y
es evidencia del capítulo 8.

La cobertura **subió al retirar pruebas**: de 76,25 / 50,57 / 59,37 / 77,97 a
76,89 / 56,25 / 66,66 / 78,31 (sentencias, ramas, funciones, líneas), con el
trinquete fijado en 76 / 56 / 66 / 78 ---al entero inferior, para que no salte
por dos centésimas en un refactor---. Las dos medidas se tomaron sobre árboles
de fuentes distintos ---la base tenía `swagger-jsdoc` y no tenía `plans.js`---,
así que la comparación es indicativa y lo que sostiene el argumento no son las
décimas, sino qué caminos se atraviesan: 24 casos de contrato cubren más camino
que las 37 heredadas, que eran
en su mayoría validaciones de esquema de modelo y no atravesaban el enrutado, la
identidad ni el manejador de errores, que es donde vive el contrato.

De la sesión salieron **nueve issues nuevos, #73 a #81**, ninguno arreglado de
paso. Seis son de `pricing` y tres tocan otros repositorios: la traza de pila
que `auth` sigue emitiendo en desarrollo, su `overrides` de axios ---que no
cambia nada de lo que se ejecuta, porque ese axios solo aparece como `import
type` en un `.d.ts`--- y el caso que le falta a `identity-headers.sh`.

**Los parches de memoria de esta sesión quedan pendientes**, sobre los capítulos
6 y 8, con el material ya identificado: la implementación de referencia de cómo
un backend consume la identidad propagada y la garantía de red frente al secreto
compartido que se descartó, para el 6; y para el 8, el hallazgo de que una
respuesta declarada sin `content` obliga a devolver el cuerpo vacío ---con el
límite que eso destapa, que `toSatisfyApiSpec()` valida la respuesta y no la
petición--- junto al argumento de cobertura.

### La fase 1 NO está terminada

La cadena de identidad ---`auth`, la pasarela y el enrutado--- lo está, y desde
la sesión 4 también el grueso de `pricing`: **C2 (#32), #65 y #66 quedan
cerrados**, y con ellos la afirmación de que lo abierto era «todo `pricing`
salvo las rutas» deja de ser cierta.

Lo que queda no es un servicio entero, son cinco cabos sueltos. **#64 avanza
sin cerrarse**: montado el andamiaje de `jest-openapi` y retiradas las pruebas
heredadas ---37 casos en 7 ficheros; los 35 que este documento venía citando
eran exactos hasta que la sesión 3 añadió `securityHeaders.test.js`, con dos
más---, pero cubre 2 de las 9 operaciones del contrato, las únicas
implementadas. Las otras siete y la batería completa son fase 3, y por el mismo
motivo de siempre: el ciclo rojo-verde necesita código que corregir, y una
batería en rojo durante dos fases deja de mirarse.

Los otros cuatro son issues abiertos en la sesión, todos con `fase:1`: **#74**
---el compose de producción de `pricing` publica el puerto de su MongoDB---;
**#79** y **#80**, de `auth`, que salen de comparar los dos servicios una vez
alineados ---la traza de pila que uno emite y el otro ya no, y un `overrides`
que silencia al escáner sin cambiar nada de lo que se ejecuta---; y **#81**, del
gateway, que cubre con una prueba la única línea de la que depende hoy que el
canal de API llegue siempre con `X-Role`.

Ninguno bloquea la fase 2. Se anotan aquí para que «fase 1 cerrada» no se dé por
buena antes de tiempo.

### Siguiente paso: `fr-commercial`

Sin cambios respecto a lo previsto: la media sesión de `pricing` que precedía a
la fase 2 está hecha, y con ella **la implementación de referencia de cómo un
backend consume la identidad que propaga la pasarela**. Era la razón de
adelantarla: `fr-commercial` son 27 operaciones que van a copiar ese patrón, y
hasta la sesión 4 el único ejemplo del repositorio lo hacía mal ---verificaba el
JWT por su cuenta, lo que obligaba a compartir el secreto de firma y dejaba
fuera al canal de API---.

**`fr-commercial`** es el grueso del trabajo y lo que sostiene la contribución:
las unidades de consumo ponderadas, el límite de estado y la campaña de medición
dependen de que exista. Es también lo que más riesgo tiene de no caber en el
tiempo restante.

Antes de empezarlo, y esto **no puede esperar**: **decidir #68**, que afecta a
27 de las 47 operaciones del contrato. Decidirlo después de escribir
`fr-commercial` obliga a repasar esas 27 una por una.

Otras dos cosas para cuando llegue:

- `fr-commercial` recibe `X-Account-Id` ya validado y **no modela la entidad
  Account**. El bloque de Kong está comentado en `kong.yml`, con el plugin ya
  configurado, y la ruta acordada es `/v1/fr/commercial`.
- `openapi/fr-commercial.yaml` es el único contrato que no vive dentro del
  repositorio de su servicio, porque ese repositorio no existe aún. Al crearlo,
  se mueve allí y se deja el enlace simbólico, como los otros dos.

---

## Decisiones tomadas en conversación

Las de diseño están en `CLAUDE.md` y en las descripciones de las
especificaciones. Estas son las que no encajaban en ninguno de los dos:

- **`application/json`, no `application/problem+json`.** Se declaraba el tipo de
  medio del RFC 7807 con un esquema `{code, message, details}` que no es el del
  RFC 7807. Usar el tipo de medio de un estándar cuyo esquema no se sigue es
  peor que no usarlo.
- **`validate-key` conserva el secreto interno.** El contrato declara
  `apiKeyAuth` **e** `internalSecret` en el mismo objeto de seguridad. El
  aislamiento de red es la protección principal, pero en `docker-compose` todos
  los servicios comparten red, así que sería el único control sobre un endpoint
  que valida credenciales.
- **`login` rechaza cuentas suspendidas con `403`.** La ventana de revocación
  se refiere a los JWT ya emitidos; no habilita a obtener uno nuevo. Sin este
  control la suspensión no tendría efecto alguno sobre el canal web.
- **El limitador de tasa va por operación**, montado solo en `login`,
  `forgot-password` y `reset-password`. Global produciría `429` en endpoints
  que no lo declaran, es decir, respuestas no conformes. El límite general es
  responsabilidad de Kong (issue I6).
- **La vigencia del JWT tiene guarda de arranque** en el rango [5m, 2h]. La
  memoria argumenta la ventana de revocación sobre 60 minutos y nada impedía
  que un despliegue la contradijera en silencio.
- **`DELETE /faces/{faceId}` devuelve `409` si es el único rostro**, en lugar
  de eliminar la identidad en cascada. Un `DELETE` sobre un subrecurso no debe
  destruir su recurso padre, y el caso de uso habitual —sustituir la única
  fotografía— perdería el `identityId` y el `externalId`.
- **Tres categorías de test con frontera nítida:** `contract/` verifica lo que
  la especificación puede expresar; `unit/` verifica reglas que ninguna
  especificación puede expresar (claims del JWT, vigencia); `legacy/` documenta
  el comportamiento anterior. Que existan las dos primeras **es** el argumento
  de que OpenAPI no basta como fuente única.
- **El saneado de cabeceras es propiedad de la pasarela, no de un plugin.** Las
  rutas que no llevan `space-auth` —las públicas de `auth` y el receptor de
  Stripe— lo hacen con `request-transformer`. Si dependiera del plugin, toda
  ruta que no lo lleve quedaría sin sanear, que es justo lo que pasaba.
- **`auth` caído devuelve `503` y no se cachea nada.** Se implementa con un
  `new_ttl` negativo, que mlcache trata como *bypass*, y no devolviendo un
  error: con un error, mlcache entra en su rama de resurrección y sirve el
  veredicto rancio. Esa rama está armada a 30 s por omisión, así que servir el
  veredicto viejo habría sido el comportamiento por defecto y no una decisión.
- **La caché negativa es optimización de latencia, no un control de
  seguridad.** Se etiqueta así a propósito: la inundación con claves inventadas
  la cubre el límite de peticiones (I6), no un TTL.
- **`X-API-Key` no va en las cabeceras permitidas del CORS.** El canal de API es
  máquina a máquina; el caso del navegador son los tokens de enrolamiento. Hay
  un test que lo fija para que revertirlo sea una decisión y no un descuido.
- **La especificación se versiona dentro del repositorio de su servicio.** Los
  `openapi/*.yaml` de la raíz del workspace son enlaces simbólicos, no copias.
- **`/docs` va exento de la CSP de `helmet` en todos los servicios.** Sin ello,
  Swagger UI no puede llamar a la pasarela: la llamada muere dentro del
  navegador y no deja rastro en ningún registro del servidor.
- **El backend confía en la pasarela, y la garantía es de red.** Se descartó un
  secreto compartido pasarela-servicio: sería defensa en profundidad real, pero
  crea un mecanismo fuera del contrato y devuelve a `pricing` la responsabilidad
  que #65 concentra en la pasarela. El puerto deja de publicarse en el compose de
  producción y en el de desarrollo queda atado a `127.0.0.1`; la garantía real es
  el `ClusterIP` de Kubernetes, no el compose.
- **Las cabeceras de identidad se exigen completas y con valores cerrados.** Sin
  respaldo al JWT y sin valores por defecto, porque un valor por defecto es
  inventar identidad. Por el camino legítimo es inalcanzable ---la guarda del
  plugin corta antes---, así que solo actúa contra quien se salta la pasarela.
- **La traza de pila no viaja en el cuerpo en ningún entorno.** Diverge de
  `auth`, que la deja en `details` en desarrollo; la divergencia es deliberada y
  su alineación es #79, no una deriva.
- **La CI de `pricing` audita con `pnpm audit --prod`.** Audita lo que se
  despliega. El árbol de producción no contiene axios: los avisos venían todos de
  una dependencia fantasma de una herramienta de test.

---

## Pendiente de decidir

- **Siembra de la cuenta administradora inicial** (issue #63). Con `register`
  asignando siempre `CUSTOMER`, no existe vía para crear el primer `ADMIN`, y
  `PATCH /accounts/{id}/status` —única vía de reactivación— lo exige. En un
  despliegue limpio, la primera cuenta suspendida es irrecuperable. Propuesta:
  script idempotente con credenciales por variables de entorno.
- **Modelado del canal API en SPHERE.** El metamodelo iPricing representa la
  estructura comercial del canal web, no las condiciones de capacidad del canal
  programático. Confirmar con el tutor si ACM2YAML está disponible; las
  limitaciones encontradas son contribución de retorno al ecosistema.
- **Alcance de la campaña de medición.** Nueve perfiles (tres modelos × tres
  operaciones), con tamaño de imagen y de galería fijos. La variación de esas
  dos dimensiones queda como trabajo futuro declarado.
- **Ubicación de la lógica del límite en unidades.** Los límites expresados en
  unidades de capacidad no pueden aplicarse con los mecanismos declarativos de
  Kong, que operan sobre recuentos de peticiones. Pasarela mediante extensión,
  o microservicio.

---

## Pendiente de revisión externa

- **Visto bueno del tutor a la primera versión de la memoria**, entregada con
  los capítulos 1 a 6 como resultados y los capítulos 7 y 8 como planificación.
- **Confirmar la referencia de SCALE**: el ejemplar disponible está anonimizado
  y los datos de publicación de MoST hay que verificarlos.
- **Presupuesto y cronograma** de la memoria: pendientes de rellenar con la
  dedicación real.

---

## Cómo continuar en un chat nuevo

> Continúo el TFM. El estado está en `ESTADO.md`, en el conocimiento del
> proyecto. Vamos con [la sesión N / el capítulo N / lo que toque].

Y al cerrar la sesión, actualizar las secciones «Estado actual» y «Pendiente de
decidir» de este documento.
