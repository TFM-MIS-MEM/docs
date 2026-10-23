# ESTADO — TFM: SaaS multicanal de reconocimiento facial

> Documento de continuidad. Se actualiza al cerrar cada sesión de trabajo.
> Su función es sustituir a la relectura de conversaciones anteriores.
>
> **Última actualización:** sesión 21: la tarifa definitiva en los issues y
> en el contrato de fr (fr#13); #62 cerrado. Siguiente paso: F9 (#41) y F10
> con SPACE (#42, #51).

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

**Sesión 9 — F1 (#33), el bootstrap de `fr-commercial`.** El objeto no era
escribir el servicio sino fijar el patrón que heredan 27 operaciones y
demostrarlo una vez. Se hizo en dos paradas: la primera resolvió las dos
decisiones que ESTADO dejaba pendientes; la segunda, dónde vive la prohibición
de campos no declarados (el «punto 3», más abajo). El bootstrap avanzó entre
una y otra, y el arnés se escribió después de la segunda. Fusionado en `main`
con commit de fusión (`13db3fd`, PR #1), para que los commits del rojo-verde que
cita esta entrada sigan existiendo; la CI de `main` tras la fusión, en verde
(`36564465692`, 197).

**Decisión 1: la identidad va en una dependencia de FastAPI montada por router,
no en un middleware.** Medido con seis montajes y los mismos casos. Un
middleware corre fuera de la capa de excepciones: si lanza el error de dominio,
sale `500 text/plain`, y con el manejador genérico, `500` en JSON; para cumplir
`ErrorReport` tiene que escribir su propio cuerpo, un segundo emisor del
esquema, que es la clase de divergencia de #66 y #79. La dependencia lanza y la
atiende el mismo manejador que a todo lo demás. Tres diferencias con la
referencia de Express, todas medidas:

- `Header()` no sirve: la ausencia sale `422`, acepta un `X-Account-Id` en
  blanco y duplicados, y mete las tres cabeceras como parámetros en el
  `/openapi.json` generado.
- **Duplicados.** `request.headers.get()` devuelve la primera: `X-Role: ADMIN`
  más `X-Role: CUSTOMER` daba `ADMIN`. Se exige exactamente un valor con
  `getlist`. La referencia de `pricing` rechaza la `X-Role` repetida **por
  accidente** ---Node une los valores con `", "` y la unión cae fuera del
  conjunto--- y **acepta un `X-Account-Id` repetido como la cuenta `"acc1,
  acc2"`**: #101. `fr-commercial` es en eso más estricto que su referencia.
- **Orden respecto al cuerpo.** FastAPI lee el cuerpo antes de resolver las
  dependencias. Medido con 50 MiB sin cabeceras: con `UploadFile = File(...)`,
  **50 MiB leídos y volcados a disco** (`SpooledTemporaryFile`, a disco por
  encima de 1 MiB) **antes del `401`**; con un cuerpo JSON, 50 MiB leídos en
  memoria; leyendo `request.stream()` después de la dependencia, cero. **Es un
  coste que hereda F5** (#37) y toda operación multipart ---F4, F8, F12---: por
  el camino legítimo no se paga, porque la pasarela rechaza antes de proxiar, y
  lo paga quien alcance el servicio saltándose la pasarela, que es justo lo que
  la topología impide. Si F5 no quiere depender solo de eso, la vía medida es
  leer el fichero del flujo después de la identidad y no declararlo como
  parámetro.

**Decisión 2: openapi-core para validar cada respuesta, más la comparación del
`/openapi.json` generado contra el `.yaml`. Schemathesis no.** Con un servicio
«mentiroso» que sirve respuestas deliberadamente no conformes contra el contrato
sin tocar, `APIOperation.validate_response` de Schemathesis ---el análogo
natural de `toSatisfyApiSpec()`--- **deja pasar un `422`, un `400` y un `500` no
declarados y un tipo de contenido erróneo**, por diseño: su validador devuelve
`None` cuando el estado no está documentado. Con todas sus comprobaciones por
omisión marca como fallo una respuesta conforme (`ignored_auth`), falso positivo
estructural en un servicio que no verifica credenciales. openapi-core, en una
sola llamada y por omisión, caza el estado no declarado, el tipo de contenido
ajeno, el obligatorio que falta, el tipo, el formato y el `enum`, y es el único
que rechaza `frozenReason: null`, con razón (#103). **No caza dos cosas:** el
campo de más ---ningún esquema del contrato lo prohíbe, y entonces es
conforme--- ni el cuerpo en una respuesta que no declara `content`, como un
`204` con cuerpo, que jest-openapi sí cazaba. La comparación estática hace falta
además porque es lo único que ve el lado de la petición: con `pageSize` sin su
cota de 100, `pageSize=1000` da un `200` **conforme**, y solo la comparación lo
delata.

**Desde F3 (#35), un caso negativo por cada parámetro acotado.** La validación
de respuestas es ciega a lo que el servicio acepta; cada cota del contrato
(`maximum`, `enum`, `minimum`) necesita su petición fuera de rango en la
batería. Y ningún listado puede cumplirlo hasta que #103 declare el `400`:
medido, para `pageSize=101` no existe implementación conforme ---aceptar,
`400` y `422` fallan los tres---.

**La operación de extremo a extremo es `getGallery`**: RETRIEVAL, cero unidades,
sin plan ni Redis ni parámetros de consulta, y con `X-Account-Id` como lo único
que decide entre `200` y `404`. La galería de otra cuenta es `404`, **también
para `ADMIN`**, e idéntico al de una inexistente: el contrato reserva su `403` a
la pasarela, un `403` confirmaría que la galería existe, y `ADMIN` gobierna la
gestión de cuentas en `auth`, no los datos biométricos de otros clientes. Los
campos opcionales se omiten uno a uno, sin `exclude_none` global: ninguno de los
tres opcionales de `Gallery` admite `null`. La frase vale para `Gallery`, no para
el contrato: `Identity.externalId`, `WebhookEndpoint.lastDeliveryAt` y cuatro
campos de `WebhookDelivery` sí lo admiten, y es exactamente por lo que la
omisión se nombra campo a campo.

**Evidencia, por commit** (rojo-verde registrado):

| Commit | Resultado |
|---|---|
| `e2d81e2` pruebas, contra la plantilla | 1 pasa · 3 ficheros sin colección · 27 `TypeError: create_app() takes 0 positional arguments` |
| `c0362f0` núcleo | 139 pasan · 25 fallos, una causa: `getGallery` no existe |
| `8da3996` getGallery | 164 pasan |
| `ac068e7` arnés | 191 pasan · 6 fallos en `test_shape.py`, una causa: el esquema generado de `Gallery` era `{}` |
| `8166f23` corrección del modelo | 197 pasan |

Las dos últimas filas son el rojo-verde más informativo de la sesión: la causa
del rojo no era código que faltaba, sino un defecto real que ninguna prueba de
extremo a extremo veía (véase «La comparación cazó un defecto real»).

**Guardianes que pueden fallar, comprobado.** Once defectos inyectados sobre una
copia, once rojos, cada uno en su prueba. El más instructivo: con el campo del
filtro mal escrito (`account_id`), los `404` seguirían pasando; los pone rojos
**solo** que cada `404` va emparejado con el `200` del propietario sobre la misma
galería.

**El determinismo se sostiene en el mecanismo**, no en las repeticiones: un
`TestClient` por prueba abierto como gestor de contexto ---su `lifespan` abre y
cierra la conexión del servicio---, siembra por un cliente síncrono que ha
escrito antes de que la petición salga, base de datos única por sesión y
colecciones borradas antes de cada prueba, sin orden entre ellas ni reloj ni
aleatoriedad en lo comparado. Las tandas acompañan: 30 × «164 passed» antes del
arnés, 30 × «197 passed» después.

**Dos guardias que fallaban por el motivo equivocado, las dos mías y cazadas
antes de darlas por buenas.** El `:?` del compose de producción llevaba «: » en
el mensaje, YAML leía el elemento como un mapa y el compose fallaba **también con
la variable definida**: la comprobación de «ausente → exit=1» pasaba sin
significar nada. Se detectó por medir también el caso con valor. Y la prueba del
bucle local por la IP de LAN imprimió `exit=0` porque era el código de `tail`,
no el de `curl`; repetida sin tubería, `curl_exit=7`, y con control: esa misma IP
sí alcanza el 8000 de Kong. Es el patrón de la sesión 7: cuando la medición y el
instrumento comparten intérprete, el instrumento entra en lo medido.

**Lo demás, verificado:** la imagen de producción no arranca sin `MONGODB_URI`
ni con ella en blanco, y con ella sirve un `/openapi.json` idéntico al `.yaml`
desde el contenedor, como `appuser`; `dev-up.sh` termina con `exit=0` con `fr`
levantado a la vez ---un primer intento falló en los tres servicios por
`DeadlineExceeded` de Docker Hub, antes de tocar puertos ni redes, y el registro
tardó 77 s en servir `node:22-alpine`---; y la CI del PR, en verde cuatro veces,
siempre con `pip-audit` sobre el árbol de producción («No known vulnerabilities
found») y cobertura 98,21 % sobre trinquete 98: `36422552795`, con el bootstrap,
164 pruebas; `36552127024`, con el arnés, 197; `36558548472`, con la base
anclada, 197; `36564274985`, con la comprobación previa de MongoDB y sin capa de
`apt-get`, 197. La auditoría es el equivalente de `pnpm audit --prod` gracias a
que las dependencias se fijan con resúmenes (`requirements.txt`) y la imagen
instala con `--require-hashes`: con los `>=` de la plantilla, la imagen resolvía
el árbol al construirse y la auditoría habría mirado otro. `pip-audit` sale con
1 tanto con avisos como sin red, así que el paso lleva el reintento de `auth`.

**Sin MongoDB, la suite falla en voz alta y en segundos.** Medido con el
contenedor parado y la suite entera como en la CI. **Antes:** 161 pasan, **37
errores** ---36 en la preparación de las pruebas que usan base, 1 en el
desmontaje de la sesión---, 0 saltadas, la cobertura cae a 77 y el trinquete
también falla, sale con 1, en **207 s**: cada prueba agotaba por su cuenta los
5 s de selección de servidor y repetía `ServerSelectionTimeoutError`.
**Después**, con un `ping` único al abrir la sesión (`tests/conftest.py`): 161
pasan, 36 errores que llevan todos el mismo mensaje ---«MongoDB no responde en
fr-commercial-mongodb:27017 (TEST_MONGODB_URI): ServerSelectionTimeoutError.
Levántelo antes de ejecutar las pruebas: …»---, sin error de desmontaje, 0
saltadas, sale con 1, en **8 s**. Con base, la suite entera igual que antes: 197
pasan. El mensaje se lanza fuera del `except`: dentro, pytest imprimía antes la
excepción encadenada y lo enterraba.

**La imagen base, anclada por resumen** en `Dockerfile` y `Dockerfile.dev`
(`python:3.11-slim@sha256:e41613d4…`, Debian 13.7). El PR afirmaba que la imagen
instala exactamente el árbol auditado, y era cierto para las dependencias de
Python y falso para la base sobre la que corren. **Las cifras de Trivy**, del
2026-09-29, solo paquetes del sistema, HIGH y CRITICAL: la copia local de
`python:3.11-slim` del 31/08 (Debian 13.6) daba **54 HIGH y 3 CRITICAL, 13 con
arreglo publicado**; la etiqueta recién bajada, que es el resumen anclado, **44
HIGH, 0 CRITICAL y ninguno con arreglo**; `node:22-alpine`, 0. El mismo `FROM`,
dos resultados según la caché. Actualizar la base pasa a ser un commit
deliberado. **Sin salvedad:** la sonda de salud del compose de desarrollo, lo
único que usaba `curl`, pasa a `python -c` con `urllib`, y la capa de `apt-get`
desaparece de las dos imágenes ---el historial solo muestra `apt-get` en las
capas de la propia base, que el resumen fija---; el servicio queda `healthy`, y
la sonda sale con 1 contra un puerto sin servicio y contra un `404`. La CI no
construye la imagen, de modo que el anclaje se verificó en local: las dos
construyen y la de producción responde `/health` 200. Quién vigila la base, y
con qué, queda en #108.

**Desviaciones de la plantilla, escritas en el código:** `pymongo.AsyncMongoClient`
en lugar de `motor`, deprecado desde el 14/05/2026 según sus propios metadatos
(#107); fuera `slowapi` ---detrás de Kong era un único cupo para todos---, fuera
`CORSMiddleware` con `["*"]` y credenciales, fuera `/api/v1`.

De la sesión salen **nueve issues, #101 a #109**, ninguno arreglado de paso: el
`X-Account-Id` duplicado y el `cors()` de `pricing` (#101, #102); los dos
defectos del contrato de `fr`, a corregir en **un solo PR antes de F3** (#103);
el bloque comentado de `kong.yml`, que apunta a un contenedor que no existe
(#104); `dev-up.sh` sin `fr` (#105); el MongoDB de `fr` sin autenticación, **que
bloquea F4** (#106); `motor` en la plantilla (#107); que **ninguna de las tres
CI audita el sistema operativo de la imagen base** ---`pip-audit` y `pnpm audit`
no lo ven; las cifras de Trivy, en «La imagen base, anclada por resumen»---
(#108); y `CLAUDE.md` desfasado en dónde se evalúa el
canal de API y dónde vive `fr-commercial.yaml` (#109). El alcance de la vía C
quedó además escrito en #103, que es donde se ejecuta.

**Punto 3: la prohibición de campos no declarados va en el contrato (vía C).**
Ninguno de los 36 esquemas de objeto del contrato cierra `additionalProperties`
---el único que lo menciona, `ErrorReport.details`, lo declara abierto---, así
que ningún validador puede cazar un campo de más: es #88 extendido a todo el
contrato. Se midieron cuatro vías:

- **A, un auxiliar en el arnés** que trate como cerrado lo que el esquema no
  abre. Es un segundo contrato, invisible para quien consume el primero, y el
  riesgo no es de principio: el auxiliar escrito para la decisión 2 **no sabía
  de `allOf`** y dejaba pasar en silencio un `accountId` en el `201` de
  `createWebhook`; cerrando cada subesquema por separado, rechaza el `201`
  legítimo por sus ocho campos. Solo lo hace bien uniendo las propiedades de
  los miembros, que es reescribir `unevaluatedProperties` a mano. La
  justificación de §8.1 para una comprobación explícita ---«el esquema no puede
  prohibirlo»--- no se sostiene: C lo prohíbe, medido.
- **B, estructural**: filtrado por `response_model`, comparación estática de
  las 2xx y lint (TID251). **Descartada por su agujero:** los errores no pasan
  por `response_model` y `details: dict[str, Any]` no se puede filtrar por
  construcción, de modo que deja a una heurística justo el camino por el que
  filtró #79. Además la regla no queda escrita en ninguna parte: sale del
  `extra="ignore"` por omisión de Pydantic más tres mecanismos que se tapan los
  huecos unos a otros (TID251 no ve `extra='allow'`, `response_model=dict` ni la
  ausencia de modelo; la comparación sí, pero no ve un `JSONResponse` a mano).
- **C, cerrar en el contrato** (`additionalProperties: false`). De los 36, 35
  se pueden cerrar ---`details` es abierto a propósito--- y ~~34~~ **33**
  (véase la sesión 10) se cierran sin más. **Hay una sola composición `allOf`
  de más de un miembro en todo
  el contrato**: el `201` de `createWebhook`, `allOf: [WebhookEndpoint,
  {secret}]`. Cerrar `WebhookEndpoint` tal cual rechaza el `201` legítimo
  («Additional properties are not allowed ('secret' was unexpected)»). El
  arreglo en 3.0.3, medido: un `WebhookEndpointBase` abierto con las
  definiciones; `WebhookEndpoint` como `allOf: [Base]` más los **7 nombres** en
  `properties` y `additionalProperties: false`; el `201` como `allOf: [Base,
  {secret}]` más los **8 nombres**. Su coste son dos listas de nombres que
  mantener, ~~y el olvido falla en voz alta~~. **Falso en la dirección
  peligrosa, medido en la sesión 10:** un nombre que falta en una lista hace
  ruido solo si alguna prueba emite ese campo; un nombre que sobra se admite
  con cualquier valor y el validador calla ---`secret` de más en la lista de
  `WebhookEndpoint` y un `getWebhook` con el secreto **pasa**---. Lo ve solo
  la guardia estática de `test_closure.py`. Y el recuento también estaba mal:
  el miembro `{secret}` no se cierra directamente (véase la sesión 10). La
  frase de §8.1 «basta prohibir los
  campos adicionales» es falsa tal como está: vale para ~~34~~ **33** esquemas
  (véase la sesión 10) y para este exige reestructurar.
- **D, migrar el contrato a 3.1** y cerrar con `unevaluatedProperties`. Sin
  nombres repetidos y resolviendo de paso el `nullable` de #103, **pero con una
  trampa medida: openapi-core ignora los hermanos de `$ref`**. La forma
  idiomática, `{"$ref": Base, "unevaluatedProperties": false}`, no cierra nada
  y calla: un `secret` en `getWebhook` pasa. Solo cierra envolviendo,
  `{"allOf": [{"$ref": Base}], "unevaluatedProperties": false}`.

**Decidido C, en 3.0.3.** Alcance: los esquemas propios de `fr`, de respuesta y
de petición. **`ErrorReport` se queda fuera y espera a #88**: es idéntico en los
tres contratos y cerrarlo solo en `fr` rompe esa igualdad. Cerrar los cuerpos de
petición obliga a `extra='forbid'` en los modelos de entrada ---campo de más,
`400`, que declaran todas las operaciones con cuerpo--- y también en los de
respuesta, porque si no la comparación estática da `contrato=False` frente a
`código=None` en cada esquema. **C no entra en F1**: va en el PR único de #103,
antes de F3, con la DoD y la memoria detrás. La contrapartida se escribe en ese
PR: cerrar las respuestas cuesta compatibilidad hacia delante ---un cliente que
valide contra el contrato rechazará un campo que se añada---, y se paga porque
añadir un campo ya es, por método, un cambio de contrato. Pendiente de medir para
cuando se plantee D: si `jest-openapi` admite 3.1, porque migrar un contrato solo
deja los tres sin comparar.

**El arnés, en `tests/contract/`.** `harness.py`: openapi-core sobre el contrato
sin tocar, con un adaptador de httpx que además exige cuerpo vacío donde la
respuesta no declara `content`, y `assert_bare_error`, la única comprobación
explícita que queda y que es **estructural**: un error que no es de dominio lleva
exactamente `code` y `message`. No busca marcas como `stack` en el cuerpo.
`shape.py`: la comparación del `/openapi.json` generado contra el canónico ---
parámetros y respuestas 2xx de cada operación implementada; los estados de error
no, que ahí son ruido---, con un normalizador de 3.1 a 3.0.3 que **se niega**
ante una clave que no sabe comparar (`Field(gt=-1)` → `exclusiveMinimum`) y ante
cuerpos de petición, hasta F3. `test_harness.py` es el **servicio mentiroso**,
permanente: 20 respuestas servidas por HTTP en las rutas canónicas, con el
veredicto afirmado en los dos sentidos. El campo de más en `Gallery` está entre
las que **pasan**, con el porqué escrito: cuando #103 cierre los esquemas, esa
fila se pondrá roja sola. `test_shape.py` lleva cada control negativo emparejado
con su gemelo correcto: `pageSize` con `le=100` da `[]`, sin él da exactamente
`parámetro query:pageSize [maximum]: código=None contrato=100`; un modelo de
respuesta con `extra='allow'` da `additionalProperties: código=True
contrato=None`. Toda respuesta de las pruebas de `getGallery` pasa por el arnés.

**Para F3, un punto ciego del guardián, escrito en `test_identity_guard.py`.**
El guardián solo ve lo que sale en `app.openapi()`. Medido: una ruta montada con
`include_in_schema=False` no aparece ahí, así que ni rompe la igualdad con
`IMPLEMENTED` ni entra en la prueba de `401`; sigue dando `401`, porque la
dependencia está en el router, pero ninguna prueba lo afirma. `IMPLEMENTED` es
una lista literal a propósito: si se calculara, el guardián compararía lo
servido consigo mismo. Y en el docstring de `identity.py`, el coste del orden
frente a Express: el orden es el mismo, el coste no ---`express.json()` corta en
100 kB por omisión y en 10 MB en `auth` y `pricing`; aquí se leyeron 50 MiB en
memoria antes del `401`, sin tope---.

**La comparación cazó un defecto real en su primera ejecución.** El
`model_serializer` de `Gallery` llevaba `-> Any`, y Pydantic deriva de esa
anotación el esquema de serialización, que es el que FastAPI publica: el esquema
generado de `Gallery` era `{}`. Las respuestas salían bien y ninguna prueba de
extremo a extremo lo veía. Después, doce defectos inyectados sobre una copia
---en el arnés, en la comparación y en el servicio, entre ellos volver a poner
el `-> Any`---, doce rojos. El que justifica la
comparación: con `extra='allow'` en el modelo del servicio, **ninguna** prueba
de extremo a extremo falla, porque la respuesta se construye campo a campo; solo
la comparación lo ve.

**La memoria se actualizó**, en `memoria_tex/v10`: ocho parches en tres
capítulos, con `parches-memoria-sesion9.tex` recogiendo el reparto y el
mismo criterio de las sesiones 3 a 8. **Uno de los ocho es corrección** de
texto ya publicado, y su interés está en que lo corregido no era una
apreciación sino un enunciado de coste: §8.1 daba por suficiente prohibir
los campos adicionales, y la medición muestra que no lo es allí donde un
esquema se compone de otro. **Un noveno parche se aplazó a propósito**: el
que enunciará en el capítulo 4 que el contrato prohíbe además lo que no
declara. El cambio de contrato se ejecuta en #103, y describir en la
memoria una propiedad que las especificaciones todavía no tienen induciría
a error a quien la lea antes. Se escribirá en el fichero de parches de esa
sesión.

| Capítulo | Cambio |
|---|---|
| 4 — Diseño del servicio | Un parche, `\subsection{Autorización sobre los recursos de la cuenta}`, nueva en §4.8. La autorización se reduce a la pertenencia del recurso a la cuenta; el recurso ajeno se responde como inexistente y **con idéntico contenido**, porque distinguirlos convierte cada operación en un oráculo de existencia sobre los datos de otro cliente, que en un servicio biométrico es un indicio sobre las personas registradas; y el rol administrativo gobierna el ciclo de vida de las cuentas, no los datos que cada cliente deposita |
| 6 — Implementación | Dos parches. §6.3.2 gana la traducción de la implementación de referencia al segundo entorno de ejecución: por qué el rechazo vive en una dependencia y no en una intercepción previa ---un solo emisor del informe de error---, el coste que eso impone a ocho de las veintisiete operaciones ---el cuerpo se recibe y se vuelca entero antes de decidir sobre la identidad, sin el tope que aplican los otros dos servicios--- y las diferencias menores donde lo idiomático no coincide con lo correcto. Y `\subsection{Comprobación de conformidad en el segundo entorno de ejecución}`, nueva: las dos piezas, por qué ninguna sustituye a la otra, y las dos reglas de construcción del arnés ---cuerpo vacío donde no se declara contenido, y un comparador que se detiene ante lo que no sabe comparar--- |
| 8 — Validación | Cinco parches. Una **corrección** en §8.1: prohibir los campos adicionales no basta donde un esquema se compone de otro, con el único caso del contrato y su coste. En la misma sección, que la conformidad es **relativa a la lectura del validador** ---dos herramientas conformes discrepan sobre el mismo documento, y la exigencia de cuerpo vacío la sostenía la biblioteca y no la especificación---, y `\subsection{Un defecto que ninguna prueba de comportamiento podía observar}`, nueva, con el esquema publicado vacío y los doce defectos inyectados como control. En §8.4, la pregunta «bajo qué condición habría fallado» dirigida a la herramienta y no a la comprobación, más el perímetro del guardián de dependencias, que no audita el sistema de la imagen base; y al cierre del capítulo, dos fallos de instrumento, uno de ellos por segunda vez |

**Sesión 10 — #103, la primera cuyo objeto es el contrato y no el código.** La
regla del proyecto ---contrato, luego DoD, luego memoria--- se había citado ocho
veces sin ejercerse en ese orden, porque hasta ahora los contratos no se
tocaban. Aquí el `.yaml` cambió primero, y el código y las pruebas fueron
detrás. Resultado: `fr-commercial-microservice` PR #2 (rama `fase2/103`, seis
commits), fusionado en `main` con commit de fusión (`36ce40b`), para que los
commits del rojo-verde que cita esta entrada sigan existiendo; la CI de `main`
tras la fusión, en verde (`36745034165`, 234). Sin ninguna operación nueva: el
guardián de montaje sigue exigiendo exactamente `{getGallery}`. La prueba de que
el cambio sirvió: un `getWebhook` que devolviera el secreto del punto de
notificación **era una respuesta conforme** y hoy la caza openapi-core, sin una
línea de código nuestro.

**Tres cambios en el contrato, en un solo PR:**

- **`400` en los tres listados** (`listGalleries`, `listIdentities`,
  `listWebhookDeliveries`). El hueco era mayor que `pageSize`: también `page`,
  con su mínimo, y el `status` de las entregas. Rechazar, no acotar en silencio,
  por la regla de #68: rechazar es una decisión, y las decisiones se declaran.
- **Los dos `nullable` sin `type`.** `frozenReason` **se omite y pierde el
  `nullable`**, con «presente si y solo si `status` es `frozen`» en prosa,
  porque el esquema no puede expresarlo. Emitir `null` sin meterlo en `required`
  habría dejado tres estados para dos significados. El cierre no cambia la
  omisión: prohíbe los nombres no declarados, no exige los declarados. La
  `identity` de `searchGallery` **se queda en `null` y entra en `required`** (el
  mismo argumento), como `anyOf: [Identity, NullValue]`. `NullValue` es `type:
  string` + `nullable` + `enum: [null]`, justificado con el texto de 3.0.3 y no
  con que el validador lo acepte ---el validador aceptaba las cuatro formas
  candidatas---. Con `type: object` habría hecho falta una excepción en
  `test_closure`, sin que el `type` cambiara nada al validar. **No se llama
  `Null`:** esa clave sin comillas es nula en YAML 1.1 y también en el esquema
  core de YAML 1.2, el de js-yaml, que es el lector de `auth` y `pricing`.
  Medido: PyYAML la carga como `None`, js-yaml como `"null"` y `yaml` 2 como
  `""`; el componente se quedaba sin nombre y `openapi-spec-validator` reventaba
  con `TypeError`. Estado medido con las dos herramientas: `frozenReason: null`,
  antes `oc=CAZA st=pasa`, ahora `CAZA/CAZA`; `identity: null`, antes `oc=CAZA
  st=pasa`, ahora `pasa/pasa`.
- **El cierre de los esquemas, vía C.** El recuento de la sesión 9 tenía **un**
  error: contó el miembro `{secret}` como cierre directo, y cerrarlo solo
  rechaza el `201` legítimo (`'status', 'events', 'url', 'createdAt', 'id' were
  unexpected`). Las cifras, medidas sobre el fichero: **36** esquemas de objeto;
  **35** cerrables; **33** directos; **2** solo reestructurando (las dos partes
  del compuesto); **32** dentro del alcance de #103 (los 33 menos `ErrorReport`,
  que espera a #88). **Después: 37 esquemas, 34 cerrados, 3 abiertos**
  (`WebhookEndpointBase`, `ErrorReport`, `details`). El compuesto, en **forma
  B**: `WebhookEndpointBase` abierta con las definiciones; `WebhookEndpoint` y
  el `201` como `allOf: [Base]` más los nombres y `additionalProperties: false`,
  con `secret` **definido en el propio `201`** y en su `required` (hasta ahora
  un `201` sin secreto validaba). Quedan 7 nombres duplicados entre las dos
  listas. **`info.version` no se toca, por decisión:** el servicio no tiene
  consumidores, y el versionado del contrato empieza a importar con el primero.
  Está escrito en la sección «Esquemas cerrados» de `info.description`, junto a
  la contrapartida (compatibilidad hacia delante).

**El olvido de una lista, en sus dos direcciones.** Cinco mutaciones de la forma
B: con un nombre de la base que falta en una lista, o en las dos, el validador
rechaza la respuesta legítima (`'description' was unexpected`), pero solo si
alguna prueba emite ese campo, y hoy no hay implementación de webhooks. Con un
nombre que sobra ---`secret` en la lista de `WebhookEndpoint`, `accountId` en la
del `201`--- **se admite con cualquier valor y el validador calla**. Las cinco
las pone en rojo `test_closure.py`, que compara las listas con la base en los
dos sentidos. Eso deja caducada la afirmación de la sesión 9 de que «el olvido
falla en voz alta» (anotada allí).

**El campo de más en los cuerpos de petición: alcance exacto.** En cuerpos JSON,
**probado**: `400` conforme (`test_rejections.py`). En los **8 cuerpos
`multipart/form-data`**, es una **obligación del contrato** que vigila
`test_closure.py` y que tienen que cumplir F4, F5, F8 y F12. No se prueba aquí
porque `python-multipart` ---que FastAPI exige para `Form` y `File`--- **no está
en el árbol fijado**. El mecanismo, medido con FastAPI 0.141.1: `Form()` y
`File()` sueltos **ignoran** la parte de más (`200`); un modelo con
`extra="forbid"` anotado como `Annotated[Modelo, File()]` da `400` y publica
`multipart/form-data`; con `Form()` también rechaza, pero publica
`application/x-www-form-urlencoded`, que es falso frente al contrato; y si F5
lee el flujo a mano, hace falta una lista explícita de las partes declaradas.
Está escrito en `src/models/__init__.py` y en un comentario en #36, #37, #40 y
#44; el de #36 recoge además tres observaciones de la misma medición: se acepta
`urlencoded`, una parte repetida pasa con un solo valor, y `UploadFile` se
publica con `contentMediaType` (3.1), ante el que el comparador se negará.

**El despertador sonó donde tenía que sonar.** La fila «campo de más en
`Gallery`» del servicio mentiroso afirmaba que **pasa**; se comprobó en verde
antes de empezar y se puso en rojo sola contra el contrato nuevo, sin tocarla.
Las filas de `ErrorReport` siguen afirmando que pasa, con su porqué: es el único
esquema propio abierto, hasta #88.

**Evidencia, por commit** (rojo-verde registrado; los rojos con `--no-verify`).
La suite se ejecutó en el contenedor de desarrollo con **`env -u LOG_LEVEL`**:
el compose fija `LOG_LEVEL=debug` y sin eso `test_log_level_default_is_info`
falla por el entorno (`1 failed, 196 passed` en `main`); con él, 197, como la
CI. Es #110.

| Commit | Resultado |
|---|---|
| `main` `13db3fd` | 197 pasan |
| `193ef80` guardias, contra el contrato viejo | 14 fallos, 203 pasan: las 6 guardias de `test_closure` y los 8 rechazos fuera de rango (`400` no declarado) |
| `46f3d77` contrato | 6 fallos, 211 pasan: **exactamente** la fila del campo de más, sin tocar (`- pasa / + CAZA`), y los 5 de `test_shape` (`código=None contrato=False`); guardias en verde |
| `d313816` modelos con `forbid` | 4 fallos, 213 pasan: la fila y 3 controles con modelos de juguete |
| `9ce2338` mentiroso y controles invertidos | 226 pasan, cobertura 98,21 % |
| `742bb6c` `'y'` entre comillas y el porqué de `NullValue` | 226 pasan; cero diferencias entre los tres lectores de YAML; CI `36732807420` en verde |
| `b66fef6` guardia de escalares planos que YAML 1.1 lee de otra forma | 234 pasan; CI `36737818299` en verde |

Lo demás, verificado:

- **Determinismo:** 20 × «226 passed».
- **Guardias que pueden fallar:** diez defectos inyectados en copias del
  contrato, diez rojos, cada uno en su prueba.
- **Ninguna respuesta real emite un campo sin declarar:** con el contrato
  cerrado, ninguna prueba de extremo a extremo de `getGallery` cae.
- **`/openapi.json` idéntico al `.yaml`:** en el contenedor de desarrollo y en
  la imagen de producción recién construida, como `appuser`.
- **Documento válido y 27 operaciones.**
- **CI del PR:** `36709704400`, en verde, con «No known vulnerabilities found»
  en el árbol de producción.
- **Comparador:** compara `additionalProperties` en los dos sentidos (un modelo
  sin `forbid` da `código=None contrato=False`) y **se niega** ante el compuesto
  cerrado y ante `anyOf: [X, NullValue]`.

**`dev-up.sh`, primero en rojo y después en verde.** Salió con exit=1 dos veces
por `gateway`: `DeadlineExceeded` de Docker Hub al pedir los metadatos de
`kong:3.6.0-ubuntu`, antes de construir nada; el registro respondía por `curl`
en 0,36 s, pero `docker manifest inspect` se colgó más de 180 s. **Por qué la
imagen «ya no estaba» no tiene respuesta, porque no hay constancia de que
estuviera**: la caché de BuildKit guarda sus capas (`pulled from
docker.io/library/kong:3.6.0-ubuntu@sha256:2f2832a7…`, último uso hace 5 meses),
pero ninguna transcripción la muestra como imagen etiquetada, ningún `prune`
aparece en ellas, y la construcción del 29/08 ya consultaba el registro (`load
metadata … 1.0s` con `[auth] library/kong:pull token`). Lo que se hereda es que,
**sin la imagen etiquetada en local, toda construcción de la pasarela depende de
que Docker Hub responda**. Los registros de Docker Desktop rotan cada ~1 MB y
solo cubren hoy y mayo, de modo que no se puede descartar un borrado entre el 10
y el 29 de septiembre. Con `docker pull kong:3.6.0-ubuntu` suelto (exit=0, el
mismo resumen, un segundo), `dev-up.sh` sale con **exit=0**, y `load metadata`
resuelve ya en `0.0s` sin pedir credencial al registro. El compose de `fr`
arranca (`healthy`, `/health` 200).

**La DoD no contradice el cambio, y tampoco lo respalda.** Lista `400` en todas
sus operaciones sin distinguir, de modo que el que aparezca en los listados no
es argumento para declararlo; el argumento es la regla de #68. ~~**La memoria
no se ha tocado:** el parche del capítulo 4 que esta sesión desbloquea ---que
el contrato prohíbe además lo que no declara--- lo escribe Miguel al cerrar.~~
**Cierto al fusionar; la memoria se actualizó después**, con ese parche y
cuatro más (al final de esta entrada).

**Lo que vino después de abrir el PR**, en un quinto commit (`742bb6c`): la
clave `y` de `boundingBox`, entre comillas. Un lector de YAML 1.1 estricto la
lee como `true` ---medido con `yaml` 2.9.1 en `version: 1.1`---, y con el
esquema cerrado un `200` legítimo de `detectFaces` daba «'y' was unexpected»;
PyYAML 6.0.3 no aplica las formas `y`/`n` de 1.1 y js-yaml es core 1.2, así que
ninguno de los dos lo veía. Es la única divergencia entre los tres lectores en
todo el documento; tras el cambio, cero. Y el comparador se niega ante `anyOf:
[X, NullValue]` y ante el envoltorio de `WebhookEndpoint`: la obligación de
enseñárselo, sin esquivarlo, queda escrita en #40 (F8, `searchGallery`) y #45
(F13, webhooks), como la del multipart. Salen dos issues, #110 (`LOG_LEVEL` en
la prueba del valor por omisión) y #111 (`listWebhooks` sin paginar ni tope).

**La guardia de YAML (`b66fef6`).** Nació de la clave `y`: recorre el contrato
con `yaml.compose` y mira solo escalares planos. En las claves rechaza lo que
YAML 1.1 lee como booleano o nulo; en los valores, solo
`y`/`n`/`yes`/`no`/`on`/`off`, de modo que `true`, `false` y `null` ---que el
contrato usa a propósito--- pasan sin excepciones escritas. Es sobre el texto
porque la carga con PyYAML no lo ve. Sobre `main` (`13db3fd`) da `línea 1643:
clave y sin comillas`; sobre la rama, nada. Controles en pareja: `y:` rojo y
`'y':` verde; `enum: [on]` rojo y `enum: ['on']` verde; `nullable: true` verde.

**Auditoría de issues tras la fusión, y por qué no se cerraban.** #103 no se
cerró al fusionar: el PR decía «Cierra TFM-MIS-MEM/docs#103», y GitHub solo
reconoce las palabras clave en inglés (`closingIssuesReferences` del PR, vacío).
De los 12 PR fusionados en los cuatro repositorios de servicio ---`docs` no
tiene PR---, solo `auth#1` y `pricing#2` cerraron sus issues, los dos únicos con
«Closes TFM-MIS-MEM/docs#N»; los de «Cierra #N» fallan además por la referencia,
que sin `owner/repo` resuelve contra el repositorio del propio PR. De los 69
issues abiertos, uno estaba hecho y abierto (#103, cerrado ahora con un
comentario que cita el PR y el commit de fusión); #33 es parcial ---F1 no
conectó Redis, que su criterio pedía, y no se declaró---, y se cerró el 01/10
con el traspaso de Redis a #43, en un [comentario que sitúa en F11 la primera
fase que lo nombra y en F10 (#42) la que podría
adelantarlo](https://github.com/TFM-MIS-MEM/docs/issues/43#issuecomment-5929070530);
#64 y #100 son parciales y siguen abiertos; el resto, pendiente. En el sentido
contrario, ninguno que este documento diera por cerrado seguía abierto salvo
#103, y #80 estaba cerrado aunque aquí figuraba abierto (anotado). #10 y #1 a
#9, cerrados sin PR ni comentario, se dejan como están por decisión de Miguel.

**Dos issues más al cerrar, de decisiones que habían quedado abiertas.**
**#112**: la DoD no describe `getWebhook`, `listWebhookDeliveries` ni
`rotateWebhookSecret` ---27 operaciones en el contrato, 24 en la DoD, ninguna
de más en ella---; plazo, antes de F13 (#45); y una decisión abierta: completar
la DoD o, si es un entregable congelado, declarar dónde diverge. Se anota aparte,
sin resolverla, la otra divergencia: la DoD lista `400` en todas sus operaciones
y el contrato solo donde es una decisión. **#113**: cerrar los esquemas propios
de `auth` y `pricing`, en los mismos PR que #88, un cambio de contrato por
repositorio. Parte de cifras ---15 y 19 esquemas de objeto, ninguna composición
de varios miembros, así que no hace falta la reestructuración de `fr`--- y de
tres medidas previas: las composiciones otra vez, si `jest-openapi` aplica
`additionalProperties: false`, y qué hace cada servicio hoy con un campo de más
en la petición. La tercera es la que puede cambiar el alcance: el código
heredado descartaba esos campos en silencio (`stripUnknown`), y cerrar los
cuerpos declararía un rechazo que el código no aplica. Prioridad baja: no se
adelanta a ninguna fase de `fr`.

**La memoria se actualizó**, en `memoria_tex/v11`: cinco parches en tres
capítulos, con `parches-memoria-sesion10.tex` recogiendo el reparto y el mismo
criterio de las sesiones 3 a 9. **Por primera vez, la regla del proyecto se
cumple en su orden**: el contrato cambió y se fusionó, y la memoria se escribió
después, sobre lo fusionado y medido. **Dos de los cinco son correcciones** de
texto ya publicado. Una es de cifra: §8.1 daba «treinta y cuatro de los treinta
y cinco» esquemas cerrables directamente, y son treinta y tres, porque el
recuento de la sesión 9 contó el miembro `{secret}` como cerrable por sí solo.
La otra es de tiempo verbal: §8.1 describía en presente una discrepancia entre
validadores sobre una construcción que el contrato ya no tiene, y una memoria
que describe una propiedad que la especificación ya no tiene induce a error
igual que una que describe una que aún no tiene ---el motivo del aplazamiento
de la sesión 9, en el otro sentido---; de paso se corrige la errata «ccon» de
la v10. **El parche aplazado en la sesión 9 está dentro**: el capítulo 4
enuncia por fin que el contrato prohíbe lo que no declara. Va al final de §4.3
como continuación de la tercera decisión, sin `\paragraph` propio, para que
«Tres decisiones merecen justificación explícita» siga siendo exacto. La
aplicación se comprobó con un script y no a ojo: los quince párrafos de los
cinco parches, literales y una sola vez; ningún resto de los dos párrafos
sustituidos; cada inserción en su frontera; ninguna línea ajena en el diff; y
los dos recuentos ya escritos («Tres decisiones» en §4.3, «dos fallos de
instrumento» al cierre del capítulo 8), intactos.

| Capítulo | Cambio |
|---|---|
| 4 — Diseño del servicio | Un parche, al final de §4.3: el **reverso del criterio de declaración**. Lo que el contrato calla no queda a discreción de quien lo implementa: una respuesta con un campo no declarado deja de ser conforme y una petición que lo traiga se rechaza; por el mismo motivo se declara el rechazo de un parámetro fuera de cota, porque ajustarlo en silencio también es una decisión, y la más difícil de descubrir. El caso que lo justifica es el secreto devuelto por una consulta, que antes era conforme. Una excepción ---el informe de error, común a las tres especificaciones, abierto hasta poder cerrarse en las tres; su detalle, abierto por diseño--- y un coste ---la compatibilidad hacia delante---, que se acepta porque añadir un campo ya es, por método, un cambio de contrato |
| 6 — Implementación | Un parche, `\subsection{Cierre de los esquemas de la especificación}`, nueva tras la de conformidad: 37 esquemas, 34 cerrados y 3 abiertos, solo en `fr`; la composición reestructurada en base abierta más dos esquemas que enumeran los nombres, con el secreto definido y obligatorio solo en la creación; las dos listas y por qué la dirección silenciosa exige la guardia estática; los dos nulos resueltos con un mismo criterio (no tres estados para dos significados); el rechazo en peticiones, **probado en JSON y solo declarado en los ocho cuerpos multiparte**, con el mecanismo medido; el comparador que se detiene ante las dos construcciones nuevas, y la versión que no se cambia, por decisión |
| 8 — Validación | Tres parches. Una **corrección** en §8.1, el párrafo de la formulación general: treinta y tres de treinta y cinco, cerrar cualquiera de los dos miembros rompe la composición, y lo previsto pasa a ejecutado con su alcance real (una especificación, no tres). Otra en el párrafo de los validadores que discrepan, que pasa a pasado, con la corrección del contrato y por qué la conclusión no depende de ella, más la errata. Y `\subsection{Un cambio de contrato verificado por su propia alarma}`, nueva al final de §8.1: la acreditación por el validador estándar y no por código propio; la fila del mentiroso que falla sola, y por qué el orden importa; la previsión «el olvido falla en voz alta», desmentida en la dirección peligrosa; la clave `y` que el cierre volvió dañina, y que no es un fallo de instrumento porque todos leían igual; y el alcance de la evidencia en multipart |

**Sesión 11 — #34 (F2), la primera fase que crea estado persistente propio en
`fr`, y la primera en que el contrato cambia por algo que descubre el modelo de
datos.** Resultado: `fr-commercial-microservice` PR #3 (rama `fase2/34`, cuatro
commits), fusionado en `main` con commit de fusión (`da38e25`), para que los
commits del rojo-verde que cita esta entrada sigan existiendo. Antes de fusionar
se comprobó que la cabeza seguía en `12c9aaf`, con su CI (`37497258438`) en
verde, y que `closingIssuesReferences` era exactamente `TFM-MIS-MEM/docs#34`.
La CI de `main` tras la fusión, en verde (`37501294383`, 270, «No known
vulnerabilities found»), y **#34 cerrado** (`COMPLETED`), comprobado con `gh`. Sin
ninguna operación nueva: el guardián de montaje sigue exigiendo exactamente
`{getGallery}`.

**Estado de partida, medido y no leído:** `main` en `36ce40b`, CI
`36745034165` en verde con auditoría, 234 pasan en local. El servicio no creaba
ningún índice (la base de desarrollo tenía `galleries` vacía y solo `_id_`).
Las pruebas llegan a MongoDB real en los dos sitios, sin sustituto: el
contenedor de desarrollo en local y un contenedor de servicio `mongo:7.0` en la
CI.

**El índice de `externalId` que describían CLAUDE.md y la DoD no hacía lo que
decían.** Medido contra `mongod 7.0.40`: con `{galleryId, externalId}` único y
**disperso**, la segunda identidad **sin** `externalId` de una galería se
rechaza (`E11000 … externalId: null`), y lo mismo con `null`. Era peor de lo que
se sospechaba: no solo el `null`, también la ausencia. Un disperso compuesto
indexa el documento en cuanto está uno de sus campos, y `galleryId` está
siempre. El índice **parcial** `{externalId: {$type: "string"}}` admite los dos
casos y rechaza el duplicado real. Dos medidas más, que deciden índices:

- El planificador **no usa el parcial sin su predicado**: `{galleryId}` a secas,
  y `{galleryId, externalId: "E-1"}` sin `$type: "string"`, hacen COLLSCAN; con
  el predicado, `IXSCAN`. Por eso `{galleryId}` suelto en `identities` **no es
  redundante**, y está escrito junto a `INDEXES`.
- En `galleries`, `{accountId}` suelto **sí lo era**: `find({accountId})` usa
  `IXSCAN(accountId_1_name_1)`, el prefijo del compuesto. No se crea.

**Las cuatro decisiones de Miguel:**

- **Unicidad: se quedan los dos índices únicos y se declara su `409`**, en un
  commit de contrato previo al código. `ConflictGalleryName`
  (`GALLERY_NAME_ALREADY_EXISTS`) en `createGallery` y `updateGallery`, con la
  **comparación exacta, sin intercalación, escrita en la descripción**: es una
  decisión y se declara. `ConflictExternalId` (`EXTERNAL_ID_ALREADY_EXISTS`) en
  `createIdentity`, que tenía un `409` en línea sin código, y en
  `updateIdentity`, que podía cambiar `externalId` sin declararlo. Más
  `minLength: 1` en `externalId` de las dos: el parcial indexa `""` y un campo
  multipart en blanco llega como `""`, así que la segunda identidad «sin
  `externalId`» daría un `409` falso. **No se normaliza `""` a ausente**: sería
  ajustar en silencio; se rechaza con el `400` que ambas ya declaran.
  `info.version` sigue en 1.0.0, con el criterio de #103.
- **Índice parcial**, y `externalId` se guarda **ausente**, nunca `null` ni
  vacío.
- **#106 no entra.** Medido su coste: con `MONGO_INITDB_ROOT_*` sobre un volumen
  ya inicializado, la imagen activa `--auth` pero **no crea el usuario** (lectura
  sin credencial `Unauthorized`, con la de root `Authentication failed`): el
  volumen de desarrollo habría que recrearlo. `ping` sin credencial sigue
  respondiendo, así que los healthchecks no cambian. Tocaría unos nueve
  ficheros, depende de #105 para generar el secreto y fijaría solo en `fr` el
  patrón de los tres servicios (#97 y #98 siguen abiertos). **Para su sesión:
  `ensure_indexes` correrá con el usuario de la aplicación, y hay que comprobar
  que `readWrite` basta.**
- **Los modelos de persistencia van en `src/documents`**; los de la API se
  quedan en `src/models`, sin `git mv`.

**Qué entra.** `GalleryDocument`, `IdentityDocument` y `FaceDocument`, cada uno
con su `COLLECTION`, sus `INDEXES` y, para cada único, el código de su `409` en
`CONFLICTS`. Al leer ignoran lo que no modelan; al escribir omiten lo opcional
sin valor, campo a campo. Valores iniciales: galería `active`, `identityCount` y
`faceCount` a 0; identidad con `faceCount` a 0. **`faceCount` de la identidad
empieza en 0 por decisión de Miguel**, y queda escrito para F4 con su
condición: con 0 el contador nunca dice más de lo que hay **siempre que el
`$inc` vaya después de insertar el rostro**; si el proceso cae entre medias,
queda una identidad huérfana con `faceCount` 0 que la reconciliación encuentra
con una consulta. Un replica set de un nodo habilitaría transacciones; lo
decide F4. **El invariante de `frozenReason`** («presente si y solo si
`frozen`») se valida al leer, y un documento corrupto da `500`: decisión
escrita y probada en los dos sentidos, de extremo a extremo por `getGallery`,
que ahora lee a través de `GalleryDocument` sin tocar sus pruebas. Junto a
`CONFLICTS`, para F3 y F4: se escribe sin comprobar antes, y el
`DuplicateKeyError` se traduce a `409` **según el índice que saltó**
(`keyPattern`, medido en el error de inserción), no solo por el 11000.

**Si un índice no se puede crear, el servicio no arranca.** Sin un único, el
`409` miente en silencio y los duplicados se acumulan; sin `{galleryId}` en
`faces`, la búsqueda 1:N degrada a COLLSCAN. Lo que se ve, medido con
duplicados previos en `galleries`:

- **`docker-compose.dev.yml`** (uvicorn con `--reload`): el contenedor **no
  sale**. Queda `running` y `health=starting` hasta los ~55 s, después
  `unhealthy`, con `RestartCount` 0. Corregidos los datos, `docker restart` lo
  devolvió a `healthy`.
- **Imagen de `Dockerfile` con `restart: unless-stopped`**: sale con código 3 y
  entra en **bucle de reinicios**, «Restarting (3)», 10 en ~65 s. Se midió con
  `docker run` y la misma política, porque los `container_name` del compose de
  producción chocan con los de desarrollo.

Un índice viejo con el mismo nombre y otra forma da `IndexKeySpecsConflict`
(86) y también impide arrancar: **cambiar la forma de un índice exige una
migración explícita**, escrito junto a `ensure_indexes`. Los índices se crean
uno a uno para que el registro (`mongodb_index_failed`) diga cuál falló. No
escribe el mensaje del servidor, que lleva los valores duplicados.

**Evidencia, por commit** (los rojos con `--no-verify`; suite en el contenedor
de desarrollo con `env -u LOG_LEVEL`):

| Commit | Resultado |
|---|---|
| `main` `36ce40b` | 234 pasan |
| `4c164c2` guardia `test_uniqueness`, contra el contrato viejo | ROJO: 6 huecos (los dos `409` de galerías, el código que faltaba en `createIdentity`, el `409` de `updateIdentity` y los dos `minLength`); sus 6 controles en verde |
| `cca4359` contrato | 241 pasan |
| `d5ebafe` índices y documentos, antes del código | ROJO: 9 fallos y 1 error de colección (`No module named 'src.documents'`), 247 pasan; las 6 de «admite» pasan ya, porque sin índice todo se admite |
| `12c9aaf` modelos e índices | 270 pasan, tres veces seguidas; cobertura 98,68 %; CI `37497258438` en verde |

- **`test_uniqueness`** cruza dos fuentes, sin comparar ninguna consigo misma:
  los índices únicos salen de `INDEXES` y `CONFLICTS`, y las operaciones
  afectadas, de los `requestBody` del contrato. Sus controles: un índice
  inyectado en `INDEXES` sin `409` da rojo, y también un único sin código o un
  código sin índice. Una prueba aparte exige los dos únicos de CLAUDE.md, para
  que vaciar `INDEXES` no la deje en verde sin vigilar nada.
- **`test_indexes`** compara `index_information()` entero (clave, unicidad,
  filtro, y la ausencia de `sparse` o intercalación). Prueba además el rechazo
  con su `keyPattern`; lo que se admite; que `""` repetido choca, que es el
  porqué del `minLength`; la idempotencia (dos arranques, mismos índices); y las
  dos negativas a arrancar.
- **Respecto al commit rojo, cambió una aserción:** el evento
  `mongodb_index_failed` lleva además `index`, porque los índices se crean uno a
  uno. Está dicho en el mensaje del commit verde.
- **`dev-up.sh` sale con exit=0**, y el compose de `fr` queda `healthy`, con
  los seis índices creados en la base de desarrollo por el propio servicio.

**El enlace del contrato no era un enlace.** `repos/openapi/fr-commercial.yaml`
era un fichero real, de fecha 01/10 12:55, aunque «Siguiente paso:
`fr-commercial`» afirmaba que la raíz conservaba el enlace. **Lo sustituyó
Miguel al editar el contrato a mano por la ruta de la raíz**, sin saber que era
un enlace; al guardarlo, el enlace quedó convertido en una copia. No fue la
sesión 10, cuyos commits de contrato son del 30/09 (`46f3d77`, `742bb6c`). Al
detectarlo, el contenido era idéntico byte a byte al del repositorio (`cmp`),
de modo que no se perdió nada; pero esta sesión cambiaba el contrato, y sin la
corrección las dos copias habrían divergido. Se convirtió en enlace antes del
commit de contrato, y desde entonces el contrato se edita solo por la ruta del
repositorio, regla que vale igual para las personas que para los agentes. Hoy:

```
lrwxr-xr-x@ 1 miguel  staff  38 Aug 29 11:46 auth.yaml -> ../auth-microservice/openapi/auth.yaml
lrwxr-xr-x@ 1 miguel  staff  56 Oct  6 18:24 fr-commercial.yaml -> ../fr-commercial-microservice/openapi/fr-commercial.yaml
lrwxr-xr-x@ 1 miguel  staff  44 Aug 29 11:46 pricing.yaml -> ../pricing-microservice/openapi/pricing.yaml
```

**Fuera del encargo, registrado y sin arreglar:**

- **#114**, nuevo: la Admin API de Kong se publica en `0.0.0.0:8001`, sin
  credencial, **también en el compose de producción**. Responde `200` por la IP
  de LAN. En modo sin base de datos, `POST /config` sustituye la configuración
  entera, `space-auth` incluido; eso no se probó, es una inferencia del modo.
  `identity-headers.sh` usa la Admin API desde el anfitrión, así que cerrarla
  sin más rompe esa prueba.
- **Comentario en #112**: las tres divergencias con la DoD. El disperso que
  «permite identidades sin él»; los `409` que no lista; y `updateIdentity` con
  «Inputs: Name», cuando el contrato admite también `externalId`, a propósito.

**Líneas de CLAUDE.md que este cambio dejaba falsas** ---**aplicadas por
Miguel** en `docs` (`4d35a3f`, y la corrección del párrafo del enlace en
`e321c1e`)---:

- l. 77, «`/src/models → esquemas MongoDB`»: son los modelos de la API; los de
  persistencia están en `/src/documents`.
- l. 275, «`índices: {accountId}, {accountId, name} único`»: `{accountId}`
  suelto no existe.
- l. 278, «`{galleryId, externalId} único disperso`»: es único y **parcial**.
- §6, «Códigos de estado»: ninguna línea queda falsa, pero no recoge que todo
  índice único lleva su `409` declarado, ni los dos códigos nuevos.
- ll. 26 y 34 («fichero real hasta que exista su repositorio»): ya eran falsas
  desde la sesión 5; desde ésta, la raíz tiene el enlace.

Con ellas entran en CLAUDE.md **dos convenciones nuevas**:

- **Todo índice único lleva su `409` declarado** en cada operación que escribe
  sus campos, y se declara antes de crear el índice. Lo vigila
  `test_uniqueness.py`, que cruza `INDEXES` con los cuerpos de petición del
  contrato.
- **El contrato se edita siempre por su ruta canónica**, la del repositorio de
  su servicio, nunca a través del enlace de `openapi/`. Un editor que guarda
  sustituyendo el fichero, lo use una persona o un agente, convierte el enlace
  en una copia sin avisar. Se comprueba con `ls -l openapi/`: los tres tienen
  que ser enlaces.

**La DoD**, en `documentacion/DoD-TFM.docx`, contradice el cambio en el índice
disperso y no recoge los `409`. Se ha comentado en #112 y no se ha editado.

**La memoria se actualizó**, en `memoria_tex/v12`: cuatro parches en tres
capítulos, con `parches-memoria-sesion11.tex` recogiendo el reparto y el mismo
criterio de las sesiones 3 a 10. **Ninguno es corrección**: la memoria no había
descrito nunca la forma de los índices ---el «único disperso» vivía en la DoD y
en CLAUDE.md---, de modo que la medición no desmiente ningún texto publicado.
Los cuatro son inserciones, y los recuentos ya escritos siguen exactos: el
parche del capítulo 4 continúa la tercera decisión de §4.3 sin `\paragraph`
propio, como en la sesión 10; en §6.2.1, «Tres decisiones de modelado» se
conserva porque el contador de la identidad continúa la primera y la unicidad
va a una subsección propia de §6.3, no como cuarta decisión; y el capítulo 8
cita la cuarta forma de guardián de §8.4 sin añadir una quinta. El anexo de
modelos de datos sigue en `%% TODO`: la relación de índices que pide ya tiene
material, y no se ha escrito.

| Capítulo | Cambio |
|---|---|
| 4 — Diseño del servicio | Un parche, al final de §4.3: la regla de declaración alcanza a lo que **impone el almacenamiento**. El nombre de la galería, único en la cuenta, y el identificador externo, único en la galería, se declaran como rechazo propio en cada operación capaz de violarlos, y antes de imponerse; sin declararlo, un valor repetido es un rechazo que el integrador no puede distinguir de un fallo. Qué cuenta como valor: la ausencia se admite cuantas veces haga falta, la cadena vacía se rechaza en lugar de leerse como ausencia, y la comparación de nombres es exacta |
| 6 — Implementación | Dos parches. En §6.2.1, el contador de rostros de la identidad **nace a cero** y se incrementa después de registrar cada rostro, de modo que nunca afirma más de los que existen; sin transacciones, una interrupción deja una identidad huérfana que su propio contador delata. Y `\subsection{Restricciones de unicidad del modelo de datos}`, nueva tras la de cierre de los esquemas: el contrato cambiado antes que el índice; el disperso que indexa la ausencia como nulo en un compuesto, sustituido por el parcial, y la longitud mínima que exige la cadena vacía; el índice por galería que el parcial no hace redundante y el de cuenta que el compuesto sí; la escritura sin comprobación previa, con el rechazo según la restricción que saltó; la negativa a arrancar, con lo que se ve en cada despliegue y la migración que exige cambiar la forma de un índice; y los modelos de persistencia, que ignoran lo que no modelan mientras los del contrato lo rechazan |
| 8 — Validación | Un parche, `\subsection{Una restricción que el diseño daba por resuelta}`, nueva al final de §8.1: el primer cambio de contrato que nace del modelo de datos; la sospecha razonada que la medición superó, y por qué exige el motor real y no un sustituto; la comprobación cruzada entre código y especificación, con un **suelo** para que no pueda satisfacerse sobre un conjunto vacío; y que **una prueba de admisión no puede fallar por la ausencia de la restricción**, sino que vigila la restricción que sobra, de modo que solo emparejada con la de rechazo cubre los dos defectos. La forma dispersa la habría delatado una de admisión |

**Sesión 12 — replanificación por plazo (entrega 29/10) y etiquetado del
backlog.** Sin código. Alcance recortado: `fr-commercial` funcional con los tres
modelos EdgeFace, CRUD de galerías e identidades, verificación y búsqueda 1:N, y
la campaña SCALE/MoST como aportación central; después, la demo (frontend
sencillo y mockup de banca, #115); SPACE y límites, si da tiempo. Etiquetas
nuevas, exactamente una por issue abierto: `prio:1-medicion` 7, `prio:2-demo` 4,
`prio:3-si-da-tiempo` 6 y `alcance:futuro` 53, estos con comentario y sin
cerrar; `prio:bloqueante` queda sin issues abiertos. **#106 ya no bloquea F4**:
queda como limitación del entorno de desarrollo (comentado en #36 y #106). La
medición se hará **en CPU, dentro de Docker**: Docker Desktop no expone la GPU
del M5 (Apple M5, 10 núcleos, 16 GB; la VM de Docker, ~7,7 GiB). **Sin
`torch.hub`**: el código de EdgeFace y MTCNN se toma de `fr-compilation` y los
pesos se versionan en el repositorio del servicio. CLAUDE.md gana la sección
«Modo entrega» (`1c56b6f`). Nada fusionado en los repositorios de servicio.

**Sesión 13 — F5 (#37), carga de los tres modelos e inferencia sin estado.**
**Fusionado**: PR #4 de `fr-commercial-microservice` (`fase2/37`, 6 commits),
con commit de fusión `8166472`; CI de `main` `37776654252` en verde; #37
cerrado, #38 referenciado. CI del PR en verde en x86_64 (`37773984370`: 359
pruebas, cobertura 99,16 %, auditoría de torch limpia), y el compose de
desarrollo, `healthy`.

- **Qué hay.** `detectFaces`, `verifyPair` y `extractEmbedding`. Los tres
  EdgeFace y MTCNN, en CPU, se cargan en el `lifespan` y, si falta un peso, el
  servicio no arranca. El código viene de `fr-compilation` sin `torch.hub` y
  los pesos se versionan en `checkpoints/`. Con torch 2.14.1+cpu y timm 1.0.30
  reproduce los `.npy` de `results/` (coseno ≥ 0,99985).
- **LSSC.** Es el método de `utils/tools_binarized.py` sobre el vector **sin
  normalizar**: 3 bits por dimensión, **192 B, no 64 B**. Los cortes se
  calcularon sobre todas las identidades de LFW y quedan como constantes de `v1`.
  `verifyPair` compara por Hamming, con `confidence = 1 − d/1536` y d_max de
  479 / 466 / 520 (FAR ≤ 1e-4).
- **Medido.** Imagen del servicio: 1,79 GB. Carga de los modelos: 1,3 s. La
  latencia aislada va de 43 a 145 ms de mediana con imágenes de 240 × 320,
  pero con mucha dispersión, así que **no sirve para comparar modelos**. Pico
  de RSS: 1389 MiB en `verifyPair base` con dos imágenes de 4096². Las cifras
  completas están en el PR.
- **Hallazgos.**
  - `TORCH_NUM_THREADS` es estado **por hilo** (OpenMP), así que se fija en
    cada hilo de trabajo.
  - El `torch` de PyPI trae CUDA también en aarch64; se usa el índice CPU.
  - `pip-audit` se salta las versiones `+cpu` con exit 0; un paso aparte de
    la CI las audita sin la etiqueta.
  - El `chown -R` del Dockerfile duplicaba 97 MB de pesos.
  - **Los pesos de EdgeFace son CC BY-NC-SA 4.0**: un despliegue comercial
    necesitaría otros.
- **Issues.** Nuevos, con `alcance:futuro`: #116 (tope de bytes en la pasarela
  y lectura tras la identidad), #117 (secreto de desarrollo fuera de
  desarrollo), #118 (EXIF) y #119 (formatos de imagen). Comentarios en #38
  (192 B) y en #36 (`createIdentity` y `addFace` heredan el
  `400 EMBEDDING_INPUT_NOT_SUPPORTED`).
- **Queda.** El orden previsto: instrumento de carga → F3 → F4 con F6 → F8 →
  campaña, que tiene que empezar antes del 15/10.

**Cambios que afectan a la memoria:**

| Dónde | Cambio |
|---|---|
| Contrato, `detectFaces` | Sin `model`; rostros por confianza; sin rostros, `200` con `faces: []`; recorte alineado de 112 × 112 en PNG |
| Contrato, `verifyPair` | Hamming sobre LSSC, el mismo comparador que contra galería; `confidence = 1 − d/1536`; umbral por omisión por modelo (0,6882 / 0,6966 / 0,6615); vectores rechazados con `400 EMBEDDING_INPUT_NOT_SUPPORTED` hasta F7 |
| Contrato, `extractEmbedding` | `embedding` = código LSSC de 192 B o 512 `float32` LE sin normalizar; `401 API_CHANNEL_REQUIRED` desde el canal web; modelo con versión (`xs-v1`) |
| Contrato, imágenes | `400 INVALID_IMAGE`, `IMAGE_TOO_LARGE` (> 4096 px por lado, en la cabecera) y `NO_FACE_DETECTED`; `VerificationResult.confidence` y `thresholdUsed` en [0, 1] |
| Embeddings (CLAUDE.md y memoria) | 192 B por rostro, no 64 B; 9,6 MB por galería de 50.000. La cifra de CLAUDE.md la corrige Miguel |
| Configuración | `EMBEDDING_TOKEN_SECRET` obligatorio (`:?` en producción, valor explícito en desarrollo); `TORCH_NUM_THREADS` e `INFERENCE_CONCURRENCY` (1) para la campaña |
| Token de procedencia | HMAC-SHA256 sobre modelo, representación y SHA-256 del vector, formato `v1.<carga>.<firma>`; nadie lo verifica hasta F7 |
| Pruebas | `make test` y el gancho de pytest corren en el contenedor de desarrollo (`+cpu` no existe en macOS); la comparación estática cubre las operaciones multipart sin el cuerpo, con el motivo escrito |
| Dependencias y CI | Índice CPU de PyTorch; paso de auditoría de torch y torchvision sin `+cpu`; `check-added-large-files` excluye `checkpoints/` |
| Licencias | Pesos de EdgeFace CC BY-NC-SA 4.0 (uso no comercial); código BSD-3 y MIT |
| Memoria, capítulo 7 | La matriz de capacidad cruzaba la detección con los tres modelos; la detección no depende del modelo y ahora es una sola celda |

**Sesión 14 — instrumento de carga MoST (#120) y primera tanda de la campaña.**
**Fusionado**: PR #5 de `fr-commercial-microservice` (`fase4/120`, 4 commits),
con commit de fusión `3b15df6`; CI de `main` `38372847972` en verde; #120
cerrado, #62 referenciado. Antes de fusionar se comprobó que la cabeza seguía
en `bed0d8e`, con su CI (`38362849316`) en verde, y que
`closingIssuesReferences` era exactamente `TFM-MIS-MEM/docs#120`. Instrumento
congelado en `b6fff3d`; 175 corridas, todas válidas.

- **Qué hay.** `load/`: k6 con tasa de llegada constante contra la imagen de
  producción, sin pasarela, red `internal` propia y cpusets disjuntos
  (aislamiento lógico, no físico: 8 vCPU ocupados rinden como ~3,3 sueltos).
  Tres restricciones iguales en las dos ventanas (60 s y 600 s); la de latencia
  compara **medianas** de tercios (≤ 1,5), no p95. Precondiciones que bloquean,
  corridas inválidas que se repiten, `analyze.py` que recalcula todo.
- **Medido.**
  - Calibración: MST 9,31 y MIT 9,03 frente a 9,69/s medidos dentro del
    contenedor (el `sleep(0.1)` dura 103 ms; la hipótesis del GIL, refutada).
    La banda [9,4, 10,0] no se cumple; **error del procedimiento declarado:
    hasta ~10 %** (5 % de bisección + 5 % si la confirmación baja un escalón).
    Un 2,4 % entre lo que mide el contenedor y lo que ve k6, sin explicar.
  - Configuración fijada: **1 worker × 1 hilo × concurrencia 8** (criba de
    siete, con 2, 4 y 8 workers incluidos).
  - **verifyPair xs: MIT 17,10, MST 13,34, ráfaga 1,28** (entregable).
    Datos de #62: base 17,50 / 12,30; s 18,50 / 13,32; detectFaces 51,30 / 38,99.
    σ_S ≈ 2,9–3,2 de verificación frente a detección; **entre modelos, la
    diferencia no supera el error del método**: a 480 × 640 manda MTCNN.
  - La capacidad cae los primeros ~3 min de carga plena y luego se estabiliza
    (deriva a 15,75/s: 13,55/s constantes del minuto 4 al 15). Causa térmica,
    hipótesis no medida.
- **Errores y lecciones.** La deriva se lanzó al 90 % del MIT y no del MST
  (error de especificación): no pasó la puerta, se informa como peor caso y no
  se repite. La cadena del viernes se suspendió por faltar `< /dev/null`. El
  criterio relativo deja pasar corridas congestionadas que no crecen (w4t1c1 a
  13,75: 653→667 ms); no cambió la elección.
- **Queda.** Los tres perfiles 1:N (~6–8 h) y la siembra de galerías (~1 h por
  galería por la API, minutos directo en MongoDB), tras F8.

| Dónde | Cambio |
|---|---|
| Memoria, capítulo 7 | Ventanas 60 s / 600 s, calentamiento de 30 s al 50 %, mediana de tercios ≤ 1,5, bisección al 5 %, confirmación 3 de 3 con dos bajadas del 5 %; error del procedimiento hasta ~10 % |
| Memoria, capítulo 7 | Calibración que no cumple su banda previa, con la capacidad medida aparte como referencia; aislamiento por cpuset lógico; capacidad que cae los primeros minutos (hipótesis térmica) |
| Pricing (memoria y CLAUDE.md) | Los pesos hipotéticos (detector 1; xs 1, s 3, base 10) no se sostienen a 480 × 640: verificar ≈ 3 detecciones con cualquier modelo. Lo corrige #62 al cerrar la campaña |
| Configuración de `fr` | `WEB_CONCURRENCY=1`, `TORCH_NUM_THREADS=1`, `INFERENCE_CONCURRENCY=8` para la campaña |

**Sesión 15 — F3 (#35), CRUD de galerías.** **Fusionado**: PR #6 de
`fr-commercial-microservice` (`fase2/35`, cabeza `bda75d7`), con commit de
fusión `d840e6f`; CI de `main` `38539525348` en verde; #35 cerrado. Antes de
fusionar se comprobó la cabeza, su CI (`38382476899`) en verde y que
`closingIssuesReferences` era exactamente `TFM-MIS-MEM/docs#35`.
Partida: `main` en `3b15df6`, CI `38372847972` en verde, 359 pruebas. Salida:
440 pruebas, cobertura 99,14 %.

- **Qué hay.** `createGallery`, `listGalleries`, `updateGallery` y
  `deleteGallery`; `IMPLEMENTED` pasa a las cinco de galerías más las tres de
  inferencia. Listado por `_id` ascendente (con `{accountId, name}` el plan es
  `SORT` en memoria sobre las galerías de la cuenta, medido); `total` con
  `count_documents` en paralelo (`COUNT_SCAN`), consistencia aceptada.
  `PATCH {}` no escribe; una congelada se edita; `null` es `400`; `""` en
  `name` se acepta conforme al contrato (propuesta de cambio: #121).
- **Provisional hasta F10.** Sin `model`, `xs`; no se emiten los `403` de plan.
  La reconciliación de galerías creadas fuera de plan, anotada en #42.
- **Cascada sin transacciones**: rostros → identidades → galería. Probada con
  caída inyectada en los dos últimos pasos (galería visible, el reintento
  termina); con el orden invertido, las dos en rojo. La carrera con un
  `addFace` concurrente, anotada en #36.
- **Medido.** El `DuplicateKeyError` de `find_one_and_update` lleva
  `keyPattern` pero **no** `index`: el `409` se traduce desde `keyPattern`.
  `utc_now` se trunca a milisegundos para que el `201` coincida con la lectura.
- **El comparador sigue sin comparar cuerpos de petición JSON**: el «hasta F3»
  de la sesión 9 queda sin efecto. `createGallery` y `updateGallery` entran con
  `without_body`; las cotas del cuerpo las vigilan pruebas en los dos lados.
- **Queda.** F4 con F6.

**Sesión 16 — F4 (#36) con F6 (#38), identidades y rostros.** **Fusionado**: PR
#7 de `fr-commercial-microservice` (`fase2/36`, cabeza `75f9b6c`), con commit de
fusión `c39513c`; CI de `main` `38870255327` en verde; #36 y #38 cerrados
(COMPLETED). Antes de fusionar se comprobó la cabeza, su CI (`38785245393`) en
verde y que `closingIssuesReferences` era exactamente `TFM-MIS-MEM/docs#36` y
`TFM-MIS-MEM/docs#38`.
Partida: `main` en `d840e6f`, CI `38539525348` en verde, 440 pruebas. Salida:
566 pruebas, cobertura 99,09 %. Las pruebas, en un commit propio y en rojo
antes del código (`e414868`): 130 rojas, 115 nuevas.

- **Qué hay.** Las siete operaciones; el rostro, como código LSSC de 192 B del
  modelo de la galería (igual byte a byte a `extractEmbedding`, probado en los
  tres modelos). `403 GALLERY_FROZEN_MODEL_NOT_IN_PLAN` en las altas; las bajas
  y `updateIdentity`, permitidas sobre una congelada.
- **Contadores sin transacciones**: ninguna alta deja un contador por encima;
  ninguna baja deja `faceCount` de la identidad por encima. Los de la galería
  en las bajas, a la reconciliación. `deleteIdentity` probada con caída
  inyectada en dos puntos.
- **Carreras cerradas con una marca de borrado** (`deletingAt`) en
  `deleteGallery` ---cambia F3--- y `deleteIdentity`, filtrada por el `$inc` de
  las altas, que compensan. El `409 LAST_FACE_OF_IDENTITY`, de un decremento
  condicional. Entrelazados forzados con dos tareas en el bucle del
  `TestClient`; siete mutantes, cada uno en rojo en su prueba.
- **Medido.** Un control de entrelazado tiene que pausar ENTRE la lectura y
  la escritura del mutante: pausado tras el decremento, el de dos `deleteFace`
  pasaba en verde con lectura previa. FastAPI 0.141.1 entrega `""` multipart al
  modelo, y `externalId=""` es `400`.
- **Sin cubrir, a propósito.** Tres líneas de `delete_face`
  (`src/controllers/identities.py`), ramas de carrera: la identidad desaparece
  entre la lectura del rostro y el decremento, y el rostro lo borra otra
  petición entre el decremento y el borrado (se devuelve el decremento). No
  se prueban.
- **Registrado.** #123 (`alcance:futuro`): `listIdentities` ordena en memoria.
- **Queda.** F8.

**Sesión 17 — F8 (#40), verificación contra identidad y búsqueda 1:N.**
**Fusionado**: PR #8 de `fr-commercial-microservice` (`fase2/40`, cabeza
`2fbd617`), con commit de fusión `ec05a34`; CI de `main` `39119439845` en
verde; #40 cerrado (COMPLETED). Antes de fusionar se comprobó la cabeza, su CI
(`38974667898`) en verde y que `closingIssuesReferences` era exactamente
`TFM-MIS-MEM/docs#40`.
Partida: `main` en `c39513c`, CI `38870255327` en verde, 566 pruebas. Salida:
648 pruebas, cobertura 99,18 %. Las pruebas, en un commit propio y en rojo
antes del código (`6c6f129`): 69 rojas y el error de colección de `test_shape`.

- **Qué hay.** `verifyAgainstIdentity` y `searchGallery`. La imagen, por el
  camino de F4 (`lssc_code`, modelo de la galería); Hamming vectorizado
  (`lssc.hamming_many`, `np.bitwise_count` sobre palabras de 64 bits); la
  decisión con `lssc.confidence(int(d))`, la expresión de `default_threshold`:
  `d = d_max` coincide, probado en la frontera en los tres modelos con códigos
  sembrados a distancia exacta del de la imagen.
- **Decidido.** verify cuenta la menor distancia sobre los rostros de la
  identidad; una identidad sin rostros es `404` (residuo de un `createIdentity`
  fallido: su cliente recibió un error). search: `confidence` solo con
  coincidencia (sin identidad no hay de quién sea); empate por **menor
  identificador** de rostro, no «el enrolado antes» (un `ObjectId` solo sigue el
  orden de alta dentro de un proceso); el mejor rostro de una identidad marcada
  o borrada es «sin coincidencia», sin pasar al siguiente: conservador, nunca
  devuelve una identidad que no sea la del mejor rostro, a cambio de un posible
  falso negativo en la ventana del borrado. `livenessToken`, `400
  LIVENESS_NOT_SUPPORTED` hasta F12. `shape.py` traduce `anyOf: [X, NullValue]`
  (`NullValue` por su forma), con controles en pareja.
- **Dónde se compara.** En el hilo de trabajo, bajo el semáforo de la
  inferencia, nunca en el bucle. search infiere, recupera y compara: con el
  servicio saturado hace cola dos veces, y eso sale en el p95. verify lee sus
  rostros antes de inferir y compara en el mismo trabajo.
- **Provisional.** `threshold` aceptado siempre hasta F10; vectores hasta F7;
  token de enrolamiento hasta F11.
- **Medido**, una vez, contra el `fr` de desarrollo: 20 búsquedas secuenciales
  por tamaño, códigos aleatorios de 192 B, plan `IXSCAN {galleryId: 1}` en
  todos (claves = documentos = rostros). Ninguna búsqueda coincide, así que la
  lectura de la identidad ganadora no entra; en la campaña sí (decisión 3, más
  abajo).
  Recuperación: del `find` a tener los códigos. Comparación: dentro del hilo.
  Tiempos en ms; los informes completos, en el cuerpo del PR #8.

  | Tanda | Rostros | MongoDB | Recuperación, mediana / p95 | Comparación, mediana / p95 | RSS antes → pico (MB) |
  |---|---|---|---|---|---|
  | 1, `dict` (`9e885b4`) | 5.000 | 3 | 5,43 / 47,06 | 0,27 / 0,32 | 709 → 711 |
  | 1, `dict` | 50.000 | 22 | 101,14 / 169,85 | 2,88 / 3,32 | 679 → 724 |
  | 2, `RawBSONDocument` (`2fbd617`) | 5.000 | 2 | 6,02 / 8,13 | 0,27 / 0,31 | 718 → 735 |
  | 2, `RawBSONDocument` | 20.000 | 9 | 22,88 / 65,07 | 0,99 / 1,18 | 684 → 694 |
  | 2, `RawBSONDocument` | 50.000 | 26 | 55,68 / 127,44 | 2,54 / 2,93 | 688 → 724 |

  Recuperación y comparación, lineales en el número de rostros; la
  comparación, de 2,5 a 2,9 ms a 50.000, no es el cuello de botella.
- **El criterio del BSON, y por qué se conserva el cambio sin cumplirlo.** Se
  fijó probar la alternativa si la recuperación pasaba de 10 ms a 50.000, y
  conservarla si la reducía a la mitad. Bajó de 101 a 55,7 ms; la mitad era
  50,5. Se conserva igualmente: el criterio estaba mal planteado, porque medía
  la recuperación entera, que incluye la ejecución en MongoDB (22 y 26 ms), que
  el código no puede cambiar y que no corre en el proceso del servicio. Lo que
  limita la capacidad es la parte en Python, en serie en el bucle con un
  worker, y pasa de ~79 a ~30 ms por búsqueda. Con eso, a 50.000, el bucle ya no
  queda por debajo de la inferencia: ~33 búsquedas/s frente a ~26/s estimadas
  con los MST de la sesión 14. Moverla a un hilo no habría contado: no suelta
  el GIL.
- **Campaña, tres decisiones.**

  1. **Perfiles 1:N (sustituye a la sesión 14).** Tres,
     todos con `xs`, con galerías de 5.000, 20.000 y 50.000 rostros, en lugar
     de uno por modelo con tamaño fijo. Un solo modelo, porque la sesión 14
     midió que a 480 × 640 los tres cuestan lo mismo dentro del error del
     método, y la comparación es idéntica en los tres (códigos de 192 B).
     Varios tamaños, porque es lo único que permite estimar
     `f(tamaño_galería)`, y la medida de F8 muestra recuperación y comparación
     lineales en el número de rostros. Los tamaños abarcan un orden de magnitud
     con un punto intermedio; no se justifican por el pricing, que es
     provisional y sale de la campaña. La variación del modelo en 1:N pasa a
     trabajo futuro.
  2. **Añadir `searchGallery` a `k6/profile.js` no obliga a repetir la
     calibración: se mantiene `w1t1c8`.** La parte de la búsqueda que va en
     serie por el GIL (~30 ms a 50.000, ~33/s) queda por encima de la capacidad
     de inferencia (~26/s), así que el límite sigue siendo la inferencia, para
     la que se calibró. Además, la fórmula de unidades compara operaciones y
     solo vale sobre el mismo despliegue. Con galerías bastante mayores que
     50.000, el límite pasaría al trabajo en Python por proceso y convendría
     más de un worker: trabajo futuro.
  3. **Las búsquedas de la campaña coinciden.** En cada galería, una identidad
     enrolada por la API con la imagen de k6; el resto de rostros, sembrado
     directamente con códigos aleatorios. Así se mide la operación completa,
     con la lectura de la identidad ganadora: un extra constante que no altera
     `f(n)`.
- **Registrado.** #124 (`alcance:futuro`): el `400` de `createIdentity` y
  `addFace` no nombra sus códigos. #125 (`alcance:futuro`, va a la memoria): en
  1:N, con el umbral de FAR 1e-4 por par, un desconocido coincide con alguien
  con probabilidad ≈ 1 − (1 − 1e-4)^N: ~39 % a 5.000 y ~99 % a 50.000. Una
  línea en #43: `searchGallery` sigue sin token cuando F11 lo admita.
- **Queda.** Los tres perfiles 1:N: la siembra y el perfil de búsqueda en
  `load/`, en la sesión siguiente.

| Dónde | Cambio |
|---|---|
| Contrato de `fr` | verify y search: el comparador y el `400` en línea con sus códigos; `LIVENESS_NOT_SUPPORTED`; `confidence` de search en [0, 1] y solo con coincidencia; desempate por menor identificador; identidad sin rostros, `404` |
| Memoria, capítulo 7 | Perfiles 1:N: `xs` con 5.000, 20.000 y 50.000 rostros; la variación del modelo en 1:N, trabajo futuro |
| Memoria, capítulo 7 | `searchGallery` en el perfil sin recalibrar (`w1t1c8`): el límite sigue siendo la inferencia; más de un worker para galerías mucho mayores, trabajo futuro |
| Memoria, capítulo 7 | Búsquedas que coinciden: una identidad enrolada por la API con la imagen de k6, el resto sembrado con códigos aleatorios |
| Memoria, capítulo 7 | Recuperación frente a comparación a 50.000: la recuperación domina; el BSON en Python, de ~79 a ~30 ms con `RawBSONDocument` |
| Memoria | Falsa aceptación en 1:N y en verify con k rostros (#125) |

**Sesión 18 — perfiles 1:N en `load/` (#62).** **Fusionado**: PR #9 de
`fr-commercial-microservice` (`fase4/62-busqueda`, cabeza `82cfb01`), con
commit de fusión `5f48e92`; CI de la cabeza `39124546675` y de `main`
`39126761309` en verde; `closingIssuesReferences` vacío (#62 referenciado, no
se cierra hasta el análisis). Partida: `main` en `ec05a34`, CI `39119439845` en
verde.

- **Qué hay.** `searchGallery` en `k6/profile.js` (la excepción de la
  congelación); `seed.py`, que siembra en el contenedor `seed` (imagen de `fr`,
  red `internal`, vCPU 0–1) una galería `xs` con una identidad enrolada por la
  API (`koch_2023`) y el resto directo en MongoDB, un rostro por identidad,
  con las clases de persistencia del servicio; una comprobación que bloquea al
  empezar el perfil y se repite al acabar; si falla al acabar, el perfil queda
  como no válido en `search-status.json`. En `most.py`, solo aditivo: comparado
  por AST contra `b6fff3d`, cambian `Service.state`, `execute`, `profile_name`
  y `main`; la corrida, la búsqueda, la confirmación y la validez, no.
  `criteria.py`, sin diferencias. Nuevo en el estado de cada corrida: CPU de
  `fr` y de mongo (`cpu.stat`) y `opLatencies.reads` de mongo. `most.py search`
  lanza los tres perfiles en secuencia; el estado, en
  `results/search-status.json`.
- **Decidido.** Un rostro por identidad; sin horquilla, desde 1/s como
  verifyPair xs; una comprobación por perfil y no por corrida (la galería vive
  en mongo, y recrear `fr` no recrea mongo: medido); si mongo cae en mitad de
  una corrida cuenta como «no pasa», no como inválida (validez congelada), y
  queda a la vista en el meta. Criterio de «lo limita MongoDB» en
  `load/README.md`; la interpretación numérica, en `analyze.py`.
- **Prueba en seco** (no es medida de la campaña): 500 rostros a 1/s y a 8/s,
  válidas y pasan; búsqueda con confianza 0,712 (umbral 0,688); siembra de
  50.000 en 0,98 s en MongoDB, 3,4 s con la comprobación. La CPU de mongo tiene
  un fondo de ~0,1 vCPU que no depende de la tasa (hipótesis: el healthcheck con
  `mongosh` cada 2 s); cada búsqueda suma ~4 operaciones en `reads`.
- **Lanzado** desde `5f48e92` (`main` tras la fusión), la noche del 18/10. La
  hora exacta de arranque, en la sesión siguiente, desde
  `results/search-status.json`.
- **Queda.** Lanzar los tres perfiles (~6–7 h; peor caso ~8,5 h); versionar los
  resultados y analizarlos (`analyze.py`, incluido el fondo de CPU de mongo) en
  la sesión siguiente, en otro PR.

| Dónde | Cambio |
|---|---|
| CLAUDE.md | Excepción de la congelación ampliada a los cambios aditivos de los perfiles 1:N; MongoDB entra en lo medido |
| Memoria, capítulo 7 | Siembra de las galerías 1:N y su comprobación; MongoDB en los vCPU 0–1 con k6, y su registro por corrida |

**Sesión 19 — análisis de los perfiles 1:N (#62).** Sigue en el chat de la 18.
**Fusionado**: PR #10 de `fr-commercial-microservice` (`fase4/62-analisis`,
cabeza `fc9dbb9`), con commit de fusión `157101d`; CI de la cabeza
`39227737199` y de `main` `39228424480` en verde; `closingIssuesReferences`
vacío. Partida: `main` en `5f48e92`.

- **La campaña 1:N, terminada y válida.** Del 18/10 a las 20:46 al 19/10 a las
  04:43 (UTC), 7 h 57 min; los tres perfiles válidos, con la comprobación de la
  galería bien al empezar y al acabar. Datos en un commit propio (`ff56a4a`).

  | Rostros | MIT (/s) | MST (/s) | 1000/MST (ms) | Latencia a 1–2/s (ms) |
  |---|---|---|---|---|
  | 5.000 | 30,40 | 20,80 | 48,08 | 77,0 |
  | 20.000 | 20,00 | 16,15 | 61,92 | 94,5 |
  | 50.000 | 12,50 | 9,59 | 104,28 | 132,5 |

  f(n): 1,27 µs por rostro en capacidad y 1,24 en latencia (ajuste lineal, 3
  puntos). σ_S respecto a detección: 1,87, 2,41 y 4,07.
- **Qué limita: una parte en serie dentro del proceso de `fr`, no MongoDB.** De
  5.000 a 50.000, 1000/MST sube 56,2 ms, lo mismo que la latencia aislada a 1 y
  2/s: la parte de f(n) no se reparte entre las 8 inferencias. La CPU de `fr` en
  las corridas que fallan baja con n (2,89 → 2,36 → 1,84 vCPU). MongoDB lo
  descarta una cota con lo medido: ~25 ms de CPU por búsqueda sobre sus 2 vCPU,
  ~77–80 búsquedas/s, ocho veces el MST. Que sea el bucle de eventos o el GIL
  del único worker es inferencia: se confirma midiendo con más workers,
  trabajo futuro.
- **El criterio del README no decide**, y se conserva tal cual con su resultado
  debajo: sin cifra para «claramente», a 50.000 da MongoDB en 8 de 8 corridas
  que fallan con un umbral ≤ ×1,28 y en 4 de 8 a ×1,5; su cláusula de CPU es
  falsa a 5.000 por construcción y a 50.000 se cumple con 0,016 vCPU de margen.
- **Dos bajadas de escalón en el MST de 50.000** (10,62 → 10,09 → 9,59, por la
  017 y la 020; la 020 coincide con una liberación de swap de 1,5 GB). Error
  del procedimiento en esa celda, ~15 %, por encima del ~10 % declarado. Con
  10,62/s el incremento de 1000/MST sería de 46,1 ms, el 83 % del de latencia:
  la conclusión se mantiene.
- **#62 sigue abierto** hasta decidir los pesos; comentario con el alcance
  actual (siete perfiles). Registrado: #126 (`prio:2-demo`), el «Estado» del
  README de `fr-commercial-microservice`, desfasado.
- **Queda.** Los pesos del pricing (Miguel). Corregir en `CLAUDE.md` el motivo
  de la excepción de «Modo entrega»: dice que hasta 50.000 rostros la búsqueda
  sigue limitada por la inferencia, y la campaña midió que no. La demo (#115).

| Dónde | Cambio |
|---|---|
| CLAUDE.md | El motivo de la excepción de los perfiles 1:N: el límite no es la inferencia sino una parte en serie dentro de `fr` |
| Memoria, capítulo 7 | f(n) medida; qué limita la búsqueda 1:N y la cota de MongoDB; el criterio que no decidió; dos bajadas de escalón a 50.000 |
| Pricing (memoria) | Los pesos, desde σ_S de los siete perfiles, cuando se decidan |

**Sesión 20 — la demo (#115).** Partida: `main` de api-gateway en `fba70f1`,
de fr en `157101d` y de docs en `6511c08`; `frontend` y `acme-demo` no
existían (se crean, privados). **Fusionado**, en este orden y con commit de
fusión: api-gateway#3 (`683cfe1`, sin CI: #93), fr#12 (`fd53be6`), fr#11
(`8e497f3`), frontend#1 (`226c972`), acme-demo#1 (`a2de300`) y este PR,
docs#130. CI de `main` en verde: fr `39634267287`, frontend `39634326327`,
acme-demo `39634374460`. Cerrados: #104, #105, #115, #126, #128.

- **La ruta de fr en la pasarela (#104).** `/v1/fr/commercial`, con la misma
  configuración que `pricing-route` y el limitador por cuenta en ámbito
  `global` hasta F10. Lo que solo lleva `enrollmentToken` se corta con `401`
  (anotado en `kong.yml` y en #43). `identity-headers.sh` comprueba la ruta
  con eco y contra fr real, con pares 200/404 entre dos cuentas. Se vio fallar
  contra una copia sin saneado. Cada push a `/config` comprueba ahora su `201`.
- **Panel** (`frontend`, `:5173`). Registro e inicio de sesión, la API KEY una
  sola vez (al registrarse y al rotarla), galerías con sus identidades y
  `verifyPair`. Refs #60.
- **Universidad ACME** (`acme-demo`, `:4000`). La matrícula llama a
  `createIdentity` con `externalId` y el acceso al examen a
  `verifyAgainstIdentity`. Solo su backend lee la API KEY y habla con la
  pasarela; el navegador le habla en el mismo origen. Medido: la clave no
  aparece ni en el bundle ni en las respuestas de `/api`.
- **La orden de la demo:** `./scripts/demo-up.sh`. Desde `docker ps` vacío,
  exit 0. No siembra nada. El respaldo es `demo-seed.sh` (Christina Koch con
  retratos de la NASA, de dominio público; matrícula ficticia). `dev-up.sh`
  levanta ya fr y el panel (#105). El recorrido de punta a punta, por la
  interfaz en Chromium, está en el cuerpo de frontend#1.
- **Pillow 13.0.0 (#128).** 8 CVE de 12.3.0 ponían en rojo la CI de fr. Con
  13.0.0, los vectores de 77 imágenes de LFW son idénticos bit a bit y
  `verifyPair` da la misma confianza. La campaña se midió en `157101d` con
  12.3.0 y no se repite.
- **Registrado:**
  - #127: `rate-limit.sh` no comprueba el push (`alcance:futuro`);
  - #129: desde un contenedor ajeno a `tfm-network`, `host.docker.internal`
    alcanza fr (`:3002`) y la Admin API de Kong (`:8001`) (`alcance:futuro`).
- **Queda.**
  - Los pesos del pricing (#62) y F10 con SPACE (#42), de Miguel.
  - Consumo y webhooks en el panel (#60).

| Dónde | Cambio |
|---|---|
| CLAUDE.md | Los repos `frontend` y `acme-demo`; los puertos 5173 y 4000; Vitest en los proyectos con Vite (lo pone Miguel). «Los microservicios solo son alcanzables a través de la pasarela» no se cumple en desarrollo con Docker Desktop (#129) |
| Memoria | La demo: los dos canales sobre la misma galería, y el respaldo |

**Sesión 21 — la tarifa en los issues y en el contrato (#62).** Sin código.
Partida: docs en `1ffbc99` (tarifa en `ea15df1` y regla 6 en `1ffbc99`, de
Miguel), fr en `8e497f3`. **Fusionado**, con commit de fusión: fr#13
(`afc7156`); CI de `main` `39765464354` en verde. Cerrados: #62, #58
(obsoleto; el resto va a #131), #59 (duplicado de #75) y #109 (`4d35a3f`,
`ea15df1`).

- **#62**, con un comentario: la tabla de unidades sale de σ_S de los siete
  perfiles, sin peso por modelo; la búsqueda, del ajuste lineal de
  5.000–50.000. Cifras de `load/README.md`, y σ_S de `analyze.py campaign`.
- **Revisión de los 72 abiertos**, contrastada con el código y el historial:
  13 con cambios y 59 vigentes. Hay un comentario de veredicto en los 10 que
  siguen abiertos (#41, #42, #44–#49, #60, #84). Etiquetas: #41 y #60 a
  `prio:3-si-da-tiempo`; #122, con `svc:fr` y `tipo:infra`.
- **Decidido (Miguel).** Agotar las unidades de cualquiera de las tres
  ventanas es `403 QUOTA_EXCEEDED`, con `details` (regla 6). Los vectores y la
  prueba de vida quedan fuera de la tarifa: hoy se rechazan con `400`. El
  Pricing2Yaml entra con SPACE (#51), junto a F10 (#42). **Sin decidir:** los
  complementos en Free y Business (#48) y al cambiar de plan (#49), con la
  pregunta anotada en cada uno.
- **fr#13, solo texto de descripción.** La tabla de unidades, el «Consumo» de
  cada operación, el umbral solo en Business, `QUOTA_EXCEEDED` en las tres
  ventanas, la prueba de vida fuera de la tarifa y `faceCount` con el límite
  por cuenta. Quitando las `description` de texto, el contrato es idéntico al
  de `main`. Ojo con esa comprobación: tiene que quitar **solo las de texto**,
  porque `Gallery` tiene una propiedad que se llama `description`. Siguen
  provisionales hasta F10 que `recognition.py` acepte `threshold` siempre y
  que nadie emita `QUOTA_EXCEEDED`.
- **Queda.**
  - F9 (#41), y F10 con SPACE (#42, #51).
  - `pricing.yaml`, que sigue con la tarifa anterior: `Limits` en peticiones
    por segundo, y `liveness` en `AddOnId` (#46, #48).

| Dónde | Cambio |
|---|---|
| Memoria, capítulos 5 y 7 | La tarifa definitiva y los pesos medidos; `QUOTA_EXCEEDED` en las tres ventanas; vectores y prueba de vida fuera de la tarifa |
| Memoria, contrato | El de fr ya describe la tarifa (fr#13); el de pricing todavía no (#46, #48) |

**Sesión 22 — SPACE: estudio e integración básica (#42, #51).** Partida: `main`
de pricing en `cbf9371`, de fr en `afc7156`, de frontend en `226c972` y de docs
en `d646f98`. **Nada fusionado**: cinco PR abiertos, pendientes de revisión
(pricing#4 y #3, fr#14, frontend#2 y docs#140). El estudio (`NOTAS.md`, `PLAN.md` y las
pruebas) está en `~/master/tfm/space-estudio/`, fuera de los repositorios.

- **Estudio.** SPACE v1.7.1 carga la tarifa 3.1 por SPHERE o por fichero, pero
  sin una `expression` por funcionalidad evalúa todo a `false`; un límite
  renovable solo se aplicaba en su primer periodo; deshacer restaura una
  instantánea en vez de restar; su nginx limita a 20 peticiones/s por IP; la
  clave `EVALUATION` no puede evaluar. Lo demás, en `NOTAS.md`.
- **Tarifa 1.1** con expresiones, publicada por Miguel en SPHERE (versión
  `6ada81594b2b5b01c587d1f0`) y versionada en
  `pricing-microservice/pricing/fr-commercial-pricing.yaml`. La versión fijada
  vive en `pricing/sphere.env`; huella comprobada contra el manifiesto.
- **SPACE desplegado** en `pricing-microservice/space/`: sin puertos, secretos
  con `${VAR:?}`, sincronización automática apagada, y la imagen construida
  desde el tag con el parche de renovación (prueba antes y después).
  `dev-up.sh` lo levanta antes que pricing y fr, y `space-bootstrap.sh` emite
  las claves `MANAGEMENT` y carga la versión fijada con `all_pick`.
- **fr (F10).** Contrato primero (`503 PLAN_UNAVAILABLE` en los dos canales,
  «El plan de la cuenta»), luego el código: plan desde `pricingContext` del
  token, unidades imputadas antes de inferir y sin deshacer, límites de estado
  con los contadores de fr, congelación al vuelo, umbral solo en Business,
  contrato FREE en el primer uso. 722 pruebas, cobertura 99,06 %.
  Comprobación contra SPACE real en el PR.
- **pricing.** Novación desde Stripe: compra → plan comprado, baja → FREE.
- **Panel.** Vista de planes pintada desde la versión fijada en SPHERE
  (CORS medido: `*`), con pricing4ts cargado bajo demanda.
- **Demo.** `demo-plan.sh` pone la cuenta de ACME en BUSINESS; `demo-up.sh` lo
  llama antes de comprobar ACME. Recorrido de la sesión 20 repetido en Chromium
  por la interfaz, en verde, más la segunda galería en FREE
  (`GALLERY_LIMIT_REACHED`) y la vista de planes; salida en el PR de frontend.
  `acme-demo/.env` queda con la cuenta del recorrido, como en la sesión 20.
- **Issues nuevos** (`alcance:futuro`): #132 (contrato FREE desde pricing con
  `account.created`), #133 (complementos y cambio de plan), #134 (mes de SPACE
  y Stripe), #135 (`account.deleted` → borrar contrato; exige clave `ALL`),
  #136 (devolver unidades), #137 (caché del plan) y #138 (analítica por canal).
  #139: la CI de pricing, roja en «Security audit» por avisos nuevos ajenos.
- **Revisión.** #139 en su propio PR (pricing#4: solo lockfile). `uuid`
  forzado a `>=11.1.1` en el panel (pricing4ts lo declara sin importarlo; aviso
  aguas arriba en #141). La imagen de SPACE se construye una vez y `dev-up.sh`
  no la reconstruye (medido desde `docker ps` vacío). Las lecturas de una
  galería reflejan la congelación al vuelo. fr#14 cierra #42 y #84; pricing#3,
  #51. `CLAUDE.md` al día (regla 4).
- **Queda.** Fusionar, por este orden: pricing#4, pricing#3, fr#14, frontend#2
  y docs#140. Proponer el parche de renovación al repositorio de SPACE.

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
alcance. ~~Queda abierto con esa corrección escrita en su comentario, propuesto
para cerrarse como improcedente~~. **Cerrado el 08/09 como `NOT_PLANNED`**
(anotado en la sesión 10: este documento lo siguió dando por abierto).

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

### Siguiente paso: F9 (#41) y F10 con SPACE (#42, #51)

Los pesos están decididos y el contrato de fr los describe (sesión 21). F9
calcula las unidades de la tabla de `CLAUDE.md`; F10 las aplica en las tres
ventanas, junto con los rostros por cuenta, las galerías y las features (canal
de API, con la propuesta de ejecutar ahí #84; 1:N; umbral solo en Business).

#### ~~Siguiente paso: pesos del pricing y F10~~ — los pesos, decididos en la sesión 21

La demo está hecha (sesión 20). Quedan los pesos del pricing desde σ_S de los
siete perfiles, que cierran #62, y F10 con SPACE (#42). Los dos son de Miguel.

#### ~~Siguiente paso: pesos del pricing → demo~~ — la demo, hecha en la sesión 20

La campaña está medida y analizada (sesión 19). Queda decidir los pesos del
pricing desde σ_S de los siete perfiles (Miguel), que cierra #62; corregir el
motivo de la excepción de «Modo entrega» en `CLAUDE.md`; y la demo (#115).

#### ~~Siguiente paso: análisis de los perfiles 1:N → demo~~ — hecho en la sesión 19

Los tres perfiles 1:N se lanzaron en la sesión 18 desde `5f48e92`. Lo que
queda de la campaña:

- Versionar `results/campaign/searchGallery-xs-{5000,20000,50000}` y
  `results/search-status.json`.
- `analyze.py` con los tres perfiles: MIT, MST, ráfaga, `f(n)`, la CPU de `fr`
  y de mongo restando el fondo de la corrida a 1/s, y el criterio de «lo
  limita MongoDB» de `load/README.md`.
- Otro PR, con `Refs TFM-MIS-MEM/docs#62`; #62 se cierra con el análisis.
- Después, la demo (#115).

Lo que dice la entrada de abajo de que cualquier cambio de `most.py` obliga a
recalibrar ya no es exacto: rige la excepción de `CLAUDE.md`, «Modo entrega».

#### ~~Siguiente paso: perfiles 1:N~~ — lanzados en la sesión 18

F8 hecho en la sesión 17 (PR #8, fusión `ec05a34`). Los perfiles 1:N son tres,
todos con `xs`, con galerías de 5.000, 20.000 y 50.000 rostros (decisión de la
sesión 17, que sustituye a la de la sesión 14). La siembra y el perfil de
búsqueda van en `load/`: en cada galería, una identidad enrolada por la API con
la imagen de k6 y el resto sembrado con códigos aleatorios, para que las
búsquedas coincidan. Añadir `searchGallery` a `k6/profile.js` **no** obliga a
repetir la calibración (`w1t1c8` se mantiene, decisión 2 de la sesión 17);
cualquier otro cambio de `criteria.py`, `most.py` o `k6/profile.js`, sí.

#### ~~Siguiente paso: F8 (#40) → perfiles 1:N~~ — F8 hecho en la sesión 17

F4 con F6 hecho en la sesión 16 (PR #7, fusión `c39513c`). F8 compara contra los códigos
guardados con `lssc.hamming`, sobre `{galleryId}` en `faces`.

#### ~~Siguiente paso: F4 (#36) con F6 (#38) → F8 (#40) → perfiles 1:N~~ — F4 con F6 hecho en la sesión 16

F3 hecho en la sesión 15. F4 hereda `conflict_code` para el `409` de
`externalId` y la carrera de la cascada anotada en #36.

#### ~~Siguiente paso: F3 (#35) → F4 (#36) con F6 (#38) → F8 (#40) → perfiles 1:N~~ — F3 hecho en la sesión 15

Con el instrumento hecho y cuatro de los siete perfiles medidos (sesión 14),
lo que falta de la campaña depende de F8 y de cómo se siembren las galerías.

#### ~~Siguiente paso: el instrumento de carga~~ — hecho en la sesión 14

Orden previsto: instrumento de carga → F3 (#35) → F4 (#36) con F6 (#38) → F8
(#40) → campaña (#62) → demo. **La campaña tiene que empezar antes del 15/10.**
El instrumento fija `TORCH_NUM_THREADS` e `INFERENCE_CONCURRENCY` antes de
medir: con los valores por omisión, la dispersión de las latencias de F5 cubre
las diferencias entre modelos (PR #4 de `fr-commercial-microservice`).

#### ~~Siguiente paso: F5 (#37), carga de modelos e inferencia sin estado~~ — hecho en la sesión 13

Se conserva el enunciado anterior.

Orden previsto: F5 (#37) → instrumento de carga → F3 (#35) → F4 (#36) con F6
(#38) → F8 (#40) → campaña (#62) → demo. **La campaña tiene que empezar antes
del 15/10.**

#### ~~Siguiente paso: por decidir al cerrar la sesión 11~~ — decidido en la sesión 12

Se conserva el enunciado anterior. Lo que dice de #106 dejó de valer en la
sesión 12: ya no bloquea F4.

F2 está hecho y fusionado: PR #3 de `fr-commercial-microservice`, commit de
fusión `da38e25`, CI de `main` `37501294383` en verde, #34 cerrado.
El orden de los issues pone a continuación F3 (#35), el CRUD de galerías; #106
sigue bloqueando F4, no F3. Lo que F2 deja escrito para las fases siguientes:

- **F3 y F4 traducen `DuplicateKeyError` a `409` según el índice que saltó**
  (`keyPattern`), sin comprobar antes de escribir, con el código de `CONFLICTS`
  de `src/documents`.
- **F4: `faceCount` de la identidad empieza en 0**, y el `$inc` va después de
  insertar el rostro. Si se quieren transacciones, hace falta un replica set de
  un nodo, y lo decide F4.
- **#106 (con #105) antes de F4.** `ensure_indexes` correrá con el usuario de
  la aplicación: hay que comprobar que `readWrite` basta. Y el volumen de
  desarrollo hay que recrearlo, porque la imagen no crea el usuario sobre uno
  ya inicializado (medido).
- **Cambiar la forma de un índice exige una migración explícita**: el arranque
  se niega ante el viejo.

#### ~~Siguiente paso: F2 (#34), modelos de dominio e índices~~ — hecho en la sesión 11

Se conserva el enunciado anterior. El índice «único y disperso» que cita resultó
no hacer lo que se esperaba, y es parcial (véase la sesión 11).

**Decidido al cerrar la sesión 10.** Con #103 fusionado, el contrato de `fr` ya
no tiene defectos conocidos que bloqueen el CRUD, y el orden vuelve a ser el de
los issues. F2 va antes que F3 porque el CRUD de galerías (F3) y el de
identidades y rostros (F4) necesitan lo que F2 define: las colecciones
`galleries`, `identities` y `faces` conforme al modelo de `CLAUDE.md`; el índice
`{galleryId}` en `faces`, crítico para la identificación 1:N; el índice único y
disperso `{galleryId, externalId}` en `identities`; y los contadores
desnormalizados `identityCount` y `faceCount`.

F2 **no implementa ninguna operación**: el guardián de montaje sigue exigiendo
exactamente `{getGallery}`. Lo que hereda de las sesiones 9 y 10:

- **Los modelos de la API, cerrados.** Todo modelo de entrada o de respuesta
  nuevo lleva `extra="forbid"`: el contrato prohíbe lo que no declara, y un
  modelo abierto da diferencia en la comparación estática. Está escrito en
  `src/models/__init__.py`. Los modelos de persistencia no son esquemas del
  contrato y no les alcanza la regla, pero lo que sale de ellos hacia una
  respuesta pasa por un modelo que sí.
- **Los nulos, campo a campo según el contrato.** Los opcionales de `Gallery`
  se omiten, sin `exclude_none` global; `Identity.externalId` y otros sí
  admiten `null` (véase la sesión 9). `model_serializer` sin anotación de
  retorno (`CLAUDE.md`).
- **Redis no entra**: se traspasó de F1 a #43 (F11), con la salvedad de F10
  (#42) escrita en el traspaso.
- **#106, el MongoDB de `fr` sin autenticación, bloquea F4.** F2 es la primera
  fase que crea índices sobre esa base, así que al abrirla hay que decidir si
  #106 entra con ella o se queda donde está.
- **Desde F3 (#35), un caso negativo por cada parámetro acotado**, que desde
  #103 ya tiene un `400` declarado al que ajustarse.

#### ~~Siguiente paso: `fr-commercial`~~ — caducado en la sesión 10

Se conserva el enunciado anterior.

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

~~Quedan dos decisiones **antes de arrancar**~~ **Resueltas en la sesión 9**
---dependencia; openapi-core más comparación estática---. Se conserva el
enunciado original:

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
  **Falso del 01/10 al 06/10**: la raíz tenía una copia, no el enlace (véase la
  sesión 11).

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

- ~~**Dónde vive la prohibición de campos no declarados en `fr-commercial`.**~~
  **Decidido en la sesión 9: en el contrato (vía C), en el PR de #103.** Ningún
  esquema del contrato cierra `additionalProperties` (36 esquemas de objeto; el
  único que lo menciona, `ErrorReport.details`, lo declara abierto). Las cuatro
  vías medidas, sus números y el alcance decidido están en la entrada de la
  sesión 9.
- **Si `jest-openapi` admite OpenAPI 3.1.** Pendiente de medir, y solo cuando se
  plantee migrar el contrato de `fr` (vía D del punto 3): migrar un contrato solo
  deja los tres sin comparar entre sí.
- **Las 5 operaciones con `enrollmentToken` y las 2 solo `apiKeyAuth`.** La
  dependencia de identidad de F1 exige las tres cabeceras de la pasarela en
  todas. Pero `createIdentity`, `addFace`, `verifyAgainstIdentity` y las dos de
  prueba de vida admiten además un token de enrolamiento que `space-auth` no
  resuelve: por la pasarela, hoy, una petición que solo lleve ese token muere
  en un `401` de Kong, y si pasara llegaría sin `X-Account-Id`. Y
  `extractEmbedding` y `createEnrollmentToken` admiten solo el canal de API, así
  que una petición del canal web tendría que rechazarse en el servicio, con un
  código que el contrato no fija. Las dos cosas se deciden con F11 (#43) y en la
  sesión que conecte `fr` a la pasarela (#104); la dependencia se diseñó para
  admitir política por operación precisamente por esto.

  **Decidido en la sesión 13 para `extractEmbedding`:** el canal web recibe
  `401 API_CHANNEL_REQUIRED`, declarado en el contrato (un JWT no es una
  credencial admitida para una operación que declara solo `apiKeyAuth`).
  Quedan `createEnrollmentToken`, que seguirá el mismo criterio, y las 5 con
  token de enrolamiento.
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
- ~~**Alcance de la campaña de medición.**~~ **Decidido en la sesión 14:
  siete perfiles**, uno de detección, que no depende del modelo (`detectFaces`
  ya no admite `model`), tres de verificación (`verifyPair`) y tres de búsqueda
  1:N, uno por modelo. **Imagen fija de 480 × 640** y **configuración
  `w1t1c8`** (1 worker, 1 hilo de torch, 8 inferencias concurrentes) para
  todos. **Cuatro medidos en la sesión 14** (detección y las tres
  verificaciones); **los tres de 1:N, pendientes de F8**, con tamaño de galería
  fijo. La variación del tamaño de imagen y de galería queda como trabajo futuro
  declarado.

  **Sustituido en la sesión 17 para los perfiles 1:N:** tres, todos con `xs`,
  con galerías de 5.000, 20.000 y 50.000 rostros. Un solo modelo, porque a
  480 × 640 los tres cuestan lo mismo dentro del error del método y la
  comparación es idéntica; varios tamaños, porque es lo único que permite
  estimar `f(tamaño_galería)`. La variación del modelo en 1:N pasa a trabajo
  futuro; la del tamaño de galería deja de serlo. El razonamiento, en la
  entrada de la sesión 17.
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
