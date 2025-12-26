"""CLI entry point for AIWR."""

import argparse
import os
import sys

from . import __version__
from .agents import get_agent, list_agents
from .resume import build_resume_prompt, build_resume_tree_prompt, get_session_agent
from .runner import Runner
from .tree import format_session_list, list_all_sessions


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        prog="aiwr",
        description="Universal CLI wrapper for AI coding assistants with session logging",
    )

    parser.add_argument(
        "-v", "--version",
        action="version",
        version=f"%(prog)s {__version__}",
    )

    parser.add_argument(
        "prompt",
        nargs="?",
        type=str,
        help="Prompt for the AI assistant",
    )

    parser.add_argument(
        "--agent",
        type=str,
        default=os.environ.get("AIWR_DEFAULT_AGENT", "claude"),
        help=f"AI agent to use (default: claude). Available: {', '.join(list_agents())}",
    )

    parser.add_argument(
        "--parent",
        type=str,
        help="Parent session ID for nested calls",
    )

    parser.add_argument(
        "--resume",
        type=str,
        metavar="SESSION_ID",
        help="Resume a single session by ID",
    )

    parser.add_argument(
        "--resume-tree",
        type=str,
        metavar="SESSION_ID",
        help="Resume a session tree by root ID",
    )

    parser.add_argument(
        "--session",
        type=str,
        metavar="SESSION_ID",
        help="Continue an existing session (appends to log file)",
    )

    parser.add_argument(
        "--list",
        action="store_true",
        help="List all sessions",
    )

    # Parse known args to handle -- separator
    args, extra_args = parser.parse_known_args()

    # Remove leading -- if present
    if extra_args and extra_args[0] == "--":
        extra_args = extra_args[1:]

    # Handle --list
    if args.list:
        return handle_list()

    # Handle --resume
    if args.resume:
        return handle_resume(args.resume, args.prompt, extra_args)

    # Handle --resume-tree
    if args.resume_tree:
        return handle_resume_tree(args.resume_tree, args.prompt, extra_args)

    # Handle regular prompt execution
    if args.prompt:
        return handle_prompt(args.agent, args.prompt, args.parent, args.session, extra_args)

    # No action specified
    parser.print_help()
    return 1


def handle_list() -> int:
    """Handle --list command."""
    sessions = list_all_sessions()

    if not sessions:
        print("No sessions found.")
        return 0

    output = format_session_list(sessions)
    print(output)
    return 0


def handle_resume(session_id: str, additional_prompt: str | None, extra_args: list[str]) -> int:
    """Handle --resume command."""
    try:
        agent_name = get_session_agent(session_id)
        prompt = build_resume_prompt(session_id, additional_prompt)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    return _run_agent(agent_name, prompt, None, None, extra_args)


def handle_resume_tree(session_id: str, additional_prompt: str | None, extra_args: list[str]) -> int:
    """Handle --resume-tree command."""
    try:
        agent_name = get_session_agent(session_id)
        prompt = build_resume_tree_prompt(session_id, additional_prompt)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    return _run_agent(agent_name, prompt, None, None, extra_args)


def handle_prompt(
    agent_name: str,
    prompt: str,
    parent_id: str | None,
    session_id: str | None,
    extra_args: list[str],
) -> int:
    """Handle regular prompt execution."""
    return _run_agent(agent_name, prompt, parent_id, session_id, extra_args)


def _run_agent(
    agent_name: str,
    prompt: str,
    parent_id: str | None,
    session_id: str | None,
    extra_args: list[str],
) -> int:
    """Run an agent with the given parameters."""
    try:
        agent = get_agent(agent_name)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    runner = Runner(
        agent=agent,
        prompt=prompt,
        extra_args=extra_args,
        parent_id=parent_id,
        session_id=session_id,
    )

    return runner.run()


if __name__ == "__main__":
    sys.exit(main())
