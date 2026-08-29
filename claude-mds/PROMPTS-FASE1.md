# Prompts para las sesiones de la Fase 1

Un prompt por sesión. Abre Claude Code **en la raíz del workspace**
(`~/master/tfm/repos`), no dentro de un microservicio: varias sesiones tocan
más de un repositorio y necesita ver las especificaciones.

Antes de cada sesión, crea la rama:

```bash
git -C <repo> checkout -b fase1/<issue>
```

---

## Sesión 1 — C1: tests de contrato en `auth`

> **Se espera que los tests fallen.** No es un error: definen el objetivo de
> las sesiones siguientes.

```
Trabaja SOLO en auth-microservice. Issue TFM-MIS-MEM/docs#<N> (C1).

OBJETIVO
Sustituir la suite de tests actual por tests de contrato generados desde
auth-microservice/openapi/auth.yaml, usando jest-openapi.

CONTEXTO IMPORTANTE
Los tests actuales fijan un contrato OBSOLETO (rutas /api/v1/, rol
'researcher', envoltorio {status, data}). No los corrijas ni los adaptes:
son la razón por la que no hay red de seguridad.

TAREAS
1. npm install --save-dev jest-openapi
2. Configurar jest-openapi en tests/setup.js apuntando a
   openapi/auth.yaml, y registrarlo en jest.config.js
3. Mover los tests actuales a tests/legacy/ y excluirlos de la ejecución
   en jest.config.js. NO LOS BORRES: documentan el comportamiento previo y
   son material para la memoria del TFM.
4. Escribir un test por cada operación de auth.yaml, incluidos los caminos
   de error declarados (400, 401, 403, 409, 429). Cada uno debe terminar
   con expect(res).toSatisfyApiSpec().
5. Cobertura obligatoria de POST /v1/auth/validate-key: hoy no tiene
   ningún test y es el endpoint bloqueante del proyecto.
6. Añadir coverageThreshold a jest.config.js con los valores actuales,
   para que la cobertura no pueda bajar.

RESULTADO ESPERADO
La mayoría de los tests FALLARÁN. Es correcto y deliberado: el código
implementa el contrato antiguo. NO modifiques el código de src/ para que
pasen. NO modifiques auth.yaml para que coincida con el código.

Al terminar, muéstrame el resumen de qué tests pasan y cuáles no, agrupado
por causa (ruta distinta, esquema distinto, endpoint inexistente).

RESTRICCIONES
- No toques pricing-microservice ni api-gateway.
- No toques src/ salvo para importar la app en los tests.
- El contrato NO se repite en el test: para eso está toSatisfyApiSpec().
```

---

## Sesión 2 — A2, A3, B1, B2 y A1 (parte de `auth`)

```
Trabaja SOLO en auth-microservice.
Issues TFM-MIS-MEM/docs#<A2> #<A3> #<B1> #<B2> y la parte de auth de #<A1>.

OBJETIVO
Poner en verde la suite de contrato escrita en la sesión anterior.

Antes de escribir código, dame un plan de los cambios por fichero y
espera mi visto bueno.

TAREAS

A1 (solo auth): montar las rutas en /v1/auth en lugar de /api/v1/auth.
  Renombrar rotate-api-key → rotate-key e internal/validate-api-key →
  validate-key. Mantener GET /health fuera del versionado.

A2: renombrar la entidad AuthUser → Account y la colección a 'accounts'.
  Exponer accountId donde hoy se expone id. Roles: solo CUSTOMER y ADMIN.
  Estado: solo active y suspended. Eliminar toda referencia a 'researcher',
  'user' e 'inactive'.
  La relación cuenta-usuario es 1:1 en esta versión, pero se modela contra
  accountId para permitir cuentas multiusuario sin migración futura. Esta
  decisión está justificada en la memoria: no la revierta por simplicidad.

A3: validate-key debe recibir la clave en la cabecera X-API-Key (no en el
  cuerpo: con morgan('dev') acabaría en trazas) y devolver
  {valid, accountId, status, role}. No devolver email: es un canal
  máquina a máquina. Eliminar el 403: una cuenta suspendida se comunica con
  200 y status:"suspended", y es la pasarela quien decide.

B1: eliminar 'role' de registerSchema. El servicio asigna siempre CUSTOMER.

B2: forgot-password devuelve 202 con el mismo cuerpo exista o no la cuenta,
  para no permitir enumerar usuarios registrados. No cortocircuitar antes
  de la comprobación, o el tiempo de respuesta delataría el caso.

CRITERIO DE TERMINADO
npm test pasa al 100%. Si algún test sigue fallando, el problema está en el
código, NO en el test ni en auth.yaml.

RESTRICCIONES
- No toques pricing-microservice ni api-gateway.
- No modifiques openapi/auth.yaml. Si crees que el contrato está mal,
  párate y pregúntame.
- No toques tests/legacy/.
```

---

## Sesión 3 — A1 (`pricing` y Kong) y A4 (plugin)

> La sesión más delicada: toca dos repositorios y, mal hecha, deja el
> sistema sin arrancar.

```
Trabaja en pricing-microservice y api-gateway.
Issues TFM-MIS-MEM/docs#<A1> (parte pendiente) y #<A4>.

Antes de escribir código, dame un plan y espera mi visto bueno.

PARTE 1 — A1 en pricing y Kong
- pricing-microservice: montar rutas en /v1/pricing (incluido el webhook
  de Stripe en app.js).
- api-gateway/kong.yml: actualizar los paths de auth-route y pricing-route.
- plugins/space-auth/schema.lua: actualizar el auth_endpoint por defecto.

Los tres cambios van juntos: corregir un servicio sin corregir Kong lo
deja inalcanzable.

PARTE 2 — A4, plugin de Kong

El plugin space-auth NO funciona hoy: exige auth_body.pricing_token, campo
que auth nunca ha devuelto, y sale con 500. Solo pasa desapercibido porque
no está aplicado a ninguna ruta activa. La pasarela no autentica nada.

1. Aceptar DOS credenciales, no una:
   - Authorization: Bearer <jwt> → validar POR FIRMA, sin llamar a auth.
     Extraer accountId y role del propio token. Canal "frontend".
   - X-API-Key → llamar a POST /v1/auth/validate-key. Canal "api".
   - Ninguna → 401.
   Hoy exige X-API-Key y responde 401 si falta, lo que excluye
   estructuralmente al canal web.

2. Propagar EXACTAMENTE estas cabeceras (hoy inyecta X-User-Id,
   X-Space-Limits y X-Space-Features, que no son las del contrato):
     X-Account-Id
     X-Auth-Channel   "frontend" | "api"
     X-Role           "CUSTOMER" | "ADMIN"

3. SANEADO — es el punto crítico de seguridad:
   llamar a kong.service.request.clear_header() sobre las tres cabeceras
   de forma INCONDICIONAL antes de escribir los valores propios.
   Hoy X-Space-Limits solo se escribe si payload.limits existe, de modo que
   cuando no existe la cabecera enviada por el cliente pasa intacta al
   backend. Ese patrón no debe repetirse.

4. Cachear el resultado de validate-key unos 60 segundos.
   Hoy hay una llamada HTTP a auth en CADA petición.

5. Cuenta suspendida → 403. Credencial inválida → 401. Son casos distintos
   y hoy se colapsan ambos en 401.

6. Aplicar el plugin a las rutas ACTIVAS, no en bloques comentados.

CRITERIO DE TERMINADO
Con los tres servicios levantados:
- POST /v1/auth/login a través de Kong responde 200
- Una petición con JWT válido llega al backend sin que se invoque a auth
- Una petición con API KEY válida llega al backend

RESTRICCIONES
- No toques auth-microservice: ya está cerrado.
- No modifiques las especificaciones OpenAPI.
```

---

## Sesión 4 — A5: test de saneado de cabeceras

```
Trabaja en api-gateway. Issue TFM-MIS-MEM/docs#<A5>.

OBJETIVO
Test de integración que verifique que la pasarela no deja pasar cabeceras
de identidad inyectadas por el cliente.

POR QUÉ IMPORTA
Es un control de seguridad cuyo fallo es SILENCIOSO: si deja de funcionar,
todo sigue pareciendo correcto hasta que alguien suplanta una cuenta.
Es el único test de la Fase 1 que se escribe a mano; el resto se generan
desde el contrato.

MONTAJE
Un servicio de eco detrás de Kong que devuelva en el cuerpo las cabeceras
que recibe. Unas líneas con http.createServer en un contenedor de pruebas
bastan; no hace falta un framework.

CASOS
1. Autenticación correcta → el backend recibe X-Account-Id con la cuenta
   real.
2. Autenticación correcta MÁS X-Account-Id: <cuenta ajena> → el backend
   recibe la cuenta REAL, no la enviada por el cliente.
3. Ídem inyectando X-Role: ADMIN → el backend recibe el rol real.
4. Ídem inyectando X-Auth-Channel: api sobre una sesión JWT → el backend
   recibe "frontend".
5. Sin credencial → 401 y el backend no recibe nada.

Los casos 2, 3 y 4 son los que importan. Si alguno pasa la cabecera del
cliente, el saneado de A4 está mal y hay que volver a él.
```

---

## Sesión 5 — C2: documentación desde el `.yaml`

```
Trabaja en auth-microservice y pricing-microservice.
Issue TFM-MIS-MEM/docs#<C2>.

OBJETIVO
Eliminar la tercera fuente de verdad. Hoy ambos servicios publican Swagger
UI desde anotaciones @swagger en el código que describen un contrato
DISTINTO del de los .yaml.

TAREAS
1. Sustituir swagger-jsdoc por la carga directa del fichero con js-yaml.
2. Servirlo en GET /docs y GET /openapi.json.
3. Eliminar TODAS las anotaciones @swagger y @openapi del código.
4. Quitar swagger-jsdoc de package.json.

CRITERIO DE TERMINADO
grep -rn "@swagger\|@openapi" src/ no devuelve resultados.
GET /docs muestra exactamente el contenido del .yaml.

NOTA
El .yaml ya vive dentro de cada repositorio, en openapi/. No introduzcas
rutas relativas que salgan del repositorio: se romperían en Docker y en CI.
```

---

## Convenciones para todas las sesiones

**Commits.** Referencia cruzada entre repositorios para que GitHub cierre
solo:

```
git commit -m "feat(auth): validate-key devuelve accountId y status

Closes TFM-MIS-MEM/docs#12"
```

**Si el agente propone cambiar una especificación**, párate. Puede tener
razón, pero el cambio empieza por el `.yaml`, sigue por la DoD y termina en
la memoria — nunca al revés.

**Si el agente se sale del alcance**, córtale. La regla 1 de `CLAUDE.md`
existe porque el desbordamiento de alcance fue lo que produjo el desajuste
anterior entre GitHub y la documentación.

**Al terminar cada sesión**, comprueba que el issue quedó cerrado y que la
rama se fusionó. Los issues cerrados a mano y olvidados fueron buena parte
del caos previo.
