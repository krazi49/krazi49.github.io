#!/usr/bin/env bash
# Update api/state.json with COMPREHENSIVE live system data
# Run via cron or heartbeat for live dashboard

set -e
STATE_FILE="$(cd "$(dirname "$0")/.." && pwd)/api/state.json"

# === HARDWARE ===
HOSTNAME=$(hostname 2>/dev/null || echo "arch-pc")
CHASSIS="laptop 💻"

CPU_MODEL="Intel Celeron N4020 @ 1.10GHz"
CORES="2 cores / 2 threads"
FREQ=$(awk '/CPU max MHz/ {printf "%.2f GHz", $4/1000}' /proc/cpuinfo 2>/dev/null || echo "2.80 GHz")
FREQ_MIN=$(awk '/CPU min MHz/ {printf "%.2f GHz", $4/1000}' /proc/cpuinfo 2>/dev/null || echo "0.80 GHz")
FREQ_DISPLAY="800 MHz – ${FREQ}"

GPU=$(lspci 2>/dev/null | grep -i "vga\|3d\|display" | sed 's/.*: //' || echo "Intel GeminiLake UHD 600")

# Memory
MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}' 2>/dev/null || echo "3.6Gi")
MEM_USED=$(free -h | awk '/^Mem:/ {print $3}' 2>/dev/null || echo "2.8Gi")
MEM_PCT=$(free | awk '/^Mem:/ {printf "%.0f%%", $3/$2 * 100}' 2>/dev/null || echo "—")
MEM_DISPLAY="${MEM_PCT} (${MEM_USED} / ${MEM_TOTAL})"

# Swap
SWAP_TOTAL=$(free -h | awk '/^Swap:/ {print $2}' 2>/dev/null || echo "7.3Gi")
SWAP_USED=$(free -h | awk '/^Swap:/ {print $3}' 2>/dev/null || echo "2.2Gi")
SWAP_DISPLAY="${SWAP_TOTAL} (${SWAP_USED} used)"

# Disk / Storage
DISK_MODEL=$(lsblk -d -o NAME,MODEL 2>/dev/null | grep "sda " | sed 's/.* //' || echo "Samsung SSD 840 PRO")
DISK_SIZE=$(lsblk -d -o SIZE 2>/dev/null | sed -n '2p' || echo "119.2G")
DISK_DISPLAY="${DISK_MODEL} ${DISK_SIZE}"
DISK_PCT=$(df -h / | awk 'NR==2 {print $5}' 2>/dev/null || echo "—")
DISK_USED=$(df -h / | awk 'NR==2 {print $3}' 2>/dev/null || echo "—")
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}' 2>/dev/null || echo "—")
DISK_USAGE="${DISK_PCT} (${DISK_USED} / ${DISK_TOTAL})"

# === SOFTWARE ===
DISTRO=$(hostnamectl 2>/dev/null | grep "Operating System" | sed 's/.*: //' || echo "Lumina (Arch Linux)")
KERNEL=$(uname -r 2>/dev/null || echo "—")
WM="Hyprland"
SHELL=$(basename "$SHELL" 2>/dev/null || echo "zsh")
PACKAGES=$(pacman -Q 2>/dev/null | wc -l || echo "—")
PROCS=$(ps aux --no-headers 2>/dev/null | wc -l || echo "—")

# === LIVE STATUS ===
UPTIME_SEC=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)
UP_DAYS=$(awk '{printf "%d", $1/86400}' /proc/uptime 2>/dev/null || echo "0")
UP_HOURS=$(awk '{printf "%d", ($1%86400)/3600}' /proc/uptime 2>/dev/null || echo "0")
UP_MINS=$(awk '{printf "%d", ($1%3600)/60}' /proc/uptime 2>/dev/null || echo "0")
UPTIME_DISPLAY="${UP_DAYS}d ${UP_HOURS}h ${UP_MINS}m"
BOOT_TS=$(( $(date +%s) - UPTIME_SEC ))
BOOT_TIME=$(TZ=Europe/London date -d "@$BOOT_TS" +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null)

CPU_LOAD=$(awk '{printf "%s / %s / %s", $1, $2, $3}' /proc/loadavg 2>/dev/null || echo "—")
TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%.0f°C", $1/1000}' || echo "—")
SCALING=$(lscpu 2>/dev/null | grep "CPU(s) scaling MHz" | awk '{print $NF}' || echo "—")

# === NETWORK ===
LOCAL_IP=$(ip -4 addr show wlo1 2>/dev/null | grep -oP 'inet \K[\d.]+' || echo "—")
TS_IP=$(ip -4 addr show tailscale0 2>/dev/null | grep -oP 'inet \K[\d.]+' || echo "—")
WIFI=$(ip link show wlo1 2>/dev/null | grep -o "state UP" >/dev/null && echo "connected (wlo1)" || echo "disconnected")

# === MOOD ===
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
  "hostname": "${HOSTNAME}",
  "chassis": "${CHASSIS}",
  "cpu_model": "${CPU_MODEL}",
  "cores": "${CORES}",
  "freq": "${FREQ_DISPLAY}",
  "gpu": "${GPU}",
  "memory": "${MEM_DISPLAY}",
  "swap": "${SWAP_DISPLAY}",
  "disk": "${DISK_DISPLAY}",
  "distro": "${DISTRO}",
  "kernel": "${KERNEL}",
  "wm": "${WM}",
  "shell": "${SHELL}",
  "packages": "${PACKAGES} (pacman)",
  "procs": "${PROCS}",
  "uptime": "${UPTIME_DISPLAY}",
  "load": "${CPU_LOAD}",
  "mem_pct": "${MEM_DISPLAY}",
  "disk_pct": "${DISK_USAGE}",
  "temp": "${TEMP}",
  "scaling": "${SCALING}%",
  "local_ip": "${LOCAL_IP}",
  "ts_ip": "${TS_IP}",
  "wifi": "${WIFI}",
  "boot_time": "${BOOT_TIME}",
  "last_seen": "${LAST_SEEN}",
  "cron_jobs": [
    {"name": "Watch pickup", "schedule": "07:00 daily", "next_run": "${NEXT_30}"},
    {"name": "Mood sync → waybar", "schedule": "every 30m", "next_run": "${NEXT_30}"},
    {"name": "Heartbeat check", "schedule": "every 30m", "next_run": "${NEXT_30}"},
    {"name": "F1 standings refresh", "schedule": "every 60m", "next_run": "${NEXT_60}"}
  ],
  "activity": [
    {"time": "${LAST_SEEN}", "text": "Dashboard state refreshed"}
  ]
}
JSONEOF

echo "✅ Updated: ${MOOD} | ${UPTIME_DISPLAY} | ${MEM_DISPLAY} | ${DISK_USAGE} | ${TEMP}"
