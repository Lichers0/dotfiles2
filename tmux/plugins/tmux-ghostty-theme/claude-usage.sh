#!/bin/bash
# Read rate-limits from a shared cache populated by Claude Code statusline.
# No network calls — every Claude Code request refreshes the cache via stdin.
#
# Usage: claude-usage.sh [5h|7d|all]
#   5h  — only the 5-hour limit
#   7d  — only the 7-day limit
#   all — both (default)

MODE="${1:-all}"

CACHE_FILE="$HOME/.cache/claude-rate-limits.json"
STALE_AFTER=1800   # 30 minutes — gray-out values older than this

# Tokyo Night Storm palette (tmux format)
C_RED="#[fg=#f7767e]"
C_YELLOW="#[fg=#e0af68]"
C_GRAY="#[fg=#565f89]"
C_RESET="#[default]"

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

format_age() {
  local seconds="$1"
  local mins=$((seconds / 60))
  if [[ $mins -lt 60 ]]; then
    echo "${mins}m"
  else
    local hours=$((mins / 60))
    echo "${hours}h"
  fi
}

# === Load shared cache ===
if [[ ! -f "$CACHE_FILE" ]]; then
  echo "${C_GRAY}🔥 — no data${C_RESET}"
  exit 0
fi

DATA=$(cat "$CACHE_FILE" 2>/dev/null)
if ! echo "$DATA" | jq -e . >/dev/null 2>&1; then
  echo "${C_GRAY}🔥 — bad cache${C_RESET}"
  exit 0
fi

NOW=$(date +%s)
UPDATED_AT=$(echo "$DATA" | jq -r '.updated_at // 0')
AGE=$((NOW - UPDATED_AT))
STALE=0
[[ $AGE -gt $STALE_AFTER ]] && STALE=1

# === Per-limit formatters ===
format_5h() {
  local pct=$(echo "$DATA" | jq -r '.five_hour.used_percentage // empty')
  [[ -z "$pct" || "$pct" == "null" ]] && return

  local pct_int=${pct%.*}
  local color
  if [[ $STALE -eq 1 ]]; then
    color="$C_GRAY"
  else
    color=$(get_pct_color "$pct_int")
  fi
  local bar=$(make_bar "$pct_int" "$color")

  local reset_at=$(echo "$DATA" | jq -r '.five_hour.resets_at // empty')
  local time_fmt="5h"
  if [[ -n "$reset_at" && "$reset_at" != "null" ]]; then
    local secs_left=$((reset_at - NOW))
    time_fmt=$(format_remaining_time "$secs_left")
  fi

  printf "%s%s:%s %s %s%s%%%s" "$C_GRAY" "$time_fmt" "$C_RESET" "$bar" "$color" "$pct_int" "$C_RESET"
}

format_7d() {
  local pct=$(echo "$DATA" | jq -r '.seven_day.used_percentage // empty')
  [[ -z "$pct" || "$pct" == "null" ]] && return

  local pct_int=${pct%.*}
  local color
  if [[ $STALE -eq 1 ]]; then
    color="$C_GRAY"
  else
    color=$(get_pct_color "$pct_int")
  fi
  local bar=$(make_bar "$pct_int" "$color")

  local reset_at=$(echo "$DATA" | jq -r '.seven_day.resets_at // empty')
  local time_fmt="7d"
  if [[ -n "$reset_at" && "$reset_at" != "null" ]]; then
    local secs_left=$((reset_at - NOW))
    time_fmt=$(format_remaining_time_days "$secs_left")
  fi

  printf "%s%s:%s %s %s%s%%%s" "$C_GRAY" "$time_fmt" "$C_RESET" "$bar" "$color" "$pct_int" "$C_RESET"
}

# Suffix shows last-update HH:MM, with "(Nm old)" appended when stale.
suffix_info() {
  local hhmm=$(date -r "$UPDATED_AT" +%H:%M 2>/dev/null || echo "?")
  if [[ $STALE -eq 1 ]]; then
    printf "%s%s (%s old)%s" "$C_GRAY" "$hhmm" "$(format_age "$AGE")" "$C_RESET"
  else
    printf "%s%s%s" "$C_GRAY" "$hhmm" "$C_RESET"
  fi
}

INFO=$(suffix_info)

case "$MODE" in
  5h)
    out=$(format_5h)
    [[ -n "$out" ]] && echo "${out} ${INFO}"
    ;;
  7d)
    out=$(format_7d)
    [[ -n "$out" ]] && echo "${out} ${INFO}"
    ;;
  all|*)
    out_5h=$(format_5h)
    out_7d=$(format_7d)
    if [[ -n "$out_5h" && -n "$out_7d" ]]; then
      echo "${out_5h} ${C_GRAY}│${C_RESET} ${out_7d} ${INFO}"
    elif [[ -n "$out_5h" ]]; then
      echo "${out_5h} ${INFO}"
    elif [[ -n "$out_7d" ]]; then
      echo "${out_7d} ${INFO}"
    fi
    ;;
esac
