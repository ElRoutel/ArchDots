#!/usr/bin/env bash
# Bloquear con MacLock (Quickshell). Si MacLock no logra bloquear, usar hyprlock como respaldo.
if ! sh ~/.config/quickshell/MacLock/lock-via-ipc.sh; then
    pidof hyprlock >/dev/null || hyprlock
fi
