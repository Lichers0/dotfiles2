#!/usr/bin/env bash

# <xbar.title>Claude Code Usage - Month</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.desc>Shows Claude Code usage cost for current month</xbar.desc>
# <xbar.dependencies>bash, jq, npx, ccusage</xbar.dependencies>

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

start=$(date +%Y%m01)

data=$(npx ccusage daily -j -s "$start" 2>/dev/null)

if [[ -z "$data" ]]; then
  echo "📅 -"
  exit 0
fi

echo "$data" | jq -r '.totals.totalCost | "📅 $\(. * 100 | round / 100)"'
