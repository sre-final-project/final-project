#!/bin/bash

REPORT_DIR="logs/inspection"
REPORT_FILE="$REPORT_DIR/report-$(date +%Y%m%d_%H%M%S).txt"

mkdir -p "$REPORT_DIR"

SERVICES="
profile-management
product-catalog
product-inventory
order-management
shipping-and-handling
contact-support-team
ecommerce-ui
prometheus
grafana
alertmanager
"

echo "Simple Log Inspection Report" | tee "$REPORT_FILE"
echo "Generated: $(date)" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

for SERVICE in $SERVICES; do
  echo "Checking $SERVICE" | tee -a "$REPORT_FILE"

  if ! docker ps --format "{{.Names}}" | grep -q "^$SERVICE$"; then
    echo "  container is not running" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    continue
  fi

  LOGS=$(docker logs "$SERVICE" --tail 100 2>&1)

  ERROR_COUNT=$(echo "$LOGS" | grep -Ei "error|exception|failed|refused|timeout" | wc -l)

  if [ "$ERROR_COUNT" -eq 0 ]; then
    echo "  no recent errors found" | tee -a "$REPORT_FILE"
  else
    echo "  possible issues found: $ERROR_COUNT" | tee -a "$REPORT_FILE"
    echo "$LOGS" | grep -Ei "error|exception|failed|refused|timeout" | head -10 | tee -a "$REPORT_FILE"
  fi

  RESTARTS=$(docker inspect "$SERVICE" --format="{{.RestartCount}}" 2>/dev/null || echo "unknown")
  echo "  restart count: $RESTARTS" | tee -a "$REPORT_FILE"
  echo "" | tee -a "$REPORT_FILE"
done

echo "Log inspection completed" | tee -a "$REPORT_FILE"
echo "Report saved to $REPORT_FILE"
