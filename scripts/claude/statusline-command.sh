#!/bin/bash
# Claude Code 3-line status line (replicates ccstatusline layout)
# Line 1: Model Version | 🥡 ctx% | ⎇ branch (changes)
# Line 2: ↔️ width | dir
# Line 3: ⏳ session ☀️ daily 📅 monthly | 🔥 5h/7d limits

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

input=$(cat)

# Debug: uncomment to inspect JSON
# echo "$input" > /tmp/claude-statusline-debug.json

# === ANSI colors (One Dark palette) ===
BMAGENTA='\033[95m'
BRED='\033[91m'
YELLOW='\033[38;5;180m'
GREEN='\033[38;5;114m'
BGREEN='\033[92m'
CYAN='\033[96m'
GRAY='\033[90m'
RED='\033[38;5;204m'
DBLUE='\033[34m'
RESET='\033[0m'

# === Parse JSON ===
model=$(echo "$input" | jq -r '
  .model.display_name // .model.id // "?"')
version=$(echo "$input" | jq -r '
  .version // empty')
ctx_pct=$(echo "$input" | jq -r '
  .context_window.used_percentage // empty')
cwd=$(echo "$input" | jq -r '
  .workspace.current_dir // .cwd // ""')
session_cost=$(echo "$input" | jq -r '
  .cost.total_cost_usd // empty')

# Fallbacks
[ -z "$version" ] && version=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

# Terminal width: read from parent process TTY
term_width="?"
parent_tty=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')
if [ -n "$parent_tty" ] && [ -e "/dev/$parent_tty" ]; then
  term_width=$(stty size <"/dev/$parent_tty" 2>/dev/null | awk '{print $2}')
fi
[ -z "$term_width" ] && term_width="?"

# === Helpers ===

# Format token count: 128234 -> 128.2k
fmt_tokens() {
  local n="$1"
  [ -z "$n" ] || [ "$n" = "null" ] && echo "?" && return
  if [ "$n" -ge 1000 ] 2>/dev/null; then
    awk "BEGIN { printf \"%.1fk\", $n/1000 }"
  else
    echo "$n"
  fi
}

# Shorten CWD: .../last/three/dirs
shorten_cwd() {
  local dir="${1/#$HOME/\~}"
  local count=$(echo "$dir" | tr '/' '\n' | grep -c .)
  if [ "$count" -gt 3 ]; then
    echo ".../$(echo "$dir" | rev | cut -d'/' -f1-3 | rev)"
  else
    echo "$dir"
  fi
}

# Read cache file, return default if missing
read_cache() { [ -f "$1" ] && cat "$1" || echo "$2"; }

# Update cache in background if stale (non-blocking)
bg_update() {
  local file="$1" ttl="$2"; shift 2
  local lock="${file}.lock"
  if [ -f "$file" ]; then
    local age=$(( $(date +%s) - $(stat -f %m "$file" 2>/dev/null || echo 0) ))
    [ "$age" -lt "$ttl" ] && return
  fi
  # Skip if another update is running (< 30s old lock)
  if [ -f "$lock" ]; then
    local la=$(( $(date +%s) - $(stat -f %m "$lock" 2>/dev/null || echo 0) ))
    [ "$la" -lt 30 ] && return
  fi
  (
    touch "$lock"
    result=$("$@" 2>/dev/null)
    [ -n "$result" ] && echo "$result" > "$file"
    rm -f "$lock"
  ) &>/dev/null &
}

# === Cost functions ===

fn_daily_cost() {
  local start=$(date +%Y%m01) today=$(date +%Y-%m-%d)
  local data=$(npx ccusage daily -j -s "$start" 2>/dev/null)
  [ -z "$data" ] && return
  echo "$data" | jq -r --arg t "$today" \
    '([.daily[] | select(.date == $t) | .totalCost] | first // 0) | "\(. * 100 | round / 100)"'
}

fn_monthly_cost() {
  local start=$(date +%Y%m01)
  local data=$(npx ccusage daily -j -s "$start" 2>/dev/null)
  [ -z "$data" ] && return
  echo "$data" | jq -r '.totals.totalCost | "\(. * 100 | round / 100)"'
}

fn_limits() {
  local CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
  [ -z "$CREDS" ] && return
  local TOKEN=$(echo "$CREDS" | jq -r '.claudeAiOauth.accessToken')
  [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ] && return

  local USAGE=$(curl -s --max-time 5 -X GET "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $TOKEN" \
    -H "anthropic-beta: oauth-2025-04-20")

  local h5=$(echo "$USAGE" | jq -r '.five_hour.utilization // 0' | xargs printf "%.0f")
  local d7=$(echo "$USAGE" | jq -r '.seven_day.utilization // 0' | xargs printf "%.0f")

  # Color by threshold
  local GC='\033[38;5;114m' YC='\033[38;5;180m' RC='\033[38;5;204m' GR='\033[90m' RS='\033[0m'
  local c5 c7
  [ "$h5" -lt 50 ] && c5="$GC" || { [ "$h5" -lt 80 ] && c5="$YC" || c5="$RC"; }
  [ "$d7" -lt 50 ] && c7="$GC" || { [ "$d7" -lt 80 ] && c7="$YC" || c7="$RC"; }

  echo -e "🔥 ${GR}5h:${RS}${c5}${h5}%${RS} ${GR}7d:${RS}${c7}${d7}%${RS}"
}

# === Trigger background cache updates ===
CACHE_DIR="/tmp/claude-statusline"
mkdir -p "$CACHE_DIR"

bg_update "$CACHE_DIR/daily-$(date +%Y%m%d)" 60 fn_daily_cost
bg_update "$CACHE_DIR/monthly-$(date +%Y%m)" 60 fn_monthly_cost
bg_update "$CACHE_DIR/limits" 10 fn_limits

# Read cached values
daily=$(read_cache "$CACHE_DIR/daily-$(date +%Y%m%d)" "-")
monthly=$(read_cache "$CACHE_DIR/monthly-$(date +%Y%m)" "-")
limits=$(read_cache "$CACHE_DIR/limits" "🔥 -")

# === Format display values ===
short_dir=$(shorten_cwd "$cwd")

# Session cost
cost_str="\$0"
[ -n "$session_cost" ] && [ "$session_cost" != "null" ] && cost_str=$(printf '$%.4f' "$session_cost")

# Git
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || \
               git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi
if [ -n "$git_branch" ]; then
  changes=$(git -C "$cwd" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ "$changes" = "0" ] && ch_str="(clean)" || ch_str="(${changes} changed)"
  git_str="${BRED}⎇ ${git_branch}${RESET} ${YELLOW}${ch_str}${RESET}"
else
  git_str="${BRED}⎇ no git${RESET} ${YELLOW}(no git)${RESET}"
fi

# Context %
ctx_str="${GREEN}${ctx_pct:-0}%${RESET}"

# === OUTPUT ===
echo -e "${BMAGENTA}${model}${RESET} ${version:-?} | ${git_str}"
echo -e "🥡 ${ctx_str} | ${GRAY}↔️${RESET} ${term_width} | ${DBLUE}${short_dir}${RESET}"
echo -e "⏳ ${CYAN}${cost_str}${RESET} ☀️ ${BGREEN}\$${daily}${RESET} 📅 ${GREEN}\$${monthly}${RESET} | ${limits}"
