#!/bin/bash

REQUESTS=${1:-20}
RESULT_DIR="logs/load-test-$(date +%Y%m%d_%H%M%S)"
RESULT_FILE="$RESULT_DIR/results.csv"
REPORT_FILE="$RESULT_DIR/report.txt"

mkdir -p "$RESULT_DIR"

echo "service,url,status_code,response_time_seconds" > "$RESULT_FILE"

test_endpoint() {
  SERVICE=$1
  URL=$2

  echo "Testing $SERVICE at $URL"

  for i in $(seq 1 "$REQUESTS"); do
    RESULT=$(curl -s -o /dev/null -w "%{http_code},%{time_total}" --max-time 10 "$URL")
    STATUS=$(echo "$RESULT" | cut -d',' -f1)
    TIME=$(echo "$RESULT" | cut -d',' -f2)
    echo "$SERVICE,$URL,$STATUS,$TIME" >> "$RESULT_FILE"
  done
}

echo "Starting simple load test"
echo "Requests per service: $REQUESTS"
echo ""

test_endpoint "product-catalog" "http://localhost:3001/api/products"
test_endpoint "product-inventory" "http://localhost:3002/api/inventory"
test_endpoint "profile-management" "http://localhost:3003/health"
test_endpoint "shipping-and-handling" "http://localhost:8080/health"
test_endpoint "contact-support-team" "http://localhost:8000/health"
test_endpoint "order-management" "http://localhost:8083/actuator/health"

echo ""
echo "Generating report..."

{
  echo "Simple Load Test Report"
  echo "Generated: $(date)"
  echo "Requests per service: $REQUESTS"
  echo ""
  echo "Results by service:"

  for SERVICE in product-catalog product-inventory profile-management shipping-and-handling contact-support-team order-management; do
    TOTAL=$(grep "^$SERVICE," "$RESULT_FILE" | wc -l)
    ERRORS=$(grep "^$SERVICE," "$RESULT_FILE" | awk -F',' '$3 >= 500 || $3 == "000"' | wc -l)
    AVG_TIME=$(grep "^$SERVICE," "$RESULT_FILE" | awk -F',' '{sum += $4; count++} END {if (count > 0) print sum / count; else print 0}')

    echo "$SERVICE"
    echo "  total requests: $TOTAL"
    echo "  errors: $ERRORS"
    echo "  average response time: ${AVG_TIME}s"
    echo ""
  done

  echo "Capacity planning notes:"
  echo "1. Services with higher response time should be scaled first."
  echo "2. order-management is important because it depends on catalog, inventory, shipping, and MongoDB."
  echo "3. If CPU or memory usage increases, add replicas or increase resources."
  echo "4. Databases should be monitored because they can become bottlenecks."
} | tee "$REPORT_FILE"

echo ""
echo "Results saved to $RESULT_DIR"
