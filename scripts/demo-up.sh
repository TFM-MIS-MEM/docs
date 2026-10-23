#!/bin/bash
# ===========================================================
# demo-up.sh — Levanta la demo entera: la plataforma y la Universidad ACME
#
# Uso:
#   ./scripts/demo-up.sh
#
# 1. scripts/dev-up.sh all: auth, pricing, fr, la pasarela y el panel.
# 2. Comprueba la configuración de acme-demo/.env con un getGallery por la
#    pasarela, con la API KEY y la galería de ACME. NO siembra nada: si falta o
#    no vale, sale con 1 y dice qué hacer.
# 3. Levanta la Universidad ACME y espera a que quede sana.
#
# Códigos de salida:
#   0  la plataforma y ACME están arriba, y la configuración de ACME vale
#   1  algo falló — el mensaje dice qué y qué hacer
# ===========================================================

set -uo pipefail

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
if [ -z "$ROOT_DIR" ]; then
  echo "No encuentro la raíz del workspace desde $SCRIPT_DIR. Indícala con TFM_ROOT." >&2
  exit 1
fi

ACME_DIR="$ROOT_DIR/acme-demo"
ACME_ENV="$ACME_DIR/.env"
# La pasarela vista desde ESTA máquina. La de .env (host.docker.internal) es la
# que ve el contenedor de ACME.
GATEWAY="${GATEWAY:-http://localhost:8000}"
HEALTH_TIMEOUT=${HEALTH_TIMEOUT:-90}

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
step() { echo -e "\n${CYAN}===> $1${NC}"; }
ok() { echo -e "  ${GREEN}[OK] $1${NC}"; }
fail() { echo -e "  ${RED}[ERROR] $1${NC}"; }

how_to_configure() {
  echo ""
  echo "  Cómo configurarla, como lo haría el cliente:"
  echo "    1. Abre el panel, http://localhost:5173, y regístrate. Copia la API KEY:"
  echo "       se muestra una sola vez (o rótala en Credenciales)."
  echo "    2. En Galerías, crea «ACME · Matrícula» y copia su id."
  echo "    3. cp $ACME_DIR/.env.example $ACME_ENV"
  echo "       y rellena ACME_API_KEY y ACME_GALLERY_ID."
  echo "    4. Vuelve a ejecutar $0"
  echo ""
  echo "  Si hay prisa: $SCRIPT_DIR/demo-seed.sh lo hace por ti y deja ACME sembrada."
}

# ---------------------
# 1. Plataforma
# ---------------------
"$SCRIPT_DIR/dev-up.sh" all
status=$?
if [ "$status" -ne 0 ]; then
  fail "dev-up.sh salió con $status: la plataforma no está entera. No se levanta ACME."
  exit 1
fi

# ---------------------
# 2. Configuración de ACME
# ---------------------
step "Comprobando la configuración de la Universidad ACME ($ACME_ENV)..."

if [ ! -d "$ACME_DIR" ]; then
  fail "no existe $ACME_DIR (repositorio TFM-MIS-MEM/acme-demo)."
  exit 1
fi

if [ ! -f "$ACME_ENV" ]; then
  fail "no existe $ACME_ENV."
  how_to_configure
  exit 1
fi

read_env_value() { grep -E "^$1=" "$ACME_ENV" | head -1 | cut -d= -f2- | tr -d '\r'; }
API_KEY=$(read_env_value ACME_API_KEY)
GALLERY_ID=$(read_env_value ACME_GALLERY_ID)

if [ -z "$API_KEY" ] || [ -z "$GALLERY_ID" ]; then
  fail "$ACME_ENV no define ACME_API_KEY y ACME_GALLERY_ID."
  how_to_configure
  exit 1
fi

# El plan de la cuenta de ACME. Entra por el canal de API, que FREE no incluye,
# y una cuenta recién registrada es FREE: sin esto, getGallery daría
# 403 FEATURE_NOT_IN_PLAN. En el SaaS el plan lo pone pricing cuando Stripe
# confirma el pago; la demo no pasa por el pago. Si falla, getGallery dice por qué.
step "Plan de la cuenta de ACME (BUSINESS, en SPACE)..."
if ! "$SCRIPT_DIR/demo-plan.sh" "$API_KEY" BUSINESS; then
  echo "  No se pudo fijar el plan; la comprobación siguiente dirá por qué."
fi

# getGallery por el canal de API, el mismo que usará ACME. La clave no se
# imprime en ningún caso.
OUT=$(mktemp)
code=$(curl -s -o "$OUT" -w '%{http_code}' \
  -H "X-API-Key: $API_KEY" "$GATEWAY/v1/fr/commercial/galleries/$GALLERY_ID")
body=$(head -c 300 "$OUT")
rm -f "$OUT"

case "$code" in
  200)
    ok "getGallery $GALLERY_ID con la API KEY de ACME: 200"
    ;;
  401)
    fail "la pasarela rechaza la API KEY de ACME (401): $body"
    echo "  La clave no existe o se ha rotado. Rótala en el panel y actualiza ACME_API_KEY."
    how_to_configure
    exit 1
    ;;
  403)
    fail "getGallery con la API KEY de ACME respondió 403: $body"
    echo "  Con FEATURE_NOT_IN_PLAN, la cuenta no está en un plan con canal de API:"
    echo "    $SCRIPT_DIR/demo-plan.sh <API_KEY> BUSINESS"
    exit 1
    ;;
  404)
    fail "la galería $GALLERY_ID no existe para la cuenta de esa API KEY (404)."
    echo "  ¿Es de otra cuenta, o se borró? Copia el id desde el panel, con la misma cuenta."
    how_to_configure
    exit 1
    ;;
  *)
    fail "getGallery respondió $code: $body"
    exit 1
    ;;
esac

# ---------------------
# 3. Universidad ACME
# ---------------------
step "Levantando la Universidad ACME (acme-demo)..."
if ! docker compose -f "$ACME_DIR/docker-compose.yml" up --build -d; then
  fail "la construcción o el arranque de ACME falló."
  exit 1
fi

waited=0
while [ "$waited" -lt "$HEALTH_TIMEOUT" ]; do
  health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' acme-demo 2>/dev/null)
  [ "$health" = "healthy" ] && break
  [ "$health" = "unhealthy" ] && break
  sleep 3
  waited=$((waited + 3))
done

if [ "$health" != "healthy" ]; then
  fail "acme-demo no llegó a estar sano en ${HEALTH_TIMEOUT}s (estado: ${health:-ausente})."
  docker logs --tail 20 acme-demo 2>&1 | sed 's/^/    /'
  exit 1
fi
ok "acme-demo sano"

echo ""
echo -e "${CYAN}===============================================${NC}"
echo -e "${GREEN} Demo levantada${NC}"
echo -e "${CYAN}===============================================${NC}"
echo ""
echo "   Panel del cliente (canal web)  -> http://localhost:5173"
echo "   Universidad ACME (canal de API) -> http://localhost:4000"
echo "   Pasarela                        -> $GATEWAY"
echo ""
exit 0
