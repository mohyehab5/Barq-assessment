#!/usr/bin/env bash
set -eo pipefail

BASE_URL="http://localhost:8080"

echo "=========================================="
echo "      FAILOVER & HA RECOVERY TEST"
echo "=========================================="

# ============================================================
# [1/4] Stop app-01
# ============================================================

echo
echo "==> [1/4] Stopping primary container app-01 to simulate backend failure..."

docker compose stop app-01

echo "app-01 stopped successfully."

# ============================================================
# [2/4] Test traffic continuity
# ============================================================

echo
echo "==> [2/4] Measuring traffic continuity and error rates during failure..."

SUCCESS_COUNT=0
TOTAL_SENT=20

for i in $(seq 1 "$TOTAL_SENT"); do

    CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        "$BASE_URL/health" || true)

    if [ "$CODE" -eq 200 ]; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    fi

    sleep 0.1
done

ERROR_COUNT=$((TOTAL_SENT - SUCCESS_COUNT))

echo
echo "Traffic Metrics during app-01 outage:"
echo "  - Total Sent: $TOTAL_SENT"
echo "  - Successful (HTTP 200): $SUCCESS_COUNT"
echo "  - Errors: $ERROR_COUNT"

# ============================================================
# [3/4] Verify failover
# ============================================================

echo
echo "==> [3/4] Verifying app-02 is handling traffic..."

if [ "$SUCCESS_COUNT" -eq "$TOTAL_SENT" ]; then

    echo "PASS: Failover successful."
    echo "PASS: Traffic remained available while app-01 was down."

else

    echo "FAIL: Unhandled errors during failover."

    echo
    echo "Docker Compose status:"
    docker compose ps

    echo
    echo "Nginx logs:"
    docker compose logs nginx --tail=50

    exit 1
fi

# ============================================================
# [4/4] Restart app-01 and verify recovery
# ============================================================

echo
echo "==> [4/4] Restarting app-01 and verifying full recovery..."

docker compose start app-01

RECOVERED=false
MAX_RETRIES=10

echo
echo "Waiting for app-01 to become healthy..."

for attempt in $(seq 1 "$MAX_RETRIES"); do

    echo
    echo "Attempt $attempt/$MAX_RETRIES"

    # --------------------------------------------------------
    # Check that app-01 container is running
    # --------------------------------------------------------

    APP1_CONTAINER=$(docker compose ps -q app-01)

    APP1_STATUS=$(docker inspect \
        --format='{{.State.Status}}' \
        "$APP1_CONTAINER" 2>/dev/null || true)

    echo "app-01 container status: $APP1_STATUS"

    # --------------------------------------------------------
    # Check app-01 directly from inside Nginx network
    # --------------------------------------------------------

    APP1_HTTP_CODE=$(docker compose exec -T nginx \
        curl -s -o /dev/null -w "%{http_code}" \
        http://app-01:8080/health || true)

    echo "app-01 direct health check: HTTP $APP1_HTTP_CODE"

    # --------------------------------------------------------
    # Recovery condition
    # --------------------------------------------------------

    if [ "$APP1_STATUS" = "running" ] && \
       [ "$APP1_HTTP_CODE" -eq 200 ]; then

        RECOVERED=true

        echo
        echo "PASS: app-01 is running and healthy."

        break
    fi

    echo "Waiting for app-01 recovery..."

    sleep 2

done

# ============================================================
# Recovery failed
# ============================================================

if [ "$RECOVERED" != true ]; then

    echo
    echo "FAIL: app-01 failed to become healthy."

    echo
    echo "Docker Compose status:"
    docker compose ps

    echo
    echo "app-01 logs:"
    docker compose logs app-01 --tail=50

    echo
    echo "Nginx logs:"
    docker compose logs nginx --tail=50

    exit 1
fi

# ============================================================
# Reload Nginx
# ============================================================

echo
echo "==> Reloading Nginx..."

docker compose exec -T nginx nginx -t

docker compose exec -T nginx nginx -s reload

echo "Nginx reload successful."

sleep 2

# ============================================================
# Verify Nginx can reach app-01
# ============================================================

echo
echo "==> Verifying Nginx can reach recovered app-01..."

NGINX_TO_APP1=$(docker compose exec -T nginx \
    curl -s -o /dev/null -w "%{http_code}" \
    http://app-01:8080/health || true)

echo "Nginx -> app-01 HTTP status: $NGINX_TO_APP1"

if [ "$NGINX_TO_APP1" -eq 200 ]; then

    echo
    echo "=========================================="
    echo "PASS: app-01 successfully recovered."
    echo "PASS: app-01 is healthy."
    echo "PASS: Nginx can reach app-01."
    echo "PASS: HA failover and recovery test passed."
    echo "=========================================="

    exit 0

else

    echo
    echo "=========================================="
    echo "FAIL: Nginx cannot reach recovered app-01."
    echo "=========================================="

    echo
    echo "Docker Compose status:"
    docker compose ps

    echo
    echo "Nginx logs:"
    docker compose logs nginx --tail=50

    exit 1
fi
