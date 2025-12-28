#compdef wtr

_wtr() {
    local -a commands branches worktrees

    # Get existing worktrees
    worktrees=($(wtr --list 2>/dev/null | cut -f1))

    # Get local branches
    branches=($(git branch --format='%(refname:short)' 2>/dev/null))

    _arguments -C \
        '(-l --list)'{-l,--list}'[List existing worktrees]' \
        '(-d --delete)'{-d,--delete}'[Delete worktree]:branch:($worktrees)' \
        '(-b --base)'{-b,--base}'[Base branch for new worktree]:branch:($branches)' \
        '--prune[Remove stale worktrees]' \
        '--completion[Generate shell completion]:shell:(zsh bash fish)' \
        '1:branch:($branches)'
}

_wtr "$@"
