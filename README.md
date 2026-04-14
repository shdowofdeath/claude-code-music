# Claude Code Music

An intelligent coding DJ plugin for Claude Code. Adjusts your Spotify music based on coding mood, activity, and preferences — automatically.

```
> /music focus
  Now playing: Awake - Tycho (focus mode)

> ugh this bug is killing me
  [Claude helps fix the bug]
  ...switched to something calmer

> it works! let's ship it!
  [Claude helps deploy]
  🔊 "Finished: deploy to production. The time is 3:45 PM"
  ...hype track incoming
```

## What it Does

- **Mood-based music** — `/music focus`, `/music hype`, `/music chill`, `/music debug`, `/music flow`, `/music refactor`
- **Automatic mood detection** — detects frustration, triumph, and deep focus from your prompts and adjusts music silently
- **Audio announcements** — speaks the time, current song, and "Finished: task name" aloud when you complete work
- **Session-aware** — auto-plays music when you start coding (if enabled)
- **Celebrates with you** — hype track + voice announcement when you ship something
- **Learns your taste** — `/music-setup` analyzes your Spotify history and builds personalized preferences
- **Status line** — shows `♫ Song - Artist | 14:32` at the bottom of Claude Code

## Quick Start

### 1. Get Spotify API credentials

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Create an app, set redirect URI to `http://127.0.0.1:8888/callback`
3. Copy your Client ID and Client Secret

### 2. Set environment variables

```bash
export SPOTIFY_CLIENT_ID="your_client_id"
export SPOTIFY_CLIENT_SECRET="your_client_secret"
```

### 3. Install the plugin

**Option A: Plugin Marketplace (recommended)**

Inside Claude Code, run:

```
/plugin install claude-code-music@claude-code-music
```

If the marketplace isn't registered yet, add it once to `~/.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "claude-code-music": {
      "source": { "source": "github", "repo": "shdowofdeath/claude-code-music" },
      "autoUpdate": true
    }
  }
}
```

**Option B: Direct install**

```bash
cd your-project
git clone https://github.com/shdowofdeath/claude-code-music.git .claude-code-music
```

The plugin is auto-discovered by Claude Code. The MCP Spotify server is fetched automatically via `npx` — no separate install needed.

### 4. Run setup

Open Claude Code and run:

```
/music-setup
```

The wizard will:
- Authenticate with Spotify
- Learn your music taste from your listening history
- Walk you through preference setup
- Play a test track to confirm it works

### Status Line (optional)

See the current song at the bottom of Claude Code:

```json
// Add to .claude/settings.json
{
  "statusLine": {
    "command": "scripts/now-playing.sh",
    "interval": 10
  }
}
```

Output: `♫ Song Name - Artist | 14:32`

## Commands

| Command | What it does |
|---------|-------------|
| `/music-setup` | First-time setup wizard |
| `/music focus` | Deep focus (ambient, classical, post-rock) |
| `/music hype` | Ship-it energy (synthwave, electronic, d&b) |
| `/music chill` | Casual vibes (indie, acoustic, dream-pop) |
| `/music debug` | Calming debug music (lo-fi, jazz, chillhop) |
| `/music refactor` | Structured cleaning (classical, jazz, piano) |
| `/music flow` | In the zone (trance, progressive, techno) |
| `/music pause` | Pause playback |
| `/music skip` | Next track |
| `/music status` | What's playing |
| `/music surprise` | Random mood, creative pick |
| `/music taste` | Update your preferences |

## How it Works

### Mood Detection

The plugin passively reads your prompts and adjusts music when it detects strong signals:

- **"ugh this bug is killing me"** → switches to calming lo-fi
- **"it works! let's ship it!"** → drops a hype track
- **"let me think about this architecture"** → shifts to ambient focus

Only acts on strong signals. Only when music is already playing. No annoying interruptions.

### Audio Announcements

Uses text-to-speech (macOS `say` / Linux `espeak`) to announce:

| Event | What you hear |
|-------|-------------|
| Song change | "Now playing: Song by Artist" |
| Task complete | "Finished: authentication feature" |
| Time check | "The time is 3:45 PM" |

**Enabled by default.** Disable with `audio_enabled: false` in preferences or during `/music-setup`.

Voice is configurable (macOS) — set `audio_voice: Daniel` in preferences. Run `say -v '?'` to see all voices.

### Preferences

Stored in `.claude/claude-code-music.local.md` (created by `/music-setup` or `/music taste`):

```yaml
---
auto_play: false
audio_enabled: true
audio_voice: Samantha
default_mood: chill
focus_genres: [ambient, electronic, classical, post-rock]
debug_genres: [lo-fi, chillhop, jazz, downtempo]
hype_genres: [electronic, synthwave, drum-and-bass, indie-rock]
no_lyrics_during_focus: true
preferred_energy: medium
---
```

Edit the file directly anytime — changes take effect immediately.

## Architecture

```
claude-code-music/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── .mcp.json                    # Auto-starts Spotify MCP server via npx
├── commands/
│   ├── music.md                 # /music command
│   └── music-setup.md           # /music-setup wizard
├── hooks/
│   └── hooks.json               # Session start, mood detection, celebrations
├── scripts/
│   ├── now-playing.sh           # Status line (♫ Song - Artist | HH:MM)
│   └── speak.sh                 # TTS announcements
├── skills/
│   └── music/
│       ├── SKILL.md             # Main DJ brain
│       └── references/
│           └── preferences-template.md
└── STATUSLINE.md                # Status line setup guide
```

The plugin uses the [mcp-claude-spotify](https://github.com/imprvhub/mcp-claude-spotify) MCP server for Spotify API access. It's fetched automatically via `npx` — no manual installation required.

## Requirements

- Claude Code
- Spotify account (free or premium)
- Spotify desktop app running on any device
- Spotify API credentials ([get them here](https://developer.spotify.com/dashboard))
- macOS or Linux

## License

Apache License 2.0
