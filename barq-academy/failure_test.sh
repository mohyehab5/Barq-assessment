#!/usr/bin/env bash
set -euo pipefail

BASE_URL="http://127.0.0.1:8080"

echo "==> [1/4] Stopping primary container app-01 to simulate backend failure..."
docker stop app-01

echo "==> [2/4] Measuring traffic continuity and error rates during failure..."
TOTAL_REQUESTS=20
SUCCESS_COUNT=0
ERROR_COUNT=0

for i in $(seq 1 $TOTAL_REQUESTS); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/instance" || true)
  if [ "$HTTP_CODE" -eq 200 ]; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    ERROR_COUNT=$((ERROR_COUNT + 1))
  fi
  sleep 0.1
done

echo "Traffic Metrics during app-01 outage:"
echo "  - Total Sent: $TOTAL_REQUESTS"
echo "  - Successful (HTTP 200): $SUCCESS_COUNT"
echo "  - Errors: $ERROR_COUNT"

if [ "$ERROR_COUNT" -gt 0 ]; then
  echo "WARNING: $ERROR_COUNT errors recorded during outage transition."
fi

echo "==> [3/4] Verifying app-02 is handling 100% of traffic..."
ACTIVE_INSTANCE=$(curl -s "${BASE_URL}/instance" | grep -o '"instance_id":"[^"]*"' | cut -d':' -f2 | tr -d '"')
if [ "$ACTIVE_INSTANCE" == "app-02" ]; then
  echo "PASS: Failover successful. Traffic seamlessly served by app-02."
else
  echo "FAIL: Failover check failed. Received response from $ACTIVE_INSTANCE"
  docker start app-01
  exit 1
fi

echo "==> [4/4] Restarting app-01 and verifying full recovery..."
docker start app-01
sleep 3

RECOVERED_INSTANCES=$(for i in {1..6}; do curl -s "${BASE_URL}/instance" | grep -o '"instance_id":"[^"]*"' | cut -d':' -f2 | tr -d '"'; echo ""; done)
if echo "$RECOVERED_INSTANCES" | grep -q "app-01" && echo "$RECOVERED_INSTANCES" | grep -q "app-02"; then
  echo "PASS: app-01 recovered and resumed participating in round-robin balancing."
else
  echo "FAIL: app-01 failed to resume traffic routing."
  exit 1
fi

echo "=========================================="
echo "FAILURE & RECOVERY TEST PASSED SUCCESSFULLY!"
echo "=========================================="
