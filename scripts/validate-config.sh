#!/bin/bash
# ============================================================
# Pre-deployment Configuration Validation
# Checks env vars, endpoints, DB strings, ports
# ============================================================

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

PASS=0; FAIL=0; WARN=0
LOG="./logs/validation-$(date +%Y%m%d_%H%M%S).log"
mkdir -p ./logs

ok()   { echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG"; ((PASS++)); }
fail() { echo -e "${RED}[✗]${NC} $1" | tee -a "$LOG"; ((FAIL++)); }
warn() { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOG"; ((WARN++)); }
info() { echo -e "${BLUE}[i]${NC} $1" | tee -a "$LOG"; }

# ── 1. Tools ──────────────────────────────────────────────────
check_tools() {
  info "=== 1. Required Tools ==="
  command -v docker        &>/dev/null && ok "docker found"        || fail "docker not found"
  docker compose version   &>/dev/null && ok "docker compose found" || fail "docker compose not found"
  command -v curl          &>/dev/null && ok "curl found"           || warn "curl not found (optional)"
}

# ── 2. Docker Compose syntax ──────────────────────────────────
check_compose_syntax() {
  info "=== 2. docker-compose.yml Syntax ==="
  if docker compose config --quiet 2>/dev/null; then
    ok "docker-compose.yml is valid"
  else
    fail "docker-compose.yml has syntax errors:"
    docker compose config 2>&1 | head -20 | tee -a "$LOG"
  fi
}

# ── 3. Required files ─────────────────────────────────────────
check_required_files() {
  info "=== 3. Required Files ==="
  local files=(
    "docker-compose.yml"
    "monitoring/prometheus.yml"
    "monitoring/alert-rules.yml"
    "monitoring/alertmanager.yml"
    "monitoring/grafana-datasources.yml"
    "monitoring/grafana-dashboards/dashboards.yml"
    "order-management/Dockerfile"
    "order-management/src/main/resources/application.properties"
    "product-inventory/Dockerfile"
    "product-inventory/requirements.txt"
    "contact-support-team/Dockerfile"
    "product-catalog/Dockerfile"
    "shipping-and-handling/Dockerfile"
    "profile-management/Dockerfile"
  )
  for f in "${files[@]}"; do
    [ -f "$f" ] && ok "$f exists" || fail "$f MISSING"
  done
}

# ── 4. Env variables in compose ──────────────────────────────
check_env_variables() {
  info "=== 4. Environment Variables ==="
  local compose
  compose=$(docker compose config 2>/dev/null)

  # order-management critical vars
  echo "$compose" | grep -q "SPRING_DATA_MONGODB_URI"           && ok "order-management: SPRING_DATA_MONGODB_URI set"        || fail "order-management: SPRING_DATA_MONGODB_URI missing"
  echo "$compose" | grep -q "PRODUCT_INVENTORY_API_HOST"        && ok "order-management: PRODUCT_INVENTORY_API_HOST set"     || fail "order-management: PRODUCT_INVENTORY_API_HOST missing"
  echo "$compose" | grep -q "PRODUCT_CATALOG_API_HOST"          && ok "order-management: PRODUCT_CATALOG_API_HOST set"       || fail "order-management: PRODUCT_CATALOG_API_HOST missing"
  echo "$compose" | grep -q "SHIPPING_HANDLING_API_HOST"        && ok "order-management: SHIPPING_HANDLING_API_HOST set"     || fail "order-management: SHIPPING_HANDLING_API_HOST missing"

  # DB connection strings format
  local mongo_uri
  mongo_uri=$(echo "$compose" | grep "SPRING_DATA_MONGODB_URI" | awk -F': ' '{print $2}' | tr -d '"')
  if [[ "$mongo_uri" =~ ^mongodb:// ]]; then
    ok "SPRING_DATA_MONGODB_URI has valid mongodb:// format"
  else
    fail "SPRING_DATA_MONGODB_URI format invalid — should start with mongodb://"
  fi

  # No localhost in service URLs (must use container names)
  if echo "$compose" | grep -E "API_HOST.*localhost" | grep -v "#" | grep -q "."; then
    fail "API_HOST contains 'localhost' — use Docker service names instead"
  else
    ok "API_HOST values use Docker service names (not localhost)"
  fi

  # No SERVER_SERVLET_CONTEXT_PATH (breaks actuator)
  if echo "$compose" | grep -q "SERVER_SERVLET_CONTEXT_PATH"; then
    fail "SERVER_SERVLET_CONTEXT_PATH is set — this breaks /actuator/prometheus endpoint"
  else
    ok "SERVER_SERVLET_CONTEXT_PATH not set (actuator paths intact)"
  fi

  # Grafana password
  if echo "$compose" | grep -q "GF_SECURITY_ADMIN_PASSWORD=admin"; then
    warn "Grafana is using default password 'admin' — change in production"
  fi

  # MySQL
  echo "$compose" | grep -q "MYSQL_HOST"    && ok "profile-management: MYSQL_HOST set"    || fail "profile-management: MYSQL_HOST missing"
  echo "$compose" | grep -q "MYSQL_USER"    && ok "profile-management: MYSQL_USER set"    || fail "profile-management: MYSQL_USER missing"
  echo "$compose" | grep -q "MYSQL_PASSWORD" && ok "profile-management: MYSQL_PASSWORD set" || fail "profile-management: MYSQL_PASSWORD missing"

  # PostgreSQL
  echo "$compose" | grep -q "POSTGRES_HOST" && ok "product-inventory: POSTGRES_HOST set"  || fail "product-inventory: POSTGRES_HOST missing"
  echo "$compose" | grep -q "POSTGRES_DB"   && ok "product-inventory: POSTGRES_DB set"    || fail "product-inventory: POSTGRES_DB missing"
}

# ── 5. Prometheus config ──────────────────────────────────────
check_prometheus_config() {
  info "=== 5. Prometheus Configuration ==="
  local prom="monitoring/prometheus.yml"
  local rules="monitoring/alert-rules.yml"

  grep -q "order-management"      "$prom" && ok "prometheus.yml: order-management scrape target found"      || fail "prometheus.yml: order-management target missing"
  grep -q "actuator/prometheus"   "$prom" && ok "prometheus.yml: actuator/prometheus path for Spring Boot"  || warn "prometheus.yml: actuator/prometheus path not found"
  grep -q "product-catalog"       "$prom" && ok "prometheus.yml: product-catalog target found"               || fail "prometheus.yml: product-catalog target missing"
  grep -q "product-inventory"     "$prom" && ok "prometheus.yml: product-inventory target found"             || fail "prometheus.yml: product-inventory target missing"
  grep -q "rule_files"            "$prom" && ok "prometheus.yml: rule_files section present"                 || fail "prometheus.yml: rule_files section missing"
  grep -q "alertmanager"          "$prom" && ok "prometheus.yml: alertmanager configured"                    || warn "prometheus.yml: alertmanager not configured"

  grep -q "ServiceDown"     "$rules" && ok "alert-rules.yml: ServiceDown alert defined"    || fail "alert-rules.yml: ServiceDown alert missing"
  grep -q "HighCPUUsage"    "$rules" && ok "alert-rules.yml: HighCPUUsage alert defined"   || fail "alert-rules.yml: HighCPUUsage alert missing"
  grep -q "HighErrorRate"   "$rules" && ok "alert-rules.yml: HighErrorRate alert defined"  || fail "alert-rules.yml: HighErrorRate alert missing"
}

# ── 6. Ports ──────────────────────────────────────────────────
check_ports() {
  info "=== 6. Port Availability ==="
  local ports=(3000 3001 3002 3003 4000 8000 8080 8083 9090 9093)
  for port in "${ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
      warn "Port $port already in use — may conflict"
    else
      ok "Port $port is free"
    fi
  done
}

# ── 7. Grafana dashboards ─────────────────────────────────────
check_grafana_dashboards() {
  info "=== 7. Grafana Dashboards ==="
  local dash_dir="monitoring/grafana-dashboards"
  [ -d "$dash_dir" ]                        && ok "grafana-dashboards directory exists"            || fail "grafana-dashboards directory missing"
  [ -f "$dash_dir/dashboards.yml" ]         && ok "dashboards.yml provisioning config exists"     || fail "dashboards.yml missing"
  [ -f "$dash_dir/services-overview.json" ] && ok "services-overview.json dashboard exists"       || warn "services-overview.json missing"
  [ -f "$dash_dir/capacity-planning.json" ] && ok "capacity-planning.json dashboard exists"       || warn "capacity-planning.json missing"
  [ -f "$dash_dir/alerts-dashboard.json" ]  && ok "alerts-dashboard.json dashboard exists"        || warn "alerts-dashboard.json missing"
  [ -f "monitoring/grafana-datasources.yml" ] && ok "grafana-datasources.yml exists"              || fail "grafana-datasources.yml missing"
}

# ── Summary ───────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${BLUE}════════════════════════════════════${NC}"
  echo -e "${BLUE}  Validation Summary${NC}"
  echo -e "${BLUE}════════════════════════════════════${NC}"
  echo -e "  ${GREEN}Passed : $PASS${NC}"
  echo -e "  ${YELLOW}Warnings: $WARN${NC}"
  echo -e "  ${RED}Failed : $FAIL${NC}"
  echo ""
  if [ "$FAIL" -eq 0 ]; then
    echo -e "  ${GREEN}✓ Ready for deployment${NC}"
    echo ""
    echo -e "  Run: ${BLUE}docker compose up -d --build${NC}"
  else
    echo -e "  ${RED}✗ Fix $FAIL error(s) before deploying${NC}"
  fi
  echo -e "  Report saved: $LOG"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════╗"
echo "║   Pre-Deployment Configuration Validation     ║"
echo "║   E-Commerce Microservices                    ║"
echo "╚═══════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Timestamp: $(date)" | tee "$LOG"
echo "" | tee -a "$LOG"

check_tools
check_compose_syntax
check_required_files
check_env_variables
check_prometheus_config
check_ports
check_grafana_dashboards
print_summary

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
