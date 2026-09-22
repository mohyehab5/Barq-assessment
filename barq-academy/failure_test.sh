echo "==> [4/4] Restarting app-01 and verifying full recovery..."

docker compose start app-01

echo "Waiting for app-01 to become healthy..."

RECOVERED=false
MAX_RETRIES=10

for attempt in $(seq 1 $MAX_RETRIES); do

  # Check container state
  APP1_CONTAINER=$(docker compose ps -q app-01)

  APP1_STATUS=$(docker inspect \
    --format='{{.State.Status}}' \
    "$APP1_CONTAINER" 2>/dev/null || true)

  echo "Attempt $attempt/$MAX_RETRIES"
  echo "app-01 container status: $APP1_STATUS"

  # Check app-01 directly from inside nginx network
  APP1_HTTP_CODE=$(docker compose exec -T nginx \
    curl -s -o /dev/null -w "%{http_code}" \
    http://app-01:8080/health || true)

  echo "app-01 direct health check: HTTP $APP1_HTTP_CODE"

  if [ "$APP1_STATUS" = "running" ] && [ "$APP1_HTTP_CODE" -eq 200 ]; then
    RECOVERED=true
    echo "PASS: app-01 is running and healthy."
    break
  fi

  sleep 2
done

if [ "$RECOVERED" != true ]; then
  echo "FAIL: app-01 failed to become healthy."
  docker compose ps
  docker compose logs app-01 --tail=50
  exit 1
fi

echo "Reloading Nginx..."
docker compose exec -T nginx nginx -s reload

sleep 2

echo "Verifying Nginx can reach recovered app-01..."

NGINX_TO_APP1=$(docker compose exec -T nginx \
  curl -s -o /dev/null -w "%{http_code}" \
  http://app-01:8080/health || true)

if [ "$NGINX_TO_APP1" -eq 200 ]; then
  echo "PASS: app-01 successfully recovered and is reachable from Nginx."
  exit 0
else
  echo "FAIL: Nginx cannot reach recovered app-01."
  docker compose logs nginx --tail=50
  exit 1
fi
