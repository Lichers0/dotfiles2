"""JSONL logging for AI sessions."""

import json
from pathlib import Path
from typing import Any


RESUME_SEPARATOR = "----------"


class Logger:
    """Writes JSONL log files - one JSON object per line."""

    def __init__(self, log_path: Path | None = None, is_resume: bool = False):
        self._log_path: Path | None = log_path
        self._entries: list[dict[str, Any]] = []
        self._is_resume = is_resume  # Whether we're continuing an existing session

    def set_log_path(self, path: Path) -> None:
        """Set the path where log will be saved."""
        self._log_path = path

    def append(self, entry: dict[str, Any]) -> None:
        """Append a JSON object to the log."""
        self._entries.append(entry)

    def save(self) -> Path | None:
        """Save log as JSONL file (one JSON object per line)."""
        if not self._log_path or not self._entries:
            return None

        self._log_path.parent.mkdir(parents=True, exist_ok=True)

        # Append to existing file if present
        file_exists = self._log_path.exists()
        mode = "a" if file_exists else "w"

        with open(self._log_path, mode, encoding="utf-8") as f:
            # Add separator when resuming an existing session
            if self._is_resume and file_exists:
                f.write(RESUME_SEPARATOR + "\n")

            for entry in self._entries:
                f.write(json.dumps(entry, ensure_ascii=False) + "\n")

        return self._log_path

    @staticmethod
    def load(path: Path) -> list[dict[str, Any]]:
        """Load JSONL log file and return list of JSON objects.

        Skips separator lines (----------) used for session resume.
        """
        entries = []
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and line != RESUME_SEPARATOR:
                    entries.append(json.loads(line))
        return entries
