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

echo "Waiting for app-01 to start up and rejoin Nginx routing pool..."
RECOVERED=false
MAX_RETRIES=15

# Bounded loop: retry every 2 seconds up to 30 seconds total
for attempt in $(seq 1 $MAX_RETRIES); do
  # Send 5 quick requests and check if any are routed to app-01
  RESPONSES=$(for k in $(seq 1 5); do curl -s "$BASE_URL/instance" || true; done)
  
  if echo "$RESPONSES" | grep -q "app-01"; then
    RECOVERED=true
    echo "PASS: app-01 successfully resumed traffic routing on attempt $attempt/$MAX_RETRIES."
    break
  fi
  
  echo "Attempt $attempt/$MAX_RETRIES: Waiting for Nginx to route traffic to app-01..."
  sleep 2
done

if [ "$RECOVERED" = true ]; then
  exit 0
else
  echo "FAIL: app-01 failed to resume traffic routing within the time limit."
  exit 1
fi
