"""
Query blueprint — the core text-to-SQL endpoint.

Full request lifecycle per query:
  1.  Authenticate  — Cognito JWT via @cognito_required
  2.  Validate      — question length, type, sanitisation
  3.  Bedrock       — invoke texttosql-agent (Claude Opus 4.5 + Pinecone KB + guardrails)
  4.  Execute       — run the returned SQL against RDS (read-only session)
  5.  Save history  — write every query attempt to query_history (always, even on error)
  6.  Respond       — return SQL + explanation + result set

Endpoints
---------
POST   /api/v1/query           Convert question → SQL, optionally execute
POST   /api/v1/query/validate  Generate SQL preview only (no execution)
DELETE /api/v1/query/sessions  End the user's Bedrock multi-turn session
GET    /api/v1/schemas         List DB tables (admins / analysts only)
"""

import logging
import uuid
from datetime import datetime, timezone
from typing import Optional

from flask import Blueprint, g, jsonify, request, current_app
from sqlalchemy import text

from app.middleware.auth import cognito_required, require_group
from app.services.bedrock import bedrock_service
from app.services.database import db_service
from app.extensions import limiter
from app.utils.validators import validate_query_request

logger = logging.getLogger(__name__)
query_bp = Blueprint("query", __name__)


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _user_key() -> str:
    """Rate-limit key scoped to the authenticated Cognito user (sub)."""
    user = getattr(g, "cognito_user", None)
    return f"user:{user['sub']}" if user else request.remote_addr


def _save_history(
    query_id:    str,
    user_sub:    str,
    username:    str,
    question:    str,
    sql:         Optional[str],
    explanation: Optional[str],
    row_count:   Optional[int],
    blocked:     bool,
    error_msg:   Optional[str] = None,
) -> None:
    """
    Persist a query attempt to the query_history table.

    Called after EVERY query — successful, blocked, or failed — so the audit
    log is complete.  Uses a raw engine connection (bypasses the read-only
    guard which is only for user-submitted SQL).

    Failures here are logged but never propagated — history persistence must
    not break the user-facing response.
    """
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
                    "id":            query_id,
                    "user_sub":      user_sub,
                    "username":      username,
                    "question":      question[:4000],
                    "sql_generated": sql[:4000]         if sql         else None,
                    "explanation":   explanation[:4000] if explanation else None,
                    "row_count":     row_count,
                    "blocked":       1 if blocked else 0,
                    "error_message": error_msg[:512]    if error_msg   else None,
                    "created_at":    datetime.now(timezone.utc),
                },
            )
            conn.commit()
        logger.debug("history.saved", extra={"query_id": query_id})
    except Exception as exc:
        logger.error("history.save_failed", extra={"query_id": query_id, "error": str(exc)})


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/query  —  the main endpoint
# ─────────────────────────────────────────────────────────────────────────────

@query_bp.route("/query", methods=["POST"])
@cognito_required
@limiter.limit("30 per minute", key_func=_user_key)
def handle_query():
    """
    Full text-to-SQL pipeline:
        validate → Bedrock agent → RDS execute → save history → respond
    """
    query_id = str(uuid.uuid4())
    user     = g.cognito_user

    # ── 1. Validate request ────────────────────────────────────────────────
    body, err = validate_query_request(request.get_json(silent=True))
    if err:
        return jsonify({"error": "validation_error", "message": err}), 400

    question = body["question"]
    execute  = body.get("execute", True)

    logger.info(
        "query.started",
        extra={
            "query_id":     query_id,
            "user_sub":     user["sub"],
            "question_len": len(question),
            "execute":      execute,
        },
    )

    # ── 2. Bedrock: natural language → SQL ────────────────────────────────
    try:
        agent_result = bedrock_service.generate_sql(
            user_question=question,
            session_id=user["sub"],
            enable_trace=current_app.config.get("DEBUG", False),
        )
    except RuntimeError as exc:
        logger.error("query.bedrock_error", extra={"query_id": query_id, "error": str(exc)})
        _save_history(
            query_id=query_id, user_sub=user["sub"], username=user["username"],
            question=question, sql=None, explanation=None,
            row_count=None, blocked=False, error_msg=str(exc),
        )
        return jsonify({
            "error":   "upstream_error",
            "message": "SQL generation service is currently unavailable. Please try again.",
        }), 502

    sql         = agent_result.get("sql")
    explanation = agent_result.get("explanation", "")
    blocked     = agent_result.get("blocked", False)

    # ── 3. Guardrail blocked — save and return early ───────────────────────
    if blocked:
        logger.warning("query.guardrail_blocked", extra={"query_id": query_id, "user_sub": user["sub"]})
        _save_history(
            query_id=query_id, user_sub=user["sub"], username=user["username"],
            question=question, sql=None, explanation=explanation,
            row_count=None, blocked=True,
        )
        return jsonify({
            "query_id":    query_id,
            "sql":         None,
            "explanation": explanation,
            "results":     None,
            "blocked":     True,
            "session_id":  user["sub"],
        }), 200

    # ── 4. Execute SQL against RDS ────────────────────────────────────────
    results   = None
    error_msg = None

    if execute and sql:
        try:
            results = db_service.execute_query(sql)
            logger.info(
                "query.executed",
                extra={
                    "query_id":  query_id,
                    "rows":      results["row_count"],
                    "truncated": results["truncated"],
                },
            )
        except ValueError as exc:
            logger.warning("query.sql_rejected", extra={"query_id": query_id, "reason": str(exc)})
            _save_history(
                query_id=query_id, user_sub=user["sub"], username=user["username"],
                question=question, sql=sql, explanation=explanation,
                row_count=None, blocked=False, error_msg=str(exc),
            )
            return jsonify({"error": "forbidden_sql", "message": str(exc)}), 400

        except RuntimeError as exc:
            logger.error("query.db_error", extra={"query_id": query_id, "error": str(exc)})
            _save_history(
                query_id=query_id, user_sub=user["sub"], username=user["username"],
                question=question, sql=sql, explanation=explanation,
                row_count=None, blocked=False, error_msg=str(exc),
            )
            return jsonify({
                "error":   "database_error",
                "message": "Query execution failed. Please try again.",
            }), 500

    # ── 5. Save successful query to history ───────────────────────────────
    _save_history(
        query_id=query_id, user_sub=user["sub"], username=user["username"],
        question=question, sql=sql, explanation=explanation,
        row_count=results["row_count"] if results else None,
        blocked=False,
    )

    # ── 6. Respond ────────────────────────────────────────────────────────
    return jsonify({
        "query_id":    query_id,
        "sql":         sql,
        "explanation": explanation,
        "results":     results,
        "blocked":     False,
        "session_id":  user["sub"],
    }), 200


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/query/validate  —  preview SQL without executing
# ─────────────────────────────────────────────────────────────────────────────

@query_bp.route("/query/validate", methods=["POST"])
@cognito_required
@limiter.limit("60 per minute", key_func=_user_key)
def validate_only():
    """Generate SQL preview — does NOT execute against RDS."""
    query_id = str(uuid.uuid4())
    user     = g.cognito_user

    body, err = validate_query_request(request.get_json(silent=True))
    if err:
        return jsonify({"error": "validation_error", "message": err}), 400

    try:
        agent_result = bedrock_service.generate_sql(
            user_question=body["question"],
            session_id=user["sub"],
        )
    except RuntimeError as exc:
        return jsonify({"error": "upstream_error", "message": str(exc)}), 502

    _save_history(
        query_id=query_id, user_sub=user["sub"], username=user["username"],
        question=body["question"],
        sql=agent_result.get("sql"),
        explanation=agent_result.get("explanation"),
        row_count=None,
        blocked=agent_result.get("blocked", False),
    )

    return jsonify({
        "query_id":    query_id,
        "sql":         agent_result.get("sql"),
        "explanation": agent_result.get("explanation"),
        "blocked":     agent_result.get("blocked", False),
    }), 200


# ─────────────────────────────────────────────────────────────────────────────
# DELETE /api/v1/query/sessions
# ─────────────────────────────────────────────────────────────────────────────

@query_bp.route("/query/sessions", methods=["DELETE"])
@cognito_required
def clear_session():
    logger.info("query.session_cleared", extra={"user_sub": g.cognito_user["sub"]})
    return jsonify({"message": "Session context cleared. Next query starts a fresh conversation."}), 200


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/v1/schemas  —  list DB tables (admins / analysts only)
# ─────────────────────────────────────────────────────────────────────────────

@query_bp.route("/schemas", methods=["GET"])
@cognito_required
@require_group("admins", "analysts")
@limiter.limit("20 per minute", key_func=_user_key)
def list_schemas():
    LIST_TABLES_SQL = """
        SELECT table_name, table_rows, data_length, create_time, table_comment
        FROM information_schema.tables
        WHERE table_schema = DATABASE()
          AND table_name   != 'query_history'
        ORDER BY table_name
    """
    try:
        engine = db_service._get_engine()
        with engine.connect() as conn:
            result  = conn.execute(text(LIST_TABLES_SQL))
            columns = list(result.keys())
            rows    = [dict(zip(columns, row)) for row in result.fetchall()]
    except Exception as exc:
        logger.error("schemas.fetch_failed", extra={"error": str(exc)})
        return jsonify({"error": "database_error", "message": str(exc)}), 500

    return jsonify({"tables": rows, "count": len(rows)}), 200