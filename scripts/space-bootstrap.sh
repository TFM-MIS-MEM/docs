#!/bin/bash
# ===========================================================
# space-bootstrap.sh — deja SPACE listo para el SaaS y reparte sus claves.
#
# Uso:
#   ./scripts/space-bootstrap.sh
#
# Requisitos: el contenedor space-server arriba y sano (lo levanta dev-up.sh).
# Idempotente: se puede lanzar las veces que haga falta.
#
# Qué hace (el detalle, en space-bootstrap.mjs):
#   1. Claves de organización MANAGEMENT para fr-commercial y para pricing.
#   2. El servicio `frsaas` desde SPHERE, con la versión fijada en
#      pricing-microservice/pricing/sphere.env (política all_pick).
#   3. Escribe SPACE_URL y SPACE_API_KEY en los .env de fr-commercial y pricing.
#
# Códigos de salida: 0 listo · 1 algo falló (el mensaje dice qué).
# ===========================================================

set -uo pipefail

# Raíz del workspace: misma búsqueda que dev-up.sh (véase allí el porqué).
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
  echo "[ERROR] No encuentro la raíz del workspace desde $SCRIPT_DIR (indícala con TFM_ROOT)." >&2
  exit 1
fi

SPHERE_ENV="$ROOT_DIR/pricing-microservice/pricing/sphere.env"
FR_ENV="$ROOT_DIR/fr-commercial-microservice/.env"
PRICING_ENV="$ROOT_DIR/pricing-microservice/.env"
SPACE_URL="http://space-server:3000"

read_env_value() { grep -E "^$1=" "$2" 2>/dev/null | head -1 | cut -d= -f2-; }

# Escribe CLAVE=valor en un .env: sustituye la línea si existe, la añade si no.
upsert_env() {
  local file="$1" key="$2" value="$3"
  touch "$file"
  if grep -qE "^$key=" "$file"; then
    sed -i.bak "s|^$key=.*|$key=$value|" "$file" && rm -f "$file.bak"
  else
    echo "$key=$value" >> "$file"
  fi
}

if [ ! -f "$SPHERE_ENV" ]; then
  echo "[ERROR] No existe $SPHERE_ENV: es la versión de la tarifa que se carga." >&2
  exit 1
fi

if [ "$(docker inspect -f '{{.State.Health.Status}}' space-server 2>/dev/null)" != "healthy" ]; then
  echo "[ERROR] space-server no está arriba y sano. Levántalo con scripts/dev-up.sh." >&2
  exit 1
fi

OUT=$(docker exec -i \
  -e SPHERE_PRICING_URL="$(read_env_value SPHERE_PRICING_URL "$SPHERE_ENV")" \
  -e SPHERE_PRICING_VERSION_ID="$(read_env_value SPHERE_PRICING_VERSION_ID "$SPHERE_ENV")" \
  -e SPHERE_PRICING_CONTENT_HASH="$(read_env_value SPHERE_PRICING_CONTENT_HASH "$SPHERE_ENV")" \
  -e FR_SPACE_API_KEY="$(read_env_value SPACE_API_KEY "$FR_ENV")" \
  -e PRICING_SPACE_API_KEY="$(read_env_value SPACE_API_KEY "$PRICING_ENV")" \
  space-server node --input-type=module - < "$SCRIPT_DIR/space-bootstrap.mjs")
STATUS=$?
if [ $STATUS -ne 0 ]; then
  echo "[ERROR] El arranque de SPACE falló (código $STATUS)." >&2
  exit 1
fi

FR_KEY=$(echo "$OUT" | read_env_value FR_SPACE_API_KEY /dev/stdin)
PRICING_KEY=$(echo "$OUT" | read_env_value PRICING_SPACE_API_KEY /dev/stdin)
if [ -z "$FR_KEY" ] || [ -z "$PRICING_KEY" ]; then
  echo "[ERROR] SPACE no devolvió las claves." >&2
  exit 1
fi

upsert_env "$FR_ENV" SPACE_URL "$SPACE_URL"
upsert_env "$FR_ENV" SPACE_API_KEY "$FR_KEY"
upsert_env "$PRICING_ENV" SPACE_URL "$SPACE_URL"
upsert_env "$PRICING_ENV" SPACE_API_KEY "$PRICING_KEY"
chmod 600 "$FR_ENV"

echo "  SPACE listo: claves escritas en fr-commercial-microservice/.env y pricing-microservice/.env"
