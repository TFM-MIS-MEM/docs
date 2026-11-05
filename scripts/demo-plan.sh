#!/bin/bash
# ===========================================================
# demo-plan.sh — Deja en un plan de la tarifa la cuenta de una API KEY.
#
# Uso:
#   ./scripts/demo-plan.sh <API_KEY> <FREE|PRO|BUSINESS>
#
# Para la demo: la Universidad ACME entra por el canal de API, y una cuenta
# recién registrada es FREE, que no lo incluye. Sin esto, ACME recibiría
# 403 FEATURE_NOT_IN_PLAN. En el SaaS el plan lo pone pricing al confirmar
# Stripe el pago; la demo no pasa por el pago.
#
#   1. La cuenta de la API KEY, preguntándole a auth directamente
#      (POST /v1/auth/validate-key, la misma consulta que hace la pasarela).
#   2. El contrato de esa cuenta en SPACE, en el plan pedido: se nova si existe
#      y se crea si no. Desde dentro de space-server, que no publica puertos,
#      con la clave de pricing, que es quien administra los contratos.
#
# Idempotente. La API KEY no se imprime.
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
API_KEY="${1:-}"
PLAN="${2:-}"
AUTH="${AUTH:-http://127.0.0.1:3000}"

die() { echo "  [ERROR] $1" >&2; exit 1; }
read_env_value() { grep -E "^$1=" "$2" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r'; }

[ -n "$ROOT_DIR" ] || die "no encuentro la raíz del workspace (indícala con TFM_ROOT)."
[ -n "$API_KEY" ] || die "uso: $0 <API_KEY> <FREE|PRO|BUSINESS>"
case "$PLAN" in
  FREE|PRO|BUSINESS) ;;
  *) die "plan desconocido: '$PLAN'. Use FREE, PRO o BUSINESS." ;;
esac

INTERNAL=$(read_env_value INTERNAL_API_SECRET "$ROOT_DIR/auth-microservice/.env")
SPACE_KEY=$(read_env_value SPACE_API_KEY "$ROOT_DIR/pricing-microservice/.env")
[ -n "$INTERNAL" ] || die "auth-microservice/.env no define INTERNAL_API_SECRET (¿has ejecutado dev-up.sh?)."
[ -n "$SPACE_KEY" ] || die "pricing-microservice/.env no define SPACE_API_KEY (¿has ejecutado dev-up.sh?)."

ACCOUNT_ID=$(curl -s -X POST "$AUTH/v1/auth/validate-key" \
  -H "x-internal-secret: $INTERNAL" -H "x-api-key: $API_KEY" \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('accountId',''))" 2>/dev/null)
[ -n "$ACCOUNT_ID" ] || die "auth no reconoce la API KEY (validate-key no devolvió accountId)."

OUT=$(docker exec -i -e K="$SPACE_KEY" -e A="$ACCOUNT_ID" -e P="$PLAN" space-server \
  node --input-type=module - <<'EOF'
const base = 'http://localhost:3000/api/v1';
const headers = { 'x-api-key': process.env.K, 'content-type': 'application/json' };
const sub = {
  // SPACE impone la versión fijada de la tarifa (all_pick): la que se envía da igual.
  contractedServices: { faceapi: 'fijada-por-space' },
  subscriptionPlans: { faceapi: process.env.P },
  subscriptionAddOns: {},
};
const call = (method, path, body) => fetch(base + path, { method, headers, body: JSON.stringify(body) });
let r = await call('PUT', `/contracts/${process.env.A}`, sub);
if (r.status === 404) {
  r = await call('POST', '/contracts', {
    userContact: { userId: process.env.A, username: process.env.A },
    billingPeriod: { autoRenew: true, renewalDays: 30 },
    ...sub,
  });
}
console.log(r.status);
EOF
)
case "$OUT" in
  200|201) echo "  [OK] cuenta $ACCOUNT_ID en el plan $PLAN (SPACE $OUT)" ;;
  *) die "SPACE respondió '$OUT' al fijar el plan $PLAN de la cuenta $ACCOUNT_ID." ;;
esac
