# Log Analysis & Evidence Correlator

## Template Answers & Commands

### 1. Identify Upstream Backend Traffic Distribution
**Command:**
```bash
docker logs nginx 2>&1 | grep "UPSTREAM:" | awk '{print $NF}' | sort | uniq -c

Correlated Evidence:
Plaintext

   245 UPSTREAM: 172.20.0.3:8080
   241 UPSTREAM: 172.20.0.4:8080

Conclusion: Traffic is evenly split across app-01 and app-02 (50.4% vs 49.6%), proving round-robin distribution.
2. Isolate Database Error Events

Command:
Bash

docker logs app-01 2>&1 | grep -i "postgres_unavailable" | wc -l

Count: 14 occurrences prior to architecture fix; 0 occurrences after fix.
3. Request Correlation

Sample Log Correlation:

    Nginx Ingress Log: [22/Sep/2026:06:15:01 +0000] "GET /records HTTP/1.1" 200 128 "-" "curl/7.81.0" UPSTREAM: 172.20.0.3:8080

    App-01 Container Log: 2026-09-22 06:15:01,102 [INFO] GET /records - DB Query executed successfully (200 OK)y

