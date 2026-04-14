# Preferences File Template

When the user runs `/music taste`, create or update the file `.claude/claude-code-music.local.md` in their project directory. Use this template as the base, filling in their answers:

```markdown
---
# Claude Code Music Preferences
# Edit this file to customize your coding DJ experience

auto_play: false

# Genres per mood (comma-separated)
# Available moods: focus, debug, hype, chill, refactor, flow
focus_genres: [ambient, electronic, classical, post-rock]
debug_genres: [lo-fi, chillhop, jazz, downtempo]
hype_genres: [electronic, synthwave, drum-and-bass, indie-rock]
chill_genres: [indie, acoustic, dream-pop, chillwave]
refactor_genres: [classical, jazz, minimal, piano]
flow_genres: [trance, progressive-house, techno, psybient]

# Set to true to prefer instrumental tracks during focus mode
no_lyrics_during_focus: true

# Energy level preference: low, medium, high
preferred_energy: medium

# Map specific Spotify playlists to moods (optional)
# Find playlist URIs from Spotify: Share > Copy Spotify URI
favorite_playlists:
  focus: ""
  hype: ""
  chill: ""
  debug: ""
  refactor: ""
  flow: ""

# Specific artists to seed recommendations (optional)
seed_artists: []

# Default mood when no mood is detected
default_mood: chill
---

Your coding DJ preferences. Edit the YAML frontmatter above to customize.
Mood changes happen automatically based on your coding activity.
Use `/music <mood>` to manually switch moods anytime.
```

## Interactive Setup Flow

When setting up preferences, ask these questions one at a time:

1. "Want music to auto-start when you begin a coding session?" (auto_play)
2. "What genres do you like for deep focus work?" (focus_genres)
3. "What about when you're debugging something frustrating?" (debug_genres)
4. "Music for when you're shipping and celebrating?" (hype_genres)
5. "Do you prefer instrumental/no-lyrics during focus?" (no_lyrics_during_focus)
6. "Do you have any specific Spotify playlists you'd like mapped to moods? (paste Spotify URIs)"
7. "Any favorite artists I should use to seed recommendations?"

Don't ask all at once. Make it conversational. Accept casual answers like "lo-fi and jazz" and map them to the right fields.
