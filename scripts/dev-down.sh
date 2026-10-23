#!/bin/bash
# ===========================================================
# dev-down.sh — Para y limpia el entorno de desarrollo TFM
#
# Uso:
#   ./scripts/dev-down.sh              # para todos, conserva volúmenes
#   ./scripts/dev-down.sh -v           # para todos y elimina volúmenes
#   ./scripts/dev-down.sh auth         # para solo un servicio
#                                      # (space | auth | pricing | fr | gateway | frontend | acme)
#
# `all` para también la Universidad ACME, que levanta scripts/demo-up.sh.
# ===========================================================

VOLUMES=false
SERVICE="all"

# Comprobar banderas
for arg in "$@"; do
  if [ "$arg" == "-v" ]; then
    VOLUMES=true
  else
    SERVICE="$arg"
  fi
done

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

# Colores helpers
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function step() { echo -e "\n${CYAN}===> $1${NC}"; }
function ok() { echo -e "  ${GREEN}[OK] $1${NC}"; }

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

DOWN_ARGS="down"
if [ "$VOLUMES" = true ]; then
  DOWN_ARGS="down -v"
fi

# ---------------------
# API Gateway (primero)
# ---------------------
if [ "$SERVICE" == "all" ] || [ "$SERVICE" == "gateway" ]; then
  step "Parando API Gateway (Kong)..."
  docker compose -f "$ROOT_DIR/api-gateway/docker-compose.dev.yml" $DOWN_ARGS
  ok "API Gateway parado"
fi

# ---------------------
# Universidad ACME y panel: los clientes, antes que la plataforma
# ---------------------
# El compose de ACME exige su .env (env_file required). Si no existe, ACME no
# pudo arrancar con este compose y no hay nada que parar.
if [ "$SERVICE" == "all" ] || [ "$SERVICE" == "acme" ]; then
  step "Parando la Universidad ACME..."
  if [ -f "$ROOT_DIR/acme-demo/.env" ]; then
    docker compose -f "$ROOT_DIR/acme-demo/docker-compose.yml" $DOWN_ARGS
  fi
  ok "Universidad ACME parada"
fi

if [ "$SERVICE" == "all" ] || [ "$SERVICE" == "frontend" ]; then
  step "Parando el panel del cliente..."
  if [ -f "$ROOT_DIR/frontend/docker-compose.dev.yml" ]; then
    docker compose -f "$ROOT_DIR/frontend/docker-compose.dev.yml" $DOWN_ARGS
  fi
  ok "Panel parado"
fi

# ---------------------
# FR Commercial
# ---------------------
if [ "$SERVICE" == "all" ] || [ "$SERVICE" == "fr" ]; then
  step "Parando FR Commercial..."
  docker compose -f "$ROOT_DIR/fr-commercial-microservice/docker-compose.dev.yml" $DOWN_ARGS
  ok "FR Commercial parado"
fi

# ---------------------
# Auth Microservice
# ---------------------
if [ "$SERVICE" == "all" ] || [ "$SERVICE" == "auth" ]; then
  step "Parando Auth Microservice..."
  docker compose -f "$ROOT_DIR/auth-microservice/docker-compose.dev.yml" $DOWN_ARGS
  ok "Auth Microservice parado"
fi

# ---------------------
# Pricing Microservice
# ---------------------
if [ "$SERVICE" == "all" ] || [ "$SERVICE" == "pricing" ]; then
  step "Parando Pricing Microservice..."
  docker compose -f "$ROOT_DIR/pricing-microservice/docker-compose.dev.yml" $DOWN_ARGS
  ok "Pricing Microservice parado"
fi

# ---------------------
# SPACE
# ---------------------
# Su compose exige space/.env (los secretos no tienen valor por omisión), y
# `docker compose` lo comprueba también al parar. Sin ese fichero, SPACE no pudo
# arrancar con este compose y no hay nada que parar. Con -v se borran también
# sus contratos y claves: el siguiente dev-up.sh emite claves nuevas y las
# reescribe en los .env de fr-commercial y pricing.
if [ "$SERVICE" == "all" ] || [ "$SERVICE" == "space" ]; then
  if [ -f "$ROOT_DIR/pricing-microservice/space/.env" ]; then
    step "Parando SPACE..."
    docker compose -f "$ROOT_DIR/pricing-microservice/space/docker-compose.yml" $DOWN_ARGS
    ok "SPACE parado"
  fi
fi

# ---------------------
# Red externa (solo si paramos todo)
# ---------------------
if [ "$SERVICE" == "all" ]; then
  step "Eliminando red tfm-network..."
  docker network rm tfm-network 2>/dev/null
  ok "Red tfm-network eliminada"
fi

echo ""
echo -e "${CYAN}===============================================${NC}"
if [ "$VOLUMES" = true ]; then
  echo -e "${YELLOW} Entorno TFM parado y volúmenes eliminados.${NC}"
else
  echo -e "${GREEN} Entorno TFM parado (volúmenes conservados).${NC}"
fi
echo -e "${CYAN}===============================================${NC}"
echo ""
