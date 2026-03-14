import logging
import sys
from flask import Flask
from app.config import Config
from app.extensions import limiter, db_pool
from app.utils.logging import configure_logging


def create_app(config: Config = None) -> Flask:
    """Application factory — creates and configures the Flask app."""
    app = Flask(__name__)
    app.config.from_object(config or Config())

    configure_logging(app)

    # ── Extensions ────────────────────────────────────────────────────────
    limiter.init_app(app)

    # ── Blueprints ────────────────────────────────────────────────────────
    from app.routes.health import health_bp
    from app.routes.query import query_bp
    from app.routes.history import history_bp

    app.register_blueprint(health_bp)
    app.register_blueprint(query_bp,   url_prefix="/api/v1")
    app.register_blueprint(history_bp, url_prefix="/api/v1")

    # ── Global error handlers ─────────────────────────────────────────────
    from app.utils.errors import register_error_handlers
    register_error_handlers(app)

    return app