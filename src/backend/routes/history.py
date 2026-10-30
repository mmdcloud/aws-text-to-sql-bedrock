"""
History blueprint — per-user query audit log.

GET  /api/v1/history           Returns the last N queries for the current user.
GET  /api/v1/history/<query_id> Returns a single historical query by ID.
DELETE /api/v1/history         Clears the current user's query history.

The query_history table is expected to exist in the application DB:

    CREATE TABLE IF NOT EXISTS query_history (
        id            VARCHAR(36)   NOT NULL PRIMARY KEY,
        user_sub      VARCHAR(128)  NOT NULL,
        question      TEXT          NOT NULL,
        sql_generated TEXT,
        row_count     INT,
        blocked       TINYINT(1)    DEFAULT 0,
        created_at    DATETIME      DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_user_sub_created (user_sub, created_at DESC)
    );
"""

import logging
import uuid
from datetime import datetime, timezone

from flask import Blueprint, g, jsonify, request
from app.middleware.auth import cognito_required
from app.services.database import db_service
from app.extensions import limiter

logger = logging.getLogger(__name__)
history_bp = Blueprint("history", __name__)


def _user_key() -> str:
    user = getattr(g, "cognito_user", None)
    return f"user:{user['sub']}" if user else request.remote_addr


@history_bp.route("/history", methods=["GET"])
@cognito_required
@limiter.limit("60 per minute", key_func=_user_key)
def get_history():
    """Return the authenticated user's last N query history entries."""
    user_sub = g.cognito_user["sub"]
    limit = min(int(request.args.get("limit", 20)), 100)
    offset = int(request.args.get("offset", 0))

    try:
        result = db_service.execute_query(
            f"SELECT id, question, sql_generated, row_count, blocked, created_at "
            f"FROM query_history "
            f"WHERE user_sub = '{_safe_sub(user_sub)}' "
            f"ORDER BY created_at DESC "
            f"LIMIT {limit} OFFSET {offset}"
        )
    except RuntimeError as exc:
        logger.error("history.fetch_failed", extra={"error": str(exc)})
        return jsonify({"error": "database_error", "message": str(exc)}), 500

    entries = [
        dict(zip(result["columns"], row))
        for row in result["rows"]
    ]

    return jsonify({
        "history": entries,
        "limit":   limit,
        "offset":  offset,
    }), 200


@history_bp.route("/history/<query_id>", methods=["GET"])
@cognito_required
def get_history_entry(query_id: str):
    """Fetch a single history entry — only the owner can access it."""
    user_sub = g.cognito_user["sub"]

    try:
        result = db_service.execute_query(
            f"SELECT id, question, sql_generated, row_count, blocked, created_at "
            f"FROM query_history "
            f"WHERE id = '{_safe_id(query_id)}' "
            f"AND user_sub = '{_safe_sub(user_sub)}'"
        )
    except RuntimeError as exc:
        return jsonify({"error": "database_error", "message": str(exc)}), 500

    if not result["rows"]:
        return jsonify({"error": "not_found", "message": "History entry not found."}), 404

    entry = dict(zip(result["columns"], result["rows"][0]))
    return jsonify(entry), 200


# ── Helper: safe UUID / sub strings ──────────────────────────────────────────
# These values come from Cognito (server-controlled) but we sanitise anyway.

def _safe_sub(sub: str) -> str:
    """Cognito sub is a UUID — allow only alphanumerics and hyphens."""
    import re
    return re.sub(r"[^a-zA-Z0-9\-]", "", sub)[:128]


def _safe_id(query_id: str) -> str:
    """query_id is a UUID we generated — same allowlist."""
    import re
    return re.sub(r"[^a-zA-Z0-9\-]", "", query_id)[:36]