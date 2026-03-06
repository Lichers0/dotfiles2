#!/bin/bash

# Usage: claude-usage.sh [5h|7d|all]
# 5h  - показать только 5-часовой лимит
# 7d  - показать только недельный лимит
# all - показать оба (по умолчанию)

MODE="${1:-all}"

CACHE_DIR="$HOME/.cache"
API_CACHE_FILE="$CACHE_DIR/claude-api-response.json"
LOCK_FILE="$CACHE_DIR/claude-usage.lock"
TTL_FILE="$CACHE_DIR/claude-usage-ttl"
BASE_TTL=180

# Tokyo Night Storm palette (tmux format)
C_RED="#[fg=#f7767e]"
C_YELLOW="#[fg=#e0af68]"
C_GRAY="#[fg=#565f89]"
C_RESET="#[default]"

[[ ! -d "$CACHE_DIR" ]] && mkdir -p "$CACHE_DIR"

get_pct_color() {
  local pct="$1"
  if [[ $pct -gt 80 ]]; then
    echo "$C_RED"
  elif [[ $pct -gt 60 ]]; then
    echo "$C_YELLOW"
  else
    echo "$C_GRAY"
  fi
}

make_bar() {
  local pct="$1"
  local color="$2"
  local width=10
  local filled=$((pct * width / 100))
  local empty=$((width - filled))
  [[ $filled -gt $width ]] && filled=$width
  [[ $filled -lt 0 ]] && filled=0
  [[ $empty -lt 0 ]] && empty=0
  local bar_filled=$(printf '%*s' "$filled" '' | tr ' ' '▓')
  local bar_empty=$(printf '%*s' "$empty" '' | tr ' ' '░')
  printf "${C_GRAY}[${C_RESET}${color}${bar_filled}${C_GRAY}${bar_empty}]${C_RESET}"
}

get_file_age() {
  local file="$1"
  local mod_time=$(stat -f '%m' "$file" 2>/dev/null)
  local now=$(date +%s)
  echo $((now - mod_time))
}

format_remaining_time() {
  local seconds="$1"
  if [[ $seconds -le 0 ]]; then
    echo "0m"
    return
  fi
  local hours=$((seconds / 3600))
  local mins=$(((seconds % 3600) / 60))
  if [[ $hours -gt 0 ]]; then
    echo "${hours}h${mins}m"
  else
    echo "${mins}m"
  fi
}

format_remaining_time_days() {
  local seconds="$1"
  if [[ $seconds -le 0 ]]; then
    echo "0m"
    return
  fi
  local days=$((seconds / 86400))
  local hours=$(((seconds % 86400) / 3600))
  local mins=$(((seconds % 3600) / 60))
  if [[ $days -gt 0 ]]; then
    echo "${days}d${hours}h"
  elif [[ $hours -gt 0 ]]; then
    echo "${hours}h${mins}m"
  else
    echo "${mins}m"
  fi
}

parse_iso_to_seconds_left() {
  local iso_date="$1"
  local clean_date=$(echo "$iso_date" | sed 's/\.[0-9]*//; s/+00:00//; s/Z$//')
  local reset_ts=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$clean_date" "+%s" 2>/dev/null)
  if [[ -n "$reset_ts" ]]; then
    local now=$(date +%s)
    echo $((reset_ts - now))
  else
    echo ""
  fi
}

get_current_ttl() {
  if [[ -f "$TTL_FILE" ]]; then
    cat "$TTL_FILE"
  else
    echo "$BASE_TTL"
  fi
}

# Получаем данные API (с кэшированием)
fetch_api_data() {
  local ttl=$(get_current_ttl)

  # TTL_FILE mtime tracks last API attempt (success or failure)
  if [[ -f "$TTL_FILE" ]]; then
    local attempt_age=$(get_file_age "$TTL_FILE")
    if [[ $attempt_age -lt $ttl ]]; then
      [[ -f "$API_CACHE_FILE" ]] && cat "$API_CACHE_FILE"
      return 0
    fi
  fi

  # Lock: prevent concurrent API calls (shlock is non-blocking)
  if ! shlock -p $$ -f "$LOCK_FILE" 2>/dev/null; then
    [[ -f "$API_CACHE_FILE" ]] && cat "$API_CACHE_FILE"
    return 0
  fi
  trap 'rm -f "$LOCK_FILE"' EXIT

  # Получаем credentials
  local keychain_data=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
  [[ -z "$keychain_data" ]] && { rm -f "$LOCK_FILE"; [[ -f "$API_CACHE_FILE" ]] && cat "$API_CACHE_FILE"; return 0; }

  local token=$(echo "$keychain_data" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
  [[ -z "$token" ]] && { rm -f "$LOCK_FILE"; [[ -f "$API_CACHE_FILE" ]] && cat "$API_CACHE_FILE"; return 0; }

  local response=$(curl -s --max-time 5 "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null)

  rm -f "$LOCK_FILE"

  if [[ -n "$response" ]]; then
    local has_error=$(echo "$response" | jq -r '.error // empty' 2>/dev/null)
    if [[ -z "$has_error" ]]; then
      # Success: reset TTL to base, touch TTL_FILE to mark attempt time
      echo "$BASE_TTL" > "$TTL_FILE"
      echo "$response" | tee "$API_CACHE_FILE"
    else
      # Rate limited: increase TTL, touch TTL_FILE to mark attempt time
      echo $(( ttl + BASE_TTL )) > "$TTL_FILE"
      if [[ -f "$API_CACHE_FILE" ]]; then
        cat "$API_CACHE_FILE"
      else
        echo "$response"
      fi
    fi
  else
    # Timeout/empty response: increase TTL like rate limit
    echo $(( ttl + BASE_TTL )) > "$TTL_FILE"
    [[ -f "$API_CACHE_FILE" ]] && cat "$API_CACHE_FILE"
  fi
}

# Форматирование 5-часового лимита
format_5h() {
  local response="$1"
  local session=$(echo "$response" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
  [[ -z "$session" ]] && return

  local session_int=${session%.*}
  local session_color=$(get_pct_color "$session_int")
  local session_bar=$(make_bar "$session_int" "$session_color")
  local reset_at=$(echo "$response" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)

  local time_fmt="5h"
  if [[ -n "$reset_at" ]]; then
    local secs_left=$(parse_iso_to_seconds_left "$reset_at")
    time_fmt=$(format_remaining_time "$secs_left")
  fi

  printf "%s: %s %s%s%%%s" "$time_fmt" "$session_bar" "$session_color" "$session_int" "$C_RESET"
}

# Форматирование недельного лимита
format_7d() {
  local response="$1"
  local weekly=$(echo "$response" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
  [[ -z "$weekly" ]] && return

  local weekly_int=${weekly%.*}
  local weekly_color=$(get_pct_color "$weekly_int")
  local weekly_bar=$(make_bar "$weekly_int" "$weekly_color")
  local reset_at=$(echo "$response" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)

  local time_fmt="7d"
  if [[ -n "$reset_at" ]]; then
    local secs_left=$(parse_iso_to_seconds_left "$reset_at")
    time_fmt=$(format_remaining_time_days "$secs_left")
  fi

  printf "%s%s:%s %s %s%s%%%s" "$C_GRAY" "$time_fmt" "$C_RESET" "$weekly_bar" "$weekly_color" "$weekly_int" "$C_RESET"
}

# Основная логика
RESPONSE=$(fetch_api_data)
[[ -z "$RESPONSE" ]] && exit 0

# Check for API errors
api_error=$(echo "$RESPONSE" | jq -r '.error.type // empty' 2>/dev/null)
if [[ -n "$api_error" ]]; then
  echo "${C_RED}🚫 429${C_RESET}"
  exit 0
fi

# Проверка max подписки
session=$(echo "$RESPONSE" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
weekly=$(echo "$RESPONSE" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
if [[ -z "$session" && -z "$weekly" ]]; then
  echo "${C_GRAY}∞ Max${C_RESET}"
  exit 0
fi

# Cache freshness: last successful update HH:MM, countdown to next attempt
TTL=$(get_current_ttl)
cache_mod=$(stat -f '%m' "$API_CACHE_FILE" 2>/dev/null || echo 0)
updated_at=$(date -r "$cache_mod" +%H:%M 2>/dev/null || echo "?")
ttl_mod=$(stat -f '%m' "$TTL_FILE" 2>/dev/null || echo 0)
attempt_age=$(( $(date +%s) - ttl_mod ))
next_min=$(( (TTL - (attempt_age % TTL) - 1) / 60 ))
[[ $next_min -lt 0 ]] && next_min=0
cache_info="${C_GRAY}${updated_at}(${next_min})${C_RESET}"

case "$MODE" in
  5h)
    format_5h "$RESPONSE"
    ;;
  7d)
    output_7d=$(format_7d "$RESPONSE")
    [[ -n "$output_7d" ]] && echo "${output_7d} ${cache_info}" || echo ""
    ;;
  all|*)
    output_5h=$(format_5h "$RESPONSE")
    output_7d=$(format_7d "$RESPONSE")
    if [[ -n "$output_5h" && -n "$output_7d" ]]; then
      echo "${output_5h} ${C_GRAY}│${C_RESET} ${output_7d} ${cache_info}"
    elif [[ -n "$output_5h" ]]; then
      echo "$output_5h ${cache_info}"
    elif [[ -n "$output_7d" ]]; then
      echo "$output_7d ${cache_info}"
    fi
    ;;
esac
