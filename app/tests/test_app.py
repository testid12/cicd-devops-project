"""
Automated tests for the CI/CD demo Flask application.
Run with: pytest -v
These are executed by Jenkins in the "Test" stage; the pipeline fails
the build if any test fails.
"""

import os
import sys

# Allow importing app.py from the parent directory when running
# pytest from the app/ folder or from the repo root.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from app import app as flask_app


@pytest.fixture
def client():
    flask_app.config.update(TESTING=True)
    with flask_app.test_client() as client:
        yield client


def test_home_page_status_code(client):
    response = client.get("/")
    assert response.status_code == 200


def test_home_page_contains_project_name(client):
    response = client.get("/")
    assert b"CI/CD Pipeline" in response.data


def test_health_endpoint_status_code(client):
    response = client.get("/health")
    assert response.status_code == 200


def test_health_endpoint_returns_json(client):
    response = client.get("/health")
    data = response.get_json()
    assert data["status"] == "healthy"
    assert data["service"] == "cicd-demo-app"


def test_version_endpoint(client):
    response = client.get("/api/version")
    assert response.status_code == 200
    data = response.get_json()
    assert "version" in data
    assert "build_number" in data


def test_404_on_unknown_route(client):
    response = client.get("/this-route-does-not-exist")
    assert response.status_code == 404
