"""
main.py — Application entry point and full request lifecycle.

This is the file you run. Everything flows through here:

    Request
      │
      ├─► before_request  : request ID injection, request logging
      │
      ├─► @cognito_required: Cognito JWT validation (auth middleware)
      │
      ├─► route handler   : validate → Bedrock → DB execute → save history
      │
      └─► after_request   : response logging, CORS headers

Start locally:
    python main.py

Production (Gunicorn picks this up via wsgi.py):
    gunicorn --config gunicorn.conf.py wsgi:application
"""

import os
import uuid
import logging

from flask import Flask, g, request, jsonify

from app.config import Config, DevelopmentConfig
from app.utils.logging import configure_logging
from app.utils.errors import register_error_handlers
from app.extensions import limiter

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
# App factory
# ─────────────────────────────────────────────────────────────────────────────

def create_app(cfg: Config = None) -> Flask:
    app = Flask(__name__)
    app.config.from_object(cfg or Config())

    # ── Logging (must be first) ───────────────────────────────────────────
    configure_logging(app)

    # ── Extensions ────────────────────────────────────────────────────────
    limiter.init_app(app)

    # ── Database pool warm-up ─────────────────────────────────────────────
    # Eagerly validate DB connectivity at startup so ECS health checks
    # fail fast if RDS is unreachable, rather than on the first user request.
    with app.app_context():
        _warmup_db(app)

    # ── Blueprints ────────────────────────────────────────────────────────
    from app.routes.health   import health_bp
    from app.routes.query    import query_bp
    from app.routes.history  import history_bp
    from app.routes.auth     import auth_bp
    from app.routes.results  import results_bp

    app.register_blueprint(health_bp)
    app.register_blueprint(query_bp,   url_prefix="/api/v1")
    app.register_blueprint(history_bp, url_prefix="/api/v1")
    app.register_blueprint(auth_bp,     url_prefix="/api/v1")
    app.register_blueprint(results_bp,  url_prefix="/api/v1")

    # ── Request lifecycle hooks ───────────────────────────────────────────
    _register_request_hooks(app)

    # ── Error handlers ────────────────────────────────────────────────────
    register_error_handlers(app)

    return app


# ─────────────────────────────────────────────────────────────────────────────
# DB warm-up: ensure query_history table exists and pool is healthy
# ─────────────────────────────────────────────────────────────────────────────

def _warmup_db(app: Flask) -> None:
    """
    Creates the query_history table if it doesn't exist, and pings the DB.
    Runs once per ECS task on cold start.

    If the DB is unreachable, logs a warning but does NOT crash the process —
    the /health endpoint will return 503 and the ALB will stop sending traffic
    until RDS recovers, at which point the pool re-connects automatically.
    """
    from app.services.database import db_service
    from sqlalchemy import text

    CREATE_HISTORY_TABLE = """
        CREATE TABLE IF NOT EXISTS query_history (
            id            VARCHAR(36)    NOT NULL,
            user_sub      VARCHAR(128)   NOT NULL,
            username      VARCHAR(255)   NOT NULL DEFAULT '',
            question      TEXT           NOT NULL,
            sql_generated TEXT,
            explanation   TEXT,
            row_count     INT            DEFAULT NULL,
            blocked       TINYINT(1)     NOT NULL DEFAULT 0,
            error_message VARCHAR(512)   DEFAULT NULL,
            created_at    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_user_sub_created (user_sub, created_at DESC),
            INDEX idx_created_at       (created_at DESC)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    """

    try:
        # history table is DDL — needs a write connection, bypass read-only guard
        engine = db_service._get_engine()
        with engine.connect() as conn:
            conn.execute(text(CREATE_HISTORY_TABLE))
            conn.commit()
            conn.execute(text("SELECT 1"))   # ping
        logger.info("startup.db_warmup_ok")
    except Exception as exc:
        logger.warning("startup.db_warmup_failed", extra={"error": str(exc)})


# ─────────────────────────────────────────────────────────────────────────────
# Request lifecycle hooks
# ─────────────────────────────────────────────────────────────────────────────

def _register_request_hooks(app: Flask) -> None:

    @app.before_request
    def inject_request_id():
        """
        Attach a unique correlation ID to every request.
        Logged on both ingress and egress — searchable in CloudWatch Logs Insights:
            fields @timestamp, correlation_id, method, path, status
        """
        g.correlation_id = request.headers.get("X-Correlation-ID", str(uuid.uuid4()))
        g.request_start  = __import__("time").monotonic()

        logger.info(
            "request.received",
            extra={
                "correlation_id": g.correlation_id,
                "method":         request.method,
                "path":           request.path,
                "remote_addr":    request.remote_addr,
                "user_agent":     request.headers.get("User-Agent", ""),
            },
        )

    @app.after_request
    def log_response(response):
        """Log every response with duration and inject correlation ID header."""
        import time
        duration_ms = round(
            (time.monotonic() - getattr(g, "request_start", 0)) * 1000, 2
        )

        response.headers["X-Correlation-ID"] = getattr(g, "correlation_id", "")
        # Prevent clickjacking and MIME-sniffing
        response.headers["X-Frame-Options"]           = "DENY"
        response.headers["X-Content-Type-Options"]    = "nosniff"
        response.headers["Referrer-Policy"]           = "strict-origin-when-cross-origin"
        # Remove server banner
        response.headers.pop("Server", None)

        logger.info(
            "request.completed",
            extra={
                "correlation_id": getattr(g, "correlation_id", ""),
                "method":         request.method,
                "path":           request.path,
                "status":         response.status_code,
                "duration_ms":    duration_ms,
                "content_length": response.content_length,
            },
        )
        return response

    @app.teardown_appcontext
    def cleanup(_exc):
        """Nothing to clean up per-request (pool is long-lived), but hook is here for future use."""
        pass


# ─────────────────────────────────────────────────────────────────────────────
# Application instance (imported by wsgi.py and by tests)
# ─────────────────────────────────────────────────────────────────────────────

_env = os.getenv("FLASK_ENV", "production")
application = create_app(DevelopmentConfig() if _env == "development" else Config())


# ─────────────────────────────────────────────────────────────────────────────
# Local dev runner
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    port  = int(os.getenv("PORT", 80))
    debug = _env == "development"

    logger.info(
        "dev_server.starting",
        extra={"port": port, "debug": debug, "env": _env},
    )

    application.run(
        host="0.0.0.0",
        port=port,
        debug=debug,
        use_reloader=debug,
    )