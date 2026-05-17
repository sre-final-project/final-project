#!/bin/bash
# ============================================================
# Log-Based Troubleshooting Automation
# Centralized log inspection with predefined error patterns
# ============================================================

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

LOG_DIR="./logs/inspection"
REPORT_FILE="$LOG_DIR/report-$(date +%Y%m%d_%H%M%S).txt"
mkdir -p "$LOG_DIR"

SERVICES=(
  "profile-management"
  "product-catalog"
  "product-inventory"
  "order-management"
  "shipping-and-handling"
  "contact-support-team"
  "ecommerce-ui"
  "prometheus"
  "grafana"
  "alertmanager"
)

# ── Pattern categories ────────────────────────────────────────
declare -A DB_PATTERNS=(
  ["connection refused"]="DB_CONN_REFUSED"
  ["connection timeout"]="DB_CONN_TIMEOUT"
  ["authentication failed"]="DB_AUTH_FAIL"
  ["too many connections"]="DB_CONN_LIMIT"
  ["could not connect"]="DB_CONN_FAIL"
  ["ECONNREFUSED"]="DB_CONN_REFUSED_NODE"
  ["MongoNetworkError"]="MONGO_NET_ERR"
  ["OperationalError"]="PG_OP_ERR"
  ["Communications link failure"]="MYSQL_LINK_FAIL"
)

declare -A RESTART_PATTERNS=(
  ["Restarting"]="CONTAINER_RESTART"
  ["OOMKilled"]="OOM_KILL"
  ["exit code"]="EXIT_CODE"
  ["panic:"]="GO_PANIC"
  ["FATAL"]="FATAL_ERR"
  ["OutOfMemoryError"]="JAVA_OOM"
  ["StackOverflowError"]="JAVA_STACKOVERFLOW"
)

declare -A APP_PATTERNS=(
  ["NullPointerException"]="JAVA_NPE"
  ["Traceback"]="PYTHON_TRACEBACK"
  ["UnhandledPromiseRejection"]="NODE_UNHANDLED_PROMISE"
  ["Error:"]="GENERIC_ERROR"
  ["WARN"]="WARNING"
  ["404"]="NOT_FOUND"
  ["500"]="SERVER_ERROR"
)

# ── Counters ──────────────────────────────────────────────────
total_issues=0
critical_issues=0

log_header() {
  echo -e "\n${BLUE}══════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
}

check_container_running() {
  docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^$1$"
}

inspect_service() {
  local svc=$1
  local found_issues=0

  if ! check_container_running "$svc"; then
    echo -e "  ${RED}[SKIP]${NC} $svc — container not running" | tee -a "$REPORT_FILE"
    return
  fi

  local logs
  logs=$(docker logs "$svc" --tail 200 2>&1)

  echo -e "\n  ${CYAN}── $svc ──${NC}" | tee -a "$REPORT_FILE"

  # Check DB patterns
  for pattern in "${!DB_PATTERNS[@]}"; do
    local hits
    hits=$(echo "$logs" | grep -ic "$pattern" 2>/dev/null || true)
    if [ "$hits" -gt 0 ]; then
      echo -e "  ${RED}[DB ERROR]${NC} '${pattern}' found ${hits}x — code: ${DB_PATTERNS[$pattern]}" | tee -a "$REPORT_FILE"
      ((total_issues++)); ((critical_issues++)); ((found_issues++))
    fi
  done

  # Check restart/crash patterns
  for pattern in "${!RESTART_PATTERNS[@]}"; do
    local hits
    hits=$(echo "$logs" | grep -ic "$pattern" 2>/dev/null || true)
    if [ "$hits" -gt 0 ]; then
      echo -e "  ${RED}[CRASH]${NC} '${pattern}' found ${hits}x — code: ${RESTART_PATTERNS[$pattern]}" | tee -a "$REPORT_FILE"
      ((total_issues++)); ((critical_issues++)); ((found_issues++))
    fi
  done

  # Check app-level patterns
  for pattern in "${!APP_PATTERNS[@]}"; do
    local hits
    hits=$(echo "$logs" | grep -ic "$pattern" 2>/dev/null || true)
    if [ "$hits" -gt 0 ]; then
      echo -e "  ${YELLOW}[APP WARN]${NC} '${pattern}' found ${hits}x — code: ${APP_PATTERNS[$pattern]}" | tee -a "$REPORT_FILE"
      ((total_issues++)); ((found_issues++))
    fi
  done

  if [ "$found_issues" -eq 0 ]; then
    echo -e "  ${GREEN}[OK]${NC} No issues found" | tee -a "$REPORT_FILE"
  fi
}

check_restart_loops() {
  log_header "Checking Container Restart Loops"
  echo "" | tee -a "$REPORT_FILE"

  docker ps --format '{{.Names}}\t{{.Status}}' 2>/dev/null | while IFS=$'\t' read -r name status; do
    local restarts
    restarts=$(docker inspect "$name" --format='{{.RestartCount}}' 2>/dev/null || echo "0")
    if [ "$restarts" -gt 3 ]; then
      echo -e "  ${RED}[RESTART LOOP]${NC} $name — restarted ${restarts} times" | tee -a "$REPORT_FILE"
      ((total_issues++)); ((critical_issues++))
    elif [ "$restarts" -gt 0 ]; then
      echo -e "  ${YELLOW}[WARN]${NC} $name — restarted ${restarts} times" | tee -a "$REPORT_FILE"
    else
      echo -e "  ${GREEN}[OK]${NC} $name — 0 restarts" | tee -a "$REPORT_FILE"
    fi
  done
}

check_unhealthy_containers() {
  log_header "Checking Unhealthy Containers"
  echo "" | tee -a "$REPORT_FILE"

  local unhealthy
  unhealthy=$(docker ps --filter health=unhealthy --format '{{.Names}}' 2>/dev/null)
  if [ -n "$unhealthy" ]; then
    echo -e "  ${RED}[UNHEALTHY]${NC} $unhealthy" | tee -a "$REPORT_FILE"
    ((critical_issues++))
  else
    echo -e "  ${GREEN}[OK]${NC} All containers healthy" | tee -a "$REPORT_FILE"
  fi
}

generate_summary() {
  log_header "Summary"
  {
    echo ""
    echo "  Timestamp : $(date)"
    echo "  Total issues found : $total_issues"
    echo "  Critical issues    : $critical_issues"
    echo ""
    if [ "$critical_issues" -gt 0 ]; then
      echo -e "  ${RED}ACTION REQUIRED: $critical_issues critical issues detected${NC}"
    else
      echo -e "  ${GREEN}System looks healthy — no critical issues${NC}"
    fi
    echo ""
    echo "  Full report: $REPORT_FILE"
  } | tee -a "$REPORT_FILE"
}

# ── Main ──────────────────────────────────────────────────────
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════╗"
echo "║   Log-Based Troubleshooting Automation        ║"
echo "║   E-Commerce Microservices                    ║"
echo "╚═══════════════════════════════════════════════╝"
echo -e "${NC}"

{
  echo "=== Log Inspection Report ==="
  echo "Generated: $(date)"
  echo ""
} > "$REPORT_FILE"

check_unhealthy_containers
check_restart_loops

log_header "Inspecting Service Logs"
for svc in "${SERVICES[@]}"; do
  inspect_service "$svc"
done

generate_summary
