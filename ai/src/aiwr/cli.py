"""CLI entry point for AIWR."""

import argparse
import os
import sys

from . import __version__
from .agents import get_agent, list_agents
from .models import MODELS, get_default_model, merge_extra_args, resolve_model
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

    parser.add_argument(
        "--model",
        nargs="?",
        const=True,
        default=None,
        help="Model to use. Without value: show available models table",
    )

    parser.add_argument(
        "--debug",
        action="store_true",
        help="Print the command before executing",
    )

    # Parse known args to handle -- separator
    args, extra_args = parser.parse_known_args()

    # Remove leading -- if present
    if extra_args and extra_args[0] == "--":
        extra_args = extra_args[1:]

    # Handle --list
    if args.list:
        return handle_list()

    # Handle --model without value (show table)
    if args.model is True:
        return handle_models()

    # Handle --resume
    if args.resume:
        return handle_resume(args.resume, args.prompt, extra_args, args.debug)

    # Handle --resume-tree
    if args.resume_tree:
        return handle_resume_tree(args.resume_tree, args.prompt, extra_args, args.debug)

    # Handle regular prompt execution
    if args.prompt:
        return handle_prompt(args.agent, args.prompt, args.parent, args.session, args.model, extra_args, args.debug)

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


def handle_models() -> int:
    """Handle --model command without value (show models table)."""
    output = format_models_table()
    print(output)
    return 0


def format_models_table() -> str:
    """Format models table for all agents."""
    lines = []

    for agent_name, models in MODELS.items():
        lines.append(f"{agent_name.capitalize()} models:")
        lines.append(f"  {'Alias':<12} {'Default':<9} {'Model ID':<30} {'Extra args'}")
        lines.append(f"  {'-'*12} {'-'*9} {'-'*30} {'-'*15}")

        for model in models:
            alias = model["alias"]
            default = "✓" if model["default"] else ""
            model_id = model["model_id"]
            extra = ", ".join(model["extra_args"]) if model["extra_args"] else "-"
            lines.append(f"  {alias:<12} {default:<9} {model_id:<30} {extra}")

        lines.append("")

    return "\n".join(lines).rstrip()


def handle_resume(session_id: str, additional_prompt: str | None, extra_args: list[str], debug: bool) -> int:
    """Handle --resume command."""
    try:
        agent_name = get_session_agent(session_id)
        prompt = build_resume_prompt(session_id, additional_prompt)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    return _run_agent(agent_name, prompt, None, None, extra_args, debug)


def handle_resume_tree(session_id: str, additional_prompt: str | None, extra_args: list[str], debug: bool) -> int:
    """Handle --resume-tree command."""
    try:
        agent_name = get_session_agent(session_id)
        prompt = build_resume_tree_prompt(session_id, additional_prompt)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    return _run_agent(agent_name, prompt, None, None, extra_args, debug)


def handle_prompt(
    agent_name: str,
    prompt: str,
    parent_id: str | None,
    session_id: str | None,
    model_alias: str | None,
    cli_extra_args: list[str],
    debug: bool,
) -> int:
    """Handle regular prompt execution."""
    try:
        # Resolve model
        if model_alias:
            model_info = resolve_model(agent_name, model_alias)
        else:
            model_info = get_default_model(agent_name)

        # Merge extra args: model args + CLI args (CLI overrides)
        merged_args = merge_extra_args(model_info.extra_args, cli_extra_args)

        # Add --model to extra_args
        final_args = ["--model", model_info.model_id] + merged_args

    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    return _run_agent(agent_name, prompt, parent_id, session_id, final_args, debug)


def _run_agent(
    agent_name: str,
    prompt: str,
    parent_id: str | None,
    session_id: str | None,
    extra_args: list[str],
    debug: bool,
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
        debug=debug,
    )

    return runner.run()


if __name__ == "__main__":
    sys.exit(main())
