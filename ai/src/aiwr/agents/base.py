"""Base agent class for AI coding assistants."""

import json
from abc import ABC, abstractmethod
from typing import Any


class BaseAgent(ABC):
    """Abstract base class for AI coding assistant agents."""

    name: str
    command: str
    prompt_flag: str
    session_id_path: str
    default_model: str | None = None
    resume_flag: str | None = None

    def build_command(
        self,
        prompt: str,
        extra_args: list[str] | None = None,
        session_id: str | None = None,
    ) -> list[str]:
        """Build the full command to execute the agent."""
        cmd = [self.command, self.prompt_flag, prompt]
        if extra_args:
            cmd.extend(extra_args)
        return cmd

    def get_model(self, extra_args: list[str] | None = None) -> str | None:
        """Get model from extra_args or return default."""
        if extra_args and "--model" in extra_args:
            try:
                idx = extra_args.index("--model")
                return extra_args[idx + 1]
            except (IndexError, ValueError):
                pass
        return self.default_model

    def parse_log_entry(self, line: str) -> dict[str, Any] | None:
        """Parse a line and return JSON dict if it's a valid log entry.

        Returns None for non-JSON lines (garbage output).
        Override in subclasses for agent-specific filtering.
        """
        line = line.strip()
        if not line.startswith("{"):
            return None
        try:
            return json.loads(line)
        except json.JSONDecodeError:
            return None

    def extract_session_id(self, json_data: dict[str, Any]) -> str | None:
        """Extract session ID from JSON output using the configured path."""
        return self._extract_by_path(json_data, self.session_id_path)

    @abstractmethod
    def extract_result(self, json_data: dict[str, Any]) -> str | None:
        """Extract final result from JSON data.

        Called for each JSON object. Should return the result text
        when appropriate (e.g., from assistant message or completion).
        """
        pass

    @abstractmethod
    def is_final(self, json_data: dict[str, Any]) -> bool:
        """Check if this JSON object marks the end of the session."""
        pass

    @abstractmethod
    def extract_prompt(self, json_data: dict[str, Any]) -> str | None:
        """Extract user prompt from JSON data."""
        pass

    @abstractmethod
    def extract_status(self, json_data: dict[str, Any]) -> str | None:
        """Extract session status from final JSON."""
        pass

    def should_reset_result(self, json_data: dict[str, Any]) -> bool:
        """Check if accumulated result should be reset.

        Override in subclasses for agents that accumulate multiple messages.
        Default: reset on any new result (no accumulation).
        """
        return self.extract_result(json_data) is not None

    def _extract_by_path(self, data: dict[str, Any], path: str) -> Any:
        """Extract value from dict using JSONPath-like notation ($.field.subfield)."""
        if not path.startswith("$."):
            return None

        keys = path[2:].split(".")
        current = data

        for key in keys:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return None

        return current
