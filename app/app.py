"""
Automated CI/CD Pipeline Demo Application
------------------------------------------
A small Flask web application used to demonstrate an end-to-end
CI/CD pipeline (Jenkins -> Docker -> Terraform -> AWS).

The app exposes:
  GET /            -> Homepage with project info and pipeline status
  GET /health      -> Health check endpoint used by Docker/ALB/Jenkins
  GET /api/version -> Returns current application version as JSON
"""

import os
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template

app = Flask(__name__)

# APP_VERSION is injected at Docker build time via --build-arg APP_VERSION
# and falls back to "dev" for local runs.
APP_VERSION = os.environ.get("APP_VERSION", "dev")
BUILD_NUMBER = os.environ.get("BUILD_NUMBER", "local")
GIT_COMMIT = os.environ.get("GIT_COMMIT", "unknown")
DEPLOY_ENV = os.environ.get("DEPLOY_ENV", "development")


@app.route("/")
def home():
    context = {
        "project_name": "Automated CI/CD Pipeline using Jenkins, Docker, Terraform and AWS",
        "developer": "BTech DevOps Project Team",
        "app_version": APP_VERSION,
        "build_number": BUILD_NUMBER,
        "git_commit": GIT_COMMIT[:7] if GIT_COMMIT != "unknown" else GIT_COMMIT,
        "deploy_env": DEPLOY_ENV,
        "hostname": socket.gethostname(),
        "server_time": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"),
        "pipeline_status": "Healthy",
    }
    return render_template("index.html", **context)


@app.route("/health")
def health():
    """Lightweight health check used by Docker HEALTHCHECK, Jenkins and
    load balancers. Must respond fast and without external dependencies."""
    return jsonify(
        status="healthy",
        service="cicd-demo-app",
        version=APP_VERSION,
        timestamp=datetime.now(timezone.utc).isoformat(),
    ), 200


@app.route("/api/version")
def version():
    return jsonify(
        version=APP_VERSION,
        build_number=BUILD_NUMBER,
        git_commit=GIT_COMMIT,
        environment=DEPLOY_ENV,
    ), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    # debug is intentionally off; this runs behind gunicorn in production
    app.run(host="0.0.0.0", port=port)
