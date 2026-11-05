#!/bin/bash
# ===========================================================
# demo-seed.sh — Datos de respaldo de la demo. Solo por si falla el camino
# manual del panel; demo-up.sh NO lo llama.
#
# Uso (con la plataforma ya levantada, por ejemplo tras un demo-up.sh que
# terminó pidiendo la configuración de ACME):
#   ./scripts/demo-seed.sh
#
# Hace, por la pasarela, lo que el cliente haría en el panel, y después usa la
# Universidad ACME como la usaría la secretaría:
#   1. Cuenta de demo: la registra; si ya existe, entra y ROTA su API KEY,
#      porque auth solo guarda el hash y no puede devolver la anterior.
#   2. Galería «ACME · Matrícula», creada con el JWT (canal web) si no existe.
#   3. Escribe acme-demo/.env con la API KEY y el id de la galería.
#   3b. Pone la cuenta en BUSINESS en SPACE (demo-plan.sh): ACME entra por el
#      canal de API, que FREE no incluye.
#   4. Levanta ACME y registra, a través de su backend (que asigna el usuario
#      virtual y guarda la correspondencia), a Christina Hammock Koch con
#      seed/koch_2023_480x640.jpg.
#
# Idempotente: si acme-demo/.env ya vale (getGallery da 200), no toca la cuenta,
# ni la galería ni el fichero; y si ACME ya tiene a la estudiante, no la vuelve
# a registrar (otro registro le daría un usuario numerado, chrhamkoc1).
#
# Las fotos son retratos oficiales de la NASA, de dominio público
# (acme-demo/seed/SOURCES.md). El registro es ficticio, sin relación con la
# persona ni con la NASA.
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
GATEWAY="${GATEWAY:-http://localhost:8000}"
ACME="${ACME:-http://localhost:4000}"
HEALTH_TIMEOUT=${HEALTH_TIMEOUT:-90}

# Cuenta de demostración, solo local. La contraseña se publica aquí a propósito:
# es la que se usa para entrar en el panel y ver la misma galería.
DEMO_EMAIL="${DEMO_EMAIL:-demo-acme@example.com}"
DEMO_PASSWORD="${DEMO_PASSWORD:-AcmeDemo-2026!}"
GALLERY_NAME="ACME · Matrícula"

# Estudiante de respaldo: nombre y dos apellidos, como pide el registro de ACME.
STUDENT_FIRST_NAME="Christina"
STUDENT_LAST_NAME_1="Hammock"
STUDENT_LAST_NAME_2="Koch"
STUDENT_NAME="$STUDENT_FIRST_NAME $STUDENT_LAST_NAME_1 $STUDENT_LAST_NAME_2"
ENROL_PHOTO="$ACME_DIR/seed/koch_2023_480x640.jpg"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
step() { echo -e "\n${CYAN}===> $1${NC}"; }
ok() { echo -e "  ${GREEN}[OK] $1${NC}"; }
die() { echo -e "  ${RED}[ERROR] $1${NC}"; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# post_json <ruta> <json> [cabeceras curl...] → código; cuerpo en $TMP/out.json
post_json() {
  local path="$1" json="$2"
  shift 2
  curl -s -o "$TMP/out.json" -w '%{http_code}' -X POST "$GATEWAY$path" \
    -H 'Content-Type: application/json' "$@" -d "$json"
}
field() { python3 -c "import json,sys; print(json.load(open('$TMP/out.json')).get('$1',''))" 2>/dev/null; }
read_env_value() { grep -E "^$1=" "$ACME_ENV" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r'; }

gallery_ok() { # gallery_ok <api-key> <gallery-id>
  [ "$(curl -s -o /dev/null -w '%{http_code}' -H "X-API-Key: $1" \
    "$GATEWAY/v1/fr/commercial/galleries/$2")" = "200" ]
}

[ -f "$ENROL_PHOTO" ] || die "no existe $ENROL_PHOTO (repositorio acme-demo)."

step "Comprobando la pasarela ($GATEWAY)..."
code=$(curl -s -o /dev/null -w '%{http_code}' "$GATEWAY/v1/fr/commercial/galleries")
[ "$code" = "401" ] || die "la pasarela no responde como se espera (GET sin credencial: $code, no 401). Levanta la plataforma: $SCRIPT_DIR/dev-up.sh"
ok "pasarela arriba y la ruta de fr protegida"

# ---------------------
# 1–3. Cuenta, galería y .env
# ---------------------
step "Configuración de ACME..."
API_KEY=$(read_env_value ACME_API_KEY)
GALLERY_ID=$(read_env_value ACME_GALLERY_ID)

# ACME entra por el canal de API, que FREE no incluye: la cuenta va a BUSINESS
# (demo-plan.sh). Antes de comprobar la galería, que por el canal de API daría
# 403 con la cuenta en FREE. Si la clave ya no vale, falla y se sigue: el
# camino de abajo registra o rota.
if [ -n "$API_KEY" ]; then
  "$SCRIPT_DIR/demo-plan.sh" "$API_KEY" BUSINESS || true
fi

if [ -n "$API_KEY" ] && [ -n "$GALLERY_ID" ] && gallery_ok "$API_KEY" "$GALLERY_ID"; then
  ok "$ACME_ENV ya vale (getGallery 200): no se toca"
else
  code=$(post_json /v1/auth/register "{\"email\":\"$DEMO_EMAIL\",\"password\":\"$DEMO_PASSWORD\"}")
  case "$code" in
    201)
      API_KEY=$(field apiKey)
      ok "cuenta $DEMO_EMAIL registrada"
      ;;
    409)
      API_KEY=""
      ok "la cuenta $DEMO_EMAIL ya existía"
      ;;
    *) die "register respondió $code: $(head -c 300 "$TMP/out.json")" ;;
  esac

  code=$(post_json /v1/auth/login "{\"email\":\"$DEMO_EMAIL\",\"password\":\"$DEMO_PASSWORD\"}")
  [ "$code" = "200" ] || die "login respondió $code: $(head -c 300 "$TMP/out.json")"
  TOKEN=$(field token)

  if [ -z "$API_KEY" ]; then
    code=$(post_json /v1/auth/rotate-key "{\"password\":\"$DEMO_PASSWORD\"}" -H "Authorization: Bearer $TOKEN")
    [ "$code" = "201" ] || die "rotate-key respondió $code: $(head -c 300 "$TMP/out.json")"
    API_KEY=$(field apiKey)
    ok "API KEY rotada (la anterior deja de valer)"
  fi

  "$SCRIPT_DIR/demo-plan.sh" "$API_KEY" BUSINESS || die "no se pudo poner la cuenta de demo en BUSINESS."

  # La galería, por el canal web: el mismo camino que el panel.
  curl -s -o "$TMP/list.json" -H "Authorization: Bearer $TOKEN" \
    "$GATEWAY/v1/fr/commercial/galleries?page=1&pageSize=100"
  GALLERY_ID=$(GALLERY_NAME="$GALLERY_NAME" python3 -c "
import json, os
d = json.load(open('$TMP/list.json'))
print(next((g['id'] for g in d.get('items', []) if g['name'] == os.environ['GALLERY_NAME']), ''))" 2>/dev/null)

  if [ -n "$GALLERY_ID" ]; then
    ok "galería «${GALLERY_NAME}» ya existía: $GALLERY_ID"
  else
    body=$(GALLERY_NAME="$GALLERY_NAME" python3 -c "
import json, os
print(json.dumps({'name': os.environ['GALLERY_NAME'], 'description': 'Fotos de matrícula de la Universidad ACME (ficticia)'}))")
    code=$(post_json /v1/fr/commercial/galleries "$body" -H "Authorization: Bearer $TOKEN")
    [ "$code" = "201" ] || die "createGallery respondió $code: $(head -c 300 "$TMP/out.json")"
    GALLERY_ID=$(field id)
    ok "galería «${GALLERY_NAME}» creada: $GALLERY_ID"
  fi

  if [ -f "$ACME_ENV" ]; then
    cp "$ACME_ENV" "$ACME_ENV.bak"
    ok "el $ACME_ENV anterior no valía: copia en .env.bak"
  fi
  {
    echo "# Escrito por docs/scripts/demo-seed.sh — cuenta $DEMO_EMAIL"
    echo "ACME_API_KEY=$API_KEY"
    echo "ACME_GALLERY_ID=$GALLERY_ID"
    echo "ACME_GATEWAY_URL=http://host.docker.internal:8000"
  } > "$ACME_ENV"
  chmod 600 "$ACME_ENV"
  gallery_ok "$API_KEY" "$GALLERY_ID" || die "la configuración recién escrita no pasa getGallery."
  ok "$ACME_ENV escrito y comprobado con getGallery"
fi

# ---------------------
# 4. ACME y la estudiante de respaldo
# ---------------------
step "Levantando la Universidad ACME..."
docker compose -f "$ACME_DIR/docker-compose.yml" up --build -d || die "no se pudo levantar ACME."
waited=0
health=""
while [ "$waited" -lt "$HEALTH_TIMEOUT" ]; do
  health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' acme-demo 2>/dev/null)
  [ "$health" = "healthy" ] && break
  sleep 3
  waited=$((waited + 3))
done
[ "$health" = "healthy" ] || die "acme-demo no llegó a estar sano (estado: ${health:-ausente})."
ok "acme-demo sano"

# El usuario lo asigna ACME: se busca por el nombre completo en su registro.
student_username() {
  curl -s "$ACME/api/students" -o "$TMP/students.json"
  STUDENT_NAME="$STUDENT_NAME" python3 -c "
import json, os
s = json.load(open('$TMP/students.json'))['students']
print(next((x['username'] for x in s if x['fullName'] == os.environ['STUDENT_NAME']), ''))" 2>/dev/null
}

step "Registrando a $STUDENT_NAME a través de ACME..."
USERNAME=$(student_username)
if [ -n "$USERNAME" ]; then
  ok "ya estaba registrada: $USERNAME"
else
  code=$(curl -s -o "$TMP/out.json" -w '%{http_code}' -X POST "$ACME/api/students" \
    -F "firstName=$STUDENT_FIRST_NAME" -F "lastName1=$STUDENT_LAST_NAME_1" \
    -F "lastName2=$STUDENT_LAST_NAME_2" -F "photo=@$ENROL_PHOTO;type=image/jpeg")
  [ "$code" = "201" ] || die "el registro respondió $code: $(head -c 300 "$TMP/out.json")"
  USERNAME=$(field username)
  ok "registrada con el usuario $USERNAME"
fi

echo ""
echo -e "${CYAN}===============================================${NC}"
echo -e "${GREEN} Datos de respaldo listos${NC}"
echo -e "${CYAN}===============================================${NC}"
echo ""
echo "   Panel:  http://localhost:5173  —  $DEMO_EMAIL / $DEMO_PASSWORD"
echo "   ACME:   http://localhost:4000  —  usuario $USERNAME"
echo ""
echo "   Inicio de sesión con la foto de 2014:"
echo "     curl -s -X POST $ACME/api/sessions -F username=$USERNAME \\"
echo "          -F photo=@$ACME_DIR/seed/koch_2014_480x640.jpg"
echo ""
