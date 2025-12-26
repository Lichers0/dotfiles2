"""Codex CLI agent implementation."""

from typing import Any

from .base import BaseAgent


class CodexAgent(BaseAgent):
    """Agent for Codex CLI."""

    name = "codex"
    command = "codex"
    prompt_flag = ""  # positional argument
    session_id_path = "$.thread_id"  # from type=thread.started JSON
    default_model = "gpt-5.2"
    resume_flag = "resume"  # positional, not --resume

    def build_command(
        self,
        prompt: str,
        extra_args: list[str] | None = None,
        session_id: str | None = None,
    ) -> list[str]:
        """Build command with JSON output format."""
        cmd = [
            self.command,
            "exec",
            prompt,
            "--json",
            "--dangerously-bypass-approvals-and-sandbox",
        ]

        # Add default model if not overridden in extra_args
        has_model = extra_args and "--model" in extra_args
        if not has_model:
            cmd.extend(["--model", self.default_model])

        # Add resume if session_id provided (positional argument)
        if session_id:
            cmd.extend([self.resume_flag, session_id])

        if extra_args:
            cmd.extend(extra_args)
        return cmd

    def extract_result(self, json_data: dict[str, Any]) -> str | None:
        """Extract result from item.completed message.

        Codex result is in type=item.completed with item.text.
        """
        if json_data.get("type") == "item.completed":
            item = json_data.get("item", {})
            if isinstance(item, dict):
                return item.get("text")
        return None

    def is_final(self, json_data: dict[str, Any]) -> bool:
        """Codex session ends with type=turn.completed."""
        return json_data.get("type") == "turn.completed"

    def extract_prompt(self, json_data: dict[str, Any]) -> str | None:
        """Extract prompt from user input."""
        if json_data.get("type") == "user.input":
            return json_data.get("text")
        return None

    def extract_status(self, json_data: dict[str, Any]) -> str | None:
        """Extract status from completion JSON."""
        if json_data.get("type") == "turn.completed":
            return "completed"
        return None
