"""
Health check blueprint.

ECS health check is configured as:
    command: ["CMD-SHELL", "curl -f http://localhost:80 || exit 1"]
    path:    "/"
    port:    80

This endpoint must respond 200 within the ALB unhealthy_threshold window.
It checks the DB connection so ECS / ALB can detect RDS failures early.
"""

import logging
from flask import Blueprint, jsonify
from app.services.database import db_service

logger = logging.getLogger(__name__)

health_bp = Blueprint("health", __name__)


@health_bp.route("/", methods=["GET"])
@health_bp.route("/health", methods=["GET"])
def health():
    db_ok = db_service.health_check()
    status = "healthy" if db_ok else "degraded"
    http_status = 200 if db_ok else 503

    logger.info("health.check", extra={"db_ok": db_ok, "status": status})

    return jsonify({
        "status":  status,
        "checks": {
            "database": "ok" if db_ok else "unreachable",
        },
    }), http_status