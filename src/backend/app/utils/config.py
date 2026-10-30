import os


class Config:
    # ── Flask ─────────────────────────────────────────────────────────────
    ENV                   = os.getenv("FLASK_ENV", "production")
    DEBUG                 = ENV == "development"
    TESTING               = False
    SECRET_KEY            = os.getenv("SECRET_KEY", os.urandom(32))
    JSON_SORT_KEYS        = False
    MAX_CONTENT_LENGTH    = 1 * 1024 * 1024   # 1 MB request cap

    # ── AWS ───────────────────────────────────────────────────────────────
    AWS_REGION            = os.getenv("AWS_REGION", "us-east-1")

    # ── Cognito ───────────────────────────────────────────────────────────
    # Pool ID  e.g. us-east-1_AbCdEfGhI
    COGNITO_USER_POOL_ID  = os.getenv("COGNITO_USER_POOL_ID", "")
    # App client ID from Terraform: texttosql_client
    COGNITO_CLIENT_ID     = os.getenv("COGNITO_CLIENT_ID", "")
    # JWKS is fetched automatically; cached in auth middleware
    COGNITO_JWKS_URL      = (
        f"https://cognito-idp.{AWS_REGION}.amazonaws.com/"
        f"{COGNITO_USER_POOL_ID}/.well-known/jwks.json"
    )

    # ── Secrets Manager ───────────────────────────────────────────────────
    # Secret names must match what Terraform created
    SM_RDS_SECRET_NAME      = os.getenv("SM_RDS_SECRET_NAME",     "rds-secrets")
    SM_PINECONE_SECRET_NAME = os.getenv("SM_PINECONE_SECRET_NAME", "pinecone-api-key")
    # Cache TTL for secrets (seconds) — alarm warns about SM throttling on cold start
    SM_CACHE_TTL_SECONDS    = int(os.getenv("SM_CACHE_TTL_SECONDS", "300"))  # 5 min

    # ── RDS / MySQL ───────────────────────────────────────────────────────
    DB_HOST               = os.getenv("DB_PATH", "")   # ECS env var name from Terraform
    DB_PORT               = int(os.getenv("DB_PORT", "3306"))
    DB_NAME               = os.getenv("DB_NAME", "db")
    DB_POOL_SIZE          = int(os.getenv("DB_POOL_SIZE",     "5"))
    DB_POOL_MAX_OVERFLOW  = int(os.getenv("DB_POOL_MAX_OVERFLOW", "10"))
    DB_POOL_TIMEOUT       = int(os.getenv("DB_POOL_TIMEOUT",  "30"))
    DB_POOL_RECYCLE       = int(os.getenv("DB_POOL_RECYCLE",  "1800"))
    # Hard cap on rows returned — aligns with Bedrock agent instruction (max 1000 rows)
    DB_RESULT_ROW_LIMIT   = int(os.getenv("DB_RESULT_ROW_LIMIT", "1000"))
    # Query execution timeout (seconds)
    DB_QUERY_TIMEOUT      = int(os.getenv("DB_QUERY_TIMEOUT", "30"))

    # ── Bedrock ───────────────────────────────────────────────────────────
    BEDROCK_AGENT_ID      = os.getenv("BEDROCK_AGENT_ID",      "")
    BEDROCK_AGENT_ALIAS   = os.getenv("BEDROCK_AGENT_ALIAS",   "TSTALIASID")
    # Idle session TTL (seconds) — matches Terraform: 500
    BEDROCK_SESSION_TTL   = int(os.getenv("BEDROCK_SESSION_TTL", "500"))
    BEDROCK_MAX_RETRIES   = int(os.getenv("BEDROCK_MAX_RETRIES", "3"))
    BEDROCK_RETRY_DELAY   = float(os.getenv("BEDROCK_RETRY_DELAY", "1.0"))

    # ── Rate Limiting (Flask-Limiter) ─────────────────────────────────────
    # Stored in-memory (single container) — use Redis in multi-container setups
    RATELIMIT_STORAGE_URI = os.getenv("RATELIMIT_STORAGE_URI", "memory://")
    RATELIMIT_DEFAULT     = os.getenv("RATELIMIT_DEFAULT",     "60 per minute")

    # ── Logging ───────────────────────────────────────────────────────────
    LOG_LEVEL             = os.getenv("LOG_LEVEL", "INFO")
    LOG_FORMAT            = "json"   # structured JSON for CloudWatch


class DevelopmentConfig(Config):
    ENV   = "development"
    DEBUG = True


class TestingConfig(Config):
    TESTING               = True
    SM_CACHE_TTL_SECONDS  = 0        # no caching in tests
    DB_RESULT_ROW_LIMIT   = 10