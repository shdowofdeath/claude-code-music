#!/usr/bin/env bash
# now-playing.sh — Status line script for Claude Code
# Shows the currently playing Spotify track and current time.
# Designed to be fast (<1s) and handle all error cases gracefully.

set -euo pipefail

get_time() {
  date +"%H:%M"
}

# macOS: use AppleScript to query Spotify
get_track_macos() {
  # Check if Spotify is running
  if ! osascript -e 'application "Spotify" is running' 2>/dev/null | grep -q "true"; then
    return 1
  fi

  # Check if Spotify is actually playing
  local state
  state=$(osascript -e 'tell application "Spotify" to player state as string' 2>/dev/null) || return 1
  if [[ "$state" != "playing" ]]; then
    return 1
  fi

  # Get track name and artist
  local track artist
  track=$(osascript -e 'tell application "Spotify" to name of current track' 2>/dev/null) || return 1
  artist=$(osascript -e 'tell application "Spotify" to artist of current track' 2>/dev/null) || return 1

  if [[ -n "$track" && -n "$artist" ]]; then
    # Truncate long strings to keep status line compact
    [[ ${#track} -gt 30 ]] && track="${track:0:27}..."
    [[ ${#artist} -gt 20 ]] && artist="${artist:0:17}..."
    echo "${track} - ${artist}"
    return 0
  fi
  return 1
}

# Linux: use playerctl (or dbus-send as fallback) to query Spotify
get_track_linux() {
  # Try playerctl first (most common and reliable)
  if command -v playerctl &>/dev/null; then
    local status
    status=$(playerctl -p spotify status 2>/dev/null) || return 1
    if [[ "$status" != "Playing" ]]; then
      return 1
    fi

    local track artist
    track=$(playerctl -p spotify metadata title 2>/dev/null) || return 1
    artist=$(playerctl -p spotify metadata artist 2>/dev/null) || return 1

    if [[ -n "$track" && -n "$artist" ]]; then
      [[ ${#track} -gt 30 ]] && track="${track:0:27}..."
      [[ ${#artist} -gt 20 ]] && artist="${artist:0:17}..."
      echo "${track} - ${artist}"
      return 0
    fi
    return 1
  fi

  # Fallback: dbus-send
  if command -v dbus-send &>/dev/null; then
    local metadata
    metadata=$(dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify \
      /org/mpris/MediaPlayer2 \
      org.freedesktop.DBus.Properties.Get \
      string:"org.mpris.MediaPlayer2.Player" \
      string:"PlaybackStatus" 2>/dev/null) || return 1

    if ! echo "$metadata" | grep -q "Playing"; then
      return 1
    fi

    local track artist
    track=$(dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify \
      /org/mpris/MediaPlayer2 \
      org.freedesktop.DBus.Properties.Get \
      string:"org.mpris.MediaPlayer2.Player" \
      string:"Metadata" 2>/dev/null | grep -A 1 "xesam:title" | tail -1 | sed 's/.*"\(.*\)".*/\1/') || return 1

    artist=$(dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify \
      /org/mpris/MediaPlayer2 \
      org.freedesktop.DBus.Properties.Get \
      string:"org.mpris.MediaPlayer2.Player" \
      string:"Metadata" 2>/dev/null | grep -A 2 "xesam:artist" | tail -1 | sed 's/.*"\(.*\)".*/\1/') || return 1

    if [[ -n "$track" && -n "$artist" ]]; then
      [[ ${#track} -gt 30 ]] && track="${track:0:27}..."
      [[ ${#artist} -gt 20 ]] && artist="${artist:0:17}..."
      echo "${track} - ${artist}"
      return 0
    fi
  fi

  return 1
}

# Main
current_time=$(get_time)

track_info=""
case "$(uname -s)" in
  Darwin)
    track_info=$(get_track_macos 2>/dev/null) || true
    ;;
  Linux)
    track_info=$(get_track_linux 2>/dev/null) || true
    ;;
esac

if [[ -n "$track_info" ]]; then
  echo "♫ ${track_info} | ${current_time}"
else
  echo "${current_time}"
fi
