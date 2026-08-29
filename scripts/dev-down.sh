#!/bin/bash
# ===========================================================
# dev-down.sh — Para y limpia el entorno de desarrollo TFM
#
# Uso:
#   ./scripts/dev-down.sh              # para todos, conserva volúmenes
#   ./scripts/dev-down.sh -v           # para todos y elimina volúmenes
#   ./scripts/dev-down.sh auth         # para solo un servicio (auth | pricing | gateway)
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
