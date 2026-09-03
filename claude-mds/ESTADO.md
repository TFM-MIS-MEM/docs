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

**La memoria se actualizó**, en `memoria_tex/v4`: cuatro cambios en tres
capítulos, con `parches-memoria-sesion3.tex` recogiendo el reparto ---el
capítulo 4 no nombra tecnologías, códigos de estado ni cifras de configuración;
el 6 sí admite mecanismos y cifras; el 8 recoge evidencia---. Los dos primeros
**corrigen texto que había pasado a ser falso**; los dos últimos incorporan
material que la sesión produjo y la memoria no recogía.

| Capítulo | Cambio |
|---|---|
| 4 — Diseño del servicio | Dos parches, ambos correcciones. `\subsection{Validación de credenciales}` gana el comportamiento ante la indisponibilidad de la fuente de validación ---se rechaza la petición y no se admite por omisión: aceptarla sería suspender el control justo cuando no puede ejercerse--- y el requisito de saneado pasa a exigirse **incondicional** ---no supeditado a que la validación produzca un valor con el que sobrescribir--- y **universal**, alcanzando también a las rutas que no exigen credencial, porque una ruta exenta sigue conduciendo a un microservicio que confía en la identidad recibida. `\subsection{Ventana de revocación}` se reemplaza entera: fijaba la caducidad en sesenta minutos, que dejó de ser una constante, y afirmaba que en el canal de API la revocación era «prácticamente inmediata», que es falso ---está acotada por la vigencia de la caché--- y era donde se apoyaba el argumento de los sesenta minutos |
| 6 — Implementación | `\subsection{Autenticación en la pasarela y saneado de la identidad}`, nueva y la primera de su sección, porque la cadena de identidad precede a todo lo demás y el resto del capítulo presupone que el microservicio de destino recibe una cuenta ya validada. El cometido triple de la extensión a medida: determinar qué credencial acompaña a la petición, obtener de ella la identidad y entregarla de modo que el destino pueda confiar sin volver a verificarla. La sección de protección de la disponibilidad del capítulo 4 **no** necesitó cambio: fue la implementación la que se ajustó a ella, retirando el limitador que `pricing` aplicaba por su cuenta |
| 8 — Validación | §8.1 gana un cuarto nivel de prueba, el de **saneado de la identidad**, tras las de transición entre planes, con su párrafo de cierre. Los tres niveles anteriores se derivan de la especificación; este **no puede derivarse de ella**, y esa imposibilidad es un resultado del trabajo y no una carencia |

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

**La memoria se actualizó**, en `memoria_tex/v5`: cuatro parches en tres
capítulos, con `parches-memoria-sesion4.tex` recogiendo el reparto y el mismo
criterio de la sesión 3.

| Capítulo | Cambio |
|---|---|
| 4 — Diseño del servicio | `\subsection{Validación de credenciales}` gana la otra mitad del saneado: qué hace con la identidad el servicio que la recibe. La acepta sin volver a verificarla ---hacerlo obligaría a compartir el secreto de firma y dejaría fuera al canal API, cuya credencial no contiene identidad alguna que verificar---, la exige completa y con valores cerrados, sin valores por omisión, y la garantía de que las comprobaciones estrictas nunca se disparan corresponde al despliegue y no al código |
| 6 — Implementación | `\subsection{Consumo de la identidad en el microservicio de destino}`, nueva, junto a la de la pasarela. Los mecanismos, el criterio de que el cambio está completo ---que desaparezca el secreto de firma, no que se lean las cabeceras---, la exposición del puerto y el secreto compartido pasarela-servicio descartado con su motivo |
| 8 — Validación | §8.1 gana dos evidencias más del límite de la especificación ---el vocabulario de códigos queda fuera de lo comprobable, y la comprobación se ejerce sobre la respuesta y no sobre la petición--- y el hallazgo inverso: lo que la especificación calla también obliga. Se añade `\subsection{Primera aplicación del procedimiento}` con la progresión rojo-verde, el caso verde por el motivo equivocado y el argumento de cobertura |

**Sesión 5 — #68, y lo que salió de verificarlo antes de decidirlo.** El objeto
era cerrar #68, que bloqueaba `fr-commercial`: cómo se declaran las respuestas
que emite la pasarela y no el servicio. Afectaba a 27 de las 47 operaciones del
contrato, y decidirlo después de escribir el servicio habría obligado a
repasarlas una a una.

Antes de decidir nada se midió qué responde hoy la pasarela, caso por caso y con
la salida literal. Es lo que más ha dado de sí la sesión:

- **El `429` no cumple `ErrorReport`, y no puede cumplirlo sin trabajo en el
  gateway.** Lo emite el plugin de límite de tasa de Kong, que construye el
  cuerpo formateando una plantilla de nodo con dos huecos ---mensaje e
  identificador de petición---. No hay hueco para `code`, y la plantilla es
  global: un `code` literal se estamparía también en el `404` de ruta
  inexistente y en los `502` de upstream. Se descartó explícitamente inyectar
  JSON por el campo del mensaje de error, que hoy funciona porque la plantilla
  no escapa nada, pero es una inyección y no una configuración. La vía real es
  reescribir el cuerpo en la fase de respuesta, un día de trabajo.
- **El orden de prioridades deja fuera del límite de tasa a quien no trae
  credencial.** El plugin de autenticación corta antes de que el limitador
  cuente. Medido: con la cuota global ya agotada, 25 claves de API aleatorias
  distintas contra una ruta protegida produjeron **cero `429`**, y 24 de ellas
  llegaron hasta `auth` ---cada clave tiene un resumen distinto, luego una
  entrada de caché distinta, de modo que la caché negativa no absorbe nada---.
  Una de las 25 obtuvo `503`: `auth` no respondió a tiempo con solo 25
  peticiones rápidas.
- **La pasarela no evalúa el plan en ningún momento.** No hay una línea que lo
  consulte, ni podría haberla sin cambiar el diseño: la validación de la clave
  devuelve veredicto, cuenta, estado y rol, y ninguno de esos campos dice nada
  del plan. La disponibilidad del canal de API pasa por tanto a evaluarse en
  `fr-commercial`, junto a los modelos y los límites, que es donde el dato ya
  está cargado. Arrastra una corrección de `CLAUDE.md`, que la situaba en la
  pasarela.
- **El único `403` que emite la pasarela es cuenta suspendida.** Se leyó el
  plugin entero en vez de suponerlo: de sus doce salidas de error, once son
  `401` o `503` y la única `403` es la cuenta suspendida, solo en el canal de
  API. Se capturó en vivo contra una cuenta desechable, y de paso se midió la
  ventana de revocación de ese canal: 41 segundos pasando después de suspender,
  coherentes con los 60 de vigencia del veredicto cacheado.

**El criterio que se fija es que se declara lo que es una decisión, no lo que es
un fallo.** Toda operación alcanzable a través de la pasarela declara `429`;
toda operación con `security` declara además `401`; toda operación que admite
la credencial del canal de API declara además `503` y `403`. No se declaran las
respuestas accidentales ni las de plataforma.

El hallazgo que corrigió la regla mientras se escribía es que **el criterio del
`429` es la alcanzabilidad, no la protección de la operación**: el limitador es
global y no mira credenciales, así que también lo declaran las rutas públicas
---registro, inicio de sesión, recuperación de contraseña y receptor de eventos
de pago---, donde además cuenta desde la primera petición. La primera redacción
lo ataba a tener `security`, y habría dejado esas cuatro sin declararlo.

**71 respuestas añadidas sobre 43 de las 47 operaciones**, verificado
programáticamente recorriendo los tres contratos: 46 operaciones son alcanzables
por la pasarela y las 46 declaran `429`, sin un solo incumplimiento. Las cuatro
restantes ya cumplían. La validación de clave es la única excepción, y es
deliberada: no es alcanzable a través de la pasarela ---es ella quien la corta
con un `404`--- y su credencial de API es la clave *a validar* y no una
credencial de acceso, de modo que un `503` por indisponibilidad de `auth` no
puede declararlo el propio `auth`, y una cuenta suspendida no es un error ahí
sino un `200` con el estado dentro. El motivo quedó escrito en la descripción de
la propia operación, no solo en la cabecera del fichero.

**Supresión de la cuenta.** Verificar el `403` destapó que una cuenta suspendida
**no puede borrarse a sí misma**: la operación de borrado comprueba el estado
antes de borrar, la única reactivación exige `ADMIN` y no hay vía de crear el
primero, así que una sola autosuspensión ---ejecutable por accidente--- deja la
cuenta y sus datos atrapados. La regla que se fija es que **la suspensión
restringe el uso del servicio, nunca el ejercicio de derechos sobre los datos
propios**: el borrado queda del lado de los derechos, alcanza a galerías,
identidades, rostros, vectores y puntos de notificación igual que el de una
cuenta activa, y conserva la confirmación por contraseña.

A cambio, el borrado de una cuenta **sancionada** deja un registro mínimo
---resumen del correo con sal fija de despliegue, fecha y código de motivo, y
nada más---, cuyo único fin es impedir que ese correo vuelva a registrarse. Es
resumen y no cifrado por la misma distinción que separa la credencial, que solo
se verifica, del secreto de firma de los avisos salientes, que hay que recuperar
en claro. Queda escrito que es un badén y no un muro ---se esquiva con otro
correo, y la prevención real en un servicio de pago pasa por el medio de pago---
y que el alta con un correo de la lista debe responder **exactamente igual** que
con uno ya registrado, o el registro se convierte en un oráculo de quién ha sido
sancionado.

Nada de eso es aplicable mientras el estado suspendido signifique dos cosas: la
pausa que el titular se aplica y la sanción que le aplica la plataforma escriben
hoy el mismo valor. Se separan con un campo aparte y no ampliando el conjunto de
estados ---son dos ejes distintos, y ampliarlo tocaría un componente compartido
con un dato que la pasarela no necesita---. El invariante que los ata es que el
campo se limpia al reactivar, y de ahí se sigue que el registro se crea si y
solo si la cuenta está sancionada **en el momento del borrado**: a quien la
plataforma readmitió, su borrado posterior no le deja veto.

**`fr-commercial-microservice` existe.** Creado desde `python-template`, privado
como sus hermanos, con `openapi/fr-commercial.yaml` ya versionado dentro y el
enlace simbólico desde la raíz del workspace, igual que los otros dos. El
contrato llevaba viviendo en un directorio que no es repositorio, de modo que la
fuente de verdad de 27 de las 47 operaciones no tenía historia; nace con ella y
no tendrá que mudarse después. Como ese diff ya no se recupera, el primer commit
lo describe entero. **El servicio será Python** ---FastAPI---, mientras `auth` y
`pricing` son Node: es la primera vez que el proyecto sostiene dos cadenas de
herramientas a la vez, y eso tiene consecuencias en las pruebas.

Los commits de la sesión: `node-template` **f71398b** y **1183495**;
`python-template` **740b2dc** y **5543930**; `fr-commercial-microservice`
**f37c69e** y **d414c5c**; `auth-microservice` **4612dac**;
`pricing-microservice` **cbf9371**; `docs` **30c85ce** y **52ed3c5**. El de
`auth` conviene mirarlo dos veces: se escribió en una rama de trabajo por
inercia, y al llevarlo a `main` con un *cherry-pick* cambió de identificador
---era `150100f`--- y la rama `fase1/A4` se borró, local y remota, después de
comprobar que el contenido de ambas era idéntico.

**#68 queda cerrado.** De la sesión salieron **seis issues nuevos, #82 a #87**,
ninguno arreglado de paso.

**La memoria se actualizó**, en `memoria_tex/v6`: cinco parches en tres
capítulos, con `parches-memoria-sesion5.tex` recogiendo el reparto y el mismo
criterio de las sesiones 3 y 4. Uno de los cinco no añade material sino que
**corrige** una afirmación falsa ya publicada, y por eso el fichero avisa de que
conviene aplicarlo aunque se descarte todo lo demás.

| Capítulo | Cambio |
|---|---|
| 4 — Diseño del servicio | Dos parches. `\paragraph` nuevo en §4.3 con el criterio de qué declara un contrato ---la frontera entre la decisión y el fallo, y por qué el `429` se ata a la alcanzabilidad y no a que la operación esté protegida---. Y `\section{Ciclo de vida de la cuenta y supresión de los datos}`, nueva, con la regla de que la suspensión restringe el uso y nunca el ejercicio de derechos, el registro mínimo y la separación entre pausa y sanción. Este segundo parche lleva aviso propio: contiene afirmaciones de alcance jurídico y hay que contrastarlo con el tutor |
| 6 — Implementación | Dos parches. El primero es una **corrección**: §6.3.1 afirmaba que la protección frente al envío masivo de credenciales inválidas corresponde al límite de tasa, y es falso ---la medición de esta sesión lo desmiente---; se sustituye por lo medido y por el diseño de los dos limitadores. El segundo es `\subsection{Registro de supresión}`, con la estructura deliberadamente pobre del registro y el argumento de por qué es resumen y no cifrado |
| 8 — Validación | §8.1 gana la divergencia del `429` como evidencia de un límite que **no se corrige desde el documento**: la respuesta la emite un componente que el contrato no gobierna, de modo que declarar el esquema correcto no basta para que se cumpla, y la conformidad pasa a depender de una decisión de despliegue |

### La fase 1 NO está terminada

La cadena de identidad ---`auth`, la pasarela y el enrutado--- lo está, y desde
la sesión 4 también el grueso de `pricing`: **C2 (#32), #65 y #66 quedan
cerrados**, y con ellos la afirmación de que lo abierto era «todo `pricing`
salvo las rutas» deja de ser cierta.

Lo que queda no es un servicio entero, son cabos sueltos. **#64 avanza sin
cerrarse**: montado el andamiaje de `jest-openapi` y retiradas las pruebas
heredadas ---37 casos en 7 ficheros; los 35 que este documento venía citando
eran exactos hasta que la sesión 3 añadió `securityHeaders.test.js`, con dos
más---, pero cubre 2 de las 9 operaciones del contrato, las únicas
implementadas. Las otras siete y la batería completa son fase 3, y por el mismo
motivo de siempre: el ciclo rojo-verde necesita código que corregir, y una
batería en rojo durante dos fases deja de mirarse.

**#79 es el bloqueante.** Es la traza de pila que `auth` sigue emitiendo dentro
del cuerpo de sus errores, y la sesión 5 la agravó al medirla: sale también en
los `401` ---en cuatro variantes, incluida la del inicio de sesión fallido, que
cualquiera puede repetir sin credencial--- y en los `404`, atraviesa la pasarela
sin filtrarse y publica de paso las versiones exactas de las dependencias, que
la disposición de pnpm codifica en la ruta. Es además lo próximo que tocará ese
repositorio.

**Después de #79, el siguiente es #83**, y no forma parte del montón que pasa a
fase 2. Es el vector de amplificación medido en la sesión 5: el orden de
prioridades de la pasarela deja fuera del límite de tasa a quien no trae
credencial, de modo que una inundación con claves inventadas no encuentra freno
alguno y cada clave distinta se convierte en una consulta a `auth`. No es una
deuda de estilo sino la desmentida de una protección que la memoria daba por
existente ---por eso arrastró la corrección del capítulo 6 y de la entrada de
«Decisiones tomadas en conversación»---, y mientras siga abierta el argumento de
disponibilidad del canal de API se sostiene sobre algo que no está.

El resto **pasa a la fase 2 de forma deliberada, no por olvido**: **#74**, el
compose de producción de `pricing` que publica el puerto de su MongoDB; **#81**,
la prueba que le falta a `identity-headers.sh` para cubrir la única línea de la
que depende hoy que el canal de API llegue siempre con `X-Role`; y **#85** con
su dependencia **#86**, la supresión de la cuenta y la separación entre pausa y
sanción. Ninguno bloquea `fr-commercial`, y #85 no puede implementarse antes que
#86.

Llevan también `fase:1` y siguen abiertos **#80** ---el `overrides` de axios
que silencia al escáner sin cambiar nada de lo que se ejecuta--- y **#63**, que
este documento sigue por separado en «Pendiente de decidir». Conviene decidir si
se reetiquetan o se suman a las listas de arriba: mientras tanto, `gh issue list
--label fase:1` y este párrafo no dicen lo mismo, que es justo el desajuste que
la convención de no duplicar la planificación quiere evitar.

Se anotan aquí para que «fase 1 cerrada» no se dé por buena antes de tiempo.

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

**#68 ya está decidido y aplicado**, que era lo que no podía esperar: las 27
operaciones del contrato declaran ya las respuestas de pasarela, de modo que
escribirlas no obliga a repasarlas después.

Quedan dos decisiones **antes de arrancar**, ambas consecuencia de que
`fr-commercial` sea el primer servicio en Python:

- **Cómo se traduce a Python la implementación de referencia del consumo de
  identidad.** El patrón está fijado y probado, pero en Express: middleware que
  lee las tres cabeceras, las exige completas y con valores cerrados, y no
  verifica ningún token. El equivalente en FastAPI ---dependencia, *middleware*
  o ambos--- y dónde vive el rechazo hay que decidirlo, porque son 27
  operaciones que van a heredar la decisión.
- **Con qué herramienta se hacen las pruebas de contrato.** `jest-openapi` no
  sirve: es de Node. Hay que elegir el equivalente en Python y comprobar que
  sostiene el argumento del capítulo 8, que descansa en poder afirmar que una
  respuesta satisface la especificación. La alternativa que el propio contrato
  ya prevé ---comparar el `/openapi.json` que genera FastAPI contra el `.yaml`
  canónico--- cubre la forma, no las respuestas concretas, así que probablemente
  hagan falta las dos cosas.

Otras dos para cuando llegue:

- `fr-commercial` recibe `X-Account-Id` ya validado y **no modela la entidad
  Account**. El bloque de Kong está comentado en `kong.yml`, con el plugin ya
  configurado, y la ruta acordada es `/v1/fr/commercial`.
- ~~`openapi/fr-commercial.yaml` no vive dentro del repositorio de su
  servicio.~~ **Hecho en la sesión 5.** El repositorio existe, el contrato está
  versionado dentro y la raíz conserva el enlace simbólico, como los otros dos.

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
  seguridad.** La primera mitad se mantiene; la segunda **era falsa y se
  corrige**. Se venía diciendo que la inundación con claves inventadas la cubría
  el límite de peticiones, y la sesión 5 lo desmintió midiéndolo: el plugin de
  autenticación tiene más prioridad que el limitador, así que en rutas
  protegidas corta antes de que este cuente, y con la cuota global ya agotada 25
  claves aleatorias distintas dieron **cero `429`** y 24 llegaron hasta `auth`.
  Cada clave tiene un resumen distinto y por tanto una entrada de caché
  distinta, de modo que la caché negativa tampoco absorbe nada. La protección
  real exige **dos limitadores**: uno amplio por IP **delante** de la
  autenticación, que corta la inundación y protege a `auth`, y otro por cuenta
  **detrás**, sobre la cabecera `X-Account-Id` que la pasarela ya escribe, que
  es el que implementa las tasas por plan y hará falta igualmente. Bajar solo
  la prioridad frenaría una IP y no muchas, y cambiaría la superficie de error
  de todas las rutas protegidas. Se sigue en #83, y la misma corrección se ha
  aplicado al capítulo 6 de la memoria.
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
