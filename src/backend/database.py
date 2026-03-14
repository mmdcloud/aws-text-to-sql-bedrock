"""
MySQL RDS service.

• Uses SQLAlchemy connection pool — avoids the connection-per-request pattern
  that would exhaust the RDS `max_connections = 1000` parameter quickly.
• Credentials fetched from Secrets Manager (cached — no cold-start throttle).
• Enforces read-only SQL at the application layer as a secondary defence,
  complementing the Bedrock agent instruction and guardrails.
• Applies DB_QUERY_TIMEOUT and DB_RESULT_ROW_LIMIT from config.
"""

import logging
import re
from contextlib import contextmanager
from typing import Any, Dict, List

import sqlalchemy as sa
from sqlalchemy import event, pool, text
from sqlalchemy.exc import OperationalError, ProgrammingError, SQLAlchemyError
from flask import current_app

from app.services.secrets import secrets_service

logger = logging.getLogger(__name__)

# DML / DDL patterns that should never reach the DB — belt-and-suspenders check
_FORBIDDEN_PATTERN = re.compile(
    r"\b(INSERT|UPDATE|DELETE|DROP|TRUNCATE|ALTER|CREATE|GRANT|REVOKE"
    r"|EXEC|EXECUTE|CALL|REPLACE|MERGE|LOAD\s+DATA|IMPORT|EXPORT"
    r"|INFORMATION_SCHEMA|SHOW\s+VARIABLES|SHOW\s+GRANTS)\b",
    re.IGNORECASE,
)


class DatabaseService:

    def __init__(self):
        self._engine: sa.Engine | None = None

    # ── Engine ────────────────────────────────────────────────────────────

    def _build_engine(self) -> sa.Engine:
        cfg = current_app.config
        creds = secrets_service.get_rds_credentials()

        url = sa.engine.URL.create(
            drivername="mysql+pymysql",
            username=creds["username"],
            password=creds["password"],
            host=cfg["DB_HOST"],
            port=cfg["DB_PORT"],
            database=cfg["DB_NAME"],
            query={"charset": "utf8mb4"},
        )

        connect_args = {
            "connect_timeout": 10,
            "read_timeout":    cfg["DB_QUERY_TIMEOUT"],
            "write_timeout":   cfg["DB_QUERY_TIMEOUT"],
        }

        engine = sa.create_engine(
            url,
            pool_size=cfg["DB_POOL_SIZE"],
            max_overflow=cfg["DB_POOL_MAX_OVERFLOW"],
            pool_timeout=cfg["DB_POOL_TIMEOUT"],
            pool_recycle=cfg["DB_POOL_RECYCLE"],
            pool_pre_ping=True,          # drops stale connections before use
            poolclass=pool.QueuePool,
            connect_args=connect_args,
            echo=cfg.get("DEBUG", False),
        )

        # Force read-only session at the MySQL level after every connect
        @event.listens_for(engine, "connect")
        def set_readonly(dbapi_conn, _connection_record):
            cursor = dbapi_conn.cursor()
            cursor.execute("SET SESSION TRANSACTION READ ONLY")
            cursor.execute("SET SESSION sql_mode='STRICT_ALL_TABLES'")
            cursor.close()

        logger.info("database.engine_created", extra={"host": cfg["DB_HOST"], "db": cfg["DB_NAME"]})
        return engine

    def _get_engine(self) -> sa.Engine:
        if self._engine is None:
            self._engine = self._build_engine()
        return self._engine

    # ── Read-only guard ───────────────────────────────────────────────────

    @staticmethod
    def _assert_readonly(sql: str) -> None:
        """
        Secondary application-level guard — the Bedrock agent + guardrails are the
        primary controls, but this adds defence-in-depth before any SQL touches the DB.
        """
        stripped = sql.strip()
        if not stripped.upper().startswith("SELECT"):
            raise ValueError(
                "Only SELECT statements are permitted. "
                "Received a statement starting with a non-SELECT keyword."
            )
        if _FORBIDDEN_PATTERN.search(stripped):
            raise ValueError(
                "Query contains forbidden SQL keywords. "
                "Only read-only SELECT operations are allowed."
            )

    # ── Context manager ───────────────────────────────────────────────────

    @contextmanager
    def _connection(self):
        engine = self._get_engine()
        conn = engine.connect()
        try:
            yield conn
        finally:
            conn.close()

    # ── Public API ────────────────────────────────────────────────────────

    def execute_query(self, sql: str) -> Dict[str, Any]:
        """
        Execute a read-only SQL query and return columns + rows.

        Returns:
            {
                "columns": ["col1", "col2", ...],
                "rows":    [[val, val], ...],
                "row_count": int,
                "truncated": bool   # True if DB_RESULT_ROW_LIMIT was hit
            }

        Raises:
            ValueError       — on forbidden SQL
            RuntimeError     — on DB connectivity or execution errors
        """
        cfg = current_app.config
        row_limit = cfg["DB_RESULT_ROW_LIMIT"]

        self._assert_readonly(sql)

        # Inject LIMIT clause only if not already present
        normalised = sql.rstrip("; \t\n")
        if not re.search(r"\bLIMIT\b", normalised, re.IGNORECASE):
            # fetch one extra row so we can detect truncation
            limited_sql = f"{normalised} LIMIT {row_limit + 1}"
        else:
            limited_sql = normalised

        logger.info("database.executing_query", extra={"sql_preview": normalised[:200]})

        try:
            with self._connection() as conn:
                result = conn.execute(text(limited_sql))
                columns: List[str] = list(result.keys())
                all_rows = result.fetchall()
        except (OperationalError, ProgrammingError) as exc:
            logger.error("database.query_failed", extra={"error": str(exc)})
            raise RuntimeError(f"Query execution failed: {exc}") from exc
        except SQLAlchemyError as exc:
            logger.error("database.unexpected_error", extra={"error": str(exc)})
            raise RuntimeError("Unexpected database error occurred.") from exc

        truncated = len(all_rows) > row_limit
        rows = [list(r) for r in all_rows[:row_limit]]

        logger.info(
            "database.query_complete",
            extra={"rows": len(rows), "truncated": truncated},
        )
        return {
            "columns":   columns,
            "rows":      rows,
            "row_count": len(rows),
            "truncated": truncated,
        }

    def health_check(self) -> bool:
        """Ping the DB — used by the /health endpoint."""
        try:
            with self._connection() as conn:
                conn.execute(text("SELECT 1"))
            return True
        except Exception as exc:
            logger.warning("database.health_check_failed", extra={"error": str(exc)})
            return False

    def dispose(self) -> None:
        """Close all pool connections — call on app shutdown."""
        if self._engine:
            self._engine.dispose()
            self._engine = None


db_service = DatabaseService()