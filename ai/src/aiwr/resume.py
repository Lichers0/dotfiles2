"""Resume functionality - building context prompts from previous sessions."""

from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .agents import get_agent
from .logger import Logger
from .session import find_children, find_session_path, get_parent_id


@dataclass
class SessionInfo:
    """Extracted session information from JSONL."""

    session_id: str
    agent: str
    prompt: str | None
    status: str | None
    result: str | None
    entries: list[dict[str, Any]]


def extract_session_info(session_path: Path) -> SessionInfo:
    """Extract session metadata from JSONL file."""
    entries = Logger.load(session_path)
    session_id = session_path.stem

    # Detect agent from init entry
    agent_name = "claude"  # default
    for entry in entries:
        if entry.get("type") == "init":
            # Gemini has session_id in init
            if "session_id" in entry:
                agent_name = "gemini"
                break
        if entry.get("type") == "thread.started":
            # Codex has thread_id
            agent_name = "codex"
            break
        if "session_id" in entry and entry.get("type") != "aiwr_meta":
            # Claude has session_id
            agent_name = "claude"
            break

    agent = get_agent(agent_name)

    # Extract metadata using agent methods
    prompt = None
    status = None
    result = None

    for entry in entries:
        if entry.get("type") == "aiwr_meta":
            continue

        if prompt is None:
            prompt = agent.extract_prompt(entry)

        extracted_result = agent.extract_result(entry)
        if extracted_result:
            result = extracted_result

        extracted_status = agent.extract_status(entry)
        if extracted_status:
            status = extracted_status

    return SessionInfo(
        session_id=session_id,
        agent=agent_name,
        prompt=prompt,
        status=status,
        result=result,
        entries=entries,
    )


def build_resume_prompt(session_id: str, additional_prompt: str | None = None) -> str:
    """
    Build a context prompt for resuming a single session.

    Includes the previous session's context and optionally additional instructions.
    """
    session_path = find_session_path(session_id)
    if not session_path:
        raise ValueError(f"Session not found: {session_id}")

    info = extract_session_info(session_path)
    return _format_single_session(info, additional_prompt)


def build_resume_tree_prompt(session_id: str, additional_prompt: str | None = None) -> str:
    """
    Build a context prompt for resuming a session tree.

    Includes the root session and all its children recursively.
    """
    session_path = find_session_path(session_id)
    if not session_path:
        raise ValueError(f"Session not found: {session_id}")

    info = extract_session_info(session_path)
    tree_context = _format_session_tree(info, depth=0)

    prompt_parts = [
        "[PREVIOUS SESSION TREE]",
        "",
        tree_context,
        "",
        "[CONTINUATION]",
        "Please continue the root session, considering all child session results.",
    ]

    if additional_prompt:
        prompt_parts.append(f"User addition: {additional_prompt}")

    return "\n".join(prompt_parts)


def _format_single_session(info: SessionInfo, additional_prompt: str | None = None) -> str:
    """Format a single session for resumption."""
    output_text = _extract_output_text(info)

    prompt_parts = [
        "[PREVIOUS SESSION CONTEXT]",
        f"Session ID: {info.session_id}",
        f"Agent: {info.agent}",
        f"Original prompt: {info.prompt or 'unknown'}",
        f"Status: {info.status or 'unknown'}",
        "",
        "Output log:",
        "---",
        output_text,
        "---",
        "",
        "[CONTINUATION]",
        "Please continue from where you left off.",
    ]

    if additional_prompt:
        prompt_parts.append(f"User addition: {additional_prompt}")

    return "\n".join(prompt_parts)


def _format_session_tree(info: SessionInfo, depth: int = 0) -> str:
    """Format a session and all its children as a tree."""
    indent = "  " * depth
    output_text = _extract_output_text(info, max_lines=50)

    if depth == 0:
        header = f"== Root Session: {info.session_id} ({info.agent}) =="
    else:
        header = f"{indent}== Child Session: {info.session_id} ({info.agent}) =="

    parts = [
        header,
        f"{indent}Prompt: {info.prompt or 'unknown'}",
        f"{indent}Status: {info.status or 'unknown'}",
        f"{indent}Output:",
        _indent_text(output_text, indent + "  "),
    ]

    # Add children recursively
    children = find_children(info.session_id)
    for child_id in children:
        child_path = find_session_path(child_id)
        if child_path:
            child_info = extract_session_info(child_path)
            parts.append("")
            parts.append(_format_session_tree(child_info, depth + 1))

    return "\n".join(parts)


def _extract_output_text(info: SessionInfo, max_lines: int | None = None) -> str:
    """Extract text from JSONL entries."""
    import json

    lines = []
    for entry in info.entries:
        if entry.get("type") == "aiwr_meta":
            continue
        # Include all JSON entries as text
        lines.append(json.dumps(entry, ensure_ascii=False))

    if max_lines and len(lines) > max_lines:
        # Keep first and last parts
        half = max_lines // 2
        lines = lines[:half] + ["...", f"[{len(lines) - max_lines} lines omitted]", "..."] + lines[-half:]

    return "\n".join(lines)


def _indent_text(text: str, indent: str) -> str:
    """Add indent to each line of text."""
    return "\n".join(indent + line for line in text.splitlines())


def get_session_agent(session_id: str) -> str:
    """Get the agent name used in a session."""
    session_path = find_session_path(session_id)
    if not session_path:
        raise ValueError(f"Session not found: {session_id}")

    info = extract_session_info(session_path)
    return info.agent
