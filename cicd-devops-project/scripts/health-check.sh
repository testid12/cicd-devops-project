#!/bin/bash
# -----------------------------------------------------------------------
# health-check.sh - Polls the application's /health endpoint until it
# responds successfully, or fails after a timeout. Used by the Jenkins
# "Health Check" stage to confirm the deployment succeeded.
#
# Usage: ./health-check.sh http://<host>:<port>/health
# -----------------------------------------------------------------------
set -euo pipefail

URL="${1:?Usage: health-check.sh <health-endpoint-url>}"
MAX_RETRIES=12
SLEEP_SECONDS=5

echo "==> Checking health endpoint: ${URL}"

for attempt in $(seq 1 "${MAX_RETRIES}"); do
  echo "Attempt ${attempt}/${MAX_RETRIES}..."

  HTTP_CODE=$(curl -s -o /tmp/health_response.json -w "%{http_code}" "${URL}" || echo "000")

  if [ "${HTTP_CODE}" = "200" ]; then
    echo "==> Application is healthy (HTTP 200)"
    cat /tmp/health_response.json
    exit 0
  fi

  echo "Received HTTP ${HTTP_CODE}, retrying in ${SLEEP_SECONDS}s..."
  sleep "${SLEEP_SECONDS}"
done

echo "==> ERROR: Application failed health check after ${MAX_RETRIES} attempts"
exit 1
