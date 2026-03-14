"""Input validation utilities."""

from typing import Any, Dict, Optional, Tuple


def validate_query_request(
    body: Optional[Dict[str, Any]],
) -> Tuple[Optional[Dict], Optional[str]]:
    """
    Validate the POST /query request body.

    Returns (parsed_body, None) on success.
    Returns (None, error_message) on failure.
    """
    if not body:
        return None, "Request body is required (JSON)."

    question = body.get("question")
    if not question:
        return None, "'question' field is required."
    if not isinstance(question, str):
        return None, "'question' must be a string."

    question = question.strip()
    if len(question) < 3:
        return None, "'question' is too short."
    if len(question) > 2000:
        return None, "'question' must not exceed 2000 characters."

    execute = body.get("execute", True)
    if not isinstance(execute, bool):
        return None, "'execute' must be a boolean."

    return {"question": question, "execute": execute}, None