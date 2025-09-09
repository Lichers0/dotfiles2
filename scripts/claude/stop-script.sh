#!/bin/bash

# Read stdin into a variable
input=$(cat)

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse JSON to extract cwd and get the last directory name
cwd_path=$(echo "$input" | jq -r '.cwd')
last_folder=$(basename "$cwd_path")

# Pass the last folder as an argument to osascript
osascript "$SCRIPT_DIR/stop-notification.applescript" "$last_folder"