"""
Results blueprint — fetch stored query results.

Endpoints
---------
GET  /api/v1/results/<query_id>          Fetch a past query with its results re-executed
GET  /api/v1/results/<query_id>/sql      Fetch only the stored SQL (no re-execution)
POST /api/v1/results/<query_id>/re-run   Re-execute the stored SQL with fresh data
"""

import logging
import uuid
from datetime import datetime, timezone

from flask import Blueprint, g, jsonify, request
from sqlalchemy import text

from app.middleware.auth import cognito_required
from app.services.database import db_service
from app.extensions import limiter

logger     = logging.getLogger(__name__)
results_bp = Blueprint("results", __name__)


def _user_key() -> str:
    user = getattr(g, "cognito_user", None)
    return f"user:{user['sub']}" if user else request.remote_addr


def _safe_id(query_id: str) -> str:
    """Sanitise query_id to UUID characters only."""
    import re
    return re.sub(r"[^a-zA-Z0-9\-]", "", query_id)[:36]


def _fetch_history_entry(query_id: str, user_sub: str) -> dict | None:
    """
    Load a query_history row for this user.
    Returns None if not found or if it belongs to a different user.
    """
    FETCH_SQL = """
        SELECT
            id, user_sub, username, question,
            sql_generated, explanation, row_count,
            blocked, error_message, created_at
        FROM query_history
        WHERE id       = :id
          AND user_sub = :user_sub
        LIMIT 1
    """
    try:
        engine = db_service._get_engine()
        with engine.connect() as conn:
            result = conn.execute(
                text(FETCH_SQL),
                {"id": _safe_id(query_id), "user_sub": user_sub},
            )
            row = result.fetchone()
            if not row:
                return None
            columns = list(result.keys())
            return dict(zip(columns, row))
    except Exception as exc:
        logger.error("results.fetch_failed", extra={"query_id": query_id, "error": str(exc)})
        raise RuntimeError(str(exc)) from exc


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/v1/results/<query_id>
# ─────────────────────────────────────────────────────────────────────────────

@results_bp.route("/results/<query_id>", methods=["GET"])
@cognito_required
@limiter.limit("60 per minute", key_func=_user_key)
def get_result(query_id: str):
    """
    Retrieve a past query and re-execute its SQL to get fresh results.

    This is useful when the user wants to see the current state of the data
    for a query they ran earlier — it uses the stored SQL, not the original question,
    so the Bedrock agent is NOT invoked again.

    Query params:
        ?execute=false   Return only the stored metadata without re-running the SQL

    Response:
        {
            "query_id":    str,
            "question":    str,
            "sql":         str | null,
            "explanation": str | null,
            "blocked":     bool,
            "created_at":  str,
            "results":     { "columns": [], "rows": [], "row_count": int, "truncated": bool } | null
        }
    """
    user      = g.cognito_user
    execute   = request.args.get("execute", "true").lower() == "true"

    try:
        entry = _fetch_history_entry(query_id=query_id, user_sub=user["sub"])
    except RuntimeError as exc:
        return jsonify({"error": "database_error", "message": str(exc)}), 500

    if entry is None:
        return jsonify({"error": "not_found", "message": "Query not found."}), 404

    sql     = entry.get("sql_generated")
    results = None

    # ── Re-execute stored SQL ─────────────────────────────────────────────
    if execute and sql and not entry.get("blocked"):
        try:
            results = db_service.execute_query(sql)
            logger.info(
                "results.re_executed",
                extra={
                    "query_id": query_id,
                    "rows":     results["row_count"],
                    "user_sub": user["sub"],
                },
            )
        except ValueError as exc:
            logger.warning("results.sql_rejected", extra={"query_id": query_id, "reason": str(exc)})
            return jsonify({"error": "forbidden_sql", "message": str(exc)}), 400
        except RuntimeError as exc:
            logger.error("results.db_error", extra={"query_id": query_id, "error": str(exc)})
            return jsonify({"error": "database_error", "message": "Query execution failed."}), 500

    return jsonify({
        "query_id":    entry["id"],
        "question":    entry["question"],
        "sql":         sql,
        "explanation": entry.get("explanation"),
        "blocked":     bool(entry.get("blocked")),
        "error":       entry.get("error_message"),
        "created_at":  str(entry.get("created_at", "")),
        "results":     results,
    }), 200


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/v1/results/<query_id>/sql
# ─────────────────────────────────────────────────────────────────────────────

@results_bp.route("/results/<query_id>/sql", methods=["GET"])
@cognito_required
@limiter.limit("120 per minute", key_func=_user_key)
def get_result_sql(query_id: str):
    """
    Return only the stored SQL and explanation for a past query.
    No DB execution — fast lookup for frontend SQL preview panels.

    Response:
        {
            "query_id":    str,
            "question":    str,
            "sql":         str | null,
            "explanation": str | null,
            "blocked":     bool,
            "created_at":  str
        }
    """
    user = g.cognito_user

    try:
        entry = _fetch_history_entry(query_id=query_id, user_sub=user["sub"])
    except RuntimeError as exc:
        return jsonify({"error": "database_error", "message": str(exc)}), 500

    if entry is None:
        return jsonify({"error": "not_found", "message": "Query not found."}), 404

    return jsonify({
        "query_id":    entry["id"],
        "question":    entry["question"],
        "sql":         entry.get("sql_generated"),
        "explanation": entry.get("explanation"),
        "blocked":     bool(entry.get("blocked")),
        "created_at":  str(entry.get("created_at", "")),
    }), 200


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/results/<query_id>/re-run
# ─────────────────────────────────────────────────────────────────────────────

@results_bp.route("/results/<query_id>/re-run", methods=["POST"])
@cognito_required
@limiter.limit("20 per minute", key_func=_user_key)
def rerun_query(query_id: str):
    """
    Re-execute the SQL for a past query and save a new history entry.

    This does NOT call Bedrock — it re-uses the stored SQL against the
    current state of the DB. Useful for refreshing a dashboard query.

    Response:
        {
            "query_id":    str,   ← NEW query_id for this execution
            "original_id": str,   ← the query_id you passed in
            "sql":         str,
            "results":     { ... }
        }
    """
    user = g.cognito_user

    try:
        entry = _fetch_history_entry(query_id=query_id, user_sub=user["sub"])
    except RuntimeError as exc:
        return jsonify({"error": "database_error", "message": str(exc)}), 500

    if entry is None:
        return jsonify({"error": "not_found", "message": "Query not found."}), 404

    sql = entry.get("sql_generated")
    if not sql:
        return jsonify({
            "error":   "no_sql",
            "message": "This query has no stored SQL to re-run (it may have been blocked).",
        }), 400

    # ── Execute ───────────────────────────────────────────────────────────
    try:
        results = db_service.execute_query(sql)
    except ValueError as exc:
        return jsonify({"error": "forbidden_sql", "message": str(exc)}), 400
    except RuntimeError as exc:
        return jsonify({"error": "database_error", "message": "Query execution failed."}), 500

    # ── Save as a new history entry (re-run) ──────────────────────────────
    new_query_id = str(uuid.uuid4())
    INSERT_SQL = """
        INSERT INTO query_history
            (id, user_sub, username, question, sql_generated,
             explanation, row_count, blocked, error_message, created_at)
        VALUES
            (:id, :user_sub, :username, :question, :sql_generated,
             :explanation, :row_count, :blocked, :error_message, :created_at)
    """
    try:
        engine = db_service._get_engine()
        with engine.connect() as conn:
            conn.execute(
                text(INSERT_SQL),
                {
                    "id":            new_query_id,
                    "user_sub":      user["sub"],
                    "username":      user["username"],
                    "question":      f"[Re-run] {entry['question']}"[:4000],
                    "sql_generated": sql[:4000],
                    "explanation":   entry.get("explanation", "")[:4000],
                    "row_count":     results["row_count"],
                    "blocked":       0,
                    "error_message": None,
                    "created_at":    datetime.now(timezone.utc),
                },
            )
            conn.commit()
    except Exception as exc:
        logger.error("results.rerun_history_save_failed", extra={"error": str(exc)})
        # Don't fail the response — results were fetched successfully

    logger.info(
        "results.rerun_ok",
        extra={
            "original_id":  query_id,
            "new_query_id": new_query_id,
            "rows":         results["row_count"],
        },
    )

    return jsonify({
        "query_id":    new_query_id,
        "original_id": query_id,
        "sql":         sql,
        "results":     results,
    }), 200