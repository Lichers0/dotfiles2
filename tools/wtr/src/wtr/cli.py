"""CLI entry point for worktree manager."""

import argparse
import sys
from pathlib import Path

from .config import load_config
from .git import GitWorktreeManager
from .tui import run_tui


SHELL_COMPLETIONS = {
    "zsh": """\
#compdef wtr

_wtr() {
    local -a commands branches worktrees

    # Get existing worktrees
    worktrees=($(wtr --list 2>/dev/null | cut -f1))

    # Get local branches
    branches=($(git branch --format='%(refname:short)' 2>/dev/null))

    _arguments -C \\
        '(-l --list)'{-l,--list}'[List existing worktrees]' \\
        '(-d --delete)'{-d,--delete}'[Delete worktree]:branch:($worktrees)' \\
        '(-b --base)'{-b,--base}'[Base branch for new worktree]:branch:($branches)' \\
        '--prune[Remove stale worktrees]' \\
        '--completion[Generate shell completion]:shell:(zsh bash fish)' \\
        '1:branch:($branches)'
}

_wtr "$@"
""",
    "bash": """\
_wtr() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="-l --list -d --delete -b --base --prune --completion"

    case "${prev}" in
        -d|--delete)
            local worktrees=$(wtr --list 2>/dev/null | cut -f1)
            COMPREPLY=( $(compgen -W "${worktrees}" -- ${cur}) )
            return 0
            ;;
        -b|--base)
            local branches=$(git branch --format='%(refname:short)' 2>/dev/null)
            COMPREPLY=( $(compgen -W "${branches}" -- ${cur}) )
            return 0
            ;;
        --completion)
            COMPREPLY=( $(compgen -W "zsh bash fish" -- ${cur}) )
            return 0
            ;;
    esac

    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    else
        local branches=$(git branch --format='%(refname:short)' 2>/dev/null)
        COMPREPLY=( $(compgen -W "${branches}" -- ${cur}) )
    fi
}
complete -F _wtr wtr
""",
    "fish": """\
function __fish_wtr_branches
    git branch --format='%(refname:short)' 2>/dev/null
end

function __fish_wtr_worktrees
    wtr --list 2>/dev/null | cut -f1
end

complete -c wtr -f
complete -c wtr -s l -l list -d 'List existing worktrees'
complete -c wtr -s d -l delete -d 'Delete worktree' -xa '(__fish_wtr_worktrees)'
complete -c wtr -s b -l base -d 'Base branch' -xa '(__fish_wtr_branches)'
complete -c wtr -l prune -d 'Remove stale worktrees'
complete -c wtr -l completion -d 'Generate completion' -xa 'zsh bash fish'
complete -c wtr -n '__fish_is_first_arg' -xa '(__fish_wtr_branches)'
""",
}


HELP_EPILOG = """\
TUI Keybindings:
  Enter      Select branch / confirm action
  Space      Toggle multi-select for bulk delete
  d          Delete worktree (single or selected)
  p          Prune stale worktrees
  q, Escape  Quit

Examples:
  wtr                     Launch TUI
  wtr feature-auth        Quick switch/create worktree
  wtr -b develop feature  Create from 'develop' branch
  wtr --prune             Remove merged/deleted worktrees
"""


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Git worktree manager with TUI",
        prog="wtr",
        epilog=HELP_EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "branch",
        nargs="?",
        help="Branch name for quick create/switch (skips TUI)",
    )
    parser.add_argument(
        "--list", "-l",
        action="store_true",
        dest="list_worktrees",
        help="List existing worktrees",
    )
    parser.add_argument(
        "--delete", "-d",
        metavar="BRANCH",
        help="Delete worktree for branch",
    )
    parser.add_argument(
        "--base", "-b",
        metavar="BRANCH",
        help="Base branch for new worktree (default: main/master)",
    )
    parser.add_argument(
        "--prune",
        action="store_true",
        help="Remove worktrees for merged/deleted branches",
    )
    parser.add_argument(
        "--completion",
        metavar="SHELL",
        choices=["zsh", "bash", "fish"],
        help="Generate shell completion script",
    )

    args = parser.parse_args()

    # Handle --completion (doesn't need git repo)
    if args.completion:
        print(SHELL_COMPLETIONS[args.completion])
        return 1  # Don't cd

    try:
        manager = GitWorktreeManager()
        config = load_config(manager.root)
    except RuntimeError as e:
        print(str(e), file=sys.stderr)
        return 2

    # Handle --list
    if args.list_worktrees:
        worktrees = manager.list_worktrees()
        if not worktrees:
            print("No worktrees found", file=sys.stderr)
            return 1
        for branch, path in sorted(worktrees.items()):
            print(f"{branch}\t{path}")
        return 1  # Don't cd

    # Handle --prune
    if args.prune:
        return handle_prune(manager)

    # Handle --delete
    if args.delete:
        try:
            manager.delete_worktree(args.delete)
            print(f"Deleted worktree: {args.delete}", file=sys.stderr)
            return 1  # Don't cd
        except RuntimeError as e:
            print(str(e), file=sys.stderr)
            return 2

    # Check structure before worktree operations
    if not manager.is_valid_structure():
        result = handle_restructure(manager)
        if result is not None:
            return result

    # Handle quick branch argument
    if args.branch:
        return handle_quick_branch(manager, args.branch, args.base, config)

    # Run TUI
    result = run_tui(manager, config)
    if result:
        print(result)
        return 0
    return 1


def handle_restructure(manager: GitWorktreeManager) -> int | None:
    """
    Handle repository restructuring prompt.

    Returns:
        None - if restructure succeeded, continue execution
        int - exit code if should stop execution
    """
    main_branch = manager.get_main_branch()

    print(
        f"Repository is not in worktree structure.\n"
        f"Move '{main_branch}' to worktree structure? [y/N] ",
        end="",
        file=sys.stderr,
    )

    try:
        response = input().strip().lower()
    except (EOFError, KeyboardInterrupt):
        print("\nCancelled", file=sys.stderr)
        return 1

    if response != "y":
        print(
            "Worktree operations require valid structure.",
            file=sys.stderr,
        )
        return 1

    # Perform restructure
    try:
        new_root = manager.restructure_to_worktree()
        print(
            f"Restructured: {new_root}",
            file=sys.stderr,
        )
        # Output new path for cd
        print(new_root)
        return 0
    except Exception as e:
        print(f"Restructure failed: {e}", file=sys.stderr)
        return 2


def handle_quick_branch(
    manager: GitWorktreeManager,
    branch: str,
    base: str | None,
    config,
) -> int:
    """Handle quick branch create/switch without TUI."""
    worktrees = manager.list_worktrees()

    if branch in worktrees:
        # Worktree exists - update symlink and return path
        manager.update_symlink(branch)
        print(worktrees[branch])
        return 0

    # Create new worktree
    base_branch = base or config.worktree.default_base or manager.get_main_branch()
    try:
        path = manager.create_worktree(branch, base_branch)
        manager.update_symlink(branch)
        print(path)
        return 0
    except RuntimeError as e:
        print(str(e), file=sys.stderr)
        return 2


def handle_prune(manager: GitWorktreeManager) -> int:
    """Handle --prune command."""
    stale = manager.find_stale_worktrees()

    if not stale:
        print("No stale worktrees found", file=sys.stderr)
        return 1

    print(f"Found {len(stale)} stale worktrees:", file=sys.stderr)
    for branch, reason in stale:
        print(f"  {branch} ({reason})", file=sys.stderr)

    # Confirm
    try:
        response = input("Delete all? [y/N] ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        print("\nCancelled", file=sys.stderr)
        return 1

    if response != "y":
        print("Cancelled", file=sys.stderr)
        return 1

    # Delete
    branches = [b for b, _ in stale]
    results = manager.prune_worktrees(branches)

    errors = [f"{b}: {e}" for b, e in results.items() if e]
    success_count = len([b for b, e in results.items() if e is None])

    if errors:
        print(f"Pruned {success_count}, errors:", file=sys.stderr)
        for err in errors:
            print(f"  {err}", file=sys.stderr)
        return 2

    print(f"Pruned {success_count} worktrees", file=sys.stderr)
    return 1  # Don't cd


if __name__ == "__main__":
    sys.exit(main())
