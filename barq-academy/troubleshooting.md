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

CI/CD Pipeline Troubleshooting Guide
Issues Summary
Issue ID	Category	Problem Summary	Impact	Status
CI-01	Container Security / Trivy	Failed image scan: No such image: barq-api:latest	Pipeline failure due to missing target image during security testing	Resolved
Detailed Issues & Root Cause Analysis
Issue CI-01: Trivy Image Scan Failure
Problem Statement

During the automated CI security scanning phase, Trivy failed to execute the container vulnerability scan with the following error:

    FATAL: image scan error: scan error: unable to initialize a scanner: unable to inspect the image (barq-api:latest): No such image: barq-api:latest

The CI workflow attempted to scan a hardcoded image tag (barq-api:latest) that did not exist on the local CI runner host.
Root Cause Analysis

    Docker Compose Tagging Behavior: The build: block in docker-compose.yml builds the application image dynamically, but it does not guarantee or automatically tag the resulting binary with a predictable static tag (e.g., barq-api:latest).

    Dockerfile Base Image Confusion: The FROM directive in the Dockerfile specifies only the base layer (e.g., python:3.11-slim), which is separate from the final application image artifact.

    Runner Image Registry: Trivy requires a valid, existing image reference or direct Image ID present in the local Docker daemon on the CI runner to perform its static analysis.

Resolution & Step-by-Step Fixes
Fix for Issue CI-01: Dynamic Image Inspection Strategy
Resolution Strategy

Instead of relying on hardcoded image tags or predicting Docker Compose output naming conventions, the pipeline inspects the active application container at runtime to extract its exact, unique Docker Image ID, passing that ID directly to Trivy.
Implementation Steps

    Build and Spin Up the Stack:
    Bring up the service containers using Docker Compose to ensure all layers are built and present in the runner's local Docker daemon.
    Bash

    docker compose up -d --build

    Dynamically Extract the Application Image ID:
    Inspect the running container (app-01) to retrieve its exact image hash ID.
    Bash

    APP_IMAGE_ID=$(docker inspect -f '{{.Image}}' app-01)

    Execute Trivy Scan via Image ID:
    Pass the dynamically captured $APP_IMAGE_ID variable directly to the Trivy scanner.
    Bash

    trivy image --severity HIGH,CRITICAL "$APP_IMAGE_ID"

Verification & Result

    Scan Precision: Trivy scans the exact application image currently running in the CI environment.

    Pipeline Resilience: Eliminates hardcoded image name dependencies, ensuring tests remain deterministic across different environments, branches, and compose configurations.
