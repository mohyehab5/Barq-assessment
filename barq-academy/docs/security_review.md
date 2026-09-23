Completed Security & Operational Improvements
1. Plaintext Secrets in .env File

    Risk and evidence: Storing database passwords and environment variables in version control files (.env).

    Impact: Credentials exposed to anyone with repository access, leading to potential unauthorized data access.

    Implemented fix / commit: Added .env to .gitignore and provided .env.example with sanitized placeholder values.

    Production follow-up: Inject credentials dynamically into the container runtime using AWS Secrets Manager or HashiCorp Vault.

    How to verify: Run git status or inspect the repository to confirm .env is ignored and not tracked by Git.

2. Prohibited Host Port Exposure

    Risk and evidence: Exposing internal data services (PostgreSQL on port 5432) directly on host interface 0.0.0.0.

    Impact: External attackers can bypass the API gateway and directly target the database layer.

    Implemented fix / commit: Removed ports mappings for postgres in docker-compose.yml, leaving only Nginx mapped to port 8080.

    How to verify: Run docker compose ps and nc -zv localhost 5432 to confirm port 5432 is not exposed on the host.

3. Container Process Privilege Escalation

    Risk and evidence: Application processes inside barq-api running as default root user (UID 0).

    Impact: Container breakout vulnerabilities could allow an attacker to gain full root access on the underlying host system.

    Implemented fix / commit: Added USER 10001 directive and created non-root system user inside Dockerfile.

    Production follow-up: Enforce securityOpt: ["no-new-privileges:true"] across container definitions.

    How to verify: Execute docker compose exec app-01 whoami and verify the returned user is non-root (e.g., appuser or UID 10001).

4. Excessive Network Exposure

    Risk and evidence: Unrestricted network access allowing Nginx proxy to directly query the database service.

    Impact: In the event of an Nginx compromise, attackers gain immediate network access to the database tier.

    Implemented fix / commit: Segregated network into lab-frontend (Nginx + App) and lab-backend (App + Postgres) in docker-compose.yml.

    Production follow-up: Implement strict network policy rules / firewalling in orchestration platforms (Kubernetes NetworkPolicies).

    How to verify: Run docker compose exec nginx ping postgres and confirm network connection is unreachable.

Planned Production Improvements
5. Missing Resource Limits (DoS Vulnerability)

    Risk and evidence: Absence of CPU and memory limits in docker-compose.yml for application containers.

    Impact: A single rogue process or traffic spike can exhaust host system resources, crashing neighboring services.

    Implemented fix / commit: Planned for production deployment configuration.

    Production follow-up: Enforce explicit resource bounds using deploy.resources.limits (e.g., memory: 512M, cpus: '0.50').

    How to verify: Run docker stats under synthetic load to verify container memory and CPU usage stay capped at configured limits.

6. Lack of Transport Security (HTTPS)

    Risk and evidence: Nginx serving external HTTP traffic over unencrypted port 80/8080.

    Impact: Sensitive request payloads, headers, and credentials exposed to man-in-the-middle (MitM) sniffing.

    Implemented fix / commit: Planned for edge ingress and domain configuration.

    Production follow-up: Configure TLS termination on Nginx using Let's Encrypt / cert-manager and enforce HTTP-to-HTTPS redirect.

    How to verify: Execute curl -I https://<domain> and verify valid SSL certificate presentation and HTTP 301 redirects from HTTP.

7. Unrestricted Database Volume Access

    Risk and evidence: Named Docker volumes storing raw PostgreSQL data files default to permissions accessible by unprivileged host users.

    Impact: Unauthorized host users can read raw database files directly from /var/lib/docker/volumes/.

    Implemented fix / commit: Planned for production host hardening script.

    Production follow-up: Enforce strict file system permissions (chmod 700) on host volume mount points and enable at-rest volume encryption.

    How to verify: Inspect host directory permissions via ls -ld /var/lib/docker/volumes/* to confirm restricted root access.

8. Logging Sensitivity & Log Injection

    Risk and evidence: Standard output logging capturing raw request headers and database connection strings.

    Impact: Secret leakage into central logging aggregators (Datadog/ELK) and vulnerability to log forging attacks.

    Implemented fix / commit: Planned for application layer middleware release.

    Production follow-up: Integrate log sanitization middleware in Python app layer to mask auth tokens, passwords, and sensitive headers.

    How to verify: Send a request containing authorization headers and inspect docker compose logs app-01 to confirm sensitive values display as [REDACTED].
