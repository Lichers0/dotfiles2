#!/bin/bash

# Read stdin into a variable
input=$(cat)

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse JSON to extract cwd and get the last directory name
cwd_path=$(echo "$input" | jq -r '.cwd')
# Check if the second-to-last folder is 'worktrees'
folder_display=$(echo "$cwd_path" | awk -F'/' '{
    if(NF>=3 && $(NF-1)=="worktrees") 
        print $(NF-2)"/.../"$NF; 
    else if(NF>=2) 
        print $(NF-1)"/"$NF; 
    else 
        print $NF
}')

# Pass the folder display as an argument to osascript
osascript "$SCRIPT_DIR/stop-notification.applescript" "$folder_display"