# AI Usage & Verification Declaration

## Tools Used
- **AI Tool:** OpenAI ChatGPT / Gemini Agent
- **Purpose:** Diagnostic script creation, log parsing automation, Docker Compose network structure generation, and documentation drafting.

## Affected Files
- `validate.py`
- `failure_test.sh`
- `backup.sh` & `restore.sh`
- `.github/workflows/ci.yml`
- `README.md`
- `troubleshooting.md`
- `log_analysis.md`
- `decisions.md`
- `security_review.md`

## Verification Methodology
1. **Automated Verification:** Executed `validate.py` against running Docker stack to confirm all network isolation, port masking, and API response assumptions made by AI were accurate.
2. **Failover Testing:** Validated AI-generated `failure_test.sh` by manually stopping container `app-01` via CLI and capturing traffic metrics.
3. **Backup Integrity:** Executed `backup.sh` and `restore.sh` on fresh database instances and ran SQL queries to verify data persistence.
