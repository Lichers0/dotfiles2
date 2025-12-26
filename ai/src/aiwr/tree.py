"""Tree building for session listing and visualization."""

from dataclasses import dataclass
from pathlib import Path

from .resume import SessionInfo, extract_session_info
from .session import find_children, find_session_path, get_logs_dir, get_parent_id


@dataclass
class SessionNode:
    """A node in the session tree."""

    info: SessionInfo
    path: Path
    children: list["SessionNode"]


def build_session_tree(session_id: str) -> SessionNode | None:
    """Build a tree structure from a session and its children."""
    session_path = find_session_path(session_id)
    if not session_path:
        return None

    info = extract_session_info(session_path)
    children = []

    for child_id in find_children(session_id):
        child_node = build_session_tree(child_id)
        if child_node:
            children.append(child_node)

    return SessionNode(info=info, path=session_path, children=children)


def list_all_sessions() -> dict[str, list[SessionNode]]:
    """
    List all sessions grouped by date.

    Returns a dict: {date_string: [SessionNode, ...]}
    Only includes root sessions (no parent_id).
    """
    logs_dir = get_logs_dir()
    result: dict[str, list[SessionNode]] = {}

    if not logs_dir.exists():
        return result

    # Sort date directories newest first
    date_dirs = sorted(
        [d for d in logs_dir.iterdir() if d.is_dir()],
        reverse=True,
    )

    for date_dir in date_dirs:
        date_str = date_dir.name
        sessions = _collect_root_sessions(date_dir)

        if sessions:
            result[date_str] = sessions

    return result


def _collect_root_sessions(date_dir: Path) -> list[SessionNode]:
    """Collect all root sessions (without parent) from a date directory."""
    sessions = []

    for item in date_dir.iterdir():
        if item.is_file() and item.suffix == ".jsonl":
            # Direct JSONL file
            parent_id = get_parent_id(item)
            if parent_id is None:  # Root session
                node = _build_node_with_children(item)
                sessions.append(node)

        elif item.is_dir():
            # Directory-based session
            jsonl_path = item / f"{item.name}.jsonl"
            if jsonl_path.exists():
                parent_id = get_parent_id(jsonl_path)
                if parent_id is None:  # Root session
                    node = _build_node_with_children(jsonl_path)
                    sessions.append(node)

    return sessions


def _build_node_with_children(path: Path) -> SessionNode:
    """Build a session node with all its children."""
    info = extract_session_info(path)
    children = []

    for child_id in find_children(info.session_id):
        child_path = find_session_path(child_id)
        if child_path:
            child_node = _build_node_with_children(child_path)
            children.append(child_node)

    return SessionNode(info=info, path=path, children=children)


def format_session_list(sessions_by_date: dict[str, list[SessionNode]]) -> str:
    """Format sessions for display."""
    lines = []

    for date_str, sessions in sessions_by_date.items():
        lines.append(f"Sessions ({date_str}):")

        for session in sessions:
            lines.extend(_format_node(session, depth=0))

        lines.append("")  # Empty line between dates

    return "\n".join(lines)


def _format_node(node: SessionNode, depth: int) -> list[str]:
    """Format a single node and its children."""
    indent = "  " * depth
    prefix = "└─ " if depth > 0 else ""

    # Truncate prompt if too long
    prompt = node.info.prompt or "unknown"
    if len(prompt) > 50:
        prompt = prompt[:47] + "..."

    status = node.info.status or "unknown"

    line = f"{indent}{prefix}{node.info.session_id}  [{node.info.agent}]  [{status}]  \"{prompt}\""
    lines = [line]

    for child in node.children:
        lines.extend(_format_node(child, depth + 1))

    return lines
