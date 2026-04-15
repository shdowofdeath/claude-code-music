#!/usr/bin/env bash
# spotify.sh — Lightweight Spotify API client for Claude Code Music
# Zero dependencies beyond curl, bash, and python3 (for OAuth callback).
#
# Usage:
#   spotify.sh auth                              — Run OAuth login flow
#   spotify.sh search <query> [type] [limit]     — Search (type: track|album|artist|playlist)
#   spotify.sh play <trackId> [deviceId]         — Play a track
#   spotify.sh pause                             — Pause playback
#   spotify.sh next                              — Skip to next track
#   spotify.sh prev                              — Previous track
#   spotify.sh status                            — Current playback info
#   spotify.sh recommend <seedGenres> [limit]    — Get recommendations (genres comma-separated)
#   spotify.sh top-tracks [time_range] [limit]   — User's top tracks
#   spotify.sh recent [limit]                    — Recently played
#   spotify.sh playlists [limit]                 — User's playlists
#   spotify.sh create-playlist <name> [desc]     — Create a playlist
#   spotify.sh add-tracks <playlistId> <ids...>  — Add tracks to playlist
#   spotify.sh devices                           — List available devices

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────
SPOTIFY_API="https://api.spotify.com/v1"
SPOTIFY_AUTH="https://accounts.spotify.com"
PORT=8888
REDIRECT_URI="http://127.0.0.1:${PORT}/callback"
TOKEN_DIR="$HOME/.spotify-mcp"
TOKEN_FILE="$TOKEN_DIR/tokens.json"

CLIENT_ID="${SPOTIFY_CLIENT_ID:-}"
CLIENT_SECRET="${SPOTIFY_CLIENT_SECRET:-}"

# ─── Token Management ────────────────────────────────────────────────
load_tokens() {
  if [[ -f "$TOKEN_FILE" ]]; then
    ACCESS_TOKEN=$(python3 -c "import json; d=json.load(open('$TOKEN_FILE')); print(d.get('accessToken',''))" 2>/dev/null) || ACCESS_TOKEN=""
    REFRESH_TOKEN=$(python3 -c "import json; d=json.load(open('$TOKEN_FILE')); print(d.get('refreshToken',''))" 2>/dev/null) || REFRESH_TOKEN=""
    TOKEN_EXPIRY=$(python3 -c "import json; d=json.load(open('$TOKEN_FILE')); print(d.get('tokenExpirationTime',0))" 2>/dev/null) || TOKEN_EXPIRY=0
  else
    ACCESS_TOKEN=""
    REFRESH_TOKEN=""
    TOKEN_EXPIRY=0
  fi
}

save_tokens() {
  mkdir -p "$TOKEN_DIR"
  python3 -c "
import json
d = {'accessToken': '''$ACCESS_TOKEN''', 'refreshToken': '''$REFRESH_TOKEN''', 'tokenExpirationTime': $TOKEN_EXPIRY}
json.dump(d, open('$TOKEN_FILE', 'w'), indent=2)
"
}

now_ms() {
  python3 -c "import time; print(int(time.time() * 1000))"
}

refresh_token() {
  if [[ -z "$REFRESH_TOKEN" ]]; then
    echo '{"error": "No refresh token. Run: spotify.sh auth"}' >&2
    return 1
  fi

  local auth_header
  auth_header=$(printf '%s:%s' "$CLIENT_ID" "$CLIENT_SECRET" | base64 | tr -d '\n')

  local response
  response=$(curl -s -X POST "$SPOTIFY_AUTH/api/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "Authorization: Basic $auth_header" \
    -d "grant_type=refresh_token&refresh_token=$REFRESH_TOKEN")

  local new_access
  new_access=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))" 2>/dev/null) || true

  if [[ -z "$new_access" ]]; then
    echo '{"error": "Token refresh failed. Run: spotify.sh auth"}' >&2
    return 1
  fi

  ACCESS_TOKEN="$new_access"
  local expires_in
  expires_in=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('expires_in',3600))" 2>/dev/null) || expires_in=3600
  TOKEN_EXPIRY=$(python3 -c "import time; print(int(time.time() * 1000) + $expires_in * 1000)")

  # Check if a new refresh token was issued
  local new_refresh
  new_refresh=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('refresh_token',''))" 2>/dev/null) || true
  if [[ -n "$new_refresh" ]]; then
    REFRESH_TOKEN="$new_refresh"
  fi

  save_tokens
}

ensure_token() {
  load_tokens

  if [[ -z "$ACCESS_TOKEN" && -z "$REFRESH_TOKEN" ]]; then
    echo '{"error": "Not authenticated. Run: spotify.sh auth"}'
    exit 1
  fi

  local now
  now=$(now_ms)
  # Refresh if token expires within 60 seconds
  if [[ -z "$ACCESS_TOKEN" || "$now" -ge $((TOKEN_EXPIRY - 60000)) ]]; then
    refresh_token
  fi
}

# ─── API Helper ──────────────────────────────────────────────────────
spotify_api() {
  local method="$1"
  local endpoint="$2"
  shift 2
  local data="${1:-}"

  ensure_token

  local args=(-s -X "$method" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    "${SPOTIFY_API}${endpoint}")

  if [[ -n "$data" ]]; then
    args+=(-d "$data")
  fi

  local response http_code
  response=$(curl -w "\n%{http_code}" "${args[@]}")
  http_code=$(echo "$response" | tail -1)
  response=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "401" ]]; then
    # Token expired mid-request, try refresh once
    refresh_token
    args=(-s -X "$method" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -H "Content-Type: application/json" \
      "${SPOTIFY_API}${endpoint}")
    if [[ -n "$data" ]]; then
      args+=(-d "$data")
    fi
    response=$(curl -w "\n%{http_code}" "${args[@]}")
    http_code=$(echo "$response" | tail -1)
    response=$(echo "$response" | sed '$d')
  fi

  if [[ "$http_code" -ge 400 ]]; then
    echo "{\"error\": \"Spotify API returned $http_code\", \"detail\": $response}"
    return 1
  fi

  # Some endpoints return empty body (204 No Content)
  if [[ -z "$response" ]]; then
    echo '{"status": "ok"}'
  else
    echo "$response"
  fi
}

# ─── OAuth Flow ──────────────────────────────────────────────────────
do_auth() {
  if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" ]]; then
    echo '{"error": "SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET must be set"}'
    exit 1
  fi

  local scopes="user-read-private user-read-email user-read-playback-state user-modify-playback-state user-read-currently-playing playlist-read-private playlist-modify-private playlist-modify-public user-library-read user-top-read user-read-recently-played"
  local encoded_scopes
  encoded_scopes=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$scopes'))")

  local auth_url="${SPOTIFY_AUTH}/authorize?response_type=code&client_id=${CLIENT_ID}&scope=${encoded_scopes}&redirect_uri=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$REDIRECT_URI'))")"

  echo "Opening browser for Spotify login..."

  # Start a tiny Python HTTP server to catch the OAuth callback
  python3 -c "
import http.server, urllib.parse, json, sys, os, webbrowser, threading

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/callback'):
            params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            code = params.get('code', [None])[0]
            if code:
                self.send_response(200)
                self.send_header('Content-Type', 'text/html')
                self.end_headers()
                self.wfile.write(b'<h2>Authentication successful!</h2><p>You can close this window.</p>')
                # Write code to temp file for the shell to pick up
                with open('/tmp/.spotify-auth-code', 'w') as f:
                    f.write(code)
            else:
                self.send_response(400)
                self.send_header('Content-Type', 'text/html')
                self.end_headers()
                self.wfile.write(b'<h2>Authentication failed</h2><p>No code received.</p>')
                with open('/tmp/.spotify-auth-code', 'w') as f:
                    f.write('ERROR')
            # Shut down after handling callback
            threading.Thread(target=self.server.shutdown).start()
        else:
            self.send_response(404)
            self.end_headers()
    def log_message(self, format, *args):
        pass  # Suppress log output

server = http.server.HTTPServer(('127.0.0.1', $PORT), Handler)
webbrowser.open('$auth_url')
server.serve_forever()
" &
  local server_pid=$!

  # Wait for the callback (timeout 120s)
  local waited=0
  while [[ ! -f /tmp/.spotify-auth-code && $waited -lt 120 ]]; do
    sleep 1
    waited=$((waited + 1))
  done

  # Clean up server if still running
  kill $server_pid 2>/dev/null || true
  wait $server_pid 2>/dev/null || true

  if [[ ! -f /tmp/.spotify-auth-code ]]; then
    echo '{"error": "Authentication timed out"}'
    exit 1
  fi

  local code
  code=$(cat /tmp/.spotify-auth-code)
  rm -f /tmp/.spotify-auth-code

  if [[ "$code" == "ERROR" || -z "$code" ]]; then
    echo '{"error": "Authentication failed — no code received"}'
    exit 1
  fi

  # Exchange code for tokens
  local auth_header
  auth_header=$(printf '%s:%s' "$CLIENT_ID" "$CLIENT_SECRET" | base64 | tr -d '\n')

  local response
  response=$(curl -s -X POST "$SPOTIFY_AUTH/api/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "Authorization: Basic $auth_header" \
    -d "grant_type=authorization_code&code=$code&redirect_uri=$REDIRECT_URI")

  ACCESS_TOKEN=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null) || true
  REFRESH_TOKEN=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('refresh_token',''))" 2>/dev/null) || true
  local expires_in
  expires_in=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('expires_in',3600))" 2>/dev/null) || expires_in=3600
  TOKEN_EXPIRY=$(python3 -c "import time; print(int(time.time() * 1000) + $expires_in * 1000)")

  if [[ -z "$ACCESS_TOKEN" || -z "$REFRESH_TOKEN" ]]; then
    echo "{\"error\": \"Token exchange failed\", \"detail\": $response}"
    exit 1
  fi

  save_tokens

  # Verify with a test call
  local user_info
  user_info=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" "$SPOTIFY_API/me")
  local display_name
  display_name=$(echo "$user_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('display_name','unknown'))" 2>/dev/null) || display_name="unknown"

  echo "{\"status\": \"authenticated\", \"user\": \"$display_name\"}"
}

# ─── Commands ────────────────────────────────────────────────────────
CMD="${1:-help}"
shift || true

case "$CMD" in
  auth)
    do_auth
    ;;

  search)
    query="${1:?Usage: spotify.sh search <query> [type] [limit]}"
    type="${2:-track}"
    limit="${3:-5}"
    encoded_query=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$query'))")
    spotify_api GET "/search?q=${encoded_query}&type=${type}&limit=${limit}"
    ;;

  play)
    track_id="${1:?Usage: spotify.sh play <trackId> [deviceId]}"
    device_id="${2:-}"
    endpoint="/me/player/play"
    if [[ -n "$device_id" ]]; then
      endpoint="${endpoint}?device_id=${device_id}"
    fi
    spotify_api PUT "$endpoint" "{\"uris\":[\"spotify:track:${track_id}\"]}"
    ;;

  pause)
    spotify_api PUT "/me/player/pause"
    ;;

  next)
    spotify_api POST "/me/player/next"
    ;;

  prev)
    spotify_api POST "/me/player/previous"
    ;;

  status)
    spotify_api GET "/me/player"
    ;;

  devices)
    spotify_api GET "/me/player/devices"
    ;;

  recommend)
    genres="${1:?Usage: spotify.sh recommend <seedGenres> [limit]}"
    limit="${2:-5}"
    encoded_genres=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$genres'))")
    spotify_api GET "/recommendations?seed_genres=${encoded_genres}&limit=${limit}"
    ;;

  top-tracks)
    time_range="${1:-medium_term}"
    limit="${2:-20}"
    spotify_api GET "/me/top/tracks?time_range=${time_range}&limit=${limit}"
    ;;

  recent)
    limit="${1:-20}"
    spotify_api GET "/me/player/recently-played?limit=${limit}"
    ;;

  playlists)
    limit="${1:-20}"
    spotify_api GET "/me/playlists?limit=${limit}"
    ;;

  create-playlist)
    name="${1:?Usage: spotify.sh create-playlist <name> [description]}"
    desc="${2:-}"
    # Need user ID first
    user_id=$(spotify_api GET "/me" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
    spotify_api POST "/users/$user_id/playlists" "{\"name\":\"$name\",\"description\":\"$desc\",\"public\":false}"
    ;;

  add-tracks)
    playlist_id="${1:?Usage: spotify.sh add-tracks <playlistId> <trackId1> [trackId2...]}"
    shift
    # Build URIs array
    uris=$(printf ',\"spotify:track:%s\"' "$@")
    uris="[${uris:1}]"  # Remove leading comma
    spotify_api POST "/playlists/$playlist_id/tracks" "{\"uris\":$uris}"
    ;;

  help|*)
    cat <<'HELP'
spotify.sh — Spotify API for Claude Code Music

Commands:
  auth                              Authenticate with Spotify
  search <query> [type] [limit]     Search (type: track|album|artist|playlist)
  play <trackId> [deviceId]         Play a track
  pause                             Pause playback
  next                              Next track
  prev                              Previous track
  status                            Current playback
  devices                           List devices
  recommend <genres> [limit]        Get recommendations (genres: comma-separated)
  top-tracks [time_range] [limit]   Top tracks (short_term|medium_term|long_term)
  recent [limit]                    Recently played
  playlists [limit]                 User playlists
  create-playlist <name> [desc]     Create playlist
  add-tracks <playlistId> <ids...>  Add tracks to playlist

Requires: SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET environment variables.
Tokens are saved to ~/.spotify-mcp/tokens.json
HELP
    ;;
esac
