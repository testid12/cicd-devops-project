# -----------------------------------------------------------------------
# Production Dockerfile - CI/CD Demo Application (Flask + Gunicorn)
# -----------------------------------------------------------------------
# Multi-stage build keeps the final image small and free of build tools.

# ---------- Stage 1: builder ----------
FROM python:3.12-slim AS builder

WORKDIR /build

# Install build deps only in this stage (not in the final image)
COPY app/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ---------- Stage 2: runtime ----------
FROM python:3.12-slim AS runtime

# Build-time metadata, overridable via --build-arg from Jenkins
ARG APP_VERSION=dev
ARG BUILD_NUMBER=local
ARG GIT_COMMIT=unknown

ENV APP_VERSION=${APP_VERSION} \
    BUILD_NUMBER=${BUILD_NUMBER} \
    GIT_COMMIT=${GIT_COMMIT} \
    DEPLOY_ENV=production \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/home/appuser/.local/bin:$PATH

# Create a non-root user to run the application
RUN useradd --create-home --shell /usr/sbin/nologin appuser

WORKDIR /app

# Copy installed Python packages from the builder stage
COPY --from=builder /root/.local /home/appuser/.local

# Copy application source code
COPY app/ /app/

# curl is required only for the container HEALTHCHECK
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

RUN chown -R appuser:appuser /app /home/appuser/.local

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# gunicorn is used instead of the Flask dev server for production
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "app:app"]
