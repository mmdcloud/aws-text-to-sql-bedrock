"""
Auth blueprint — all Cognito authentication endpoints.

Matches the Terraform Cognito configuration exactly:
  - Pool           : text-to-sql-users
  - Client         : texttosql_client  (public, no secret)
  - Username attr  : email
  - Auth flows     : ALLOW_USER_PASSWORD_AUTH, ALLOW_REFRESH_TOKEN_AUTH
  - Verification   : CONFIRM_WITH_CODE (email OTP)
  - Password policy: min 8, upper + lower + number + symbol required

Endpoints
---------
POST /api/v1/auth/signup               Register a new user
POST /api/v1/auth/confirm              Verify email with OTP code
POST /api/v1/auth/resend-code          Re-send OTP to email
POST /api/v1/auth/login                Authenticate → tokens
POST /api/v1/auth/refresh              Exchange refresh token → new access token
POST /api/v1/auth/logout               Globally invalidate all tokens
POST /api/v1/auth/forgot-password      Trigger reset code email
POST /api/v1/auth/reset-password       Complete reset with code + new password
POST /api/v1/auth/change-password      Change password (authenticated users)
GET  /api/v1/auth/me                   Get current user profile
"""

import logging
import re

from flask import Blueprint, g, jsonify, request

from app.middleware.auth import cognito_required
from app.services.cognito import cognito_service, CognitoError
from app.extensions import limiter

logger  = logging.getLogger(__name__)
auth_bp = Blueprint("auth", __name__)

# ── Password policy regex (mirrors Terraform config) ─────────────────────────
_PASSWORD_RE = re.compile(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]).{8,}$'
)
_EMAIL_RE = re.compile(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')

# ── Rate limit keys ───────────────────────────────────────────────────────────

def _ip_key() -> str:
    return f"ip:{request.remote_addr}"

def _email_key() -> str:
    """Per-email rate limit — prevents targeted brute force."""
    body = request.get_json(silent=True) or {}
    email = body.get("email", request.remote_addr)
    return f"email:{email.lower()}"


# ─────────────────────────────────────────────────────────────────────────────
# Validators
# ─────────────────────────────────────────────────────────────────────────────

def _validate_email(email: str) -> str | None:
    """Returns error message or None."""
    if not email or not isinstance(email, str):
        return "Email is required."
    if not _EMAIL_RE.match(email.strip()):
        return "Invalid email address."
    if len(email) > 254:
        return "Email address is too long."
    return None

def _validate_password(password: str) -> str | None:
    """Returns error message or None. Mirrors Terraform password policy."""
    if not password or not isinstance(password, str):
        return "Password is required."
    if not _PASSWORD_RE.match(password):
        return (
            "Password must be at least 8 characters and contain "
            "an uppercase letter, lowercase letter, number, and special character."
        )
    return None

def _validate_code(code: str) -> str | None:
    if not code or not isinstance(code, str):
        return "Verification code is required."
    if not code.strip().isdigit() or len(code.strip()) != 6:
        return "Verification code must be a 6-digit number."
    return None

def _require_json_fields(body, *fields):
    """Returns (body_dict, error_str). Checks body exists and all fields present."""
    if not body:
        return None, "Request body is required (JSON)."
    missing = [f for f in fields if not body.get(f)]
    if missing:
        return None, f"Missing required fields: {', '.join(missing)}."
    return body, None


# ─────────────────────────────────────────────────────────────────────────────
# Error response helper
# ─────────────────────────────────────────────────────────────────────────────

def _cognito_error_response(exc: CognitoError):
    return jsonify({"error": exc.code, "message": exc.message}), exc.status


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/auth/signup
# ─────────────────────────────────────────────────────────────────────────────

@auth_bp.route("/auth/signup", methods=["POST"])
@limiter.limit("5 per minute", key_func=_ip_key)
@limiter.limit("3 per hour",   key_func=_email_key)
def signup():
    """
    Register a new user account.

    Request:  { "email": str, "password": str }
    Response: { "message": str, "destination": str, "user_sub": str }

    On success, Cognito sends an OTP to the email.
    The user must then call /confirm with the code before they can log in.
    """
    body, err = _require_json_fields(request.get_json(silent=True), "email", "password")
    if err:
        return jsonify({"error": "validation_error", "message": err}), 400

    email    = body["email"].strip().lower()
    password = body["password"]

    if err := _validate_email(email):
        return jsonify({"error": "validation_error", "message": err}), 400
    if err := _validate_password(password):
        return jsonify({"error": "validation_error", "message": err}), 400

    try:
        result = cognito_service.sign_up(email=email, password=password)
    except CognitoError as exc:
        return _cognito_error_response(exc)

    logger.info("auth.signup_ok", extra={"email": email, "user_sub": result["user_sub"]})

    return jsonify({
        "message":     "Account created. Please check your email for a verification code.",
        "destination": result["destination"],
        "user_sub":    result["user_sub"],
        "confirmed":   result["confirmed"],
    }), 201


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/auth/confirm
# ─────────────────────────────────────────────────────────────────────────────

@auth_bp.route("/auth/confirm", methods=["POST"])
@limiter.limit("10 per minute", key_func=_ip_key)
@limiter.limit("10 per hour",   key_func=_email_key)
def confirm():
    """
    Verify email address with the 6-digit OTP from the verification email.
    Subject: "Verify your email for TextToSQL"

    Request:  { "email": str, "code": str }
    Response: { "message": str }
    """
    body, err = _require_json_fields(request.get_json(silent=True), "email", "code")
    if err:
        return jsonify({"error": "validation_error", "message": err}), 400

    email = body["email"].strip().lower()
    code  = body["code"].strip()

    if err := _validate_email(email):
        return jsonify({"error": "validation_error", "message": err}), 400
    if err := _validate_code(code):
        return jsonify({"error": "validation_error", "message": err}), 400

    try:
        cognito_service.confirm_sign_up(email=email, code=code)
    except CognitoError as exc:
        return _cognito_error_response(exc)

    logger.info("auth.confirm_ok", extra={"email": email})

    return jsonify({"message": "Email verified successfully. You can now sign in."}), 200


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/auth/resend-code
# ─────────────────────────────────────────────────────────────────────────────

@auth_bp.route("/auth/resend-code", methods=["POST"])
@limiter.limit("3 per minute",  key_func=_ip_key)
@limiter.limit("5 per hour",    key_func=_email_key)
def resend_code():
    """
    Re-send the email OTP for unconfirmed users.

    Request:  { "email": str }
    Response: { "message": str, "destination": str }
    """
    body, err = _require_json_fields(request.get_json(silent=True), "email")
    if err:
        return jsonify({"error": "validation_error", "message": err}), 400

    email = body["email"].strip().lower()
    if err := _validate_email(email):
        return jsonify({"error": "validation_error", "message": err}), 400

    try:
        destination = cognito_service.resend_confirmation_code(email=email)
    except CognitoError as exc:
        return _cognito_error_response(exc)

    return jsonify({
        "message":     f"Verification code resent to {destination}.",
        "destination": destination,
    }), 200


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/auth/login
# ─────────────────────────────────────────────────────────────────────────────

@auth_bp.route("/auth/login", methods=["POST"])
@limiter.limit("10 per minute", key_func=_ip_key)
@limiter.limit("20 per hour",   key_func=_email_key)
def login():
    """
    Authenticate with email and password.
    Uses USER_PASSWORD_AUTH flow (ALLOW_USER_PASSWORD_AUTH in Terraform).

    Request:
        { "email": str, "password": str }

    Response:
        {
            "access_token":  str,   ← send as Bearer token on all /api/v1/* calls
            "id_token":      str,   ← contains user profile claims
            "refresh_token": str,   ← store securely; use to refresh access token
            "expires_in":    int,   ← seconds until access_token expires (3600)
            "token_type":    "Bearer"
        }
    """
    body, err = _require_json_fields(request.get_json(silent=True), "email", "password")
    if err:
        return jsonify({"error": "validation_error", "message": err}), 400

    email    = body["email"].strip().lower()
    password = body["password"]

    if err := _validate_email(email):
        return jsonify({"error": "validation_error", "message": err}), 400
    if not password:
        return jsonify({"error": "validation_error", "message": "Password is required."}), 400

    try:
        tokens = cognito_service.sign_in(email=email, password=password)
    except CognitoError as exc:
        return _cognito_error_response(exc)

    logger.info("auth.login_ok", extra={"email": email})

    return jsonify({
        "access_token":  tokens.access_token,
        "id_token":      tokens.id_token,
        "refresh_token": tokens.refresh_token,
        "expires_in":    tokens.expires_in,
        "token_type":    "Bearer",
    }), 200


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/auth/refresh
# ─────────────────────────────────────────────────────────────────────────────

@auth_bp.route("/auth/refresh", methods=["POST"])
@limiter.limit("30 per minute", key_func=_ip_key)
def refresh():
    """
    Exchange a valid RefreshToken for a new AccessToken + IdToken.
    Uses REFRESH_TOKEN_AUTH flow (ALLOW_REFRESH_TOKEN_AUTH in Terraform).

    Request:  { "refresh_token": str }
    Response: { "access_token": str, "id_token": str, "expires_in": int, "token_type": "Bearer" }

    Note: Cognito does NOT return a new RefreshToken here — the original remains valid.
    """
    body, err = _require_json_fields(request.get_json(silent=True), "refresh_token")
    if err:
        return jsonify({"error": "validation_error", "message": err}), 400

    try:
        tokens = cognito_service.refresh_tokens(refresh_token=body["refresh_token"])
    except CognitoError as exc:
        return _cognito_error_response(exc)

    return jsonify({
        "access_token": tokens.access_token,
        "id_token":     tokens.id_token,
        "expires_in":   tokens.expires_in,
        "token_type":   "Bearer",
    }), 200


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/auth/logout
# ─────────────────────────────────────────────────────────────────────────────

@auth_bp.route("/auth/logout", methods=["POST"])
@cognito_required
def logout():
    """
    Globally sign out — invalidates ALL tokens for this user across all sessions.
    The client must also delete locally stored tokens.

    Requires: Authorization: Bearer <access_token>
    Response: { "message": str }
    """
    auth_header = request.headers.get("Authorization", "")
    access_token = auth_header[len("Bearer "):]

    try:
        cognito_service.sign_out(access_token=access_token)
    except CognitoError as exc:
        # Token already expired — treat as success (idempotent logout)
        if exc.code == "NotAuthorizedException":
            return jsonify({"message": "Signed out successfully."}), 200
        return _cognito_error_response(exc)

    logger.info("auth.logout_ok", extra={"user_sub": g.cognito_user["sub"]})

    return jsonify({"message": "Signed out successfully. All sessions have been invalidated."}), 200


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/auth/forgot-password
# ─────────────────────────────────────────────────────────────────────────────

@auth_bp.route("/auth/forgot-password", methods=["POST"])
@limiter.limit("3 per minute", key_func=_ip_key)
@limiter.limit("5 per hour",   key_func=_email_key)
def forgot_password():
    """
    Initiate password reset — Cognito sends an OTP to the user's email.
    Always returns 200 even if the email doesn't exist (prevents enumeration).

    Request:  { "email": str }
    Response: { "message": str, "destination": str }
    """
    body, err = _require_json_fields(request.get_json(silent=True), "email")
    if err:
        return jsonify({"error": "validation_error", "message": err}), 400

    email = body["email"].strip().lower()
    if err := _validate_email(email):
        return jsonify({"error": "validation_error", "message": err}), 400

    try:
        destination = cognito_service.forgot_password(email=email)
    except CognitoError as exc:
        if exc.code in ("LimitExceededException", "TooManyRequestsException"):
            return _cognito_error_response(exc)
        # All other errors return 200 to prevent email enumeration
        return jsonify({
            "message":     "If an account exists for this email, a reset code has been sent.",
            "destination": "your email",
        }), 200

    return jsonify({
        "message":     f"Password reset code sent to {destination}.",
        "destination": destination,
    }), 200


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/auth/reset-password
# ─────────────────────────────────────────────────────────────────────────────

@auth_bp.route("/auth/reset-password", methods=["POST"])
@limiter.limit("5 per minute",  key_func=_ip_key)
@limiter.limit("10 per hour",   key_func=_email_key)
def reset_password():
    """
    Complete the forgot-password flow.

    Request:  { "email": str, "code": str, "new_password": str }
    Response: { "message": str }
    """
    body, err = _require_json_fields(
        request.get_json(silent=True), "email", "code", "new_password"
    )
    if err:
        return jsonify({"error": "validation_error", "message": err}), 400

    email        = body["email"].strip().lower()
    code         = body["code"].strip()
    new_password = body["new_password"]

    if err := _validate_email(email):
        return jsonify({"error": "validation_error", "message": err}), 400
    if err := _validate_code(code):
        return jsonify({"error": "validation_error", "message": err}), 400
    if err := _validate_password(new_password):
        return jsonify({"error": "validation_error", "message": err}), 400

    try:
        cognito_service.confirm_forgot_password(
            email=email, code=code, new_password=new_password
        )
    except CognitoError as exc:
        return _cognito_error_response(exc)

    logger.info("auth.reset_password_ok", extra={"email": email})

    return jsonify({"message": "Password reset successfully. You can now sign in."}), 200


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/auth/change-password
# ─────────────────────────────────────────────────────────────────────────────

@auth_bp.route("/auth/change-password", methods=["POST"])
@cognito_required
@limiter.limit("5 per minute", key_func=_ip_key)
def change_password():
    """
    Change password for a signed-in user.
    Requires: Authorization: Bearer <access_token>

    Request:  { "old_password": str, "new_password": str }
    Response: { "message": str }
    """
    body, err = _require_json_fields(
        request.get_json(silent=True), "old_password", "new_password"
    )
    if err:
        return jsonify({"error": "validation_error", "message": err}), 400

    if err := _validate_password(body["new_password"]):
        return jsonify({"error": "validation_error", "message": err}), 400

    if body["old_password"] == body["new_password"]:
        return jsonify({
            "error": "validation_error",
            "message": "New password must be different from the current password.",
        }), 400

    access_token = request.headers["Authorization"][len("Bearer "):]

    try:
        cognito_service.change_password(
            access_token=access_token,
            old_password=body["old_password"],
            new_password=body["new_password"],
        )
    except CognitoError as exc:
        return _cognito_error_response(exc)

    logger.info("auth.change_password_ok", extra={"user_sub": g.cognito_user["sub"]})

    return jsonify({"message": "Password changed successfully."}), 200


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/v1/auth/me
# ─────────────────────────────────────────────────────────────────────────────

@auth_bp.route("/auth/me", methods=["GET"])
@cognito_required
def me():
    """
    Return the authenticated user's profile from the Cognito token claims.
    No extra Cognito API call needed — claims are already decoded by @cognito_required.

    Requires: Authorization: Bearer <access_token>
    Response:
        {
            "sub":      str,
            "email":    str,
            "username": str,
            "groups":   list[str]
        }
    """
    user = g.cognito_user
    return jsonify({
        "sub":      user["sub"],
        "email":    user["email"],
        "username": user["username"],
        "groups":   user["groups"],
    }), 200