# Git worktree manager shell wrapper (for auto-cd feature)
#
# Installation:
#   source /path/to/wtr/shell/wtr.sh
#
# This creates a 'wtrc' function that wraps 'wtr' with auto-cd.
# Use 'wtr' directly if you don't need auto-cd.
#
# Shell completions (optional):
#   eval "$(wtr --completion zsh)"

wtrc() {
    local result
    local exit_code

    # Run the CLI and capture output
    result=$(command wtr "$@")
    exit_code=$?

    # If exit code is 0 and result is a directory, cd into it
    if [[ $exit_code -eq 0 && -n "$result" && -d "$result" ]]; then
        cd "$result" && echo "Switched to: $result"
    elif [[ -n "$result" ]]; then
        # Print any other output (errors, list, etc.)
        echo "$result"
    fi

    return $exit_code
}
