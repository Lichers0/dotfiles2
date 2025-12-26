"""Claude Code agent implementation."""

from typing import Any

from .base import BaseAgent


class ClaudeAgent(BaseAgent):
    """Agent for Claude Code CLI."""

    name = "claude"
    command = "claude"
    prompt_flag = "--print"
    session_id_path = "$.session_id"
    default_model = "opus"
    resume_flag = "--resume"

    def build_command(
        self,
        prompt: str,
        extra_args: list[str] | None = None,
        session_id: str | None = None,
    ) -> list[str]:
        """Build command with stream-json output format."""
        cmd = [
            self.command,
            "--verbose",
            "--output-format", "stream-json",
        ]

        # Add resume flag if session_id provided
        if session_id:
            cmd.extend([self.resume_flag, session_id])

        cmd.extend(["--print", prompt])

        # Add default model if not overridden in extra_args
        has_model = extra_args and "--model" in extra_args
        if not has_model:
            cmd.extend(["--model", self.default_model])

        if extra_args:
            cmd.extend(extra_args)
        return cmd

    def extract_result(self, json_data: dict[str, Any]) -> str | None:
        """Extract result from completion JSON.

        Claude result is in type=result with field 'result'.
        """
        if json_data.get("type") == "result":
            return json_data.get("result")
        return None

    def is_final(self, json_data: dict[str, Any]) -> bool:
        """Claude session ends with type=result."""
        return json_data.get("type") == "result"

    def extract_prompt(self, json_data: dict[str, Any]) -> str | None:
        """Extract prompt from user message."""
        if json_data.get("type") == "user" or (
            json_data.get("type") == "message" and json_data.get("role") == "user"
        ):
            return json_data.get("content") or json_data.get("message")
        return None

    def extract_status(self, json_data: dict[str, Any]) -> str | None:
        """Extract status from result JSON."""
        if json_data.get("type") == "result":
            # Claude uses "result" type for success
            return "completed"
        return None
