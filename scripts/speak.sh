#!/usr/bin/env bash
# speak.sh — Audio feedback for Claude Code Music
# Speaks text aloud using macOS `say` or Linux `espeak`/`spd-say`.
# Usage: speak.sh <type> [args...]
#   speak.sh time              — "The time is 2:30 PM"
#   speak.sh song              — "Now playing: Song by Artist"
#   speak.sh task "task name"  — "Finished: task name"
#   speak.sh custom "text"     — Says arbitrary text
#
# Checks .claude/claude-code-music.local.md for audio_enabled preference.
# Default is ENABLED if no preference file exists.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PREFS_FILE="$PROJECT_ROOT/.claude/claude-code-music.local.md"

# ─── Check if audio is enabled ───────────────────────────────────────
is_audio_enabled() {
  # Default: enabled
  if [[ ! -f "$PREFS_FILE" ]]; then
    return 0
  fi
  # Read the audio_enabled field from YAML frontmatter
  local val
  val=$(sed -n '/^---$/,/^---$/p' "$PREFS_FILE" | grep -E '^\s*audio_enabled:' | head -1 | sed 's/.*:\s*//' | tr -d '[:space:]') || true
  if [[ "$val" == "false" ]]; then
    return 1
  fi
  return 0
}

# ─── Read voice preference ────────────────────────────────────────────
get_voice() {
  local default_voice="Samantha"
  if [[ ! -f "$PREFS_FILE" ]]; then
    echo "$default_voice"
    return
  fi
  local val
  val=$(sed -n '/^---$/,/^---$/p' "$PREFS_FILE" | grep -E '^\s*audio_voice:' | head -1 | sed 's/.*:\s*//' | tr -d '[:space:]') || true
  if [[ -n "$val" && "$val" != '""' ]]; then
    echo "$val"
  else
    echo "$default_voice"
  fi
}

# ─── Cross-platform TTS ──────────────────────────────────────────────
speak() {
  local text="$1"
  case "$(uname -s)" in
    Darwin)
      local voice
      voice=$(get_voice)
      say -v "$voice" -r 185 "$text" &
      ;;
    Linux)
      if command -v spd-say &>/dev/null; then
        spd-say -r 10 "$text" &
      elif command -v espeak &>/dev/null; then
        espeak -s 170 "$text" &
      elif command -v espeak-ng &>/dev/null; then
        espeak-ng -s 170 "$text" &
      fi
      ;;
  esac
}

# ─── Get current Spotify track info ──────────────────────────────────
get_current_track() {
  case "$(uname -s)" in
    Darwin)
      if ! osascript -e 'application "Spotify" is running' 2>/dev/null | grep -q "true"; then
        return 1
      fi
      local state
      state=$(osascript -e 'tell application "Spotify" to player state as string' 2>/dev/null) || return 1
      if [[ "$state" != "playing" ]]; then
        return 1
      fi
      local track artist
      track=$(osascript -e 'tell application "Spotify" to name of current track' 2>/dev/null) || return 1
      artist=$(osascript -e 'tell application "Spotify" to artist of current track' 2>/dev/null) || return 1
      echo "$track by $artist"
      ;;
    Linux)
      if command -v playerctl &>/dev/null; then
        local status
        status=$(playerctl -p spotify status 2>/dev/null) || return 1
        [[ "$status" != "Playing" ]] && return 1
        local track artist
        track=$(playerctl -p spotify metadata title 2>/dev/null) || return 1
        artist=$(playerctl -p spotify metadata artist 2>/dev/null) || return 1
        echo "$track by $artist"
      else
        return 1
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

# ─── Main ─────────────────────────────────────────────────────────────
if ! is_audio_enabled; then
  exit 0
fi

TYPE="${1:-}"
shift || true

case "$TYPE" in
  time)
    # Speak the current time in a friendly format
    HOUR=$(date +"%I" | sed 's/^0//')
    MINUTE=$(date +"%M")
    AMPM=$(date +"%p")
    if [[ "$MINUTE" == "00" ]]; then
      speak "The time is ${HOUR} ${AMPM}"
    else
      speak "The time is ${HOUR} ${MINUTE} ${AMPM}"
    fi
    ;;
  song)
    # Speak the currently playing track
    track_info=$(get_current_track 2>/dev/null) || true
    if [[ -n "$track_info" ]]; then
      speak "Now playing: ${track_info}"
    fi
    ;;
  task)
    # Announce task completion
    TASK_NAME="${1:-a task}"
    speak "Finished: ${TASK_NAME}"
    ;;
  custom)
    # Say arbitrary text
    TEXT="${1:-}"
    if [[ -n "$TEXT" ]]; then
      speak "$TEXT"
    fi
    ;;
  *)
    echo "Usage: speak.sh <time|song|task|custom> [args...]"
    exit 1
    ;;
esac
