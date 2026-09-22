# Part 2 Execution Evidence: Docker, Networking, NGINX & Core Endpoints

This document serves as complete, end-to-end reproducible evidence for Task 2 (Part 2) requirements, captured directly from the local terminal environment (`mohyehab@mohyehab`).

---

## 1. Container Status & Process Overview

### Command & Output:
```bash
mohyehab@mohyehab:~/devops/Barq-ass/barq-academy$ docker compose ps
NAME        IMAGE                                                                                    COMMAND                  SERVICE    CREATED         STATUS                   PORTS
app-01      barq-assessment-app-01                                                                   "python -m app.server"   app-01     8 minutes ago   Up 8 minutes (healthy)   8080/tcp
app-02      barq-assessment-app-02                                                                   "python -m app.server"   app-02     8 minutes ago   Up 8 minutes (healthy)   8080/tcp
nginx       nginx:1.28-alpine@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236    "/docker-entrypoint.…"   nginx      8 minutes ago   Up 8 minutes             0.0.0.0:8080->80/tcp, [::]:8080->80/tcp
postgres    postgres:16-alpine@sha256:cf78e76683b9ca8c5733cbbdce6c9262b45b6767934dd0a95e671f9a0fc20685   "docker-entrypoint.s…"   postgres   8 minutes ago   Up 8 minutes (healthy)   5432/tcp
redis       redis:7.4-alpine@sha256:ff02b58f971e7d7d156a1267e283fcbbeee91773b6aa36c49dac28ecfe28eadf     "docker-entrypoint.s…"   redis      8 minutes ago   Up 8 minutes (healthy)   6379/tcp


Security & User Context Verification:
mohyehab@mohyehab:~/devops/Barq-ass/barq-academy$ docker exec app-01 id
uid=10001(app) gid=10001(app) groups=10001(app)


Endpoints Test Session & Load Balancing Verification:
mohyehab@mohyehab:~/devops/Barq-ass/barq-academy$ curl http://127.0.0.1:8080
{"instance_id":"app-01","message":"Welcome to BARQ Systems","service":"barq-api","version":"2.0.0"}

mohyehab@mohyehab:~/devops/Barq-ass/barq-academy$ curl -s http://127.0.0.1:8080
{"instance_id":"app-02","message":"Welcome to BARQ Systems","service":"barq-api","version":"2.0.0"}


mohyehab@mohyehab:~/devops/Barq-ass/barq-academy$ curl http://127.0.0.1:8080/health
{"instance_id":"app-02","service":"barq-api","status":"alive","version":"2.0.0"}

mohyehab@mohyehab:~/devops/Barq-ass/barq-academy$ curl http://127.0.0.1:8080/ready
{"dependencies":{"postgres":"unavailable","redis":"ready"},"instance_id":"app-01","service":"barq-api","status":"not_ready","version":"2.0.0"}

mohyehab@mohyehab:~/devops/Barq-ass/barq-academy$ curl http://127.0.0.1:8080/instance
{"instance_id":"app-02","service":"barq-api","status":"ok","version":"2.0.0"}

mohyehab@mohyehab:~/devops/Barq-ass/barq-academy$ curl http://127.0.0.1:8080/instance
{"instance_id":"app-01","service":"barq-api","status":"ok","version":"2.0.0"}

mohyehab@mohyehab:~/devops/Barq-ass/barq-academy$ curl http://127.0.0.1:8080/instance
{"instance_id":"app-02","service":"barq-api","status":"ok","version":"2.0.0"}

mohyehab@mohyehab:~/devops/Barq-ass/barq-academy$ curl http://127.0.0.1:8080/instance
{"instance_id":"app-01","service":"barq-api","status":"ok","version":"2.0.0"}

# Barq Infrastructure & Application System

Comprehensive orchestration, fault tolerance, and persistence setup for the `barq-api` Python application stack.

## Architecture Quick Reference
- **Nginx Reverse Proxy:** Listening on public port `8080`
- **Application Layer:** `app-01` and `app-02` (FastAPI / Flask)
- **Database:** PostgreSQL 15 (`postgres:5432` - isolated network)
- **Cache:** Redis (`redis:6379` - isolated network)

---

## Setup & Execution Commands

### 1. Build and Start Stack
```bash
cp .env.example .env
docker compose up -d --build


Stop and Cleanup Stack:

   # Stop containers
   docker compose stop

   # Destroy containers and isolated networks
   docker compose down

   # Full cleanup (including database volume)
   docker compose down -v




Run Automated System Validation:
   python3 validate.py

Run Failover and Fault-Tolerance Tests
  chmod +x failure_test.sh
  ./failure_test.sh

Execute Backup and Restore Procedure:
      # Create database backup
      chmod +x backup.sh restore.sh
      ./backup.sh
 
       # Restore database from backup
      ./restore.sh ./backups/latest.sql
      
Answers to System Architecture Questions:



Q1: What failed first? What proved the cause? Which failed attempt taught you something?

    What Failed First: The /records endpoint returned HTTP 500 ({"error":"postgres_unavailable"}).

    Proof of Cause: Running docker logs app-01 revealed psycopg2.OperationalError: could not translate host name "postgres" to address: Name or service not known and authentication failure messages.

    Key Insight from Failed Attempt: Attaching app-01 to lab-backend while leaving postgres on an isolated network broke host resolution. Placing both on a shared internal network (lab-backend) instantly resolved DNS lookups.

Q2: What patterns did the logs reveal? How did you avoid double-counting requests?

    Nginx access logs showed alternating UPSTREAM: 172.20.0.3:8080 and 172.20.0.4:8080 headers, confirming round-robin load balancing.

    To avoid double-counting requests in analysis, Nginx edge access logs were filtered by unique $request_id or upstream IP, separating proxy ingress logs from application logs.

Q3: How do requests flow? Why these ports, networks, and readiness checks?

    Flow: Client -> http://127.0.0.1:8080 (Nginx) -> Upstream app-01 / app-02 (Port 8080) -> PostgreSQL (Port 5432) / Redis (Port 6379).

    Network Boundaries: lab-frontend connects Nginx and App instances. lab-backend connects App instances, PostgreSQL, and Redis.

    Port Security: Only port 8080 is exposed to the host. DB (5432) and Cache (6379) ports are unmapped from the host network.

    Readiness Checks: pg_isready -U barq_app ensures PostgreSQL is accepting sockets before app containers initiate connection pools.

Q4: Why these timeouts, retries, restart settings, and resource limits?

    Restart Policy (restart: unless-stopped): Ensures transient container crashes self-heal without manual intervention.

    Proxy Timeouts (proxy_connect_timeout 3s): Prevents Nginx worker exhaustion if an app backend hangs.

    Upstream Retries (proxy_next_upstream error timeout http_502): Allows Nginx to transparently failover to app-02 if app-01 drops without returning an HTTP 500 to the client.

Q5: When should validation fail? What does green CI prove, or not prove?

    Validation Fails When: Endpoints return HTTP status != 200, load balancing fails, prohibited ports (5432, 6379) are accessible on host IP, or persistence checks fail.

    Green CI Proves: The code, configuration, health checks, multi-container orchestration, and API endpoints work synchronously in an isolated environment.

    Green CI Does NOT Prove: Real-world performance under massive concurrent load (DDOS), cloud network latency, long-term disk fragmentation, or zero zero-day vulnerabilities in container base images.

Q6: Which single points of failure remain? How would you fix them in production?

    Remaining SPOFs:

        Single Nginx reverse proxy instance.

        Single PostgreSQL primary container without replica/failover.

    Production Resolution:

        Deploy HAProxy or Cloud Load Balancer (AWS ALB) across multiple Availability Zones.

        Replace containerized single-node Postgres with AWS RDS Multi-AZ or a patroni-managed PostgreSQL HA cluster.

Q7: What would you improve? How did you verify AI-assisted work?

    Future Improvements: Implement SSL/TLS termination on Nginx, inject secrets via HashiCorp Vault or AWS Secrets Manager, and add Prometheus/Grafana monitoring.

    AI Verification: Every AI-generated script was tested via docker compose up, checked with raw socket/curl tests, and cross-referenced against security best practices.





Pipeline Architecture & Security Gates:

[ Developer Commit ]
         │
         ▼
┌─────────────────────────┐
│  1. Source & Linting    │ ──► Git Checkout, Environment Setup & Code Linting
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  2. SAST & SCA Scanning │ ──► Static Code & Dependency Security (SonarQube/Bandit/Trivy FS)
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  3. Secrets Detection   │ ──► Hardcoded Credentials & Token Scanning (Gitleaks/Trufflehog)
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  4. Container Build &   │ ──► Docker Compose Build, Dynamic Image Resolution, 
│     Trivy Vulnerability │     and Runtime Image Vulnerability Scanning
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  5. Security Report     │ ──► Vulnerability Centralization & Parsing (DefectDojo)
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  6. Deployment          │ ──► Deployment to Target Environment / Kubernetes Cluster
└─────────────────────────┘

 Detailed Workflow Stages

Stage 1: Source Control & Environment Setup

Trigger: Code push or Pull Request (PR) to monitored branches (main, dev).

Actions:

Pull source code from repository.

Setup runtime environments (Python/Node/Go) and cache dependencies.

Stage 2: Static Application Security Testing (SAST) & SCA

Objective: Identify security flaws in application source code and third-party dependencies before build.

Tools:

SAST: SonarQube / Bandit / Semgrep

SCA (Dependency Scan): Safety / OWASP Dependency-Check / Trivy FS

Fail Criteria: Pipeline halts on HIGH or CRITICAL vulnerabilities.

Stage 3: Secrets & Credentials Detection

Objective: Ensure no private keys, API tokens, or credentials are hardcoded into source code.

Tools: Gitleaks / TruffleHog

Action: Scans commit history and current working tree.

Stage 4: Container Build & Image Security (Trivy Scan)

Objective: Build application container and scan container layers/OS packages for CVEs.

Workflow:

Build container stack using Docker Compose:

docker compose up -d --build


Dynamically extract the running container's exact Image ID to eliminate hardcoded tag issues:

APP_IMAGE_ID=$(docker inspect -f '{{.Image}}' app-01)


Execute Trivy container vulnerability scan targeting the extracted Image ID:

trivy image --severity HIGH,CRITICAL "$APP_IMAGE_ID"


Stage 5: Vulnerability Management & Centralization

Objective: Centralize security findings across all pipeline scanners.

Tools: DefectDojo Integration

Action: Export SAST, SCA, and Container scan reports (JSON/SARIF) and import them into DefectDojo via API for deduplication and tracking.

Stage 6: Deployment

Objective: Deploy validated application artifacts to the target environment.
