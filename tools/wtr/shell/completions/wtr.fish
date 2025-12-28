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
