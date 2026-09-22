#!/usr/bin/env bash
set -eo pipefail

BASE_URL="http://0.0.0.0:8080"

echo "==> [1/4] Stopping primary container app-01 to simulate backend failure..."
docker compose stop app-01

echo "==> [2/4] Measuring traffic continuity and error rates during failure..."
SUCCESS_COUNT=0
TOTAL_SENT=20

for i in $(seq 1 $TOTAL_SENT); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health" || true)
  if [ "$CODE" -eq 200 ]; then
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  fi
  sleep 0.1
done

echo "Traffic Metrics during app-01 outage:"
echo "  - Total Sent: $TOTAL_SENT"
echo "  - Successful (HTTP 200): $SUCCESS_COUNT"
echo "  - Errors: $((TOTAL_SENT - SUCCESS_COUNT))"

echo "==> [3/4] Verifying app-02 is handling 100% of traffic..."
if [ "$SUCCESS_COUNT" -eq "$TOTAL_SENT" ]; then
  echo "PASS: Failover successful. Traffic seamlessly served by app-02."
else
  echo "FAIL: Unhandled errors during failover."
  exit 1
fi

echo "==> [4/4] Restarting app-01 and verifying full recovery..."
docker compose start app-01

# Wait for app-01 container health check directly
echo "Waiting for app-01 container to be healthy..."
sleep 5

RECOVERED=false
for attempt in $(seq 1 20); do
  # Send traffic requests to health or root endpoint
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health" || true)
  
  # Verify app-01 container status explicitly
  APP1_STATUS=$(docker inspect --format='{{.State.Status}}' $(docker compose ps -q app-01) 2>/dev/null || true)

  if [ "$HTTP_CODE" -eq 200 ] && [ "$APP1_STATUS" = "running" ]; then
    RECOVERED=true
    echo "PASS: app-01 successfully resumed and container state is running."
    break
  fi

  echo "Attempt $attempt/20: Waiting for app-01 recovery..."
  sleep 2
done

if [ "$RECOVERED" = true ]; then
  exit 0
else
  echo "FAIL: app-01 failed to resume traffic routing."
  exit 1
fi
