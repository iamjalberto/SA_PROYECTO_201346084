#!/usr/bin/env bash
# ============================================================
# smoke-test.sh – Smoke tests automatizados para Delivereats
# ============================================================
set -uo pipefail

BASE_URL="${BASE_URL:-http://localhost:3000}"
PASS=0
FAIL=0
ERRORS=()

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check() {
  local desc="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" =~ $expected ]]; then
    echo -e "  ${GREEN}✓${NC} $desc"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}✗${NC} $desc (expected '$expected', got '$actual')"
    ERRORS+=("FAIL: $desc")
    FAIL=$((FAIL + 1))
  fi
}

check_status() {
  local desc="$1"
  local expected_code="$2"
  local url="$3"
  local data="${4:-}"
  local method="${5:-GET}"
  local token="${6:-}"

  local http_code
  local curl_args=(-s -o /dev/null -w "%{http_code}" -X "$method")
  if [[ -n "$token" ]]; then
    curl_args+=(-H "Authorization: Bearer $token")
  fi
  if [[ -n "$data" ]]; then
    curl_args+=(-H "Content-Type: application/json" -d "$data")
  fi
  http_code=$(curl "${curl_args[@]}" "$url")

  check "$desc" "$expected_code" "$http_code"
}

get_body() {
  local url="$1"
  local token="${2:-}"
  if [[ -n "$token" ]]; then
    curl -s -H "Authorization: Bearer $token" "$url"
  else
    curl -s "$url"
  fi
}

post_body() {
  local url="$1"
  local data="$2"
  local token="${3:-}"
  if [[ -n "$token" ]]; then
    curl -s -X POST -H "Content-Type: application/json" \
      -H "Authorization: Bearer $token" \
      -d "$data" "$url"
  else
    curl -s -X POST -H "Content-Type: application/json" \
      -d "$data" "$url"
  fi
}

# ─────────────────────────────────────────────────────────────
# SUITE 1: Health Checks
# ─────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}▶ Suite 1: Health Checks${NC}"

check_status "API Gateway health" "200" "$BASE_URL/api/health"
check_status "Auth route responds" "[2-4].." "$BASE_URL/api/auth/login" '{}' "POST"
check_status "Restaurants route requires auth" "401" "$BASE_URL/api/restaurants"
check_status "Orders route requires auth" "401" "$BASE_URL/api/orders/my"
check_status "Payments route requires auth" "401" "$BASE_URL/api/payments/wallet"
check_status "FX route requires auth" "401" "$BASE_URL/api/fx/rates"

# ─────────────────────────────────────────────────────────────
# SUITE 2: Autenticación
# ─────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}▶ Suite 2: Autenticación${NC}"

TEST_EMAIL="smoketest_$(date +%s)@delivereats.test"
TEST_PASS="SmkTest1234!"
TEST_NAME="Smoke Test User"

REGISTER_RESP=$(post_body "$BASE_URL/api/auth/register" \
  "{\"name\":\"$TEST_NAME\",\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASS\",\"role\":\"CLIENTE\"}")

check "Registro de usuario exitoso" '"success":true' "$REGISTER_RESP"

LOGIN_RESP=$(post_body "$BASE_URL/api/auth/login" \
  "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASS\"}")

check "Login retorna token" "token" "$LOGIN_RESP"

TOKEN=$(echo "$LOGIN_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token', d.get('access_token','')))" 2>/dev/null || echo "")
check "Token no vacío" ".+" "$TOKEN"

# ─────────────────────────────────────────────────────────────
# SUITE 3: Endpoints protegidos
# ─────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}▶ Suite 3: Endpoints protegidos${NC}"

if [[ -n "$TOKEN" ]]; then
  RESTAURANTS=$(get_body "$BASE_URL/api/restaurants" "$TOKEN")
  check "Listado de restaurantes" "restaurants" "$RESTAURANTS"

  FX_RESP=$(get_body "$BASE_URL/api/fx/rates" "$TOKEN")
  check "FX rates disponibles" "success|rates|GTQ|USD" "$FX_RESP"

  ORDERS_RESP=$(get_body "$BASE_URL/api/orders/my" "$TOKEN")
  check "Mis órdenes retorna lista" "orders" "$ORDERS_RESP"

  check_status "Wallet con token válido responde" "2.." "$BASE_URL/api/payments/wallet" "" "GET" "$TOKEN"
else
  echo -e "  ${RED}⚠${NC} Token vacío – se omiten pruebas de endpoints protegidos"
  FAIL=$((FAIL + 4))
fi

# ─────────────────────────────────────────────────────────────
# SUITE 4: Sin autenticación → 401
# ─────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}▶ Suite 4: Seguridad – sin autenticación${NC}"

check_status "Órdenes sin token → 401" "401" "$BASE_URL/api/orders/my"
check_status "Wallet sin token → 401"  "401" "$BASE_URL/api/payments/wallet"
check_status "Delivery sin token → 401" "401" "$BASE_URL/api/delivery/my"

# ─────────────────────────────────────────────────────────────
# Resumen
# ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo -e "  ${GREEN}Passed:${NC} $PASS"
echo -e "  ${RED}Failed:${NC} $FAIL"
echo "════════════════════════════════════════"

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo ""
  echo -e "${RED}Failures:${NC}"
  for e in "${ERRORS[@]}"; do
    echo "  - $e"
  done
fi

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo -e "${RED}Smoke tests FAILED${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}All smoke tests passed!${NC}"
exit 0
