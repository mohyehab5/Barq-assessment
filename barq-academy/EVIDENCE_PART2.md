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

