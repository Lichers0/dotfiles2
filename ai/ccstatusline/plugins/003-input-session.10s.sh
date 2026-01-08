#!/bin/bash
# Читаем JSON из stdin
# read json
#     # Извлекаем model.id через jq
# echo "$json" | jq -r '.cost.total_cost_usd // "unknown"'
cost=$(jq -r '.cost.total_cost_usd // empty')
[ -n "$cost" ] && printf '$%.4f' "$cost"
