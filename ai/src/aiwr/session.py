"""Session management - finding and organizing log files."""

import os
import shutil
from datetime import datetime, timezone
from pathlib import Path

from .logger import Logger

DEFAULT_LOG_DIR = ".aiwr/logs"


def get_project_root() -> Path:
    """Return current working directory as project root."""
    return Path.cwd()


def get_logs_dir() -> Path:
    """Get the logs directory path."""
    custom_dir = os.environ.get("AIWR_LOG_DIR")
    if custom_dir:
        return Path(custom_dir)

    return get_project_root() / DEFAULT_LOG_DIR


def get_today_dir() -> Path:
    """Get today's log directory."""
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    return get_logs_dir() / today


def get_log_path(session_id: str, parent_id: str | None = None) -> Path:
    """
    Get the path for a session log file.

    If parent_id is provided, the log goes into the parent's directory.
    """
    today_dir = get_today_dir()

    if parent_id:
        parent_path = find_session_path(parent_id)
        if parent_path:
            parent_dir = ensure_session_dir(parent_path)
            return parent_dir / f"{session_id}.jsonl"
        # Parent not found, fall back to today's dir
        return today_dir / f"{session_id}.jsonl"

    return today_dir / f"{session_id}.jsonl"


def ensure_session_dir(session_path: Path) -> Path:
    """
    Ensure a session has its own directory.

    If the session is just a file, convert it to a directory:
    abc123.jsonl -> abc123/abc123.jsonl

    Returns the directory path.
    """
    if session_path.is_dir():
        return session_path

    if session_path.is_file() and session_path.suffix == ".jsonl":
        session_id = session_path.stem
        parent_dir = session_path.parent
        new_dir = parent_dir / session_id
        new_file = new_dir / f"{session_id}.jsonl"

        # Create directory and move file
        new_dir.mkdir(parents=True, exist_ok=True)
        shutil.move(str(session_path), str(new_file))

        return new_dir

    # Path doesn't exist yet, create as directory
    session_path.mkdir(parents=True, exist_ok=True)
    return session_path


def find_session_path(session_id: str) -> Path | None:
    """
    Find a session by ID, searching all date directories.

    Returns the path to the session file or directory.
    """
    logs_dir = get_logs_dir()

    if not logs_dir.exists():
        return None

    # Search all date directories (newest first)
    date_dirs = sorted(logs_dir.iterdir(), reverse=True)

    for date_dir in date_dirs:
        if not date_dir.is_dir():
            continue

        # Check for direct file
        file_path = date_dir / f"{session_id}.jsonl"
        if file_path.exists():
            return file_path

        # Check for directory
        dir_path = date_dir / session_id
        if dir_path.is_dir():
            jsonl_path = dir_path / f"{session_id}.jsonl"
            if jsonl_path.exists():
                return jsonl_path

        # Search recursively in subdirectories
        result = _find_in_dir(date_dir, session_id)
        if result:
            return result

    return None


def _find_in_dir(directory: Path, session_id: str) -> Path | None:
    """Recursively search for a session in a directory."""
    for item in directory.iterdir():
        if item.is_file() and item.stem == session_id and item.suffix == ".jsonl":
            return item

        if item.is_dir():
            # Check if this is the session's directory
            jsonl_path = item / f"{session_id}.jsonl"
            if jsonl_path.exists():
                return jsonl_path

            # Search deeper
            result = _find_in_dir(item, session_id)
            if result:
                return result

    return None


def list_sessions() -> list[tuple[str, Path]]:
    """
    List all sessions grouped by date.

    Returns list of (date_string, session_path) tuples, newest first.
    """
    logs_dir = get_logs_dir()
    sessions: list[tuple[str, Path]] = []

    if not logs_dir.exists():
        return sessions

    date_dirs = sorted(logs_dir.iterdir(), reverse=True)

    for date_dir in date_dirs:
        if not date_dir.is_dir():
            continue

        date_str = date_dir.name
        for item in date_dir.iterdir():
            if item.is_file() and item.suffix == ".jsonl":
                sessions.append((date_str, item))
            elif item.is_dir():
                jsonl_path = item / f"{item.name}.jsonl"
                if jsonl_path.exists():
                    sessions.append((date_str, jsonl_path))

    return sessions


def register_child(parent_id: str, child_id: str) -> bool:
    """
    Register a child session with its parent.

    With JSONL format, children are found by scanning for aiwr_meta entries.
    This function is kept for compatibility but doesn't modify files.
    Children are linked via aiwr_meta in their own JSONL files.
    """
    # No need to update parent - child contains parent_id in aiwr_meta
    return True


def find_children(parent_id: str) -> list[str]:
    """
    Find all child session IDs for a given parent.

    Scans JSONL files for aiwr_meta entries with matching parent_id.
    """
    children = []
    logs_dir = get_logs_dir()

    if not logs_dir.exists():
        return children

    # Scan all JSONL files
    for jsonl_path in logs_dir.rglob("*.jsonl"):
        entries = Logger.load(jsonl_path)
        for entry in entries:
            if entry.get("type") == "aiwr_meta" and entry.get("parent_id") == parent_id:
                # Extract session_id from filename
                session_id = jsonl_path.stem
                children.append(session_id)
                break

    return children


def get_parent_id(session_path: Path) -> str | None:
    """Get parent_id from a session's JSONL file."""
    entries = Logger.load(session_path)
    for entry in entries:
        if entry.get("type") == "aiwr_meta":
            return entry.get("parent_id")
    return None
