"""
Bedrock Agent service.

Invokes the `texttosql-agent` (Amazon Titan Text Premier) with the Pinecone knowledge
base and guardrails configured in Terraform.

Key design decisions:
• Session IDs are per-user (Cognito sub) — the agent can maintain multi-turn
  context within the Bedrock idle TTL (500 s from Terraform config).
• Exponential backoff on ThrottlingException — aligns with the
  `bedrock_throttles` CloudWatch alarm threshold of 5 in 5 minutes.
• The raw agent response is parsed to extract the SQL statement and any
  accompanying explanation so they can be stored and returned separately.
"""

import json
import logging
import re
import time
from typing import Dict, Any, Optional

import boto3
from botocore.exceptions import ClientError
from flask import current_app

logger = logging.getLogger(__name__)

# Matches a SQL code block returned by the agent (```sql … ``` or bare SELECT)
_SQL_BLOCK_RE = re.compile(
    r"```(?:sql)?\s*(SELECT[\s\S]+?)```",
    re.IGNORECASE,
)
_BARE_SELECT_RE = re.compile(
    r"(SELECT\b[\s\S]+?;)",
    re.IGNORECASE,
)


class BedrockAgentService:

    def __init__(self):
        self._client = None

    # ── AWS client ────────────────────────────────────────────────────────

    def _get_client(self):
        if self._client is None:
            self._client = boto3.client(
                "bedrock-agent-runtime",
                region_name=current_app.config["AWS_REGION"],
            )
        return self._client

    # ── Response parsing ──────────────────────────────────────────────────

    @staticmethod
    def _extract_sql(agent_text: str) -> Optional[str]:
        """
        Pull the SQL statement out of the agent's response text.
        The agent is instructed to wrap SQL in a ```sql``` block.
        Falls back to the first bare SELECT … ; if no block is found.
        """
        match = _SQL_BLOCK_RE.search(agent_text)
        if match:
            return match.group(1).strip()
        match = _BARE_SELECT_RE.search(agent_text)
        if match:
            return match.group(1).strip()
        return None

    @staticmethod
    def _parse_event_stream(stream) -> str:
        """Collect all chunk bytes from the agent's streaming response."""
        chunks = []
        for event in stream:
            if "chunk" in event:
                payload = event["chunk"].get("bytes", b"")
                if payload:
                    chunks.append(payload.decode("utf-8", errors="replace"))
            elif "trace" in event:
                # Trace events give orchestration visibility — log at debug
                trace = event["trace"].get("trace", {})
                logger.debug("bedrock.trace", extra={"trace": json.dumps(trace)[:500]})
        return "".join(chunks)

    # ── Retry helper ──────────────────────────────────────────────────────

    def _invoke_with_retry(
        self,
        agent_id: str,
        alias_id: str,
        session_id: str,
        user_input: str,
        enable_trace: bool,
    ) -> str:
        max_retries = current_app.config["BEDROCK_MAX_RETRIES"]
        base_delay  = current_app.config["BEDROCK_RETRY_DELAY"]
        last_exc    = None

        for attempt in range(max_retries):
            try:
                response = self._get_client().invoke_agent(
                    agentId=agent_id,
                    agentAliasId=alias_id,
                    sessionId=session_id,
                    inputText=user_input,
                    enableTrace=enable_trace,
                    sessionState={},
                )
                return self._parse_event_stream(response["completion"])

            except ClientError as exc:
                code = exc.response["Error"]["Code"]
                if code == "ThrottlingException":
                    delay = base_delay * (2 ** attempt)
                    logger.warning(
                        "bedrock.throttled",
                        extra={"attempt": attempt + 1, "retry_in": delay},
                    )
                    time.sleep(delay)
                    last_exc = exc
                    continue
                # Non-retryable errors — surface immediately
                logger.error("bedrock.invoke_failed", extra={"error_code": code, "error": str(exc)})
                raise RuntimeError(f"Bedrock agent invocation failed: {code}") from exc

        raise RuntimeError(
            f"Bedrock agent throttled after {max_retries} retries."
        ) from last_exc

    def _invoke_foundation_model(self, user_question: str, session_id: str) -> Dict[str, Any]:
        """
        Direct invocation of Amazon Titan Text Premier via bedrock-runtime.
        Bypasses Bedrock Agents Classic (which is in AWS Maintenance Mode for new accounts).
        """
        runtime = boto3.client(
            "bedrock-runtime",
            region_name=current_app.config.get("AWS_REGION", "us-east-1"),
        )
        prompt = (
            "You are a specialized SQL generation assistant. Convert the following natural language query "
            "into a safe, read-only SELECT SQL query for MySQL.\n\n"
            "Rules:\n"
            "- ONLY generate SELECT statements (never DROP, DELETE, UPDATE, INSERT, ALTER)\n"
            "- Wrap the SQL statement in a ```sql ... ``` block\n"
            "- Include a brief explanation of what the query does below the SQL block\n\n"
            f"User Question: {user_question}\n"
        )
        body = json.dumps({
            "inputText": prompt,
            "textGenerationConfig": {
                "maxTokenCount": 2048,
                "temperature": 0.0,
                "topP": 0.9,
                "stopSequences": [],
            },
        })
        logger.info("bedrock.invoking_foundation_model", extra={"model_id": "amazon.titan-text-premier-v1:0"})
        response = runtime.invoke_model(
            modelId="amazon.titan-text-premier-v1:0",
            body=body,
            contentType="application/json",
            accept="application/json",
        )
        payload = json.loads(response["body"].read().decode("utf-8"))
        results = payload.get("results", [{}])[0]
        output_text = results.get("outputText", "")
        sql = self._extract_sql(output_text)
        return {
            "sql":         sql,
            "explanation": output_text,
            "session_id":  session_id,
            "blocked":     False,
        }

    # ── Public API ────────────────────────────────────────────────────────

    def generate_sql(
        self,
        user_question: str,
        session_id: str,
        enable_trace: bool = False,
    ) -> Dict[str, Any]:
        """
        Send a natural language question to Bedrock to generate SQL.
        Falls back to direct Titan Premier foundation model if Bedrock Agent is disabled or unavailable.
        """
        cfg      = current_app.config
        agent_id = cfg.get("BEDROCK_AGENT_ID", "")
        alias_id = cfg.get("BEDROCK_AGENT_ALIAS", "TSTALIASID")

        # If agent is disabled, use Titan Premier directly via bedrock-runtime
        if not agent_id or agent_id in ("DISABLED", "NONE", "MOCK"):
            return self._invoke_foundation_model(user_question, session_id)

        logger.info(
            "bedrock.invoking_agent",
            extra={
                "session_id":    session_id,
                "question_len":  len(user_question),
                "agent_id":      agent_id,
            },
        )

        try:
            agent_response = self._invoke_with_retry(
                agent_id=agent_id,
                alias_id=alias_id,
                session_id=session_id,
                user_input=user_question,
                enable_trace=enable_trace,
            )
        except Exception as exc:
            err_str = str(exc)
            if "Maintenance Mode" in err_str or "AccessDeniedException" in err_str or "ValidationException" in err_str:
                logger.warning("bedrock.agent_fallback_to_model", extra={"error": err_str})
                return self._invoke_foundation_model(user_question, session_id)
            raise

        # Detect guardrail blocks — the guardrail blocked_outputs_messaging
        # is set in Terraform: "The generated SQL was blocked due to safety policies."
        blocked = (
            "blocked due to safety" in agent_response.lower()
            or "cannot be processed" in agent_response.lower()
        )

        sql = None if blocked else self._extract_sql(agent_response)

        logger.info(
            "bedrock.response_received",
            extra={
                "session_id":     session_id,
                "sql_found":      sql is not None,
                "blocked":        blocked,
                "response_len":   len(agent_response),
            },
        )

        return {
            "sql":         sql,
            "explanation": agent_response,
            "session_id":  session_id,
            "blocked":     blocked,
        }


bedrock_service = BedrockAgentService()