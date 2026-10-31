# =============================================================================
# Text-to-SQL Backend — Production Dockerfile
#
# Multi-stage build:
#   Stage 1 (builder) — installs dependencies into an isolated virtual environment
#   Stage 2 (runtime) — lean runtime containing venv, system libs, and app code
#
# Matches Terraform ECS task definition:
#   containerPort = 80
#   health check  = curl -f http://localhost:80/health || exit 1
#   log driver    = awslogs  →  /aws/ecs/backend-ecs
#   cpu = 1024, memory = 2048
# =============================================================================

# ── Stage 1: builder ──────────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

# System build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libssl-dev \
        libffi-dev \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Create isolated virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install dependencies
COPY requirements.txt .
RUN pip install --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt


# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM python:3.12-slim AS runtime

# Runtime packages:
#   - curl: required for ECS / Docker HEALTHCHECK
#   - ca-certificates: required for HTTPS calls to AWS services (Cognito, Bedrock, Secrets Manager)
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create dedicated non-root application user and group (UID/GID 10001)
RUN groupadd --gid 10001 appgroup \
    && useradd  --uid 10001 --gid appgroup --no-create-home --shell /sbin/nologin appuser

# Copy virtual environment from builder stage
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Application directory
WORKDIR /app

# Copy application source code with proper ownership
COPY --chown=appuser:appgroup app/             ./app/
COPY --chown=appuser:appgroup wsgi.py          ./wsgi.py
COPY --chown=appuser:appgroup main.py          ./main.py
COPY --chown=appuser:appgroup __init__.py      ./__init__.py
COPY --chown=appuser:appgroup gunicorn.conf.py ./gunicorn.conf.py

# Environment configuration
ENV FLASK_ENV=production \
    PORT=80 \
    LOG_LEVEL=INFO \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    AWS_EC2_METADATA_DISABLED=true

# Port exposure (matches ECS container definition: containerPort = 80)
EXPOSE 80

# Health check matching ECS task definition
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

# Start Gunicorn.
# The master arbiter starts, binds to port 80, and drops worker privileges
# to appuser:appgroup as configured in gunicorn.conf.py.
CMD ["gunicorn", "--config", "gunicorn.conf.py", "wsgi:application"]
