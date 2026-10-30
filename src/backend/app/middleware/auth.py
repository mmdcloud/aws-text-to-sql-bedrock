import functools
import logging
from flask import g, jsonify, request
import requests
from app.config import Config

try:
    from jose import jwt, JWTError
except ImportError:
    import jwt
    JWTError = getattr(jwt, "PyJWTError", Exception)

logger = logging.getLogger(__name__)

_jwks_cache = None


def get_jwks():
    global _jwks_cache
    if not _jwks_cache and Config.COGNITO_JWKS_URL:
        try:
            resp = requests.get(Config.COGNITO_JWKS_URL, timeout=5)
            if resp.status_code == 200:
                _jwks_cache = resp.json()
        except Exception as e:
            logger.warning("Failed to fetch Cognito JWKS", extra={"error": str(e)})
    return _jwks_cache


def cognito_required(f):
    @functools.wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"error": "unauthorized", "message": "Missing or invalid Bearer token"}), 401

        token = auth_header[len("Bearer "):].strip()
        jwks = get_jwks()

        try:
            key = None
            if jwks:
                unverified_header = jwt.get_unverified_header(token)
                kid = unverified_header.get("kid")
                key = next((k for k in jwks.get("keys", []) if k.get("kid") == kid), None)

            if key:
                # If using PyJWT, algorithms must be specified, and key can be algorithm instance or raw
                claims = jwt.decode(
                    token,
                    key,
                    algorithms=["RS256"],
                    audience=Config.COGNITO_CLIENT_ID if Config.COGNITO_CLIENT_ID else None,
                    issuer=f"https://cognito-idp.{Config.AWS_REGION}.amazonaws.com/{Config.COGNITO_USER_POOL_ID}" if Config.COGNITO_USER_POOL_ID else None,
                    options={"verify_aud": bool(Config.COGNITO_CLIENT_ID), "verify_iss": bool(Config.COGNITO_USER_POOL_ID)},
                )
            else:
                # Fallback decoding without signature verification if JWKS is unavailable (e.g. offline dev)
                claims = jwt.decode(token, options={"verify_signature": False})

            g.cognito_user = {
                "sub": claims.get("sub", ""),
                "email": claims.get("email", ""),
                "username": claims.get("cognito:username", claims.get("username", "")),
                "groups": claims.get("cognito:groups", []),
            }
        except JWTError as exc:
            logger.warning("JWT validation failed", extra={"error": str(exc)})
            return jsonify({"error": "unauthorized", "message": f"Invalid token: {str(exc)}"}), 401
        except Exception as exc:
            logger.error("Unexpected error in auth middleware", extra={"error": str(exc)})
            return jsonify({"error": "unauthorized", "message": "Authentication failed"}), 401

        return f(*args, **kwargs)

    return decorated


def require_group(*allowed_groups):
    def decorator(f):
        @functools.wraps(f)
        def wrapper(*args, **kwargs):
            user = getattr(g, "cognito_user", None)
            if not user:
                return jsonify({"error": "unauthorized", "message": "User not authenticated"}), 401

            user_groups = set(user.get("groups", []))
            required_groups = set(allowed_groups)

            if not (user_groups & required_groups):
                return jsonify({
                    "error": "forbidden",
                    "message": f"Requires membership in one of: {list(allowed_groups)}",
                }), 403

            return f(*args, **kwargs)

        return wrapper

    return decorator
