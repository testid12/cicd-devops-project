"""
Automated CI/CD Pipeline Demo Application
------------------------------------------
Flask application demonstrating an end-to-end
CI/CD pipeline using Jenkins, Docker, Terraform and AWS.

Routes:
  GET /            -> Main application UI
  GET /health      -> Health check endpoint
  GET /api/version -> Application version information
"""

import os
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template

app = Flask(__name__)

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
        "server_time": datetime.now(timezone.utc).strftime(
            "%Y-%m-%d %H:%M:%S UTC"
        ),
        "pipeline_status": "Healthy",
    }

    return render_template("index.html", **context)


@app.route("/health")
def health():
    """Health check endpoint used by Docker, Jenkins and AWS."""

    return jsonify(
        status="healthy",
        service="cicd-demo-app",
        version=APP_VERSION,
        timestamp=datetime.now(timezone.utc).isoformat(),
    ), 200


@app.route("/api/version")
def version():
    """Return application build and deployment information."""

    return jsonify(
        version=APP_VERSION,
        build_number=BUILD_NUMBER,
        git_commit=GIT_COMMIT,
        environment=DEPLOY_ENV,
    ), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))

    app.run(
        host="0.0.0.0",
        port=port,
        debug=False,
    )
