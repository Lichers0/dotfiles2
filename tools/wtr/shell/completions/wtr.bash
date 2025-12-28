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
