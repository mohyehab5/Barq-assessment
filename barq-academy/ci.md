Root Directory: Missing .github/workflowsIssue:
After creating the workflow file, it did not appear in the Actions tab on GitHub[cite: 1, 2, 3]. GitHub showed the default "Get started with GitHub Actions" welcome page, indicating it could not locate any workflow configuration[cite: 1, 2, 3].Cause:
The .github/workflows directory structure was missing from the repository, meaning the YAML file was either not committed, misspelled, or misplaced[cite: 1, 2, 3].Resolution:
We explicitly created the required directory structure and committed the file into it[cite: 1, 2, 3].Bash# Correcting the directory structure and path
mkdir -p .github/workflows
mv ci.yml .github/workflows/ci.yml

# Commit and Push
git add .github/workflows/ci.yml
git commit -m "docs: add GitHub Actions workflow in standard .github directory"
git push origin main
Status: $\checkmark$ Resolved2. Workflow File Structure: Correcting Subfolder PathIssue:
The workflow was successfully committed but still failed to trigger[cite: 2]. A closer inspection of the repository structure showed the file located at barq-academy/.github/workflows/ci.yml[cite: 2].Cause:
GitHub Actions requires the .github/workflows folder to be at the strict root level of the repository (/), not within a subfolder or application directory (/barq-academy/...)[cite: 2].Resolution:
We moved the entire .github directory from the subfolder to the repository root[cite: 2].Bash# Moving the structure to the repository root
mv barq-academy/.github .github

# Commit and Push
git add .
git commit -m "fix: move .github folder to repository root for proper Actions detection"
git push origin main
Status: $\checkmark$ Resolved3. Environment Setup Failure: Missing Config/Env FilesIssue:
The pipeline failed early in the Environment Setup step[cite: 3]. Commands like docker compose down and configuration checks reported "no configuration file provided: not found" errors[cite: 3].Cause:
Two issues occurred:The workflow commands were running at the root, while the application files were in barq-academy/[cite: 3].The .env file containing required credentials was missing from the CI environment.Resolution:
We updated the ci.yml file to set the default working-directory and added a step to dynamically create the necessary .env file before launching services.YAML# Fix in ci.yml
jobs:
  validate-stack:
    defaults:
      run:
        working-directory: barq-academy  # Run all steps from subfolder

    steps:
      # Create .env dynamically
      - name: Environment Setup
        run: |
          cat << 'EOF' > .env
          POSTGRES_USER=...
          # ... rest of the .env ...
          EOF
Status: $\checkmark$ Resolved4. Python Dependency Issue: validate.py Validation FailureIssue:
The Run Automated Stack Validation step failed during the execution of python3 validate.py[cite: 4]. The error message was exit code 2 and the specific print statement: NOT IMPLEMENTED: write bounded checks with PASS/FAIL and non-zero failure exits.[cite: 4].Cause:
The Python script was a placeholder and did not contain actual testing logic (bounded checks) or correct exit code management[cite: 4].Resolution:
The placeholder Python script was replaced with a complete validation suite that used requests and sys.exit correctly[cite: 4].Python# Fix in barq-academy/validate.py
import requests, sys
# Implementation of actual connection tests, health checks, and load balancing
# sys.exit(0) on success, sys.exit(1) on failure
Status: $\checkmark$ Resolved5. Language Migration: Changing Validation from Python to BashIssue:
The pipeline required substantial Python dependencies (requests, psycopg2-binary, redis) to run the simple network validation, slowing down the pipeline[cite: 4]. A decision was made to standardize the entire validation process using Bash shell scripts (validate.sh).Cause:
Request to streamline the CI workflow and reduce dependency overhead.Resolution:
We refactored the entire validation step from Python (validate.py) to pure Bash (validate.sh). All subsequent Python setup steps were removed from the workflow.YAML# Changes in ci.yml
# - removed: name: Set up Python
# - removed: name: Environment Setup (dependencies)

- name: Run Automated Stack Validation
  run: |
    chmod +x validate.sh
    ./validate.sh
Status: $\checkmark$ Resolved6. Network Binding Error: localhost vs 0.0.0.0 (Inside CI)Issue:
The Run Automated Stack Validation step failed again when executing validate.sh[cite: 5, 6]. The error was FAIL: Root endpoint unreachable (HTTP 000) and reported that it couldn't connect to localhost:8080. The application logs simultaneously confirmed the services were running successfully[cite: 7, 8].Cause:
The CI runner environment is independent. When testing network services inside Docker from the CI host, you must target the network interface shared with Docker (0.0.0.0 or the Docker bridge IP), not localhost[cite: 19].Resolution:
We updated the validate.sh script to explicitly bind and test against 0.0.0.0:8080.Bash# Fix in barq-academy/validate.sh
# Changed the target from localhost to 0.0.0.0
BASE_URL="http://0.0.0.0:8080"
Status:  Resolved
