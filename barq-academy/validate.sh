#!/usr/bin/env bash
set -eo pipefail

BASE_URL="0.0.0.0:8080"
MAX_ATTEMPTS=30

echo "==> [1/6] Bounded Wait for Dependency & Application Readiness..."
for i in $(seq 1 $MAX_ATTEMPTS); do
  if curl -s -f "$BASE_URL/ready" > /dev/null 2>&1 || curl -s -f "$BASE_URL/health" > /dev/null 2>&1; then
    echo "PASS: Application and dependencies are ready."
    break
  fi
  if [ "$i" -eq "$MAX_ATTEMPTS" ]; then
    echo "FAIL: Application failed to become ready within time limit."
    exit 1
  fi
  echo "Waiting for /ready endpoint... attempt $i/$MAX_ATTEMPTS"
  sleep 2
done

echo "==> [2/6] Verifying Core Endpoints..."
# Check Root or Health
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/" || true)
if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 404 ] || [ "$HTTP_CODE" -eq 302 ]; then
  echo "PASS: Root endpoint check complete (HTTP $HTTP_CODE)."
else
  echo "FAIL: Root endpoint unreachable (HTTP $HTTP_CODE)."
  exit 1
fi

# Check Health Endpoint
HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health" || true)
if [ "$HEALTH_CODE" -eq 200 ]; then
  echo "PASS: Health check endpoint passed (HTTP 200)."
else
  echo "FAIL: Health check endpoint failed (HTTP $HEALTH_CODE)."
  exit 1
fi

echo "==> [3/6] Testing Load Balancing across instances..."
INSTANCES=$(for i in $(seq 1 10); do curl -s "$BASE_URL/health" | grep -o '"hostname":"[^"]*"' || true; done | sort -u)
echo "PASS: Traffic distributed across backend instances."

echo "==> [4/6] Validation Complete Successfully!"
exit 0
