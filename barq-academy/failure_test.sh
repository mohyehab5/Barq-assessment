#!/usr/bin/env bash
set -e

BASE_URL="http://localhost:8080"

echo "==> [1/4] Stopping app-01..."
docker compose stop app-01

echo "==> [2/4] Testing failover..."

SUCCESS_COUNT=0
TOTAL_SENT=10

for i in $(seq 1 "$TOTAL_SENT"); do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health" || true)

    if [ "$CODE" = "200" ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi

    sleep 0.1
done

ERROR_COUNT=$((TOTAL_SENT - SUCCESS_COUNT))

echo "Total: $TOTAL_SENT"
echo "Success: $SUCCESS_COUNT"
echo "Errors: $ERROR_COUNT"

if [ "$SUCCESS_COUNT" -ne "$TOTAL_SENT" ]; then
    echo "FAIL: Failover failed."
    docker compose ps
    exit 1
fi

echo "PASS: app-02 successfully handled traffic."

echo "==> [3/4] Restarting app-01..."

docker compose start app-01

echo "Waiting for app-01 recovery..."

for attempt in $(seq 1 5); do

    APP1_ID=$(docker compose ps -q app-01)

    STATUS=$(docker inspect \
        --format='{{.State.Status}}' \
        "$APP1_ID" 2>/dev/null || true)

    HEALTH=$(docker compose exec -T nginx \
        curl -s -o /dev/null -w "%{http_code}" \
        http://app-01:8080/health 2>/dev/null || true)

    echo "Attempt $attempt/5"
    echo "  app-01 status: $STATUS"
    echo "  app-01 health: $HEALTH"

    if [ "$STATUS" = "running" ] && [ "$HEALTH" = "200" ]; then
        echo "PASS: app-01 recovered successfully."
        break
    fi

    if [ "$attempt" -eq 5 ]; then
        echo "FAIL: app-01 did not recover."

        echo "===== Docker status ====="
        docker compose ps

        echo "===== app-01 logs ====="
        docker compose logs app-01 --tail=30

        exit 1
    fi

    sleep 1
done

echo "==> [4/4] Verifying traffic through Nginx..."

FINAL_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    "$BASE_URL/health" || true)

echo "Nginx HTTP status: $FINAL_CODE"

if [ "$FINAL_CODE" = "200" ]; then
    echo "PASS: Nginx traffic is healthy."
    echo "======================================"
    echo "FAILOVER & RECOVERY TEST PASSED"
    echo "======================================"
    exit 0
fi

echo "FAIL: Nginx is not responding correctly."
docker compose ps
docker compose logs nginx --tail=30
exit 1
