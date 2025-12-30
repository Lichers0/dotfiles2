"""OpenCode CLI agent implementation."""

from typing import Any

from .base import BaseAgent


class OpenCodeAgent(BaseAgent):
    """Agent for OpenCode CLI."""

    name = "opencode"
    command = "opencode"
    prompt_flag = ""  # positional argument
    session_id_path = "$.sessionID"  # from any JSON event
    resume_flag = "--session"

    def build_command(
        self,
        prompt: str,
        extra_args: list[str] | None = None,
        session_id: str | None = None,
    ) -> list[str]:
        """Build command with json output format."""
        cmd = [
            self.command,
            "run",
            "--format", "json",
        ]

        # Add session flag if session_id provided
        if session_id:
            cmd.extend([self.resume_flag, session_id])

        if extra_args:
            cmd.extend(extra_args)

        cmd.append(prompt)
        return cmd

    def extract_result(self, json_data: dict[str, Any]) -> str | None:
        """Extract result from text event.

        OpenCode result is in type=text with part.text.
        """
        if json_data.get("type") == "text":
            part = json_data.get("part", {})
            return part.get("text")
        return None

    def is_final(self, json_data: dict[str, Any]) -> bool:
        """OpenCode session ends with type=step_finish."""
        return json_data.get("type") == "step_finish"

    def extract_prompt(self, json_data: dict[str, Any]) -> str | None:
        """Extract prompt from step_start event.

        Note: OpenCode doesn't include user prompt in JSON output.
        Prompt is passed as command argument.
        """
        return None

    def extract_status(self, json_data: dict[str, Any]) -> str | None:
        """Extract status from step_finish JSON."""
        if json_data.get("type") == "step_finish":
            part = json_data.get("part", {})
            reason = part.get("reason")
            # "stop" means completed successfully
            if reason == "stop":
                return "completed"
            return reason
        return None
