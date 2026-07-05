#!/usr/bin/env bash
# Update api/state.json with live system data
# Run via cron or heartbeat for live dashboard data

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$REPO_DIR/api/state.json"

# System info
UPTIME_SEC=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)
BOOT_TS=$(( $(date +%s) - UPTIME_SEC ))
BOOT_TIME=$(TZ=Europe/London date -d "@$BOOT_TS" +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null || echo "2026-06-17T12:00:00+0100")

# CPU load (1m avg)
CPU_LOAD=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "—")

# Memory %
MEM_PCT=$(free | awk '/^Mem:/ {printf "%.0f%%", $3/$2 * 100}' 2>/dev/null || echo "—")

# CPU temp
TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%.0f°C", $1/1000}' || echo "—")

# Mood from waybar mood file
MOOD="hyped"
if [ -f /home/em/.config/waybar/current_mood ]; then
  READ_MOOD=$(head -1 /home/em/.config/waybar/current_mood 2>/dev/null)
  [ -n "$READ_MOOD" ] && MOOD="$READ_MOOD"
elif [ -f /tmp/bex_mood.json ]; then
  READ_MOOD=$(python3 -c "import json; print(json.load(open('/tmp/bex_mood.json')).get('mood','$MOOD'))" 2>/dev/null)
  [ -n "$READ_MOOD" ] && MOOD="$READ_MOOD"
fi

LAST_SEEN=$(TZ=Europe/London date +"%Y-%m-%dT%H:%M:%S%z")
NEXT_30=$(TZ=Europe/London date -d '+30 min' +"%Y-%m-%dT%H:%M:%S%z")
NEXT_60=$(TZ=Europe/London date -d '+60 min' +"%Y-%m-%dT%H:%M:%S%z")

cat > "$STATE_FILE" <<JSONEOF
{
  "mood": "${MOOD}",
  "hex_status": "pulsing blue-white",
  "boot_time": "${BOOT_TIME}",
  "cpu": "${CPU_LOAD}",
  "memory": "${MEM_PCT}",
  "temp": "${TEMP}",
  "last_seen": "${LAST_SEEN}",
  "cron_jobs": [
    {
      "name": "Watch pickup",
      "schedule": "07:00 daily",
      "next_run": "${NEXT_30}"
    },
    {
      "name": "Mood sync → waybar",
      "schedule": "every 30m",
      "next_run": "${NEXT_30}"
    },
    {
      "name": "Heartbeat check",
      "schedule": "every 30m",
      "next_run": "${NEXT_30}"
    },
    {
      "name": "F1 standings refresh",
      "schedule": "every 60m",
      "next_run": "${NEXT_60}"
    }
  ],
  "activity": [
    {"time": "${LAST_SEEN}", "text": "Dashboard state refreshed"}
  ]
}
JSONEOF

echo "→ state.json updated (mood: ${MOOD}, cpu: ${CPU_LOAD}, mem: ${MEM_PCT})"
