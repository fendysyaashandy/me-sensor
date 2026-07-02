#!/usr/bin/env bash
set -Eeuo pipefail

IF_INGRESS="ens19"   # arah attacker
IF_EGRESS="ens20"    # arah target

OUT_DIR="/home/hduser/me-sensor/pcap"
mkdir -p "$OUT_DIR"
chmod 755 "$OUT_DIR"

RUN_ID="$(date +%Y%m%d-%H%M%S)"

TOTAL_DURATION=3600
ROTATE=300

log() {
  echo "[$(date '+%F %T')] $*"
}

align_to_next_hour() {
  local now=$(date +%s)
  local next=$(( (now / 3600 + 1) * 3600 ))
  local wait=$((next - now))

  log "Align wait $wait sec until $(date -d @$next)" >&2
  sleep "$wait"

  echo "$next"
}

log "Preparing dual capture..."

START=$(align_to_next_hour)

log "START: $(date -d @$START '+%F %T')"

log "Starting tcpdump on BOTH interfaces..."

timeout "$TOTAL_DURATION" tcpdump -i "$IF_INGRESS" -Z root \
  -nn -s 0 -G "$ROTATE" \
  -w "$OUT_DIR/in-$RUN_ID-%Y%m%d-%H%M%S.pcap" &

PID1=$!

timeout "$TOTAL_DURATION" tcpdump -i "$IF_EGRESS" -Z root \
  -nn -s 0 -G "$ROTATE" \
  -w "$OUT_DIR/out-$RUN_ID-%Y%m%d-%H%M%S.pcap" &

PID2=$!

wait $PID1
wait $PID2

log "Capture finished"
