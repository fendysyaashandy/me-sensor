#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 \"YYYY-MM-DD HH:MM:SS\" \"YYYY-MM-DD HH:MM:SS\" [output_file]"
  exit 1
fi

START_HUMAN="$1"
END_HUMAN="$2"
OUT_FILE="${3:-snort-window.jsonl}"

START_EPOCH=$(date -d "$START_HUMAN" +%s)
END_EPOCH=$(date -d "$END_HUMAN" +%s)

echo "Requested window: $START_HUMAN -> $END_HUMAN"
echo "Epoch window    : $START_EPOCH -> $END_EPOCH"

if docker compose exec snort sh -lc 'command -v jq >/dev/null 2>&1'; then
  echo "Using jq backend (container)"
  docker compose exec snort sh -lc "
    jq -c --argjson s ${START_EPOCH} --argjson e ${END_EPOCH} \
    '(.seconds | tonumber?) as \$sec | select(\$sec != null and \$sec >= \$s and \$sec <= \$e)' \
    /var/log/snort/alert_json.txt > /tmp/${OUT_FILE}
  "
  docker compose cp "snort:/tmp/${OUT_FILE}" "./${OUT_FILE}"
else
  echo "Using awk backend (host)"
  TMP_SRC="./.${OUT_FILE}.src"
  docker compose cp "snort:/var/log/snort/alert_json.txt" "${TMP_SRC}"
  awk -v s="${START_EPOCH}" -v e="${END_EPOCH}" '
    {
      if (match($0, /"seconds"[[:space:]]*:[[:space:]]*[0-9]+/)) {
        sec = substr($0, RSTART, RLENGTH)
        gsub(/[^0-9]/, "", sec)
        if (sec >= s && sec <= e) print
      }
    }
  ' "${TMP_SRC}" > "./${OUT_FILE}"
  rm -f "${TMP_SRC}"
fi

COUNT=$(wc -l < "./${OUT_FILE}" || echo 0)
echo "Saved: ./${OUT_FILE} (lines: ${COUNT})"

if [[ "${COUNT}" -eq 0 ]]; then
  echo "No alerts found in requested window."
  echo "Hint: verify time range and timezone (Snort 'seconds' is epoch UTC)."
  echo "Try shifting window by +7h/-7h if your test notes use WIB."
fi
