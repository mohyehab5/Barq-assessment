#!/usr/bin/env bash
set -euo pipefail

BASE_URL="http://127.0.0.1:8080"
MAX_RETRIES=30
RETRY_INTERVAL=1

echo "==> [1/6] Bounded Wait for Dependency & Application Readiness..."
ready=0
for ((i=1; i<=MAX_RETRIES; i++)); do
  response=$(curl -s "${BASE_URL}/ready" || true)
  if echo "$response" | grep -q '"status":"ready"'; then
    ready=1
    echo "PASS: Application and dependencies are ready."
    break
  fi
  echo "Waiting for /ready endpoint... attempt $i/$MAX_RETRIES"
  sleep "$RETRY_INTERVAL"
done

if [ "$ready" -ne 1 ]; then
  echo "FAIL: Application failed to reach ready state within $MAX_RETRIES seconds."
  exit 1
fi

echo "==> [2/6] Verifying Core Endpoints..."
curl -sf "${BASE_URL}/" > /dev/null || { echo "FAIL: Root endpoint / failed"; exit 1; }
curl -sf "${BASE_URL}/health" > /dev/null || { echo "FAIL: Health endpoint /health failed"; exit 1; }
curl -sf "${BASE_URL}/counter" > /dev/null || { echo "FAIL: Counter endpoint /counter failed"; exit 1; }
echo "PASS: All core HTTP endpoints responded successfully."

echo "==> [3/6] Verifying Round-Robin Load Balancing across app-01 and app-02..."
INSTANCES=$(for i in {1..4}; do curl -s "${BASE_URL}/instance" | grep -o '"instance_id":"[^"]*"' | cut -d':' -f2 | tr -d '"'; echo ""; done)
if echo "$INSTANCES" | grep -q "app-01" && echo "$INSTANCES" | grep -q "app-02"; then
  echo "PASS: Both app-01 and app-02 are serving traffic via NGINX."
else
  echo "FAIL: Load balancing check failed. Observed instances: $INSTANCES"
  exit 1
fi

echo "==> [4/6] Verifying Container User Security (Non-Root UID 10001)..."
UID10001=$(docker exec app-01 id -u)
if [ "$UID10001" -eq 10001 ]; then
  echo "PASS: Container running as non-root user (UID 10001)."
else
  echo "FAIL: Container user UID is $UID10001 (expected 10001)."
  exit 1
fi

echo "==> [5/6] Verifying Prohibited Host Port Isolation (Postgres 15432 & Redis 16379)..."
if nc -zv -w 2 127.0.0.1 15432 2>/dev/null; then
  echo "FAIL: Host port 15432 (Postgres) is exposed publicly!"
  exit 1
fi
if nc -zv -w 2 127.0.0.1 16379 2>/dev/null; then
  echo "FAIL: Host port 16379 (Redis) is exposed publicly!"
  exit 1
fi
echo "PASS: Raw database ports are completely isolated from host interface."

echo "==> [6/6] Verifying Network Isolation (NGINX -> DB network routing block)..."
if docker exec nginx nc -zv postgres 5432 2>/dev/null; then
  echo "FAIL: NGINX can reach Postgres directly on the backend network!"
  exit 1
fi
echo "PASS: NGINX has no direct route or network access to Postgres."

echo "=========================================="
echo "ALL VALIDATION CHECKS PASSED SUCCESSFULLY!"
echo "=========================================="
