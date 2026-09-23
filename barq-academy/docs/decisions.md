```markdown
# Architectural & Operational Decisions

## Decision 1: Dual-Network Attachment for Backend Applications
- **Context:** Application backends must accept web requests from Nginx and communicate with DB/Cache.
- **Decision:** Attach `app-01` and `app-02` to both `lab-frontend` and `lab-backend` Docker networks.
- **Alternatives:** Put all containers in a single flat network.
- **Trade-offs:** Flat networks reduce security isolation. Dual-network attachment provides strict tier segregation (Nginx cannot touch PostgreSQL directly).

## Decision 2: Standardized Environment Variable Injection (`DATABASE_URL`)
- **Context:** Python application supported `DATABASE_URL` connection strings as well as individual parameters.
- **Decision:** Provide both explicit parameter sets (`POSTGRES_USER`, `POSTGRES_PASSWORD`, etc.) and consolidated `DATABASE_URL` in `.env`.
- **Limitation:** Hardcoded `.env` files in git repos pose security risks. Production must use secret management tools.

## Decision 3: Non-Exposed Database Host Ports
- **Context:** Database needs to be accessed by application containers.
- **Decision:** Omit `ports: - "5432:5432"` mapping from `postgres` service in `docker-compose.yml`.
- **Trade-offs:** Host machines cannot run direct `psql` commands without `docker exec`, but this guarantees host port security and prevents external DB scanning.

## Decision 4: Application Container Health Dependency (`service_healthy`)
- **Context:** App services crash if initialized before PostgreSQL is accepting connections.
- **Decision:** Configured `depends_on: postgres: condition: service_healthy` using native `pg_isready` check.
- **Trade-offs:** Increases stack startup time slightly, but eliminates boot loop crashes and container restart cascades.

## Decision 5: Non-Root Execution in Containers
- **Context:** Running application processes as `root` inside containers presents container-escape vulnerabilities.
- **Decision:** Configured Dockerfiles to execute application binaries under a non-privileged system user (`appuser`).
- **Trade-offs:** Requires careful permission mapping on container directory mounts.
