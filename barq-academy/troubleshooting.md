# Troubleshooting Journal & Investigation Log

## Incident Overview
End-to-end API endpoints (`POST /records`, `GET /records`) were non-functional, returning database connection error payloads (`postgres_unavailable`).

---

## Chronological Investigation Steps

### Phase 1: Ingress & Network Inspection
1. Executed `curl http://127.0.0.1:8080/health`. Nginx returned `200 OK`, routing to `app-01`.
2. Executed `curl http://127.0.0.1:8080/records`. Endpoint returned HTTP 500 / `postgres_unavailable`.
3. Executed `docker ps` to verify container states. All 4 containers were listed as running.

### Phase 2: Log Analysis & Diagnostics
1. Inspected application logs:


bash
   docker logs app-01
psycopg2.OperationalError: could not connect to server: Connection refused

    KeyError: 'DATABASE_URL' 

    Diagnostic Script Execution (Script A from earlier):

        TCP Socket test to host postgres on port 5432 failed inside container app-01.

Phase 3: Root Cause Isolation

    Cause 1: Missing DATABASE_URL environment variable in docker-compose.yml for app services.

    Cause 2: Docker network segregation. app-01 was attached exclusively to lab-frontend, while postgres was attached exclusively to lab-backend.

Phase 4: Resolution & Verification

    Modified docker-compose.yml to attach app-01 and app-02 to both lab-frontend and lab-backend networks.

    Defined DATABASE_URL and POSTGRES_* environment variables in .env and docker-compose.yml.

    Restarted stack (docker compose down && docker compose up -d).

    Re-ran Diagnostic Script A -> SUCCESS.

    Executed validate.py -> PASS.
