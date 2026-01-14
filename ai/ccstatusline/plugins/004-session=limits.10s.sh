#!/bin/bash

# Colors (One Dark style)
GRAY='\033[90m'
GREEN='\033[38;5;114m'
YELLOW='\033[38;5;180m'
RED='\033[38;5;204m'
RESET='\033[0m'

# Get color based on percentage
get_color() {
    local val=$(echo "$1" | cut -d'.' -f1)
    if [ "$val" -lt 50 ]; then
        echo "$GREEN"
    elif [ "$val" -lt 80 ]; then
        echo "$YELLOW"
    else
        echo "$RED"
    fi
}

# Get access token from macOS Keychain
CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
if [ -z "$CREDS" ]; then
    echo "Error: No credentials"
    exit 1
fi

ACCESS_TOKEN=$(echo "$CREDS" | jq -r '.claudeAiOauth.accessToken')
if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
    echo "Error: No token"
    exit 1
fi

# Fetch usage
USAGE=$(curl -s -X GET "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "anthropic-beta: oauth-2025-04-20")

# Parse values
FIVE_HOUR=$(echo "$USAGE" | jq -r '.five_hour.utilization // 0' | xargs printf "%.0f")
SEVEN_DAY=$(echo "$USAGE" | jq -r '.seven_day.utilization // 0' | xargs printf "%.0f")

# Get colors
COLOR_5H=$(get_color "$FIVE_HOUR")
COLOR_7D=$(get_color "$SEVEN_DAY")

# Output
echo -e "🔥 ${GRAY}5h:${RESET}${COLOR_5H}${FIVE_HOUR}%${RESET} ${GRAY}7d:${RESET}${COLOR_7D}${SEVEN_DAY}%${RESET}"
