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
