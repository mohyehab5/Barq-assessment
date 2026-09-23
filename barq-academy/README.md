# BARQ Infrastructure & Application System

Comprehensive containerized infrastructure and application stack for the `barq-api` Python application, including Docker orchestration, Nginx reverse proxy, load balancing, PostgreSQL persistence, Redis caching, automated validation, fault-tolerance testing, backup/restore procedures, and a security-focused CI/CD pipeline.

---

## Table of Contents

* [Architecture](#architecture)
* [Services](#services)
* [Network Architecture](#network-architecture)
* [Quick Start](#quick-start)
* [Validation & Testing](#validation--testing)
* [Backup & Restore](#backup--restore)
* [System Architecture Decisions](#system-architecture-decisions)
* [CI/CD Pipeline](#cicd-pipeline)
* [Security Gates](#security-gates)
* [Troubleshooting & Resolved Issues](#troubleshooting--resolved-issues)
* [Production Improvements](#production-improvements)
* [Execution Evidence](#execution-evidence)
* [Project Status](#project-status)
* [Repository Structure](#repository-structure)
* [Summary](#summary)

---

## Architecture

The system consists of two application instances behind an Nginx reverse proxy, with PostgreSQL used for persistent data and Redis used as a cache.

```text
                 Client
                    |
                    | HTTP :8080
                    v
           +----------------+
           | Nginx Proxy    |
           | Load Balancer  |
           +-------+--------+
                   |
          +--------+--------+
          |                 |
          v                 v
    +-----------+     +-----------+
    |  app-01   |     |  app-02   |
    |  :8080    |     |  :8080    |
    +-----+-----+     +-----+-----+
          |                 |
          +--------+--------+
                   |
          +--------+--------+
          |                 |
          v                 v
    +-----------+     +-----------+
    | PostgreSQL|     |   Redis   |
    |   :5432   |     |   :6379   |
    +-----------+     +-----------+
```

### Architecture Quick Reference

| Component  | Purpose                         | Port |
| ---------- | ------------------------------- | ---: |
| Nginx      | Reverse proxy and load balancer | 8080 |
| app-01     | Application instance            | 8080 |
| app-02     | Application instance            | 8080 |
| PostgreSQL | Persistent database             | 5432 |
| Redis      | Application cache               | 6379 |

Only Nginx exposes a port to the host.

PostgreSQL and Redis remain isolated from direct host access.

---

## Services

### Nginx

Nginx acts as the public-facing reverse proxy and load balancer.

Responsibilities:

* Accept client requests on port `8080`.
* Forward requests to `app-01` and `app-02`.
* Perform upstream failover.
* Apply connection and proxy timeouts.
* Balance traffic between application instances.

### Application Layer

The application runs in two independent containers:

```text
app-01
app-02
```

Both expose port `8080` internally.

The containers run under a non-root application user:

```text
uid=10001(app)
gid=10001(app)
```

### PostgreSQL

PostgreSQL provides persistent application storage.

Internal port:

```text
5432
```

The database port is not mapped to the host.

### Redis

Redis provides application caching.

Internal port:

```text
6379
```

The Redis port is not mapped to the host.

---

## Network Architecture

The application uses two Docker networks.

### lab-frontend

Connects:

```text
Nginx
   |
   +-- app-01
   |
   +-- app-02
```

### lab-backend

Connects:

```text
app-01
app-02
   |
   +-- PostgreSQL
   |
   +-- Redis
```

This separation prevents PostgreSQL and Redis from being directly exposed to the host.

### Request Flow

```text
Client
  |
  v
127.0.0.1:8080
  |
  v
Nginx
  |
  +----> app-01:8080
  |
  +----> app-02:8080
             |
             +----> PostgreSQL:5432
             |
             +----> Redis:6379
```

---

## Quick Start

### 1. Configure Environment

Create the environment file from the provided example:

```bash
cp .env.example .env
```

Update the required values inside `.env`.

Do not commit real credentials, passwords, API keys, or other secrets to the repository.

### 2. Build and Start the Stack

```bash
docker compose up -d --build
```

### 3. Check Container Status

```bash
docker compose ps
```

Expected services:

```text
app-01
app-02
nginx
postgres
redis
```

### Stop & Cleanup

#### Stop Containers

```bash
docker compose stop
```

#### Remove Containers and Networks

```bash
docker compose down
```

#### Full Cleanup Including Database Volume

```bash
docker compose down -v
```

---

## Validation & Testing

### Automated System Validation

Run:

```bash
chmod +x validate.sh
./validate.sh
```

The validation process checks:

* Application availability.
* HTTP endpoint status.
* Health endpoints.
* Readiness endpoints.
* Load balancing.
* Network exposure.
* Persistence behavior.

The validation script should return a non-zero exit code when a required check fails.

### Application Endpoints

#### Root Endpoint

```bash
curl http://127.0.0.1:8080
```

Example response:

```json
{
  "instance_id": "app-01",
  "message": "Welcome to BARQ Systems",
  "service": "barq-api",
  "version": "2.0.0"
}
```

A subsequent request can be served by the second application instance:

```json
{
  "instance_id": "app-02",
  "message": "Welcome to BARQ Systems",
  "service": "barq-api",
  "version": "2.0.0"
}
```

This demonstrates load balancing between the application replicas.

### Health Endpoint

```bash
curl http://127.0.0.1:8080/health
```

Example:

```json
{
  "instance_id": "app-02",
  "service": "barq-api",
  "status": "alive",
  "version": "2.0.0"
}
```

### Readiness Endpoint

```bash
curl http://127.0.0.1:8080/ready
```

The readiness endpoint verifies application dependencies such as PostgreSQL and Redis.

Example:

```json
{
  "dependencies": {
    "postgres": "unavailable",
    "redis": "ready"
  },
  "instance_id": "app-01",
  "service": "barq-api",
  "status": "not_ready",
  "version": "2.0.0"
}
```

### Instance Endpoint

```bash
curl http://127.0.0.1:8080/instance
```

Repeated requests demonstrate traffic distribution:

```text
app-02
app-01
app-02
app-01
```

### Security & User Context Verification

Application containers run as a non-root user.

Verify with:

```bash
docker exec app-01 id
```

Expected:

```text
uid=10001(app) gid=10001(app) groups=10001(app)
```

This reduces the impact of a potential container-level compromise compared with running the application as root.

### Fault Tolerance Testing

Run the fault-tolerance test:

```bash
chmod +x failure_test.sh
./failure_test.sh
```

The objective is to verify application behavior when one of the application instances becomes unavailable.

Nginx is configured to use upstream failover so that traffic can continue to another available application instance.

---

## Backup & Restore

### Create Database Backup

```bash
chmod +x backup.sh restore.sh
./backup.sh
```

### Restore Database

```bash
./restore.sh ./backups/latest.sql
```

---

## System Architecture Decisions

### Q1. What failed first?

The `/records` endpoint initially returned:

```text
HTTP 500
```

with:

```json
{
  "error": "postgres_unavailable"
}
```

### Root Cause

Application logs showed errors such as:

```text
psycopg2.OperationalError:
could not translate host name "postgres" to address:
Name or service not known
```

The issue occurred because `app-01` was attached to `lab-backend` while PostgreSQL was isolated on another network.

### Resolution

Placing the application and PostgreSQL containers on the same internal Docker network allowed Docker DNS resolution to work correctly.

### Q2. How was Load Balancing Verified?

Nginx access logs showed alternating upstream addresses:

```text
172.20.0.3:8080
172.20.0.4:8080
```

This demonstrated round-robin traffic distribution between the application instances.

Repeated requests to:

```bash
curl http://127.0.0.1:8080/instance
```

also returned:

```text
app-01
app-02
app-01
app-02
```

To avoid double-counting requests during analysis, Nginx edge access logs can be filtered using unique request IDs or upstream IP addresses.

### Q3. Why These Ports and Networks?

The complete request flow is:

```text
Client
  |
  v
Nginx :8080
  |
  v
Application :8080
  |
  +----> PostgreSQL :5432
  |
  +----> Redis :6379
```

### Network Boundaries

`lab-frontend`:

```text
Nginx <-> Applications
```

`lab-backend`:

```text
Applications <-> PostgreSQL
Applications <-> Redis
```

### Port Security

Only:

```text
8080
```

is exposed to the host.

The following remain internal:

```text
5432
6379
```

### Readiness

PostgreSQL readiness can be checked using:

```bash
pg_isready -U barq_app
```

This verifies that PostgreSQL is accepting connections before application connection pools are initialized.

### Q4. Why These Timeouts, Retries and Restart Settings?

#### Restart Policy

```yaml
restart: unless-stopped
```

This allows containers to automatically recover from transient failures without requiring manual intervention.

#### Nginx Connection Timeout

```nginx
proxy_connect_timeout 3s;
```

This prevents Nginx workers from waiting indefinitely when an upstream application becomes unavailable.

#### Upstream Failover

Nginx uses upstream retry behavior for errors and timeouts, allowing traffic to move to another available application instance.

For example:

```text
app-01 unavailable
       |
       v
Nginx
       |
       v
app-02
```

### Q5. When Should Validation Fail?

Validation should fail when required system behavior is broken.

Examples include:

* Endpoint returns a status other than HTTP 200.
* Load balancing is not working.
* PostgreSQL port `5432` is unexpectedly exposed to the host.
* Redis port `6379` is unexpectedly exposed to the host.
* Persistence checks fail.
* Required health/readiness checks fail.

### What Does Green CI Prove?

A successful CI pipeline demonstrates that the tested:

* Code
* Configuration
* Container orchestration
* Health checks
* API endpoints
* Security checks

passed within the CI test environment.

### What Green CI Does Not Prove

A successful pipeline does not prove:

* Real-world performance under massive concurrent traffic.
* DDoS resistance.
* Cloud network latency behavior.
* Long-term disk fragmentation behavior.
* Absence of zero-day vulnerabilities in container base images.

### Q6. Remaining Single Points of Failure

The current architecture contains remaining single points of failure.

#### Nginx

There is a single Nginx reverse proxy instance.

#### PostgreSQL

There is a single PostgreSQL primary container without database replication or failover.

---

## Production Improvements

### Possible Production Architecture

```text
           Cloud Load Balancer
                    |
          +--------+--------+
          |                 |
       Nginx-01          Nginx-02
          |                 |
          +--------+--------+
                   |
             Application Layer
               /           \
           app-01         app-02
                   |
               Database HA
```

For example:

* AWS Application Load Balancer across multiple Availability Zones.
* AWS RDS Multi-AZ for PostgreSQL.
* Patroni-managed PostgreSQL HA cluster.

---

## CI/CD Pipeline

The repository includes a security-focused CI/CD architecture.

```text
Developer Commit
       |
       v
+-------------------------+
| 1. Source & Linting    |
| Git Checkout            |
| Environment Setup       |
| Code Linting            |
+------------+------------+
             |
             v
+-------------------------+
| 2. SAST & SCA           |
| SonarQube / Bandit      |
| Semgrep / Trivy FS     |
+------------+------------+
             |
             v
+-------------------------+
| 3. Secrets Detection    |
| Gitleaks / TruffleHog  |
+------------+------------+
             |
             v
+-------------------------+
| 4. Container Build      |
| Docker Compose          |
| Trivy Image Scan        |
+------------+------------+
             |
             v
+-------------------------+
| 5. Security Report      |
| DefectDojo              |
+------------+------------+
             |
             v
+-------------------------+
| 6. Deployment            |
| Target Environment      |
| / Kubernetes Cluster   |
+-------------------------+
```

### CI/CD Pipeline Stages

### Stage 1 — Source Control & Environment Setup

#### Trigger

The pipeline runs on code pushes or Pull Requests to monitored branches such as:

```text
main
dev
```

#### Actions

* Checkout repository source code.
* Configure the required runtime environment.
* Cache dependencies where applicable.
* Prepare the CI environment.

### Stage 2 — SAST & SCA

#### Objective

Identify application security issues and vulnerable dependencies before deployment.

#### SAST Tools

Possible tools include:

* SonarQube
* Bandit
* Semgrep

#### SCA / Dependency Scanning

Possible tools include:

* Safety
* OWASP Dependency-Check
* Trivy FS

#### Failure Criteria

The pipeline can be configured to stop when HIGH or CRITICAL vulnerabilities are detected.

### Stage 3 — Secrets Detection

#### Objective

Prevent credentials and sensitive information from being committed to source control.

Tools:

* Gitleaks
* TruffleHog

The scanner checks the current working tree and, where configured, commit history for:

* API tokens
* Passwords
* Private keys
* Credentials
* Other sensitive secrets

### Stage 4 — Container Build & Trivy Security Scan

#### Objective

Build the application containers and identify vulnerabilities in container layers and operating-system packages.

Build the stack:

```bash
docker compose up -d --build
```

Instead of relying on a hardcoded image tag, the running container's exact image ID can be retrieved dynamically:

```bash
APP_IMAGE_ID=$(docker inspect -f '{{.Image}}' app-01)
```

Then scan the exact image:

```bash
trivy image --severity HIGH,CRITICAL "$APP_IMAGE_ID"
```

This ensures that the vulnerability scan targets the image actually running in the environment.

### Stage 5 — Vulnerability Management

#### Objective

Centralize security findings generated by the different pipeline scanners.

#### Platform

DefectDojo

#### Process

Security reports from:

* SAST
* SCA
* Container scanning

can be exported in formats such as:

```text
JSON
SARIF
```

and imported into DefectDojo through its API.

DefectDojo can then be used for:

* Finding centralization.
* Deduplication.
* Vulnerability tracking.
* Security reporting.

### Stage 6 — Deployment

The final stage deploys validated application artifacts to the target environment.

Possible target:

```text
Kubernetes Cluster
```

The deployment stage should only proceed after the required validation and security gates have passed.

---

## Security Gates

The CI/CD pipeline can apply security gates before deployment.

### Source Code Security

Potential checks include:

* SAST
* Code quality
* Static security analysis

### Dependency Security

Potential checks include:

* SCA
* Dependency vulnerability scanning
* Trivy filesystem scanning

### Secrets Security

Potential checks include:

* Gitleaks
* TruffleHog
* Credential detection

### Container Security

Potential checks include:

* Trivy image scanning
* HIGH vulnerability detection
* CRITICAL vulnerability detection

### Deployment Gate

Deployment should only proceed after the required validation and security checks pass.

---

## Troubleshooting & Resolved Issues

### 1. GitHub Actions Could Not Find the Workflow Issue

After creating the workflow file, it did not appear in the GitHub Actions tab.

GitHub displayed the default:

```text
Get started with GitHub Actions
```

page, indicating that no workflow configuration was detected.

#### Cause

The required directory structure was missing or the workflow file was misplaced.

GitHub Actions expects workflow files under:

```text
.github/workflows/
```

at the repository root.

#### Resolution

Create the directory:

```bash
mkdir -p .github/workflows
```

Move the workflow:

```bash
mv ci.yml .github/workflows/ci.yml
```

Commit and push:

```bash
git add .github/workflows/ci.yml
git commit -m "docs: add GitHub Actions workflow in standard .github directory"
git push origin main
```

**Status:** Resolved

---

### 2. Workflow Located Inside Application Directory Issue

The workflow was committed but still did not trigger.

The repository structure contained:

```text
barq-academy/.github/workflows/ci.yml
```

#### Cause

The `.github` directory was located inside the application directory instead of the repository root.

The expected structure is:

```text
repository-root/
├── .github/
│   └── workflows/
│       └── ci.yml
└── barq-academy/
```

#### Resolution

Move `.github` to the repository root:

```bash
mv barq-academy/.github .github
```

Then:

```bash
git add .
git commit -m "fix: move .github folder to repository root for proper Actions detection"
git push origin main
```

**Status:** Resolved

---

### 3. CI Environment Setup Failure Issue

The pipeline failed during environment setup.

Commands such as:

```bash
docker compose down
```

returned errors similar to:

```text
no configuration file provided: not found
```

#### Causes

Two issues were identified:

1. The workflow was executing from the repository root while the application files were located in:

```text
barq-academy/
```

2. The `.env` file was not available inside the CI environment.

#### Resolution

The workflow was configured to use:

```yaml
defaults:
  run:
    working-directory: barq-academy
```

The CI environment also creates the required `.env` file dynamically before starting the services.

Example:

```yaml
- name: Environment Setup
  run: |
    cat << 'EOF' > .env
    POSTGRES_USER=...
    # ... remaining environment variables ...
    EOF
```

**Status:** Resolved

---

### 4. Python Validation Script Failure Issue

The automated validation step initially executed:

```bash
python3 validate.py
```

and failed with:

```text
exit code 2
```

The script contained a placeholder message:

```text
NOT IMPLEMENTED: write bounded checks with PASS/FAIL and non-zero failure exits.
```

#### Cause

`validate.py` was only a placeholder and did not contain actual validation logic or proper failure exit codes.

#### Resolution

The placeholder was replaced with a validation implementation using:

* `requests`
* `sys.exit()`

The validation suite checked connectivity, health endpoints, and load balancing.

**Status:** Resolved

---

### 5. Validation Migrated from Python to Bash Issue

The Python validation approach required additional dependencies such as:

```text
requests
psycopg2-binary
redis
```

This introduced unnecessary dependency overhead for basic network and endpoint validation.

#### Resolution

Validation was migrated from:

```text
validate.py
```

to:

```text
validate.sh
```

The workflow now executes:

```yaml
- name: Run Automated Stack Validation
  run: |
    chmod +x validate.sh
    ./validate.sh
```

Python setup and dependency installation steps were removed from the validation workflow.

**Status:** Resolved

---

### 6. Network Binding Error: localhost vs `0.0.0.0` Issue

The Bash validation script failed with:

```text
FAIL: Root endpoint unreachable
HTTP 000
```

while testing:

```text
localhost:8080
```

At the same time, Docker logs showed that the application services were running successfully.

#### Cause

The validation target did not match the network interface used by the CI/Docker environment.

#### Resolution

The validation script was updated to use:

```bash
BASE_URL="http://0.0.0.0:8080"
```

instead of targeting:

```text
localhost:8080
```

This allowed the validation process to reach the exposed Nginx service correctly.

**Status:** Resolved

---

## Production Improvements

The current architecture can be extended for production environments.

### High Availability

Replace the single Nginx instance with:

```text
AWS ALB
```

or another highly available load-balancing solution.

Deploy infrastructure across multiple Availability Zones.

### Database High Availability

Replace the single PostgreSQL container with:

```text
AWS RDS Multi-AZ
```

or:

```text
Patroni PostgreSQL HA
```

### TLS

Implement SSL/TLS termination at the reverse proxy or load balancer.

### Secrets Management

Replace environment-file based secrets with a dedicated secrets manager such as:

* HashiCorp Vault
* AWS Secrets Manager

### Monitoring

Add:

* Prometheus
* Grafana

for infrastructure and application monitoring.

---

## AI-Assisted Development Verification

AI-assisted scripts and configuration changes were verified through actual execution rather than being accepted without testing.

Verification included:

* `docker compose up`
* Docker container status checks.
* Raw curl endpoint tests.
* Network connectivity tests.
* Application log inspection.
* Security-oriented configuration review.
* Cross-checking against security best practices.

---

## Execution Evidence

The following evidence demonstrates the running stack:

```bash
docker compose ps
```

Expected services include:

```text
app-01       Up (healthy)
app-02       Up (healthy)
nginx        Up
postgres     Up (healthy)
redis        Up (healthy)
```

Nginx exposes:

```text
0.0.0.0:8080 -> 80/tcp
```

while PostgreSQL and Redis remain internal.

The application containers run as:

```text
uid=10001(app)
gid=10001(app)
```

Repeated requests to the application demonstrate traffic distribution between:

```text
app-01
app-02
```

The execution evidence and endpoint testing confirm the container orchestration, Nginx reverse proxy, application replicas, internal PostgreSQL/Redis services, and load-balancing behavior.

---

## Project Status

| Area                    | Status                     |
| ----------------------- | -------------------------- |
| Docker Compose Stack    | ✅ Working                  |
| Nginx Reverse Proxy     | ✅ Working                  |
| Application Replicas    | ✅ Working                  |
| Load Balancing          | ✅ Verified                 |
| PostgreSQL              | ✅ Configured               |
| Redis                   | ✅ Configured               |
| Health Checks           | ✅ Implemented              |
| Readiness Checks        | ✅ Implemented              |
| Automated Validation    | ✅ Implemented              |
| Fault-Tolerance Testing | ✅ Implemented              |
| Backup / Restore        | ✅ Implemented              |
| GitHub Actions          | ✅ Configured               |
| SAST / SCA              | ✅ Pipeline Design          |
| Secrets Detection       | ✅ Pipeline Design          |
| Trivy Container Scan    | ✅ Pipeline Design          |
| DefectDojo Integration  | ✅ Pipeline Design          |
| Kubernetes Deployment   | 🔄 Target Deployment Stage |
| Production HA           | 🔄 Future Improvement      |
| TLS                     | 🔄 Future Improvement      |
| Prometheus / Grafana    | 🔄 Future Improvement      |

---

## Repository Structure

A recommended repository structure is:

```text
repository-root/
│
├── .github/
│   └── workflows/
│       └── ci.yml
│
├── barq-academy/
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── .env.example
│   ├── validate.sh
│   ├── failure_test.sh
│   ├── backup.sh
│   ├── restore.sh
│   └── ...
│
└── README.md
```

---

## Summary

This project demonstrates a containerized application environment with:

* Docker Compose orchestration.
* Nginx reverse proxy.
* Application replicas.
* Round-robin load balancing.
* PostgreSQL persistence.
* Redis caching.
* Internal network segmentation.
* Health and readiness checks.
* Fault-tolerance testing.
* Database backup and restore.
* Automated Bash-based validation.
* GitHub Actions CI/CD.
* SAST and SCA security scanning.
* Secrets detection.
* Trivy container vulnerability scanning.
* DefectDojo vulnerability management.
* Deployment preparation for Kubernetes.

The architecture was iteratively tested and corrected through actual Docker execution, endpoint testing, log analysis, and CI troubleshooting.
