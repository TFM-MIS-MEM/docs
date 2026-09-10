# ESTADO — TFM: SaaS multicanal de reconocimiento facial

> Documento de continuidad. Se actualiza al cerrar cada sesión de trabajo.
> Su función es sustituir a la relectura de conversaciones anteriores.
>
> **Última actualización:** cierre de la sesión 8 (#95 cerrado; `auth` deja de
> ser alcanzable fuera de la pasarela y de arrancar con un secreto publicado).

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

**No se fusiona nada con el check en rojo**, aunque el rojo sea preexistente y
esté explicado en el cuerpo del PR. Si el rojo no lo causa el cambio: rama
aparte desde `main`, arreglo, fusión, y después traer `main` a la rama. Fusionar
en rojo no se defiende por bien documentado que esté.

**No se aceptan pruebas intermitentes.** O se arreglan para ser deterministas, o
se retiran asumiendo la pérdida de cobertura. «Es preexistente» no crea una
tercera opción: una prueba que falla a veces no es fuente de verdad.

Las dos se aplicaron en la sesión 6 y son la razón de que hicieran falta tres PR
en `auth-microservice` ---#2, #3 y #4--- donde se esperaba uno: el rojo de la CI
y el no determinismo de la suite eran preexistentes, y ninguno de los dos podía
entrar en el PR del issue que se venía a cerrar.

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

**Sesión 6 — #79 y #90, más el guardián de la CI.** El objeto era #79, el
bloqueante: la traza de pila en el cuerpo de los errores de `auth`. Se cerró, y
por el camino salieron dos cosas que impedían darlo por terminado, cada una en
su PR.

- **#79 (`auth-microservice#2`).** El manejador devuelve `ErrorReport
  {code, message}` y no la traza, en todo entorno; es la implementación de
  `pricing`, con el vocabulario de códigos de dominio como única divergencia.
  Las 34 pruebas nuevas se escribieron **antes** y quedaron en rojo ---8 de 34,
  siete por la traza en el cuerpo y una por la traza ausente del registro---, en
  un commit propio y con `--no-verify`, porque el hook rechaza un commit rojo.
  Ese orden es la evidencia del ciclo y solo existe si queda registrada.
  Verificado con `curl` contra el servicio y a través de Kong para `400`, `401`
  del inicio de sesión fallido y `404`: el cuerpo pasa de 310 bytes con 223 de
  traza a 60 sin ella, y la respuesta llegaba idéntica por los dos caminos.
  **El manejador estaba mal por partida doble y en sentidos opuestos**: `main`
  no registraba la traza en ninguna parte, de modo que en producción se perdía y
  en desarrollo salía solo al cliente. Las dos mitades se corrigen.
- **El guardián de la CI (`auth-microservice#3`).** El paso de auditoría llevaba
  en rojo permanente desde el 02/09 por `browserslist`, transitiva de `jest`.
  Pasa a `pnpm audit --prod` ---se audita lo que se despliega--- con reintento
  que distingue el registro caído del aviso real. Al quitar el ruido aparecieron
  **dos vulnerabilidades moderadas de `qs`**, que `express` usa para parsear la
  cadena de consulta en cada petición: `qs@6.16.0` entra por `overrides` con
  techo `<7`, comprobado con 39 casos de parseo sin una sola diferencia.
- **#90 (`auth-microservice#4`).** La suite era no determinista, ~1 vuelta de
  cada 30. La causa no estaba en el código ni en la lógica de las pruebas, sino
  en el andamiaje: `supertest` levantaba un servidor por petición ---399 por
  vuelta--- y alguna aterrizaba en un puerto reciclado de otro proceso. Un
  servidor por fichero lo elimina, y de paso las tres pruebas de ráfaga bajan de
  ~290 ms a ~62. Verificado con 105 vueltas sin fallos, y otras 40 sobre la rama
  de #79 ya fusionada con `main`.

La suite pasa de **69 a 103 pruebas** en 14 suites, y la cobertura de
87,13 / 69,67 / 85,71 / 87,50 a **88 / 75,49 / 87,30 / 88,41**. El trinquete
queda en **87 / 75 / 87 / 88**, y el de sentencias baja de 88 a 87 a propósito:
la medida era 88,00 **exacto**, de modo que fijarlo en 88 lo dejaba clavado
sobre la medición y sin margen ninguno, que es justo lo que la convención del
entero inferior quiere evitar. Cuando la medida ya cae en un entero, el inferior
es el anterior.

De la sesión salen **cinco issues nuevos, #88 a #92**, ninguno arreglado de
paso. Dos de ellos no son tareas sino **límites del método**, y por eso se
anotan aquí y no solo en GitHub:

- **#88.** `ErrorReport` no declara `additionalProperties: false`, y su `details`
  declara `additionalProperties: true`. Un cuerpo con la traza dentro de
  `details` **cumplía la especificación**, de modo que `toSatisfyApiSpec()` no
  podía rechazarlo: la fuga de #79 convivió con 69 pruebas en verde, y no por
  descuido de la batería.
- **#89.** El mismo argumento sobre el mensaje: un `400` cuyo texto dice
  «Internal server error» satisface el esquema, porque `ErrorReport` solo exige
  dos cadenas y no puede atar el mensaje al estado.

Los dos son la cara complementaria de la entrada de «Decisiones tomadas en
conversación» sobre las tres categorías de test. Allí el argumento es que la
especificación **no llega** a ciertas reglas, y por eso existe `unit/`. Aquí es
que, donde sí llega, **comprueba que no falta nada de lo declarado y no que no
sobre nada**: la conformidad automática verifica la forma, no la coherencia. Lo
que el esquema no puede prohibir hay que escribirlo como prueba, y eso es lo que
hace `tests/contract/error-report.test.js` al comprobar a mano que no sobra
ningún campo. Se suma al `429` de la pasarela (#82) como tercer caso de la misma
familia.

`pricing` queda avisado en **#91**: tiene el mismo `qs` vulnerable y su CI dice
verde solo porque no se ha vuelto a ejecutar desde antes de que se publicaran
los avisos.

**La memoria se actualizó**, en `memoria_tex/v7`: los parches de
`parches-memoria-sesion6.tex` están aplicados. Se listan aquí por lo que
aportan, no como pendiente:

- **Capítulos 6 y 8.** El arreglo de #79 y su evidencia de `curl`, directa y a
  través de la pasarela, con el antes y el después.
- **La doble mitad del manejador**: la traza salía al cliente y no al registro,
  que es el mismo error al revés. Interesa como ejemplo de defecto que se
  compensa en apariencia y por eso convive con una batería en verde.
- **Tres lecciones sobre guardianes**, las tres medidas en esta sesión: el que
  lleva tanto tiempo en rojo que **deja de leerse** ---y el aviso de `qs` entró
  en un informe que ya nadie miraba---, el que **no se ejecuta** ---la CI de
  `pricing`, verde por caducidad---, y el que **pasa en verde porque la
  preparación se tragó la anomalía**. Este último es el más difícil de ver: el
  fallo visible fue una respuesta ajena que rompió cuatro pruebas, pero el
  riesgo real era la que no rompía ninguna.
- **Sobre el método, y va a §8.1**: con 40 vueltas por rama no hay potencia
  estadística para distinguir una tasa del 2,5 % de una del 7,5 %. El A/B no se
  resolvió por el p-valor, sino por identificar el mecanismo y por que el mismo
  síntoma apareciera en un fichero que el PR no tocaba. En no determinismo la
  medición acota; lo que concluye es el mecanismo.

**Apunte operativo, conviene mirarlo antes de la fase 2.** El script
`test:coverage` añade `--detectOpenHandles` y triplica el tiempo de la suite: 21
s frente a 7. Para tandas de repetición, `pnpm exec jest --coverage`. Con suites
mayores esto va a doler.

**Sesión 7 — #83, el último bloqueante de la fase 1.** El objeto era el vector
de amplificación medido en la sesión 5. Se cerró en `api-gateway#2`, y lo que
más ha dado de sí no fue implementarlo sino que **el diseño escrito no era
implementable tal cual** y que **la prueba escrita para vigilarlo no podía
fallar**.

**La medición, antes y después, con el mismo script.** Se reprodujo primero
sobre `main` sin tocar nada, porque un «antes» heredado no es un «antes»: con la
cuota agotada, 25 claves aleatorias contra una ruta protegida dieron **cero
`429`** y el recuento de validaciones en el registro de `auth` pasó de 98 a 123.
Después: **25 de 25 en `429`** y el recuento inmóvil en 132. El script agota
hasta ver un `429` en lugar de enviar un número fijo, de modo que sirve para las
dos medidas sin cambiar ninguna constante.

**La divergencia con la sesión 5, que no fue motivo de parada.** Aquella midió
24 de 25 llegando a `auth` y una con `503` por tiempo de espera agotado. En la
reproducción llegaron **las 25**, en dos pasadas consecutivas, **sin un solo
`503`**. Se decidió seguir y decirlo: el resultado que sostiene el issue ---cero
`429`, la caché negativa no absorbe nada, una consulta a Mongo por clave
inventada--- se reprodujo exacto, y la amplificación medida resultó **peor** que
la registrada, no mejor. El `503` era una propiedad de la carga de aquel momento
y no del diseño; parar por su ausencia habría sido parar porque el sistema
aguantó más.

**Tres hechos de la pasarela, medidos y no razonados**, porque los tres decidían
el diseño y ninguno se lee en la documentación del producto:

- **Dos instancias del mismo plugin no se acumulan**: la más específica
  sustituye a la global. Medido con una global de 5 por minuto y otra por ruta
  de 100 sobre la misma ruta: ocho peticiones, límite efectivo 100, ningún
  rechazo. Es lo que obliga a que los dos limitadores sean **dos extensiones
  distintas**, porque la prioridad de un plugin es fija y única y el diseño
  escrito las quería a los dos lados de la autenticación.
- **Que el limitador por cuenta no se pueda evadir falsificando la cabecera de
  identidad no se podía dar por bueno leyendo el código**: el accesor de
  cabeceras de la pasarela resuelve por una variable de nginx y no por la tabla
  de cabeceras, de modo que dependía de que la reescritura actualizase esa
  variable. Se midió: seis peticiones autenticadas con la cabecera falsificada y
  distinta en cada una, el contador decreciendo de forma monótona. Cuenta por el
  valor que escribe la pasarela.
- **La resolución de identificador del limitador de serie termina en «o la
  dirección reenviada»**, así que cualquier criterio que no resuelva cae a la
  dirección de origen **en silencio**.

**El hueco del propio plan, cerrado antes de escribir la prueba.** El plan
aprobado decía que montar el limitador por cuenta donde no debe se delataría con
un `500`. Al escribirlo se vio que eso solo era cierto **si la cabecera
faltaba**: con la validación ausente pero el cliente enviándola, el limitador
habría contado el valor del cliente y respondido con normalidad. Se cerró con un
apretón de manos ---la validación deja marca en el contexto de la petición y el
limitador la exige---, de modo que ahora falla también con la cabecera
falsificada. Las dos vías tienen prueba.

**Y el hallazgo incómodo: la prueba nueva no podía fallar por dos vías
distintas.** Se buscaron a propósito, aplicando la tercera lección sobre
guardianes de la sesión 6, y las dos estaban:

- El bloque del limitador de abuso **se calibraba sobre la cuota que
  encontrara**. Con una cabecera no numérica ---un `500`, la conexión
  rechazada--- el recuento quedaba vacío, los bucles no iteraban y esperado y
  obtenido salían **ambos vacíos**: la comprobación pasaba.
- La comprobación de que la inundación **no** deja líneas nuevas en el registro
  de `auth` compara dos lecturas cuyo valor esperado es **cero**. Con el
  instrumento roto ---contenedor parado, otro controlador de registro--- las dos
  lecturas darían cero y habría pasado **justo cuando no puede ver nada**.

Los dos bloques exigen ahora el estado exacto de partida, esperan a que ruede la
ventana si hace falta y **abortan diciendo qué encontraron**; y antes de la
inundación se comprueba que el recuento **se mueve** con una credencial válida,
para que el cero posterior signifique algo. El mismo defecto tenía el guardián
de la propia medición.

**Un defecto real lo destapó esa prueba**, no la revisión: el contador por
cuenta se indexaba sin ámbito, de modo que todas las rutas con el limitador
compartían cupo aunque cada una declarase un número distinto, y el efectivo era
el menor de ellos. Compartir cupo entre rutas es **lo correcto** para un límite
económico ---la tasa es de la cuenta, y un contador por ruta se evade
repartiendo las llamadas entre extremos---, pero tiene que ser deliberado: la
clave lleva ahora un ámbito configurable, que es además el gancho para separar
inferencia de gestión cuando toque.

**Sobre el método, y va a §8.1: la expansión de llaves del intérprete de órdenes
como límite de la instrumentación.** Un programa de Python con un diccionario
por comprensión, incrustado en una sustitución de órdenes anidada dentro de
comillas dobles, lo **parte el intérprete** ---hay una coma dentro de llaves---:
el resultado es que la petición se ejecuta **dos veces** y el programa no
compila. Con el error redirigido a la nada, el síntoma aparece a distancia y
disfrazado: un contador una vuelta por delante de lo que la prueba cree haber
gastado, que se atribuye al sistema medido y no al instrumento. Es el mismo
patrón que el registro de acceso de la sesión 3 ---el fallo no estaba donde
apuntaba el síntoma---, y la lección es de método: **cuando la medición y el
instrumento comparten intérprete, el instrumento entra en el sistema bajo
medida**. La regla que queda en el repositorio es que el programa incrustado
vive en una función, nunca en línea.

**Lo que hereda I6, enunciado en el PR a propósito.** Los números del sustrato
---600 por minuto y dirección de origen, 300 por minuto y cuenta--- quedan **muy
por debajo** de las tasas que publica la oferta: 600 por minuto son 10 por
segundo, y un cliente del plan superior haciendo gestión a sus 200 por segundo
toparía al **5 %** de lo contratado. Hoy no lo nota nadie porque nada evalúa
planes, pero la dificultad no es elegir otro número: **el limitador de abuso
corre antes de saber quién llama**, por construcción, así que no puede conocer
el plan. Reconciliar un límite previo a la autenticación con tasas que dependen
del plan es el trabajo de I6. Se anotan también como suyos el almacenamiento
local ---por nodo, de modo que con varias réplicas el límite efectivo se
multiplica--- y la ventana fija, que admite una ráfaga del doble en el borde.

Ninguno de los dos se cambió aquí, por acuerdo explícito: este PR construye el
sustrato y no la segmentación por plan.

**La memoria se actualizó**, en `memoria_tex/v8`: siete parches en tres
capítulos, con `parches-memoria-sesion7.tex` recogiendo el reparto y el mismo
criterio de las sesiones 3 a 5. **Dos de los siete son correcciones** de texto ya
publicado, y uno de ellos ---la frase de §6.3.1 que daba la implementación por
pendiente--- lo vuelve falso la propia fusión de esta sesión: es la tercera vez
que ese párrafo se queda desfasado. Un séptimo parche documenta un defecto
**abierto**, con el precedente de la divergencia del `429`.

| Capítulo | Cambio |
|---|---|
| 4 — Diseño del servicio | `\subsection{Protección de la disponibilidad}` gana el diseño de **dos límites con sujetos distintos** ---uno por dirección de origen antes de la validación, cuyo cometido es contener el abuso y proteger al servicio que valida; otro por cuenta después, que es el que aplica las tasas publicadas--- y la consecuencia que se asume de forma deliberada: una petición sin credencial desde un origen con la cuota agotada recibe `429` y no `401`. La subsección gana etiqueta propia, porque hasta ahora el capítulo 6 enunciaba ese diseño por no tener adónde remitir |
| 6 — Implementación | Una **corrección** y material nuevo, ambos en §6.3.1. La corrección retira «su implementación queda como trabajo pendiente» y sustituye el enunciado del diseño por la remisión al capítulo 4, que es donde toca por reparto. Lo nuevo: la desviación de mecanismo y por qué era forzosa ---prioridad fija y única, y dos configuraciones del mismo mecanismo no se acumulan---, el reparto elegido y sus dos razones, que el límite por cuenta **no admite respaldo** y falla en vez de contar por origen, las cifras y su contradicción estructural con las tasas publicadas ---un límite anterior a la validación no puede conocer el plan porque todavía no sabe quién llama---, y que el almacenamiento es local por nodo y la ventana fija |
| 8 — Validación | Cuatro parches. Una **tercera aplicación del procedimiento**, cuyo objeto no es una discrepancia con la especificación sino una propiedad que la memoria afirmaba y la implementación no tenía, con el antes y el después, el diseño del instrumento de agotamiento y la lección de que **una medición heredada no es línea de partida hasta reproducirla**. `\subsection{Un defecto que no reside en ningún componente}`, nueva, con los dos juegos de cabeceras de las rutas públicas: una propiedad que no falta en ninguno de los dos servicios y falta en su composición, y que **ninguno de los dos puede corregir por su cuenta**. En §8.4, la **corrección** de «tres formas» a «cuatro» de guardián que deja de controlar sin dejar de existir, con la cuarta ---la comprobación que no puede fallar--- y sus dos manifestaciones; la acotación de validez externa a un nodo y un origen; y la advertencia de que cuando la medición y su instrumento comparten intérprete, el instrumento entra en el sistema medido |

**Sesión 8 — #95, y una premisa del capítulo 4 que era falsa.** El objeto no era
un puerto abierto: era **la frase del capítulo 4 que exige «que los
microservicios sean accesibles únicamente a través de [la pasarela]»**, y que
el propio capítulo advierte que es una propiedad de la topología y no del
código. Los dos composes de `auth` la contradecían. Se cierra en
`auth-microservice#5`.

**Lo primero que salió fue que el encargo apuntaba al párrafo equivocado**, y
eso vale más que el arreglo. El prompt aplicaba a `auth` el argumento del
microservicio **de destino** ---el que acepta la identidad ya resuelta sin
volver a verificarla---, y `auth` es el **emisor**: no lee `X-Account-Id` ni
`X-Role`, cero apariciones en `src/`, y `protect` verifica firma y cuenta contra
su propia base de datos. La sonda que el encargo pedía ---cabeceras de identidad
falsificadas contra una ruta protegida--- devolvió `401`, es decir **no
reprodujo nada**. La sesión se reencauzó en vez de fabricar la evidencia que se
esperaba. Dato para la memoria: esa frase del capítulo 4 alcanza a `pricing` y a
`fr-commercial`, **no a `auth`**; la que sí alcanza a `auth` es la de la
accesibilidad, dos párrafos antes.

**Tres agujeros, todos medidos por la IP de LAN y no por `127.0.0.1`.** Medir
por el bucle local habría sido la cuarta forma de guardián de la sesión 7 ---la
comprobación que no puede fallar---: con el puerto atado a `127.0.0.1`, un
`curl` a `localhost` sigue funcionando después del cambio y el «después» saldría
idéntico al «antes».

| | Antes | Después |
|---|---|---|
| `validate-key` por LAN, sin secreto | `HTTP 401` ---la operación responde--- | `exit=7`, conexión rechazada |
| MongoDB de `auth` por LAN, sin credencial | `CONECTADO`, `["accounts"]`, **30 documentos** | `ECONNREFUSED` |
| `INTERNAL_API_SECRET` ausente | `ARRANCA. secreto efectivo: dev_internal_secret_key_789` | `NO ARRANCA` |

El segundo **no estaba en el texto del issue** y es el peor: la colección
`accounts` ---correos, hashes de contraseña y de API KEY--- quedaba legible **y
escribible** sin pasar por el servicio. Escribir `role: "ADMIN"` en un documento
no necesita ni JWT ni secreto, y elude la regla de que `register` asigna siempre
`CUSTOMER`.

**Producción no es «lo mismo pero en el bucle local».** En desarrollo,
`127.0.0.1` compra depuración directa y `/docs` en el navegador ---el primer
`servers` del contrato, que por eso no hubo que tocar--- a cambio de dejar fuera
a la red. En producción ese lado del intercambio no existe y el coste sigue: el
bucle local es alcanzable por todo proceso del anfitrión, por un contenedor con
`network_mode: host` y, según el reenvío que haya delante, por un `ssh -L`.
Publicar en el bucle local no es «no publicar», es «publicar a todo el
anfitrión». Producción se queda **sin `ports`**, que en Kubernetes se traduce a
`ClusterIP` sin traducción.

**La guarda rechaza lo que CONSTA público, no lo que parece débil.** Mismo
patrón que `jwtExpiry` ---validar el valor, no su presencia--- y el criterio
escrito en la cabecera del fichero: la lista de literales es verificable leyendo
el repositorio, mientras que la longitud mínima y la entropía son heurísticas
que no distinguen un secreto de una cadena larga cualquiera, no detectan el
literal publicado si además es largo, y rechazan secretos legítimos por cortos.

**Y la guarda va en las dos capas, o no está.** Un valor por defecto en el
compose anula una guarda del código, porque ésta nunca llega a ver la variable
ausente. Por eso `INTERNAL_API_SECRET` lo pierde también en
`docker-compose.dev.yml` y el de producción usa `${VAR:?...}`.

**El barrido del patrón `|| '<valor>'`**: nueve apariciones, todas en
`src/config/index.js`. Entran tres. `MONGODB_URI` y `FRONTEND_URL` acompañan al
secreto porque su defecto no era inseguro sino **silencioso** ---el primero
arrancaba el servicio contra otra base de datos, el segundo metía enlaces a
`localhost:3000` en el correo de recuperación de contraseña, que es como
producción venía funcionando al no pasarlo `docker-compose.yml`---. Seis se
quedan por tener un defecto razonable. Y apareció una categoría que el patrón no
encuentra: `JWT_SECRET` y `RESEND_API_KEY`, sin defecto **y sin guarda**, que
fallan tarde con un 500 en vez de al arrancar (#99).

**Lo que el PR NO cierra, dicho en el propio compose y en un issue aparte.**
Atar el puerto a `127.0.0.1` deja fuera a la red, **no al anfitrión**: sin
autenticación en MongoDB, cualquier proceso de la máquina sigue leyendo la tabla
de cuentas (#97). Se abre para que no se dé por resuelto lo que no lo está.

**Recorrido después del cambio**, porque el riesgo real era romper lo que llama
a `auth` desde el anfitrión: 125 pruebas en verde y trinquete a 88/79/87/88; las
**cuatro** suites de shell de `api-gateway` ejecutadas sin tocarlas, las cuatro
`exit=0`; `dev-up.sh` **desde cero** con los tres `.env` borrados ---la ruta que
sufre el cambio de `.env.example`---, con el secreto generado coincidiendo entre
`auth` y la pasarela; y el canal web completo por la pasarela, de `register` a
`me`.

**La CI se tiñó de rojo por algo ajeno, y ésa es la mejor noticia de la
sesión.** El aviso `GHSA-jxfw-x594-9x9m` sobre `morgan` <1.12.0 se difundió el
**08/09 a las 21:28 UTC**, entre el último verde de `main` y el PR. `main`
fallaba igual y el diff no tocaba ninguna dependencia. Se cerró aparte, en
`auth-microservice#6` ---rama desde `main`, arreglo, fusión, y `main` traído a
`fase2/95`---, y es **cambio de lockfile y no de manifiesto**: `^1.11.0` ya
alcanzaba a 1.12.0, así que `package.json` no se toca. `pnpm update` sube además
el rango por su cuenta; se revirtió, porque subir un rango que ya alcanzaba la
versión parcheada habría hecho pasar por decisión un efecto colateral de la
herramienta.

Lo que vale para el capítulo 8 no es el arreglo sino **que nadie lo buscó**. La
sesión 6 argumentó que un guardián en rojo permanente deja de leerse, y lo
argumentó sobre un guardián que nunca había tenido ocasión de dispararse. Ahora
la ha tenido: tres ejecuciones en verde, se publica un aviso real sobre una
dependencia de producción ---`morgan` escribe una línea por petición--- y el
paso **se tiñe solo, en la primera ejecución posterior**. Es la diferencia entre
un guardián y un adorno, y no se podía afirmar antes.

De la sesión salen **cuatro issues nuevos, #97 a #100**, ninguno arreglado de
paso, más un comentario en **#74** dejando dicho que su alcance no cambia ---es
el MongoDB de producción de `pricing`, y la sesión sólo tocó `auth`--- y que el
criterio de #95 está listo para reutilizarse.

- **#97.** La autenticación de MongoDB en `auth`. Se abre **para que no se dé
  por resuelto lo que no lo está**: atar el puerto deja fuera a la red, no al
  anfitrión.
- **#98.** El MongoDB de desarrollo de `pricing`, en `0.0.0.0`. Cuarto hermano
  del mismo defecto de topología, con #74 y los dos de `auth`.
- **#99.** `JWT_SECRET` y `RESEND_API_KEY`: sin valor por defecto **y sin
  guarda**, de modo que fallan tarde con un 500 en vez de al arrancar. La
  categoría que el barrido de `|| '<valor>'` no encuentra.
- **#100.** El secreto interno estaba publicado en **tres** `.env.example`
  ---`auth`, `api-gateway` y `pricing`---, y sólo se corrigió el primero. Lo
  anotable no es el descuido sino el mecanismo: **una guarda escrita en un
  repositorio ha cambiado lo que arranca en otros dos**, sin que ningún fichero
  suyo cambiara, porque el secreto es compartido por naturaleza y su ejemplo
  estaba duplicado. El sistema queda a medio levantar y el fallo aparece en el
  componente que hizo lo correcto. Hermano del «defecto que no reside en ningún
  componente» de la sesión 7: aquél vivía en la composición de dos servicios,
  éste en la de tres ejemplos.

**La memoria se actualizó**, en `memoria_tex/v9`: ocho parches en tres
capítulos, con `parches-memoria-sesion8.tex` recogiendo el reparto y el mismo
criterio de las sesiones 3 a 7. **Uno de los ocho es corrección**, y su interés
está en la antigüedad: la frase de §6.3.2 que daba por buena la restricción al
bucle local se escribió sobre `pricing` cinco sesiones atrás, y ha sido el
trabajo sobre `auth` el que la ha delatado. **El capítulo 4 no se corrige, y eso
es un resultado**: la frase de la topología resultó cierta como enunciado de
diseño; lo que la contradecía era el despliegue, no el diseño.

El fichero de parches va por su **versión 2**. Dos de sus instrucciones
indujeron error al aplicarlas ---una mostraba solo la cola del párrafo a
sustituir, y la frase acabó duplicada; otra señalaba un punto de inserción que
partía en dos un argumento continuo y dejaba sin antecedente un «por tanto»---,
y se corrigieron en el propio fichero para que la sesión que lo relea no repita
el error.

| Capítulo | Cambio |
|---|---|
| 4 — Diseño del servicio | Un parche, material nuevo al final de `\subsection{Ventana de revocación}`. La guarda de arranque deja de leerse como particular de un parámetro y se enuncia como criterio ---un componente rechaza arrancar cuando un valor que solo el despliegue puede fijar llega ausente, o llega con uno de los que el propio proyecto divulga a título de ejemplo---, con el fundamento de que suponer es inventar y de que el arranque es el único momento en que alguien está mirando. Y su relación con la premisa de topología de la subsección anterior: **el código no puede garantizarla, pero puede negarse a constituir la segunda mitad de su fallo** |
| 6 — Implementación | Cuatro parches, uno de ellos **corrección**. La corrección retira de §6.3.2 que la configuración local «únicamente evita que el entorno de desarrollo contradiga esa premisa» y la sustituye por lo medido: la reduce sin llegar a impedirla. Lo nuevo, en la misma subsección: que **restringir al bucle local es publicar al anfitrión entero**, con las tres vías por las que sigue alcanzándose y por qué la asimetría entre entornos es deliberada y no copiada; y que el coste atribuido a la alternativa descartada ---un secreto replicado en tantos ficheros de configuración como servicios--- dejó de ser hipotético, por vía independiente de la decisión que lo invocó, con el enlace a §8.1.3. Y `\subsection{Configuración que el servicio rechaza asumir}`, nueva: el barrido de los nueve parámetros, los tres que pierden su valor supletorio por ser silenciosamente incorrectos después, el criterio de que la guarda **rechaza lo que consta público y no lo que parece débil**, y que ha de existir en dos planos o no existe |
| 8 — Validación | Tres parches. `\subsection{Una medición que no reprodujo lo que se esperaba de ella}`, nueva: el procedimiento se aplicó a confirmar una vulnerabilidad enunciada de antemano y devolvió un rechazo, porque el componente probado era el emisor de las credenciales y no un consumidor de identidad; **una no reproducción es un resultado y no un defecto del procedimiento**. En §8.4, el cierre en indicativo de un argumento que la sesión 6 solo pudo dejar en condicional ---un guardián mantenido en verde detectó un aviso que nadie buscaba, en la primera ejecución posterior a su difusión---, y la regla de diseñar la medición para que pueda fallar: **una medición idéntica entre el antes y el después solo resulta concluyente si lo que se conserva idéntico no es precisamente aquello que el cambio modifica** |

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

~~**#79 es el bloqueante.**~~ **Cerrado en la sesión 6**, junto con #90, que
salió de verificarlo. Con ellos, el repositorio de `auth` queda además con la CI
en verde de forma determinista, que era la otra mitad del criterio.

~~**El bloqueante pasa a ser #83.**~~ **Cerrado en la sesión 7**
(`api-gateway#2`). Era el vector de amplificación medido en la sesión 5: el
orden de prioridades de la pasarela dejaba fuera del límite de tasa a quien no
traía credencial, de modo que una inundación con claves inventadas no encontraba
freno alguno y cada clave distinta se convertía en una consulta a `auth`. No era
una deuda de estilo sino la desmentida de una protección que la memoria daba por
existente ---por eso arrastró la corrección del capítulo 6 y de la entrada de
«Decisiones tomadas en conversación»---. Medido antes y después con el mismo
script: de **cero `429` y 25 de 25 llegando a `auth`** a **25 de 25 en `429` y
ninguna llegando**.

**La fase 1 se queda sin bloqueante.** Lo que sigue con etiqueta `fase:1` es lo
que ya estaba señalado como aplazado deliberadamente, más el que este documento
sigue aparte:

| Issue | Qué es | Destino |
|---|---|---|
| **#74** | el compose de producción de `pricing` publica el puerto de su MongoDB | fase 2 |
| **#81** | la prueba que le falta a `identity-headers.sh` para cubrir la única línea de la que depende hoy que el canal de API llegue siempre con `X-Role` | fase 2 |
| **#85** y **#86** | supresión de la cuenta y separación entre pausa y sanción; #85 no puede ir antes que #86 | fase 2 |
| **#63** | siembra de la cuenta administradora inicial | sin decidir, ver «Pendiente de decidir» |

Los cuatro se aplazaron **de forma deliberada, no por olvido**, y el criterio fue
que ninguno bloquea `fr-commercial`. **#63 es el único que hoy produce desajuste
entre `gh issue list --label fase:1` y este documento**, y por eso se sigue
aparte en «Pendiente de decidir» en lugar de darlo por planificado.

Dos que podrían parecer que faltan y no faltan. **#64** sigue siendo fase 3, por
lo ya escrito arriba. Y **#80 dejó de contar en la sesión 6**, al comprobarse
que **su premisa era falsa**: el `overrides` de axios no silencia al escáner,
**fuerza** la versión parcheada. Medido sobre `main`, retirarlo devuelve 23
avisos de axios al árbol de desarrollo ---25 en total, con los dos de
`browserslist`--- a cambio de nada, porque `--prod` ya los deja fuera de
alcance. Queda abierto con esa corrección escrita en su comentario, propuesto
para cerrarse como improcedente.

De la sesión 7 salen además **cuatro issues nuevos**, ninguno bloqueante:

- **#93** — `api-gateway` es el único repositorio de servicio sin integración
  continua. Se comprobó contra la API de GitHub: cero flujos de trabajo y cero
  comprobaciones sobre `main`, de modo que su PR se fusionó sin comprobación
  porque no hay ninguna. Alcance mínimo: validación declarativa de `kong.yml` y
  `luacheck` sobre `plugins/`.
- **#94** — el README de la pasarela funde las dos ventanas de revocación ---la
  del JWT, acotada por la guarda de arranque a [5 min, 2 h], y la del veredicto
  cacheado, del orden del minuto--- en una cifra de 60 minutos que no es de
  ninguna de las dos.
- ~~**#95** — el compose de `auth` publica el puerto del servicio en `0.0.0.0`,
  y con ello la terminación de `validate-key` en la pasarela deja de proteger
  nada. **No es un defecto solo de desarrollo**: el compose de producción
  publica el puerto del servicio *y* el de MongoDB. Hermano de **#74**.~~
  **Cerrado en la sesión 8.**
- **#96** — en las rutas públicas salen dos juegos de `RateLimit-*`, con
  `RateLimit-Limit` dos veces ---600 de la pasarela y 100 de `auth`---, emitidos
  por componentes de repositorios distintos. Lleva anotadas las dos líneas de
  README que quedaron pendientes al cerrar #83, que se escriben al arreglarlo.

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
- **El limitador de tasa de `auth` va por operación**, montado solo en `login`,
  `forgot-password` y `reset-password`. **La decisión se mantiene; su motivo
  original ha dejado de valer y se sustituye.** Se justificaba en que montarlo
  global produciría `429` en operaciones que no lo declaran, es decir,
  respuestas no conformes; desde la sesión 5 **las 46 operaciones alcanzables
  por la pasarela declaran `429`**, incluidas las públicas de `auth`, porque el
  criterio es la alcanzabilidad y no la protección. Esa objeción ya no existe.
  Y la coletilla de que «el límite general es responsabilidad de Kong (I6)»
  también caducó: **el límite general existe desde la sesión 7**; lo que queda
  en I6 es la segmentación por plan, los números y el almacén compartido, no la
  existencia del límite.

  El motivo que sí la sostiene, y que además está medido, es que **los dos
  limitadores atacan ataques de forma distinta y quieren ventanas distintas**.
  El de la pasarela es de inundación: 600 por minuto y dirección de origen,
  generoso, pensado para que una ráfaga no tumbe a `auth`. El de `auth` es de
  relleno de credenciales, que es lento por naturaleza: 100 **cada quince
  minutos**, es decir 6,7 por minuto sostenidos, un número que el limitador de
  la pasarela no alcanza a ver porque su ventana dura sesenta segundos. Montarlo
  por operación y no sobre todo `/v1/auth` mantiene ese presupuesto estrecho en
  las tres rutas atacables por fuerza bruta sin racionar las demás, que no lo
  son. Medido en la sesión 7: con el de la pasarela por delante, el de `auth`
  **sigue disparando y dispara primero**, y el cuerpo del `429` es el suyo.
- **La vigencia del JWT tiene guarda de arranque** en el rango [5m, 2h]. La
  memoria argumenta la ventana de revocación sobre 60 minutos y nada impedía
  que un despliegue la contradijera en silencio.
- **`DELETE /faces/{faceId}` devuelve `409` si es el único rostro**, en lugar
  de eliminar la identidad en cascada. Un `DELETE` sobre un subrecurso no debe
  destruir su recurso padre, y el caso de uso habitual —sustituir la única
  fotografía— perdería el `identityId` y el `externalId`.
- **Tres categorías de test con frontera nítida, en `auth` y en `pricing`:**
  `contract/` verifica lo que la especificación puede expresar; `unit/` verifica
  reglas que ninguna especificación puede expresar (claims del JWT, vigencia);
  `legacy/` documenta el comportamiento anterior. Que existan las dos primeras
  **es** el argumento de que OpenAPI no basta como fuente única.

  **La taxonomía es de esos dos servicios, no del proyecto.** Las suites de la
  pasarela son de otra naturaleza ---guiones contra un despliegue vivo, no
  derivadas de una especificación--- y no encajan en ninguna de las tres. No se
  les inventa una cuarta categoría: lo que hay que dejar escrito es el alcance
  real de la clasificación.
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
  corrigió**. Se venía diciendo que la inundación con claves inventadas la
  cubría el límite de peticiones, y la sesión 5 lo desmintió midiéndolo: el
  plugin de autenticación tenía más prioridad que el limitador, así que en rutas
  protegidas cortaba antes de que este contase, y con la cuota global ya agotada
  25 claves aleatorias distintas dieron **cero `429`** y 24 llegaron hasta
  `auth`. Cada clave tiene un resumen distinto y por tanto una entrada de caché
  distinta, de modo que la caché negativa tampoco absorbe nada.

  La protección real exige **dos limitadores**: uno amplio por dirección de
  origen **delante** de la autenticación, que corta la inundación y protege a
  `auth`, y otro por cuenta **detrás**, sobre la identidad que la pasarela ya
  escribe, que es el que implementará las tasas por plan y hará falta
  igualmente. Bajar solo la prioridad frenaría una dirección y no muchas, y
  cambiaría la superficie de error de todas las rutas protegidas.

  **#83 queda cerrado en la sesión 7, y ese argumento se conserva intacto:
  posición, clave y naturaleza de los dos limitadores son exactamente los que
  aquí estaban escritos.** Lo que cambió al implementarlo fue el **mecanismo**.
  Esta entrada los describía a los dos en vocabulario del limitador que Kong
  trae de serie ---`limit_by: ip` y `limit_by: header`---, y eso no es
  implementable: **la prioridad de un plugin es fija y única**, de modo que dos
  configuraciones del mismo no pueden quedar una a cada lado de la
  autenticación; y además **dos instancias del mismo plugin no se acumulan**, la
  más específica sustituye a la global, lo cual se midió. Uno de los dos tiene
  que ser extensión propia. El de abuso es el de Kong, para que el camino de la
  inundación descanse sobre código de la plataforma; el de cuenta es propio,
  que es donde caben las tasas por plan que el de serie no puede aplicar sin
  conocer el plan. La corrección del capítulo 6 de la memoria sigue siendo la
  aplicable en cuanto al diseño; su última frase, que dejaba la implementación
  como trabajo pendiente, deja de serlo.
- **El limitador por cuenta no cae a la dirección de origen cuando le falta el
  identificador: falla con `500`.** El limitador que Kong trae de serie sí cae
  ---su resolución de identificador termina en un «o la dirección reenviada»---,
  y hacerlo en silencio sería un control que aparenta contar y no cuenta:
  montado por descuido en una ruta donde la validación no corre, seguiría
  respondiendo con normalidad mientras cuenta por algo que no es la cuenta.
  Y no depende de la cabecera, que sería insuficiente: en una ruta sin
  validación la cabecera que llega es la del cliente, y el limitador habría
  contado ese valor tan campante. **La validación deja marca en el contexto de
  la petición y el limitador la exige**, de modo que montarlo donde no debe
  falla también **con la cabecera falsificada**. Las dos vías están fijadas con
  prueba.
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
  que #65 concentra en la pasarela. La garantía real es el `ClusterIP` de
  Kubernetes, no el compose.

  ~~**Lo del puerto vale para `pricing` y no para `auth`, y conviene no leerlo
  como general.**~~ **Cerrado en la sesión 8.** El argumento se conserva entero
  porque sigue siendo el bueno: en `pricing` el puerto dejaba de publicarse en
  el compose de producción y en el de desarrollo quedaba atado a `127.0.0.1`,
  mientras que el de desarrollo de `auth` lo publicaba en `0.0.0.0`. **Lo que
  importa no es el puerto sino qué control puentea**: la pasarela termina
  `POST /v1/auth/validate-key` con `request-termination` precisamente para que
  no se alcance desde fuera ---era un bloqueante de la auditoría---, y con el
  puerto publicado esa terminación no protege nada, porque se llega al servicio
  sin pasar por ella. Lo único que quedaba sobre un extremo que valida
  credenciales era el secreto interno, que la propia auditoría situó en **tres
  ficheros `.env`**.

  Lo que añade el cierre, y no estaba en el enunciado: **atar el puerto al
  bucle local deja fuera a la red, no al anfitrión**. Sin autenticación en
  MongoDB ---que `auth` no tiene---, cualquier proceso de la máquina sigue
  leyendo la tabla de cuentas. Por eso el cierre vino acompañado de #97 en vez
  de darse por completo, y por eso los tres ficheros `.env` son #100: la
  corrección de uno solo deja el sistema a medio levantar.
- **Las cabeceras de identidad se exigen completas y con valores cerrados.** Sin
  respaldo al JWT y sin valores por defecto, porque un valor por defecto es
  inventar identidad. Por el camino legítimo es inalcanzable ---la guarda del
  plugin corta antes---, así que solo actúa contra quien se salta la pasarela.
- **La traza de pila no viaja en el cuerpo en ningún entorno.** Desde la sesión
  6 rige en `auth` y en `pricing` por igual: la divergencia que este documento
  registraba ---`auth` la dejaba en `details` en desarrollo, «cuya alineación es
  #79»--- **ya no existe**. Va al registro, y solo cuando el error no es
  operacional; un error operacional es un camino previsto del contrato, no un
  fallo que haya que depurar.
- **Las CI auditan con `pnpm audit --prod`.** Auditan lo que se despliega. En
  `pricing` bastó con eso: los avisos venían todos de una dependencia fantasma de
  una herramienta de test. En `auth` **no bastó**, y la diferencia importa: al
  quitar el ruido quedó a la vista `qs`, que sí se ejecuta en producción, de modo
  que hizo falta además forzar la versión parcheada. Un `--prod` que deja el paso
  en rojo no es un guardián en verde, es un guardián que sigue sin leerse.

---

## Pendiente de decidir

- **Qué hacer con `RESEND_API_KEY`.** No puede ser obligatoria en desarrollo
  ---se trabaja sin ella y el arnés usa una falsa---, de modo que la guarda de
  arranque que se le aplicó a las demás no le vale tal cual. ¿Se exige sólo con
  `NODE_ENV=production`, o el servicio arranca sin ella y **degrada el envío de
  correo de forma explícita** en vez de reventar en la primera recuperación de
  contraseña? Es la mitad de #99 que sigue siendo una pregunta; la otra mitad,
  `JWT_SECRET`, no lo es.
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

  **La sesión 7 aporta el primer precedente en funcionamiento de la primera
  opción**, y con sus costes ya medidos en lugar de estimados: el limitador por
  cuenta es una extensión propia de la pasarela y funciona, pero paga almacén
  local ---por nodo, de modo que con varias réplicas el límite efectivo se
  multiplica---, ventana fija ---con ráfaga del doble en el borde---, un cuerpo
  de error escrito a mano en la extensión porque el formato de la plataforma no
  admite el campo que el contrato exige, y un diccionario compartido que hay que
  declarar **fuera** del plugin, como directiva del servidor, porque la edición
  libre de Kong no permite declararlo desde él. Nada de esto decide la cuestión:
  el límite en unidades necesita además el consumo acumulado de la cuenta, que
  la pasarela no tiene. Pero el coste de la vía «extensión» deja de ser una
  incógnita.

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
