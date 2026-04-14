# Status Line: Now Playing

Show the current time and your currently playing Spotify track in Claude Code's status line.

## Setup

Add the following to your Claude Code settings file (`.claude/settings.json` in your project, or `~/.claude/settings.json` for global settings):

```json
{
  "statusLine": {
    "command": ".claude-plugin/scripts/now-playing.sh",
    "interval": 10
  }
}
```

You can also configure this via the `/config` command inside Claude Code.

## What it shows

When Spotify is playing:

```
♫ Song Name - Artist | 14:32
```

When Spotify is not running or paused:

```
14:32
```

## How it works

The script uses AppleScript on macOS (`osascript`) and `playerctl` on Linux to query the local Spotify application directly. No Spotify API credentials are needed -- it talks to the running desktop app.

Long track names and artist names are automatically truncated to keep the status line compact.

## Requirements

- **macOS**: Spotify desktop app (uses AppleScript, no extra dependencies)
- **Linux**: `playerctl` (recommended) or `dbus-send` (fallback)
  - Install playerctl: `sudo apt install playerctl` (Debian/Ubuntu) or `sudo pacman -S playerctl` (Arch)

## Troubleshooting

Test the script directly to verify it works:

```bash
.claude-plugin/scripts/now-playing.sh
```

If you only see the time and Spotify is playing, check that the Spotify desktop app is running (not just the web player).
