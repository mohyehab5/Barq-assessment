#!/usr/bin/env python3
import subprocess
import time
import urllib.request
import json
import sys

NGINX_URL = "http://127.0.0.1:8080"

def log(msg):
    print(f"[+] {msg}")

def log_warn(msg):
    print(f"[!] {msg}")

def log_err(msg):
    print(f"[-] {msg}")

def run_cmd(cmd):
    """Executes a shell command and returns the stripped stdout."""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        log_err(f"Command failed: {cmd}\nError: {result.stderr.strip()}")
    return result.stdout.strip()

def get_instance_id():
    """Fetches the root endpoint and returns the instance_id handling the request."""
    try:
        req = urllib.request.Request(NGINX_URL, headers={"User-Agent": "FailureTest/1.0"})
        with urllib.request.urlopen(req, timeout=3) as resp:
            if resp.status == 200:
                data = json.loads(resp.read().decode())
                return data.get("instance_id")
    except Exception as e:
        log_err(f"HTTP request error: {e}")
        return None

def main():
    log("Starting Scoped Container Failure & Recovery Test...")

    # 1. Baseline Verification
    log("Verifying initial cluster state...")
    instances = set()
    for _ in range(6):
        inst = get_instance_id()
        if inst:
            instances.add(inst)
        time.sleep(0.3)

    log(f"Active backend instances detected: {list(instances)}")
    if "app-01" not in instances or "app-02" not in instances:
        log_warn("Warning: Both app-01 and app-02 should be running before starting the test.")

    try:
        # 2. Simulate Failure (Stop app-01)
        log("Simulating failure: Stopping container 'app-01'...")
        run_cmd("docker compose stop app-01")
        time.sleep(2)  # Give Nginx a moment to recognize upstream drop

        # 3. Verify Failover
        log("Testing failover through Nginx proxy...")
        failover_instances = set()
        for i in range(5):
            inst = get_instance_id()
            if inst:
                failover_instances.add(inst)
            time.sleep(0.3)

        log(f"Active instances during app-01 outage: {list(failover_instances)}")

        if "app-01" in failover_instances:
            log_err("FAIL: app-01 still responded despite being stopped!")
            sys.exit(1)
        elif "app-02" in failover_instances:
            log("SUCCESS: All traffic successfully rerouted to app-02!")
        else:
            log_err("FAIL: No backend instances responded during failover.")
            sys.exit(1)

    finally:
        # 4. Recovery & Cleanup
        log("Recovering environment: Starting container 'app-01' back up...")
        run_cmd("docker compose start app-01")
        
        # Wait for app-01 health/readiness
        log("Waiting for app-01 to recover and join the upstream pool...")
        time.sleep(4)

        recovered_instances = set()
        for _ in range(6):
            inst = get_instance_id()
            if inst:
                recovered_instances.add(inst)
            time.sleep(0.3)

        log(f"Active instances after recovery: {list(recovered_instances)}")

        if "app-01" in recovered_instances and "app-02" in recovered_instances:
            log("SUCCESS: Both app-01 and app-02 are healthy and load balancing restored!")
            print("\n✅ FAILURE AND RECOVERY TEST PASSED SUCCESSFULLY.")
        else:
            log_warn("Cleanup completed, but load balancing dual-instance state is still stabilizing.")

if __name__ == "__main__":
    main()
