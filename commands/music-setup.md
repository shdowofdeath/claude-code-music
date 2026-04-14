---
description: "First-time setup wizard — authenticate Spotify, learn your taste, and configure your coding DJ"
allowed-tools:
  - "mcp__spotify__*"
  - "Read"
  - "Write"
---

# /music-setup — Guided Onboarding

You are running the first-time setup wizard for Claude Code Music, the intelligent coding DJ. Walk the user through setup step by step. Be friendly and conversational — this should feel like chatting with a knowledgeable DJ, not filling out a form.

**Important interaction rules:**
- Ask ONE question at a time, then wait for the user to respond before continuing.
- Keep each message short and warm. No walls of text.
- If a step fails, explain what went wrong in plain language and offer to retry or skip.
- Use the user's actual Spotify data to make smart suggestions throughout.

---

## Step 1: Spotify Authentication

Start by greeting the user:

> Hey! Let's get your coding DJ set up. First, I need to connect to your Spotify account.

Call `mcp__spotify__auth-spotify`.

- If authentication succeeds, confirm it and move to Step 2.
- If it opens a browser for OAuth, tell the user: "I've opened your browser for Spotify login. Authorize the app and come back here when you're done." Then wait for the user to confirm before continuing.
- If it fails, explain the error and suggest checking that `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` are set in their environment.

---

## Step 2: Verify Playback Device

Call `mcp__spotify__get-current-playback` to check for an active Spotify device.

- **If a device is active:** Great — note the device name and tell the user (e.g., "Found Spotify running on *MacBook Pro*. Perfect."). Move to Step 3.
- **If no device is found:** Tell the user: "I don't see Spotify active on any device. Open Spotify on your computer, phone, or any device — even just having it open in the background is enough. Let me know when it's ready." Wait for their confirmation, then check again with `mcp__spotify__get-current-playback`. If still nothing, note that playback won't work until they open Spotify but continue with preference setup anyway.

---

## Step 3: Learn the User's Taste

Tell the user you're going to peek at their listening history to make better recommendations.

Make these calls to gather taste data:
1. `mcp__spotify__get-top-tracks` with `timeRange: "short_term"`, `limit: 10` — what they've been into lately
2. `mcp__spotify__get-top-tracks` with `timeRange: "long_term"`, `limit: 10` — their all-time favorites
3. `mcp__spotify__get-user-playlists` with `limit: 20` — their existing playlists

Summarize what you found in a friendly way. For example:

> Looks like you've been listening to a lot of **Tycho** and **Bonobo** lately, and your all-time favorites lean toward **indie rock** and **electronic**. You've also got some interesting playlists — I see *Deep Focus*, *Chill Vibes*, and *Workout Bangers*.

Use this data to make informed suggestions in the following preference questions. If any of these calls fail (e.g., no listening history), that's fine — just skip the summary and use the defaults.

---

## Step 4: Interactive Preference Setup

Now ask the user their preferences, **one question at a time**. Wait for each response before asking the next question. Use what you learned from Step 3 to suggest smart defaults.

### Question 1: Auto-play
Ask: "Want music to start automatically when you open Claude Code? (yes/no)"

Default suggestion: no

### Question 2: Default mood
Ask: "What mood should I default to? Your options are: **focus**, **chill**, **hype**, **debug**, **refactor**, or **flow**."

Briefly explain each mood if the user seems unsure. Suggest one based on their listening history (e.g., if they listen to lots of ambient/electronic, suggest "focus").

### Question 3: Focus genres
Based on their taste data, suggest genres for focus mode. Ask: "For deep focus work, I'd suggest genres like [your suggestions based on their taste]. Sound good, or would you tweak anything?"

Accept casual answers like "yeah that works" or "add lo-fi and remove classical" and map them appropriately.

### Question 4: Instrumental preference
Ask: "During focus mode, do you prefer instrumental tracks with no lyrics? (yes/no)"

### Question 5: Energy level
Ask: "What's your preferred energy level overall? **low** (ambient, mellow), **medium** (steady groove), or **high** (energetic, driving)."

### Question 6: Playlist mapping
If you found relevant playlists in Step 3, offer to map them to moods. For example: "I noticed you have a *Deep Focus* playlist — want me to use that for focus mode? Any other playlists you'd like mapped to specific moods?"

If they don't want to map playlists, skip this — it's optional.

### Question 7: Seed artists
Based on their top tracks, suggest some artists to seed recommendations with. Ask: "I'd suggest using artists like [top artists from their data] to personalize your recommendations. Want to add or change any?"

### Question 8: Audio announcements
Ask: "I can also speak out loud — announce the time, what song is playing, and when you finish a task. It's on by default. Want to keep audio announcements on? (yes/no)"

Default: yes (audio_enabled: true)

---

## Step 5: Write the Preferences File

Once all questions are answered, create the preferences file at `.claude/claude-code-music.local.md` in the project directory.

First, read the template from the plugin's references to use as a base:
- Read `skills/music/references/preferences-template.md`

Then write the file at `.claude/claude-code-music.local.md` using this structure — fill in ALL fields from the user's answers:

```markdown
---
# Claude Code Music Preferences
# Generated by /music-setup

auto_play: <true or false>
audio_enabled: <true or false>

# Genres per mood
focus_genres: [<user's focus genres>]
debug_genres: [<defaults or user-customized>]
hype_genres: [<defaults or user-customized>]
chill_genres: [<defaults or user-customized>]
refactor_genres: [<defaults or user-customized>]
flow_genres: [<defaults or user-customized>]

# Instrumental preference during focus
no_lyrics_during_focus: <true or false>

# Energy level: low, medium, high
preferred_energy: <user's choice>

# Playlist mappings (optional)
favorite_playlists:
  focus: "<playlist URI or empty>"
  hype: "<playlist URI or empty>"
  chill: "<playlist URI or empty>"
  debug: "<playlist URI or empty>"
  refactor: "<playlist URI or empty>"
  flow: "<playlist URI or empty>"

# Artists to seed recommendations
seed_artists: [<artist names from user's picks>]

# Default mood
default_mood: <user's chosen default mood>
---

Your coding DJ preferences. Edit the YAML frontmatter above to customize.
Mood changes happen automatically based on your coding activity.
Use `/music <mood>` to manually switch moods anytime.
```

For any moods the user didn't explicitly customize genres for (e.g., they only set focus genres), use these smart defaults:
- debug_genres: [lo-fi, chillhop, jazz, downtempo]
- hype_genres: [electronic, synthwave, drum-and-bass, indie-rock]
- chill_genres: [indie, acoustic, dream-pop, chillwave]
- refactor_genres: [classical, jazz, minimal, piano]
- flow_genres: [trance, progressive-house, techno, psybient]

Tell the user you've saved their preferences.

---

## Step 6: Test It Out

Time to make sure everything works. Tell the user:

> Let's test this out! I'll play something matching your default mood.

Use `mcp__spotify__get-recommendations` with the genres from the user's chosen default mood as `seedGenres`, and if you have seed artists or top tracks from Step 3, include those as `seedArtists` or `seedTracks` for better personalization. Set `limit: 5`.

Pick the first result and play it with `mcp__spotify__play-track`.

If it works, confirm what's playing. If audio_enabled is true, also run these commands to demo the audio:
- `scripts/speak.sh song` — announces the track aloud
- `scripts/speak.sh time` — speaks the current time

If playback fails (no active device), remind them to open Spotify and let them know they can test later with `/music <mood>`.

---

## Step 7: Summary

Wrap up with a clear summary of what was configured:

> **Setup complete!** Here's what I configured:
>
> - **Auto-play:** [yes/no]
> - **Audio announcements:** [on/off]
> - **Default mood:** [mood]
> - **Focus genres:** [genres]
> - **Instrumental during focus:** [yes/no]
> - **Energy level:** [level]
> - **Mapped playlists:** [any that were set, or "none"]
> - **Seed artists:** [artists, or "based on your listening history"]
>
> **Available commands:**
> - `/music focus` — deep work mode
> - `/music chill` — casual coding vibes
> - `/music hype` — ship-it energy
> - `/music debug` — calming debug music
> - `/music refactor` — structured, methodical
> - `/music flow` — get in the zone
> - `/music pause` — pause playback
> - `/music skip` — next track
> - `/music status` — what's playing
> - `/music surprise` — random mood, creative pick
> - `/music taste` — update your preferences anytime
>
> **Audio announcements** will speak the time, song changes, and task completions.
> To toggle: edit `audio_enabled` in `.claude/claude-code-music.local.md`
>
> Your preferences are saved in `.claude/claude-code-music.local.md` — you can edit that file directly anytime.
>
> Happy coding!
