#!/bin/bash
# -----------------------------------------------------------------------
# deploy.sh - Rolls out a new Docker image version on the EC2 server.
# Copied and executed remotely by the Jenkins "Deploy" stage:
#   scp deploy.sh ubuntu@<ec2-ip>:/tmp/
#   ssh ubuntu@<ec2-ip> "/tmp/deploy.sh <image>:<tag>"
# -----------------------------------------------------------------------
set -euo pipefail

IMAGE_REF="${1:?Usage: deploy.sh <docker-image>:<tag>}"
CONTAINER_NAME="cicd-demo-app"
APP_PORT="${APP_PORT:-5000}"

echo "==> Deploying image: ${IMAGE_REF}"

echo "==> Pulling latest image"
docker pull "${IMAGE_REF}"

echo "==> Stopping and removing old container (if any)"
docker stop "${CONTAINER_NAME}" 2>/dev/null || true
docker rm "${CONTAINER_NAME}" 2>/dev/null || true

echo "==> Starting new container"
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  -p "${APP_PORT}:${APP_PORT}" \
  "${IMAGE_REF}"

echo "==> Waiting for container to become healthy"
for i in $(seq 1 10); do
  STATUS=$(docker inspect --format='{{.State.Health.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "starting")
  echo "Health status: ${STATUS}"
  if [ "${STATUS}" = "healthy" ]; then
    echo "==> Deployment successful. Container is healthy."
    exit 0
  fi
  sleep 5
done

echo "==> WARNING: Container did not report healthy within timeout."
docker logs --tail 50 "${CONTAINER_NAME}"
exit 1
