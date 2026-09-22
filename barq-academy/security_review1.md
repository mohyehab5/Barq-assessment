# Security Review & Vulnerability Assessment

## Identified Concrete Risks & Implemented / Production Fixes

### 1. Plaintext Secrets in `.env` File
- **Risk:** Storing DB passwords in git repo configuration files.
- **Implemented Fix:** Added `.env` to `.gitignore`.
- **Production Plan:** Inject secrets dynamically using AWS Secrets Manager or HashiCorp Vault at runtime.

### 2. Prohibited Host Port Exposure
- **Risk:** Exposing database (5432) or cache (6379) directly on host `0.0.0.0`.
- **Implemented Fix:** Removed port bindings for internal services in `docker-compose.yml`. Verified via `validate.py`.

### 3. Container Process Privilege Escalation
- **Risk:** Applications running as `root` (UID 0).
- **Implemented Fix:** Applied `USER 10001` in Dockerfile.

### 4. Excessive Network Exposure
- **Risk:** Database accessible directly from reverse proxy tier.
- **Implemented Fix:** Segregated network into `lab-frontend` and `lab-backend`.

### 5. Missing Resource Limits (DoS Risk)
- **Risk:** Single backend container consuming all host memory/CPU during spike.
- **Production Plan:** Define `deploy.resources.limits` in Docker Compose (e.g., `memory: 512M`, `cpus: '0.50'`).

### 6. Lack of Transport Security (HTTPS)
- **Risk:** Plaintext HTTP traffic between client and Nginx.
- **Production Plan:** Implement TLS certs (Let's Encrypt / cert-manager) terminating HTTPS at Nginx (Port 443).

### 7. Unrestricted Database Volume Access
- **Risk:** Host file permissions on named Docker volumes allowing unprivileged host users to read raw database files.
- **Production Plan:** Restrict `/var/lib/docker/volumes/` host permissions to root user only (`chmod 700`).

### 8. Logging Sensitivity & Log Injection
- **Risk:** Potentially logging sensitive credentials or unvalidated request parameters.
- **Production Plan:** Implement log sanitization middleware in Python app layer to mask auth headers and passwords
