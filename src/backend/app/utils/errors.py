"""Global Flask error handlers — consistent JSON error envelope."""

import logging
from flask import Flask, jsonify
from werkzeug.exceptions import HTTPException

logger = logging.getLogger(__name__)


def register_error_handlers(app: Flask) -> None:

    @app.errorhandler(400)
    def bad_request(exc):
        return jsonify({"error": "bad_request", "message": str(exc)}), 400

    @app.errorhandler(401)
    def unauthorized(exc):
        return jsonify({"error": "unauthorized", "message": "Authentication required."}), 401

    @app.errorhandler(403)
    def forbidden(exc):
        return jsonify({"error": "forbidden", "message": "Access denied."}), 403

    @app.errorhandler(404)
    def not_found(exc):
        return jsonify({"error": "not_found", "message": "Resource not found."}), 404

    @app.errorhandler(405)
    def method_not_allowed(exc):
        return jsonify({"error": "method_not_allowed", "message": str(exc)}), 405

    @app.errorhandler(429)
    def rate_limited(exc):
        return jsonify({
            "error":   "rate_limited",
            "message": "Too many requests. Please slow down.",
        }), 429

    @app.errorhandler(500)
    def internal_error(exc):
        logger.error("unhandled_exception", exc_info=exc)
        return jsonify({
            "error":   "internal_server_error",
            "message": "An unexpected error occurred.",
        }), 500

    @app.errorhandler(HTTPException)
    def handle_http_exception(exc):
        return jsonify({"error": exc.name.lower().replace(" ", "_"), "message": exc.description}), exc.code