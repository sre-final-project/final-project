#!/bin/bash

# Simple configuration validation script.
# Usage: bash scripts/validate-config.sh

LOG_FILE="logs/validation-$(date +%Y%m%d_%H%M%S).log"
mkdir -p logs

PASS=0
FAIL=0

check_file() {
  FILE=$1

  if [ -f "$FILE" ]; then
    echo "OK: $FILE exists" | tee -a "$LOG_FILE"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $FILE is missing" | tee -a "$LOG_FILE"
    FAIL=$((FAIL + 1))
  fi
}

check_command() {
  COMMAND=$1

  if command -v "$COMMAND" >/dev/null 2>&1; then
    echo "OK: $COMMAND is installed" | tee -a "$LOG_FILE"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $COMMAND is not installed" | tee -a "$LOG_FILE"
    FAIL=$((FAIL + 1))
  fi
}

echo "Simple Configuration Validation" | tee "$LOG_FILE"
echo "Generated: $(date)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

echo "Checking required tools" | tee -a "$LOG_FILE"
check_command docker
check_command curl
echo "" | tee -a "$LOG_FILE"

echo "Checking required project files" | tee -a "$LOG_FILE"
check_file docker-compose.yml
check_file docker-stack.yml
check_file monitoring/prometheus.yml
check_file monitoring/alert-rules.yml
check_file monitoring/alertmanager.yml
check_file monitoring/grafana-datasources.yml
check_file product-catalog/Dockerfile
check_file product-inventory/Dockerfile
check_file profile-management/Dockerfile
check_file order-management/Dockerfile
check_file shipping-and-handling/Dockerfile
check_file contact-support-team/Dockerfile
echo "" | tee -a "$LOG_FILE"

echo "Checking Docker Compose syntax" | tee -a "$LOG_FILE"
if docker compose config >/dev/null 2>&1; then
  echo "OK: docker-compose.yml syntax is valid" | tee -a "$LOG_FILE"
  PASS=$((PASS + 1))
else
  echo "FAIL: docker-compose.yml has syntax errors" | tee -a "$LOG_FILE"
  FAIL=$((FAIL + 1))
fi

echo "" | tee -a "$LOG_FILE"
echo "Validation summary" | tee -a "$LOG_FILE"
echo "Passed checks: $PASS" | tee -a "$LOG_FILE"
echo "Failed checks: $FAIL" | tee -a "$LOG_FILE"

if [ "$FAIL" -eq 0 ]; then
  echo "Result: project configuration looks ready" | tee -a "$LOG_FILE"
  exit 0
else
  echo "Result: fix failed checks before deployment" | tee -a "$LOG_FILE"
  exit 1
fi
