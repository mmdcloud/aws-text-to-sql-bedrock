"""
Secrets Manager service with in-memory TTL cache.

The CloudWatch alarm `secretsmanager_throttle_alarm` fires when GetSecretValue
is throttled.  ECS tasks fetch both rds_secrets and pinecone_api_key at cold
start — caching for 5 minutes prevents repeated calls and eliminates throttle
risk on rolling deployments.
"""

import json
import logging
import time
from dataclasses import dataclass, field
from typing import Any, Dict, Optional

import boto3
from botocore.exceptions import ClientError
from flask import current_app

logger = logging.getLogger(__name__)


@dataclass
class _CacheEntry:
    value: Any
    expires_at: float


class SecretsManagerService:
    """Thread-safe, TTL-backed Secrets Manager wrapper."""

    def __init__(self):
        self._cache: Dict[str, _CacheEntry] = {}
        self._client = None

    # ── Private helpers ───────────────────────────────────────────────────

    def _get_client(self):
        if self._client is None:
            self._client = boto3.client(
                "secretsmanager",
                region_name=current_app.config["AWS_REGION"],
            )
        return self._client

    def _is_expired(self, entry: _CacheEntry) -> bool:
        ttl = current_app.config["SM_CACHE_TTL_SECONDS"]
        if ttl == 0:
            return True
        return time.monotonic() > entry.expires_at

    # ── Public API ────────────────────────────────────────────────────────

    def get_secret(self, secret_name: str) -> Dict[str, Any]:
        """
        Fetch and JSON-parse a secret.  Returns cached value if within TTL.
        Raises RuntimeError if the secret cannot be retrieved.
        """
        cached = self._cache.get(secret_name)
        if cached and not self._is_expired(cached):
            logger.debug("secrets_manager.cache_hit", extra={"secret": secret_name})
            return cached.value

        logger.info("secrets_manager.fetching", extra={"secret": secret_name})
        try:
            response = self._get_client().get_secret_value(SecretId=secret_name)
            raw = response.get("SecretString") or response.get("SecretBinary", b"").decode()
            value = json.loads(raw)
        except ClientError as exc:
            code = exc.response["Error"]["Code"]
            logger.error(
                "secrets_manager.fetch_failed",
                extra={"secret": secret_name, "error_code": code},
            )
            raise RuntimeError(f"Could not retrieve secret '{secret_name}': {code}") from exc

        ttl = current_app.config["SM_CACHE_TTL_SECONDS"]
        self._cache[secret_name] = _CacheEntry(
            value=value,
            expires_at=time.monotonic() + ttl,
        )
        return value

    def get_rds_credentials(self) -> Dict[str, str]:
        """Returns {'username': ..., 'password': ...}"""
        name = current_app.config["SM_RDS_SECRET_NAME"]
        return self.get_secret(name)

    def get_pinecone_api_key(self) -> str:
        """Returns the raw Pinecone API key string."""
        name = current_app.config["SM_PINECONE_SECRET_NAME"]
        return self.get_secret(name)["api_key"]

    def invalidate(self, secret_name: Optional[str] = None) -> None:
        """Force-evict one or all cached secrets (useful after rotation)."""
        if secret_name:
            self._cache.pop(secret_name, None)
        else:
            self._cache.clear()


# Module-level singleton — one instance per ECS task
secrets_service = SecretsManagerService()