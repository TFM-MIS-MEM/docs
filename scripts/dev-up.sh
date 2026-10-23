#!/bin/bash
# ===========================================================
# dev-up.sh — Levanta el entorno de desarrollo TFM completo
#
# Uso:
#   ./scripts/dev-up.sh              # levanta todos los servicios
#   ./scripts/dev-up.sh auth         # levanta solo un servicio
#                                    # (space | auth | pricing | fr | gateway | frontend)
#
# Levanta la plataforma: SPACE, los tres microservicios, la pasarela y el panel. La
# Universidad ACME, que es un cliente de la plataforma y no parte de ella, la
# añade scripts/demo-up.sh.
#
# Códigos de salida:
#   0  todos los servicios solicitados están arriba y sanos
#   1  al menos uno falló — el resumen final dice cuál y por qué
# ===========================================================

set -uo pipefail

SERVICE=${1:-"all"}

# ---------------------
# Raíz del workspace
# ---------------------
# Se BUSCA, no se cuenta. La versión anterior la resolvía por profundidad fija
# (`dirname $0`/..), lo que ataba el script a vivir exactamente un nivel por
# debajo del workspace: al moverlo a este repositorio, ese `..` habría apuntado
# al repositorio en lugar de a la raíz, y las rutas de los tres composes se
# habrían roto en silencio.
#
# Primero se resuelven los enlaces simbólicos: `repos/scripts` es un enlace a
# este directorio, y sin resolverlo la búsqueda arrancaría desde el sitio
# equivocado según cómo se invocara el script.
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  LINK_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  case "$SOURCE" in
    /*) ;;
    *) SOURCE="$LINK_DIR/$SOURCE" ;;
  esac
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

# El marcador es el propio contenido del workspace: el directorio que contiene
# los tres repositorios de servicio. No hace falta un fichero centinela.
find_workspace_root() {
  local dir="$1"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/auth-microservice" ] && [ -d "$dir/pricing-microservice" ] \
       && [ -d "$dir/api-gateway" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

ROOT_DIR="${TFM_ROOT:-$(find_workspace_root "$SCRIPT_DIR")}"

if [ -z "$ROOT_DIR" ] || [ ! -d "$ROOT_DIR/api-gateway" ]; then
  echo "No encuentro la raíz del workspace desde $SCRIPT_DIR." >&2
  echo "Debe ser el directorio que contiene auth-microservice, pricing-microservice" >&2
  echo "y api-gateway. Si están en otro sitio, indícalo con TFM_ROOT:" >&2
  echo "  TFM_ROOT=/ruta/al/workspace $0 $*" >&2
  exit 1
fi

# La versión fijada de la tarifa en SPHERE (SPHERE_PRICING_*). Su única fuente es
# pricing-microservice/pricing/sphere.env; la leen el compose del panel (vista de
# planes) y space-bootstrap.sh. Se exporta aquí para que `docker compose` la
# interpole: el compose del panel la exige con `:?`, también al parar.
SPHERE_ENV="$ROOT_DIR/pricing-microservice/pricing/sphere.env"
if [ -f "$SPHERE_ENV" ]; then
  set -a
  . "$SPHERE_ENV"
  set +a
fi

# Tiempo máximo de espera, en segundos, a que un contenedor quede sano.
# Configurable para poder probar el camino de fallo sin esperar minuto y medio.
HEALTH_TIMEOUT=${HEALTH_TIMEOUT:-90}

# Colores
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Servicios que han fallado. Se acumulan en lugar de abortar al primero: si
# `auth` no arranca, saber si `pricing` y Kong lo hacen sigue siendo útil.
FAILED=""
STARTED=""
SKIPPED=""

function step() {
  echo -e "\n${CYAN}===> $1${NC}"
}

function ok() {
  echo -e "  ${GREEN}[OK] $1${NC}"
}

function warn() {
  echo -e "  ${YELLOW}[AVISO] $1${NC}"
}

function fail() {
  echo -e "  ${RED}[ERROR] $1${NC}"
}

# Registra un servicio como fallido y muestra las últimas trazas de sus
# contenedores, que es lo que hace falta para diagnosticar sin volver a lanzar
# nada a mano.
function record_failure() {
  local service="$1"
  local reason="$2"
  shift 2

  FAILED="$FAILED $service"
  fail "$service: $reason"

  local container
  for container in "$@"; do
    if docker ps -a --format '{{.Names}}' | grep -qx "$container"; then
      echo -e "  ${YELLOW}--- últimas trazas de $container ---${NC}"
      docker logs --tail 20 "$container" 2>&1 | sed 's/^/    /'
    fi
  done
}

# Espera a que un contenedor quede sano. Si no declara healthcheck, se conforma
# con que siga en ejecución: un contenedor que arranca y muere de inmediato es
# justo lo que este script dejaba pasar por bueno.
function wait_healthy() {
  local container="$1"
  local waited=0

  while [ "$waited" -lt "$HEALTH_TIMEOUT" ]; do
    local state
    state=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)

    if [ -z "$state" ]; then
      return 1  # el contenedor ni siquiera existe
    fi

    if [ "$state" = "exited" ] || [ "$state" = "dead" ]; then
      return 1
    fi

    local health
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
      "$container" 2>/dev/null)

    case "$health" in
      healthy) return 0 ;;
      none)    [ "$state" = "running" ] && return 0 ;;
      unhealthy) return 1 ;;
    esac

    sleep 3
    waited=$((waited + 3))
  done

  return 1  # agotado el tiempo de espera
}

# Levanta un compose y comprueba de verdad que lo que declara acabó sano.
#
# `docker compose up -d` devuelve 0 en cuanto los contenedores se han creado,
# de modo que su código de salida no basta: un servicio que arranca y muere
# en el primer segundo lo daba por bueno.
function compose_up() {
  local service="$1"
  local label="$2"
  local compose_file="$3"
  shift 3
  local containers=("$@")

  step "Levantando $label..."

  if [ ! -f "$compose_file" ]; then
    record_failure "$service" "no existe $compose_file"
    return 1
  fi

  if ! docker compose -f "$compose_file" up --build -d; then
    record_failure "$service" "la construcción o el arranque falló" "${containers[@]}"
    return 1
  fi

  local container
  for container in "${containers[@]}"; do
    if ! wait_healthy "$container"; then
      record_failure "$service" \
        "$container no llegó a estar sano en ${HEALTH_TIMEOUT}s" "${containers[@]}"
      return 1
    fi
    ok "$container sano"
  done

  STARTED="$STARTED $service"
  ok "$label arrancado"
  return 0
}

# ---------------------
# 0. Comprobaciones previas
# ---------------------
step "Comprobando requisitos..."

if ! command -v docker > /dev/null 2>&1; then
  fail "docker no está en el PATH."
  exit 1
fi

if ! docker info > /dev/null 2>&1; then
  fail "el demonio de Docker no responde. Arranca Docker Desktop y repite."
  exit 1
fi

if ! docker compose version > /dev/null 2>&1; then
  fail "'docker compose' no está disponible (¿versión antigua con docker-compose?)."
  exit 1
fi

case "$SERVICE" in
  all|space|auth|pricing|fr|gateway|frontend) ;;
  *)
    fail "servicio desconocido: '$SERVICE'. Use: all | space | auth | pricing | fr | gateway | frontend"
    exit 1
    ;;
esac

ok "Docker operativo · objetivo: $SERVICE"

# ---------------------
# 1. Bootstrap: Autoconfiguración M2M
# ---------------------
step "Verificando Bootstrap de Configuración Local y Secretos M2M..."

if [ ! -f "$ROOT_DIR/api-gateway/.env" ]; then
  ok "Primera inicialización detectada. Generando secretos y configurando entornos locales..."

  # Los secretos se generan con openssl. Antes había un plan B a base de
  # `sha256sum`/`md5sum`, que en macOS no existen: habría escrito un secreto
  # vacío sin decir nada. Es preferible parar.
  if ! command -v openssl > /dev/null 2>&1; then
    fail "openssl no está disponible y es imprescindible para generar los secretos."
    exit 1
  fi

  # 1. Aprovisionar .env de auth si no existe
  if [ ! -f "$ROOT_DIR/auth-microservice/.env" ]; then
    cp "$ROOT_DIR/auth-microservice/.env.example" "$ROOT_DIR/auth-microservice/.env"
  fi

  # 2. Generar secreto de alta seguridad interno (32 bytes = 64 chars)
  NEW_INTERNAL_SECRET=$(openssl rand -hex 32)

  # 3. Generar secreto altísima seguridad para JWTs (64 bytes = 128 chars)
  NEW_JWT_SECRET=$(openssl rand -hex 64)

  if [ -z "$NEW_INTERNAL_SECRET" ] || [ -z "$NEW_JWT_SECRET" ]; then
    fail "la generación de secretos devolvió un valor vacío. Abortando."
    exit 1
  fi

  # 4. Escribir configuración a api-gateway
  #
  # Los nombres los fija el vault de entorno de Kong: kong.yml referencia
  # {vault://env/space-auth-internal-secret}, y el vault traduce el recurso a
  # mayúsculas cambiando guiones por subrayados, SIN prefijo. No se usa KONG_
  # porque ese es el espacio de nombres de la configuración de Kong.
  #
  # Los DOS son imprescindibles: sin el de firma, la pasarela no puede validar
  # ningún JWT. Kong arranca igualmente y se declara sano —una referencia sin
  # resolver solo produce un `warn`—, de modo que el síntoma sería que todo
  # responde 401 sin explicación.
  {
    echo "SPACE_AUTH_INTERNAL_SECRET=$NEW_INTERNAL_SECRET"
    echo "SPACE_AUTH_JWT_SECRET=$NEW_JWT_SECRET"
  } > "$ROOT_DIR/api-gateway/.env"

  # 5. Sincronizar Auth-Microservice: Cambiar Internal y JWT Secret
  sed -i.bak "s/^INTERNAL_API_SECRET=.*/INTERNAL_API_SECRET=$NEW_INTERNAL_SECRET/" "$ROOT_DIR/auth-microservice/.env"
  sed -i.bak "s/^JWT_SECRET=.*/JWT_SECRET=$NEW_JWT_SECRET/" "$ROOT_DIR/auth-microservice/.env"

  # 6. Aprovisionar .env de pricing si no existe y sincronizar secretos compartidos
  if [ ! -f "$ROOT_DIR/pricing-microservice/.env" ]; then
    cp "$ROOT_DIR/pricing-microservice/.env.example" "$ROOT_DIR/pricing-microservice/.env"
  fi
  sed -i.bak "s/^INTERNAL_API_SECRET=.*/INTERNAL_API_SECRET=$NEW_INTERNAL_SECRET/" "$ROOT_DIR/pricing-microservice/.env"
  sed -i.bak "s/^JWT_SECRET=.*/JWT_SECRET=$NEW_JWT_SECRET/" "$ROOT_DIR/pricing-microservice/.env"
  rm -f "$ROOT_DIR/pricing-microservice/.env.bak"

  # 7. Sincronizar API Key de Resend (si el archivo existe en la raiz)
  if [ -f "$ROOT_DIR/resend-apikey.txt" ]; then
    RESEND_KEY=$(tr -d '\r\n' < "$ROOT_DIR/resend-apikey.txt")
    sed -i.bak "s|^RESEND_API_KEY=.*|RESEND_API_KEY=$RESEND_KEY|" "$ROOT_DIR/auth-microservice/.env"
  fi

  rm -f "$ROOT_DIR/auth-microservice/.env.bak"

  # 8. Sincronizar keys de Stripe (si los archivos existen en la raiz)
  if [ -f "$ROOT_DIR/stripe-secret-key.txt" ]; then
    STRIPE_SECRET=$(tr -d '\r\n' < "$ROOT_DIR/stripe-secret-key.txt")
    sed -i.bak "s|^STRIPE_SECRET_KEY=.*|STRIPE_SECRET_KEY=$STRIPE_SECRET|" "$ROOT_DIR/pricing-microservice/.env"
    rm -f "$ROOT_DIR/pricing-microservice/.env.bak"
  fi

  if [ -f "$ROOT_DIR/stripe-webhook-secret.txt" ]; then
    STRIPE_WEBHOOK=$(tr -d '\r\n' < "$ROOT_DIR/stripe-webhook-secret.txt")
    sed -i.bak "s|^STRIPE_WEBHOOK_SECRET=.*|STRIPE_WEBHOOK_SECRET=$STRIPE_WEBHOOK|" "$ROOT_DIR/pricing-microservice/.env"
    rm -f "$ROOT_DIR/pricing-microservice/.env.bak"
  fi

  ok "Secretos compartidos M2M autogenerados y sincronizados correctamente."
else
  ok "Entornos de desarrollo .env locales listos."
  # Asegurar que pricing tiene .env aunque no sea primera inicialización
  if [ ! -f "$ROOT_DIR/pricing-microservice/.env" ]; then
    cp "$ROOT_DIR/pricing-microservice/.env.example" "$ROOT_DIR/pricing-microservice/.env"
    ok "pricing-microservice/.env creado desde .env.example"
  fi

  # Los secretos de la pasarela tienen que existir y coincidir con los de auth.
  # Se comprueba aquí porque el fallo es silencioso: Kong arranca, el
  # healthcheck da verde y toda petición autenticada responde 401. El único
  # rastro es un `warn` de referencia no resuelta en su registro.
  read_env_value() { grep -E "^$1=" "$2" 2>/dev/null | head -1 | cut -d= -f2-; }

  GW_INTERNAL=$(read_env_value SPACE_AUTH_INTERNAL_SECRET "$ROOT_DIR/api-gateway/.env")
  GW_JWT=$(read_env_value SPACE_AUTH_JWT_SECRET "$ROOT_DIR/api-gateway/.env")
  AUTH_INTERNAL=$(read_env_value INTERNAL_API_SECRET "$ROOT_DIR/auth-microservice/.env")
  AUTH_JWT=$(read_env_value JWT_SECRET "$ROOT_DIR/auth-microservice/.env")

  if [ -z "$GW_INTERNAL" ] || [ -z "$GW_JWT" ]; then
    fail "api-gateway/.env no define SPACE_AUTH_INTERNAL_SECRET y SPACE_AUTH_JWT_SECRET."
    echo "  La pasarela arrancaría sana y respondería 401 a todo. Bórralo y"
    echo "  vuelve a ejecutar este script para regenerar los secretos:"
    echo "    rm $ROOT_DIR/api-gateway/.env && scripts/dev-up.sh"
    exit 1
  fi

  if [ "$GW_INTERNAL" != "$AUTH_INTERNAL" ] || [ "$GW_JWT" != "$AUTH_JWT" ]; then
    fail "los secretos de api-gateway/.env no coinciden con los de auth-microservice/.env."
    echo "  La pasarela rechazaría con 401 los JWT que emite auth. Bórralo y"
    echo "  vuelve a ejecutar este script para regenerarlos en los tres:"
    echo "    rm $ROOT_DIR/api-gateway/.env && scripts/dev-up.sh"
    exit 1
  fi

  ok "Secretos M2M presentes y coincidentes entre auth y la pasarela."
fi

# ---------------------
# 2. Red externa compartida
# ---------------------
step "Verificando red tfm-network..."
if docker network ls --filter name=tfm-network --format '{{.Name}}' | grep -q 'tfm-network'; then
  ok "tfm-network ya existe"
elif docker network create tfm-network > /dev/null; then
  ok "tfm-network creada"
else
  fail "no se pudo crear tfm-network. Ningún servicio podrá levantarse."
  exit 1
fi

# ---------------------
# 3. SPACE
# ---------------------
# Va antes que pricing y fr-commercial: los dos leen de su .env la clave que
# escribe space-bootstrap.sh, y fr-commercial no arranca sin ella.
#
# Sus secretos (firma de tokens, administrador, MongoDB) viven en
# pricing-microservice/space/.env y se generan aquí la primera vez. No tienen
# valor por omisión en el compose: si falta uno, no arranca.
if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "space" ]; then
  SPACE_ENV="$ROOT_DIR/pricing-microservice/space/.env"
  if [ ! -f "$SPACE_ENV" ]; then
    if ! command -v openssl > /dev/null 2>&1; then
      fail "openssl no está disponible y es imprescindible para generar los secretos de SPACE."
      exit 1
    fi
    (
      umask 077
      {
        echo "SPACE_JWT_SECRET=$(openssl rand -hex 32)"
        echo "SPACE_JWT_SALT=$(openssl rand -hex 16)"
        echo "SPACE_ADMIN_USER=admin"
        echo "SPACE_ADMIN_PASSWORD=$(openssl rand -hex 16)"
        echo "SPACE_MONGO_ROOT_USERNAME=space"
        echo "SPACE_MONGO_ROOT_PASSWORD=$(openssl rand -hex 16)"
      } > "$SPACE_ENV"
    )
    ok "Secretos de SPACE generados en pricing-microservice/space/.env"
  fi

  if compose_up "space" "SPACE (space-server + space-mongodb + space-redis)" \
    "$ROOT_DIR/pricing-microservice/space/docker-compose.yml" \
    "space-mongodb" "space-redis" "space-server"; then
    step "Configurando SPACE (claves y tarifa fijada)..."
    if ! "$SCRIPT_DIR/space-bootstrap.sh"; then
      STARTED="${STARTED/ space/}"
      record_failure "space" "space-bootstrap.sh falló" "space-server"
    fi
  fi
else
  SKIPPED="$SKIPPED space"
fi

# ---------------------
# 4. Auth Microservice
# ---------------------
if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "auth" ]; then
  compose_up "auth" "Auth Microservice (auth-service + auth-mongodb)" \
    "$ROOT_DIR/auth-microservice/docker-compose.dev.yml" \
    "auth-mongodb" "auth-service"
else
  SKIPPED="$SKIPPED auth"
fi

# ---------------------
# 5. Pricing Microservice
# ---------------------
if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "pricing" ]; then
  compose_up "pricing" "Pricing Microservice (pricing-service + pricing-mongodb)" \
    "$ROOT_DIR/pricing-microservice/docker-compose.dev.yml" \
    "pricing-mongodb" "pricing-service"
else
  SKIPPED="$SKIPPED pricing"
fi

# ---------------------
# 6. FR Commercial
# ---------------------
# Sin .env: el compose de desarrollo fija MONGODB_URI y EMBEDDING_TOKEN_SECRET
# en la capa de orquestación, así que no hay secreto que generar. Si MongoDB
# pasa a exigir autenticación (docs#106), este paso tendrá que generar la
# credencial como hace el bootstrap con los de auth.
#
# Va antes que la pasarela: la ruta /v1/fr/commercial de kong.yml apunta a
# fr-commercial-service, y Kong no necesita que exista para arrancar, pero la
# primera petición sí.
if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "fr" ]; then
  compose_up "fr" "FR Commercial (fr-commercial-service + fr-commercial-mongodb)" \
    "$ROOT_DIR/fr-commercial-microservice/docker-compose.dev.yml" \
    "fr-commercial-mongodb" "fr-commercial-service"
else
  SKIPPED="$SKIPPED fr"
fi

# ---------------------
# 7. API Gateway (Kong)
# ---------------------
if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "gateway" ]; then
  compose_up "gateway" "API Gateway (Kong)" \
    "$ROOT_DIR/api-gateway/docker-compose.dev.yml" \
    "kong-gateway"
else
  SKIPPED="$SKIPPED gateway"
fi

# ---------------------
# 8. Panel del cliente (frontend)
# ---------------------
# Ficheros estáticos: el navegador habla con la pasarela en :8000, no con este
# contenedor, que por eso no entra en tfm-network.
if [ "$SERVICE" = "all" ] || [ "$SERVICE" = "frontend" ]; then
  compose_up "frontend" "Panel del cliente (frontend-panel)" \
    "$ROOT_DIR/frontend/docker-compose.dev.yml" \
    "frontend-panel"
else
  SKIPPED="$SKIPPED frontend"
fi

# ---------------------
# Resumen
# ---------------------
echo ""
echo -e "${CYAN}===============================================${NC}"

if [ -n "$FAILED" ]; then
  echo -e "${RED} Entorno TFM levantado CON FALLOS${NC}"
  echo -e "${CYAN}===============================================${NC}"
  echo ""
  echo -e "${RED} Han fallado:${NC}$FAILED"
  [ -n "$STARTED" ] && echo -e "${GREEN} Han arrancado:${NC}$STARTED"
  [ -n "$SKIPPED" ] && echo -e "${YELLOW} No solicitados:${NC}$SKIPPED"
  echo ""
  echo " Para ver el detalle completo de un servicio:"
  echo "   docker compose -f <ruta>/docker-compose.dev.yml logs -f"
  echo ""
  exit 1
fi

echo -e "${GREEN} Entorno TFM levantado correctamente!${NC}"
echo -e "${CYAN}===============================================${NC}"
echo ""
echo -e " Servicios sanos:${GREEN}$STARTED${NC}"
[ -n "$SKIPPED" ] && echo -e " No solicitados:${YELLOW}$SKIPPED${NC}"
echo ""
echo " Endpoints disponibles:"
echo "   Panel del cliente -> http://localhost:5173"
echo "   Kong Proxy        -> http://localhost:8000"
echo "   Kong Admin API    -> http://localhost:8001"
echo "   Auth (directo)    -> http://localhost:3000"
echo "   Pricing (directo) -> http://localhost:3001"
echo "   SPACE             -> sin puertos: solo http://space-server:3000 dentro de tfm-network"
echo "   FR (directo)      -> http://localhost:3002   (solo 127.0.0.1)"
echo "   Auth MongoDB      -> mongodb://localhost:27017"
echo "   Pricing MongoDB   -> mongodb://localhost:27018"
echo "   FR MongoDB        -> mongodb://localhost:27019 (solo 127.0.0.1)"
echo ""
echo " Prueba rápida (directa a auth, sin pasar por Kong):"
echo "   curl -X POST http://localhost:3000/v1/auth/register \\"
echo "        -H 'Content-Type: application/json' \\"
echo "        -d '{\"email\":\"test@example.com\",\"password\":\"Test1234!\"}'"
echo ""
echo " A través de la pasarela, con las dos credenciales:"
echo "   curl -X POST http://localhost:8000/v1/auth/login \\"
echo "        -H 'Content-Type: application/json' \\"
echo "        -d '{\"email\":\"test@example.com\",\"password\":\"Test1234!\"}'"
echo ""
echo "   curl -X POST http://localhost:8000/v1/pricing/checkout/create-session \\"
echo "        -H 'Authorization: Bearer <jwt>'      # canal web"
echo "   curl -X POST http://localhost:8000/v1/pricing/checkout/create-session \\"
echo "        -H 'X-API-Key: <clave>'               # canal API"
echo ""
