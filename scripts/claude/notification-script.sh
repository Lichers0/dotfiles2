#!/bin/bash

# Read stdin into a variable
input=$(cat)

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse JSON to extract cwd and message
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

# Extract last 4 words from message
message=$(echo "$input" | jq -r '.message')
last_4_words=$(echo "$message" | awk '{print $(NF-3), $(NF-2), $(NF-1), $NF}')

# Format the message for display
display_message="$folder_display
$last_4_words"

# Pass the formatted message as an argument to osascript
osascript "$SCRIPT_DIR/notification-script.applescript" "$display_message"