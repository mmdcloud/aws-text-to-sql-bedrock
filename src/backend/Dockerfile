# =============================================================================
# Text-to-SQL Backend — Production Dockerfile
#
# Multi-stage build:
#   Stage 1 (builder) — installs dependencies into a virtual env
#   Stage 2 (runtime) — copies only the venv + app code; no build tools
#
# Matches Terraform ECS task definition:
#   containerPort = 80
#   health check  = curl -f http://localhost:80 || exit 1
#   log driver    = awslogs  →  /aws/ecs/backend-ecs
#   cpu = 1024, memory = 2048
# =============================================================================

# ── Stage 1: builder ──────────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

# System build deps (needed to compile cryptography / pymysql C extensions)
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libssl-dev \
        libffi-dev \
        default-libmysqlclient-dev \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Create isolated virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install dependencies first (Docker layer cache — only re-runs on requirements change)
COPY requirements.txt .
RUN pip install --upgrade pip==25.0.1 \
    && pip install --no-cache-dir -r requirements.txt


# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM python:3.12-slim AS runtime

# Runtime-only system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        # curl required for ECS health check
        curl \
        # libmysqlclient runtime (no dev headers)
        default-mysql-client \
        # CA certs for HTTPS calls to Cognito JWKS, Bedrock, Secrets Manager
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    # Remove SUID/SGID bits from system binaries (hardening)
    && find / -perm /6000 -type f -exec chmod a-s {} + 2>/dev/null || true

# ── Non-root user ─────────────────────────────────────────────────────────────
# ECS Fargate runs as root by default — we drop privileges immediately.
# Matches principle of least privilege expected in the security posture
# established by the VPC security group layering in the Terraform config.
RUN groupadd --gid 10001 appgroup \
    && useradd  --uid 10001 --gid appgroup --no-create-home --shell /sbin/nologin appuser

# ── Copy virtual env from builder ─────────────────────────────────────────────
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# ── Application code ──────────────────────────────────────────────────────────
WORKDIR /app

COPY --chown=appuser:appgroup app/           ./app/
COPY --chown=appuser:appgroup wsgi.py        ./wsgi.py
COPY --chown=appuser:appgroup gunicorn.conf.py ./gunicorn.conf.py

# ── Environment defaults ──────────────────────────────────────────────────────
# Sensitive values (DB_PATH, DB_NAME, COGNITO_*, BEDROCK_*) are injected
# by the ECS task definition environment block — never baked into the image.
ENV FLASK_ENV=production \
    PORT=80 \
    LOG_LEVEL=INFO \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    # Prevent Python from buffering logs — critical for CloudWatch awslogs
    PYTHONFAULTHANDLER=1 \
    # Disable boto3 IMDS v1 fallback (ECS uses task role, not instance role)
    AWS_EC2_METADATA_DISABLED=true

# ── Switch to non-root ────────────────────────────────────────────────────────
USER appuser

# ── Port ──────────────────────────────────────────────────────────────────────
# Matches ECS container definition: containerPort = 80
EXPOSE 80

# ── Health check ──────────────────────────────────────────────────────────────
# Mirrors the ECS task health check in Terraform exactly:
#   command: ["CMD-SHELL", "curl -f http://localhost:80 || exit 1"]
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

# ── Entrypoint ────────────────────────────────────────────────────────────────
# Gunicorn replaces the default CMD — no shell wrapper needed.
# Signals (SIGTERM from ECS drain) are forwarded directly to Gunicorn,
# which triggers graceful_timeout (30 s) before hard shutdown.
CMD ["gunicorn", "--config", "gunicorn.conf.py", "wsgi:application"]