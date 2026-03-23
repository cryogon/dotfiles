#!/bin/bash

set -euo pipefail

CONFIG_PATH="${QS_CONFIG_PATH:-$HOME/.config/quickshell}"

if quickshell ipc -p "$CONFIG_PATH" call wallpaper toggle 2>/dev/null; then
  exit 0
fi

if quickshell ipc --any-display --newest call wallpaper toggle 2>/dev/null; then
  exit 0
fi

notify-send "Wallpaper Picker" "Couldn't reach Quickshell IPC. Is quickshell running?"
exit 1
