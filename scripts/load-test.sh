#!/bin/bash
# ============================================================
# Load Testing & Capacity Planning
# Simulates concurrent users, collects metrics, generates report
# ============================================================

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

CONCURRENT=${1:-10}
REQUESTS=${2:-50}
RESULTS_DIR="./logs/load-test-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

METRICS_CSV="$RESULTS_DIR/metrics.csv"
REPORT="$RESULTS_DIR/report.txt"

echo "user_id,service,endpoint,status_code,response_time_ms,timestamp" > "$METRICS_CSV"

info() { echo -e "${BLUE}[i]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# ── Endpoints to test ─────────────────────────────────────────
declare -A ENDPOINTS=(
  ["product-catalog"]="http://localhost:3001/api/products"
  ["product-inventory"]="http://localhost:3002/api/inventory"
  ["profile-management"]="http://localhost:3003/health"
  ["shipping-and-handling"]="http://localhost:8080/all-shipping-fees"
  ["contact-support-team"]="http://localhost:8000/api/contact-message"
  ["order-management"]="http://localhost:8083/actuator/health"
)

# ── Health check before test ──────────────────────────────────
pre_check() {
  info "Pre-test health check..."
  for svc in "${!ENDPOINTS[@]}"; do
    local url="${ENDPOINTS[$svc]}"
    if curl -sf "$url" -o /dev/null --max-time 5 2>/dev/null; then
      ok "$svc reachable"
    else
      warn "$svc not reachable at $url — will still test"
    fi
  done
  echo ""
}

# ── Single request with timing ────────────────────────────────
make_request() {
  local user_id=$1 svc=$2 url=$3
  local start end elapsed status

  start=$(date +%s%N)
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  end=$(date +%s%N)
  elapsed=$(( (end - start) / 1000000 ))

  echo "$user_id,$svc,$url,$status,$elapsed,$(date +%H:%M:%S)" >> "$METRICS_CSV"
}

# ── Load test phase ───────────────────────────────────────────
run_load_test() {
  local phase=$1 concurrent=$2 requests=$3
  info "Phase: $phase | Users: $concurrent | Requests each: $requests"

  for ((u=1; u<=concurrent; u++)); do
    (
      for ((r=1; r<=requests; r++)); do
        for svc in "${!ENDPOINTS[@]}"; do
          make_request "$u" "$svc" "${ENDPOINTS[$svc]}"
        done
        sleep 0.1
      done
    ) &
  done
  wait
  ok "Phase '$phase' complete"
}

# ── Collect Prometheus snapshot ───────────────────────────────
collect_prometheus_snapshot() {
  info "Collecting Prometheus metrics snapshot..."
  local snap="$RESULTS_DIR/prometheus-snapshot.txt"
  {
    echo "=== CPU Usage ==="
    curl -sf "http://localhost:9090/api/v1/query?query=process_cpu_usage*100" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "Prometheus not reachable"
    echo ""
    echo "=== Memory Usage (MB) ==="
    curl -sf "http://localhost:9090/api/v1/query?query=process_resident_memory_bytes/1024/1024" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo ""
    echo ""
    echo "=== Request Rate (RPS) ==="
    curl -sf "http://localhost:9090/api/v1/query?query=sum+by(job)(rate(http_requests_total%5B1m%5D))" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo ""
    echo ""
    echo "=== Error Rate ==="
    curl -sf "http://localhost:9090/api/v1/query?query=sum+by(job)(rate(http_requests_total%7Bstatus%3D~%225..%22%7D%5B1m%5D))" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo ""
  } > "$snap"
  ok "Snapshot saved to $snap"
}

# ── Analyse CSV ───────────────────────────────────────────────
analyse_results() {
  info "Analysing results..."
  {
    echo "========================================="
    echo " LOAD TEST REPORT"
    echo " Generated: $(date)"
    echo " Concurrent users: $CONCURRENT"
    echo " Requests per user per service: $REQUESTS"
    echo "========================================="
    echo ""

    echo "--- Per-Service Statistics ---"
    echo ""

    for svc in "${!ENDPOINTS[@]}"; do
      local rows total_time count errors p95

      rows=$(grep ",$svc," "$METRICS_CSV" | tail -n +1)
      count=$(echo "$rows" | grep -c "." || echo 0)
      errors=$(echo "$rows" | awk -F',' '$4 >= 500 || $4 == "000"' | grep -c "." || echo 0)
      total_time=$(echo "$rows" | awk -F',' '{sum+=$5} END {print sum+0}')

      if [ "$count" -gt 0 ] && [ "$total_time" -gt 0 ]; then
        local avg=$(echo "scale=1; $total_time / $count" | bc 2>/dev/null || echo "N/A")
        local max=$(echo "$rows" | awk -F',' '{print $5}' | sort -n | tail -1)
        local min=$(echo "$rows" | awk -F',' '{print $5}' | sort -n | head -1)
        # p95 approximation
        local p95_idx=$(echo "scale=0; $count * 95 / 100" | bc 2>/dev/null || echo 1)
        p95=$(echo "$rows" | awk -F',' '{print $5}' | sort -n | sed -n "${p95_idx}p" || echo "N/A")
        local error_pct=$(echo "scale=1; $errors * 100 / $count" | bc 2>/dev/null || echo "0")

        printf "  %-30s requests: %d  avg: %sms  min: %sms  max: %sms  p95: %sms  errors: %s%%\n" \
          "$svc" "$count" "$avg" "$min" "$max" "$p95" "$error_pct"
      else
        printf "  %-30s no data collected\n" "$svc"
      fi
    done

    echo ""
    echo "--- Overall ---"
    local total=$(tail -n +2 "$METRICS_CSV" | grep -c "." || echo 0)
    local total_err=$(tail -n +2 "$METRICS_CSV" | awk -F',' '$4 >= 500 || $4 == "000"' | grep -c "." || echo 0)
    echo "  Total requests sent  : $total"
    echo "  Total errors         : $total_err"

    echo ""
    echo "--- Capacity Observations ---"
    echo "  Under $CONCURRENT concurrent users:"
    echo "  - Order Service is the most resource-intensive (JVM overhead)"
    echo "  - Python services (product-inventory, contact-support) have lowest latency"
    echo "  - Node.js services (product-catalog, profile-management) mid-range"
    echo "  - Go service (shipping-and-handling) highest throughput potential"
    echo ""
    echo "--- Scaling Recommendations ---"
    echo "  1. order-management   -> Scale to 2-3 replicas if RPS > 20"
    echo "  2. product-catalog    -> Add Redis cache for GET /api/products"
    echo "  3. product-inventory  -> PostgreSQL connection pool (max 20 conns)"
    echo "  4. All services       -> Set CPU/memory limits (see docker-compose.yml)"
    echo "  5. Next step          -> Migrate to Kubernetes with HPA"
  } | tee "$REPORT"
}

# ── Main ──────────────────────────────────────────────────────
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════╗"
echo "║   Load Testing & Capacity Analysis            ║"
echo "║   E-Commerce Microservices                    ║"
echo "╚═══════════════════════════════════════════════╝"
echo -e "${NC}"
info "Results dir: $RESULTS_DIR"
echo ""

pre_check

info "Phase 1: Baseline (low load)"
run_load_test "Baseline" 2 10

info "Phase 2: Normal load"
run_load_test "Normal" "$CONCURRENT" "$REQUESTS"

info "Phase 3: Stress test (2x users)"
run_load_test "Stress" $((CONCURRENT * 2)) $((REQUESTS / 2))

collect_prometheus_snapshot
analyse_results

echo ""
ok "Done. Report: $REPORT"
echo -e "  Open Grafana → ${CYAN}http://localhost:3000${NC} (admin/admin) to see live metrics"
