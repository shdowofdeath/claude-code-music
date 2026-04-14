---
description: "Control your coding DJ — play music matched to your coding mood"
argument-hint: "<action: focus|hype|chill|debug|refactor|flow|pause|skip|status|taste|surprise|playlist>"
allowed-tools:
  - "mcp__spotify__*"
---

# /music Command

The user wants to interact with their coding DJ.

Parse the action argument:
- No argument or "status" → Show what's playing and current mood
- "focus" → Start focus mode music
- "hype" → Start hype/ship-it mode music
- "chill" → Start chill coding music
- "debug" → Start calming debug mode music
- "refactor" → Start structured refactor mode music
- "flow" → Start hypnotic flow state music
- "pause" → Pause playback
- "skip" → Skip to next track
- "taste" → Start interactive preference setup
- "surprise" → Random mood, creative pick
- "playlist ..." → Search and play a specific playlist

Load the `music` skill for full instructions on how to handle each action.
