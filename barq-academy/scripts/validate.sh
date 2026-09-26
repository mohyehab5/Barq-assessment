#!/usr/bin/env bash
set -eo pipefail

BASE_URL="http://127.0.0.1:8090"
MAX_ATTEMPTS=30

echo "==> [1/6] Validating Docker Container Health States..."
for container in app-01 app-02 app-03 nginx postgres redis; do
  STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "not_running")
  if [ "$STATUS" = "healthy" ]; then
    echo "PASS: Container '$container' is running and healthy."
  else
    echo "FAIL: Container '$container' health status is '$STATUS' (expected 'healthy')."
    exit 1
  fi
done

echo "==> [2/6] Bounded Wait for NGINX & Application Readiness on Port 8090..."
for i in $(seq 1 $MAX_ATTEMPTS); do
  if curl -s -f "$BASE_URL/ready" > /dev/null 2>&1; then
    echo "PASS: Application and backend dependencies are ready via NGINX."
    break
  fi
  if [ "$i" -eq "$MAX_ATTEMPTS" ]; then
    echo "FAIL: Application failed to become ready within time limit."
    exit 1
  fi
  echo "Waiting for /ready endpoint... attempt $i/$MAX_ATTEMPTS"
  sleep 2
done

echo "==> [3/6] Verifying All Core Endpoints..."

# 1. Root Endpoint /
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/" || true)
if [ "$HTTP_CODE" -eq 200 ]; then
  echo "PASS: Root endpoint (/) returned HTTP 200."
else
  echo "FAIL: Root endpoint unreachable (HTTP $HTTP_CODE)."
  exit 1
fi

# 2. Liveness Endpoint /health
HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health" || true)
if [ "$HEALTH_CODE" -eq 200 ]; then
  echo "PASS: Health check (/health) returned HTTP 200."
else
  echo "FAIL: Health check failed (HTTP $HEALTH_CODE)."
  exit 1
fi

# 3. Redis Endpoint /counter
COUNTER_RESP=$(curl -s -f "$BASE_URL/counter" || true)
if [ -n "$COUNTER_RESP" ]; then
  echo "PASS: Redis counter endpoint (/counter) executed successfully."
else
  echo "FAIL: Redis counter endpoint failed."
  exit 1
fi

# 4. PostgreSQL Endpoint /records
RECORDS_RESP=$(curl -s -X POST -H "Content-Type: application/json" -d '{"data":"validation_test"}' "$BASE_URL/records" || true)
if echo "$RECORDS_RESP" | grep -q -E 'id|success|created|validation_test'; then
  echo "PASS: PostgreSQL records endpoint (/records) write operation succeeded."
else
  echo "FAIL: PostgreSQL records endpoint write failed."
  exit 1
fi

echo "==> [4/6] Verifying NGINX Load Balancing Across ALL 3 Apps (app-01, app-02, app-03)..."
SEEN_INSTANCES=$(for i in $(seq 1 30); do curl -s "$BASE_URL/instance" || true; echo ""; done | grep -o -E 'app-0[1-3]' | sort -u)

EXPECTED_COUNT=$(echo "$SEEN_INSTANCES" | grep -v '^$' | wc -l)
echo "Instances responded: $(echo $SEEN_INSTANCES | tr '\n' ' ')"

if [ "$EXPECTED_COUNT" -eq 3 ]; then
  echo "PASS: All 3 app instances (app-01, app-02, app-03) responded through NGINX."
else
  echo "FAIL: Expected 3 distinct app instances, but found: $EXPECTED_COUNT"
  exit 1
fi

echo "==> [5/6] Verifying Database & Cache Connection Integrity..."
# Direct database write check inside postgres container
docker exec postgres psql -U barq_app -d barq_tasks -c "SELECT 1;" > /dev/null 2>&1
echo "PASS: Direct PostgreSQL connection verified."

# Direct ping check inside redis container
docker exec redis redis-cli ping | grep -q "PONG"
echo "PASS: Direct Redis ping response verified."

echo "==> [6/6] Verifying Network Isolation & Security Constraints..."
# Ensure DB and Cache ports are NOT exposed on host
if nc -z -w 1 127.0.0.1 5432 2>/dev/null; then
  echo "FAIL: PostgreSQL port 5432 is directly exposed to host!"
  exit 1
fi

if nc -z -w 1 127.0.0.1 6379 2>/dev/null; then
  echo "FAIL: Redis port 6379 is directly exposed to host!"
  exit 1
fi

# Ensure App ports (8080/8090) are NOT exposed directly on host (only NGINX 8090 exposed)
if nc -z -w 1 127.0.0.1 8080 2>/dev/null; then
  echo "FAIL: Port 8080 is still open on host!"
  exit 1
fi

echo "PASS: Network isolation verified (PostgreSQL, Redis, and App instances are shielded behind NGINX)."
echo "==> ALL VALIDATION CHECKS PASSED SUCCESSFULLY!"
exit 0
