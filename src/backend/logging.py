"""
Structured JSON logging for CloudWatch.

Log groups provisioned in Terraform:
  /aws/ecs/backend-ecs  (retention: 90 days)

Each log line is a JSON object so CloudWatch Logs Insights can parse
fields like `level`, `message`, `correlation_id`, `user_sub` directly.
"""

import json
import logging
import traceback
from datetime import datetime, timezone
from flask import Flask


class _JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        log: dict = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level":     record.levelname,
            "logger":    record.name,
            "message":   record.getMessage(),
        }

        # Merge any extra= kwargs passed to the logger
        for key, value in record.__dict__.items():
            if key not in (
                "args", "exc_info", "exc_text", "filename", "funcName",
                "levelname", "levelno", "lineno", "message", "module",
                "msecs", "msg", "name", "pathname", "process",
                "processName", "relativeCreated", "stack_info",
                "thread", "threadName", "created",
            ):
                log[key] = value

        if record.exc_info:
            log["exception"] = traceback.format_exception(*record.exc_info)

        return json.dumps(log, default=str)


def configure_logging(app: Flask) -> None:
    level = getattr(logging, app.config.get("LOG_LEVEL", "INFO").upper(), logging.INFO)

    handler = logging.StreamHandler()
    handler.setFormatter(_JsonFormatter())

    root = logging.getLogger()
    root.setLevel(level)
    root.handlers = [handler]

    # Suppress noisy third-party loggers
    logging.getLogger("botocore").setLevel(logging.WARNING)
    logging.getLogger("boto3").setLevel(logging.WARNING)
    logging.getLogger("urllib3").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(
        logging.INFO if app.config.get("DEBUG") else logging.WARNING
    )