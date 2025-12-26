"""Gemini CLI agent implementation."""

from typing import Any

from .base import BaseAgent


class GeminiAgent(BaseAgent):
    """Agent for Gemini CLI."""

    name = "gemini"
    command = "gemini"
    prompt_flag = ""  # positional argument
    session_id_path = "$.session_id"  # from type=init JSON
    default_model = "gemini-3-pro-preview"
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
            "--yolo",
            "--output-format", "stream-json",
        ]

        # Add default model if not overridden in extra_args
        has_model = extra_args and "--model" in extra_args
        if not has_model:
            cmd.extend(["--model", self.default_model])

        # Add resume flag if session_id provided
        if session_id:
            cmd.extend([self.resume_flag, session_id])

        cmd.append(prompt)

        if extra_args:
            cmd.extend(extra_args)
        return cmd

    def extract_result(self, json_data: dict[str, Any]) -> str | None:
        """Extract result from assistant message.

        Gemini result is in type=message with role=assistant.
        """
        if json_data.get("type") == "message" and json_data.get("role") == "assistant":
            return json_data.get("content")
        return None

    def is_final(self, json_data: dict[str, Any]) -> bool:
        """Gemini session ends with type=result."""
        return json_data.get("type") == "result"

    def extract_prompt(self, json_data: dict[str, Any]) -> str | None:
        """Extract prompt from user message."""
        if json_data.get("type") == "message" and json_data.get("role") == "user":
            return json_data.get("content")
        return None

    def extract_status(self, json_data: dict[str, Any]) -> str | None:
        """Extract status from result JSON."""
        if json_data.get("type") == "result":
            return json_data.get("status")  # "success" or "error"
        return None

    def should_reset_result(self, json_data: dict[str, Any]) -> bool:
        """Reset result when interrupted by tool calls.

        Gemini sends multiple consecutive assistant messages that should be
        concatenated. Reset only on tool_use/tool_result.
        """
        msg_type = json_data.get("type")

        # Reset on tool calls - they interrupt the message flow
        if msg_type in ("tool_use", "tool_result"):
            return True

        # Don't reset on messages or result
        return False
