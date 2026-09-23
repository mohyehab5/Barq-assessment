## Answers to System Architecture Questions

### Q1: What failed first? What proved the cause? Which failed attempt taught you something?

* **What Failed First:** The `/records` endpoint returned HTTP 500 (`{"error":"postgres_unavailable"}`).
* **Proof of Cause:** Running `docker logs app-01` revealed `psycopg2.OperationalError: could not translate host name "postgres" to address: Name or service not known` and authentication failure messages.
* **Key Insight from Failed Attempt:** Attaching `app-01` to `lab-frontend` while leaving `postgres` on an isolated network broke host resolution. Placing both on a shared internal network (`lab-backend`) instantly resolved DNS lookups.

### Q2: What patterns did the logs reveal? How did you avoid double-counting requests?

* NGINX access logs showed alternating `UPSTREAM: 172.20.0.3:8080` and `172.20.0.4:8080` headers, confirming round-robin load balancing.
* To avoid double-counting requests in analysis, NGINX edge access logs were filtered by unique `$request_id` or upstream IP, separating proxy ingress logs from application logs.

### Q3: How do requests flow? Why these ports, networks, and readiness checks?

* **Request Flow:** Client → `http://127.0.0.1:8080` (NGINX) → Upstream `app-01` / `app-02` (Port 8080) → PostgreSQL (Port 5432) / Redis (Port 6379).
* **Network Boundaries:** `lab-frontend` connects NGINX and App instances. `lab-backend` connects App instances, PostgreSQL, and Redis.
* **Port Security:** Only port `8080` is exposed to the host. DB (`5432`) and Cache (`6379`) ports are unmapped from the host network.
* **Readiness Checks:** `pg_isready -U barq_app` ensures PostgreSQL is accepting sockets before app containers initiate connection pools.

### Q4: Why these timeouts, retries, restart settings, and resource limits?

* **Restart Policy (`restart: unless-stopped`):** Ensures transient container crashes self-heal without manual intervention.
* **Proxy Timeouts (`proxy_connect_timeout 3s`):** Prevents NGINX worker exhaustion if an app backend hangs.
* **Upstream Retries (`proxy_next_upstream error timeout http_502`):** Allows NGINX to transparently fail over to `app-02` if `app-01` drops without returning an HTTP 500 to the client.

### Q5: When should validation fail? What does green CI prove, or not prove?

* **Validation Fails When:** Endpoints return HTTP status ≠ `200`, load balancing fails, prohibited ports (`5432`, `6379`) are accessible on the host IP, or persistence checks fail.
* **Green CI Proves:** The code, configuration, health checks, multi-container orchestration, and API endpoints work synchronously in an isolated environment.
* **Green CI Does NOT Prove:** Real-world performance under massive concurrent load (DDoS), cloud network latency, long-term disk fragmentation, or zero-day vulnerabilities in container base images.

### Q6: Which single points of failure remain? How would you fix them in production?

* **Remaining SPOFs:**

  * Single NGINX reverse proxy instance.
  * Single PostgreSQL primary container without replica/failover.

* **Production Resolution:**

  * Deploy HAProxy or a Cloud Load Balancer (AWS ALB) across multiple Availability Zones.
  * Replace the containerized single-node PostgreSQL instance with AWS RDS Multi-AZ or a Patroni-managed PostgreSQL HA cluster.

### Q7: What would you improve? How did you verify AI-assisted work?

* **Future Improvements:**

  * Implement SSL/TLS termination on NGINX.
  * Inject secrets using HashiCorp Vault or AWS Secrets Manager.
  * Add Prometheus/Grafana monitoring.

* **AI Verification:** Every AI-generated script was tested using `docker compose up`, checked with raw socket/curl tests, and cross-referenced against security best practices.
