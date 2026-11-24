#!/bin/sh
# Read-only environment check for the AI short-video editing toolkit.
# It never installs, downloads, uploads, or prints a credential.
# Output: one "CHECK <item> <ok|missing|old|stop|info> <detail>" line per item,
# then "NEED_STEP1=" and "NEED_STEP2=" summary lines the agent can act on.
set -u

VIDEO_USE_DIR="$HOME/Developer/video-use"
VIDEO_USE_ORIGIN=https://github.com/browser-use/video-use.git
ELEVENLABS_MCP_URL=https://api.elevenlabs.io/v1/mcp
HYPERFRAMES_VERSION=${HYPERFRAMES_VERSION:-0.9.86}

need1=""
need2=""
stops=""
add1() { need1="$need1 $1"; }
add2() { need2="$need2 $1"; }
say() {
  printf 'CHECK %s %s %s\n' "$1" "$2" "${3:-}"
  [ "$2" = stop ] && stops="$stops $1"
  return 0
}

inspect_repo() {
  repo=$1
  expected_origin=$2

  if [ ! -e "$repo" ] && [ ! -L "$repo" ]; then
    printf '%s\n' "missing repository: $repo"
    return 2
  fi

  inside=$(git -C "$repo" rev-parse --is-inside-work-tree 2>/dev/null) || {
    printf '%s\n' "STOP: existing path is not a Git worktree: $repo" >&2
    return 1
  }
  [ "$inside" = true ] || {
    printf '%s\n' "STOP: existing path is not inside a Git worktree: $repo" >&2
    return 1
  }

  commit=$(git -C "$repo" rev-parse --verify HEAD) || return 1
  branch=$(git -C "$repo" branch --show-current) || return 1
  [ -n "$branch" ] || branch="(detached at $commit)"
  actual_origin=$(git -C "$repo" remote get-url origin) || {
    printf '%s\n' "STOP: origin is missing: $repo" >&2
    return 1
  }
  [ "$actual_origin" = "$expected_origin" ] || {
    printf '%s\n' "STOP: unexpected origin for $repo: $actual_origin" >&2
    return 1
  }
  status=$(git -C "$repo" status --short) || return 1
  printf '%s\n' "repo=$repo" "origin=$actual_origin" \
    "branch=$branch" "commit=$commit" "status=${status:-clean}"
  [ -z "$status" ] || {
    printf '%s\n' "STOP: repository is dirty: $repo" >&2
    return 1
  }
}

# --- platform and agents -----------------------------------------------------
os=$(uname -s)
say platform info "$os $(uname -m)"
for agent in codex claude; do
  if command -v "$agent" >/dev/null 2>&1; then say "agent-$agent" ok "$(command -v "$agent")"; fi
done

# --- runtime tools -----------------------------------------------------------
for tool in git python3 curl; do
  if command -v "$tool" >/dev/null 2>&1; then say "$tool" ok "$(command -v "$tool")"
  else say "$tool" missing "required"; add2 "$tool"; fi
done
if command -v uv >/dev/null 2>&1; then say uv ok "$(uv --version 2>/dev/null)"
else say uv missing "needed by Agent Reach and video-use"; add1 uv; fi
for tool in ffmpeg ffprobe; do
  if command -v "$tool" >/dev/null 2>&1; then say "$tool" ok "$(command -v "$tool")"
  else say "$tool" missing "required"; add2 ffmpeg; fi
done
if [ "$os" = Darwin ]; then
  if command -v brew >/dev/null 2>&1; then say brew ok "$(command -v brew)"
  else say brew missing "only needed when FFmpeg is missing"; fi
fi

# --- step 1: Agent Reach -----------------------------------------------------
if command -v agent-reach >/dev/null 2>&1; then
  ver=$(agent-reach version 2>/dev/null | head -n 1)
  case "$ver" in
    \{*) say agent-reach ok "1.6+ (JSON output)" ;;
    *) say agent-reach old "$ver; upgrade to 1.6+ with uv"; add1 agent-reach ;;
  esac
else
  say agent-reach missing "install from the official GitHub release"; add1 agent-reach
fi

# --- step 1: ElevenLabs MCP (configuration only; tool availability is checked by the agent itself)
mcp_found=no
if command -v codex >/dev/null 2>&1; then
  if row=$(codex mcp get elevenlabs 2>/dev/null) && printf '%s' "$row" | grep -q "$ELEVENLABS_MCP_URL"; then
    say mcp-codex ok "elevenlabs -> $ELEVENLABS_MCP_URL (run: codex mcp login elevenlabs if not signed in)"
    mcp_found=yes
  elif codex mcp list 2>/dev/null | grep -qi 'elevenlabs'; then
    say mcp-codex info "an ElevenLabs MCP entry exists but is not the hosted URL"
    mcp_found=yes
  else
    say mcp-codex missing "add the hosted ElevenLabs MCP to Codex"
  fi
fi
if command -v claude >/dev/null 2>&1; then
  if [ -f "$HOME/.claude.json" ] && grep -q "$ELEVENLABS_MCP_URL" "$HOME/.claude.json" 2>/dev/null; then
    say mcp-claude ok "elevenlabs -> $ELEVENLABS_MCP_URL (authenticate inside /mcp if needed)"
    mcp_found=yes
  else
    say mcp-claude missing "add the hosted ElevenLabs MCP to Claude Code"
  fi
fi
[ "$mcp_found" = yes ] || add1 elevenlabs-mcp

# --- step 2: video-use ---------------------------------------------------------
repo_report=$(inspect_repo "$VIDEO_USE_DIR" "$VIDEO_USE_ORIGIN" 2>&1)
repo_result=$?
case "$repo_result" in
  0) say video-use ok "$(printf '%s' "$repo_report" | tr '\n' ' ')"
     if [ -d "$VIDEO_USE_DIR/.venv" ]; then say video-use-deps ok "$VIDEO_USE_DIR/.venv"
     else say video-use-deps missing "uv sync not run"; add2 video-use-deps; fi ;;
  2) say video-use missing "$VIDEO_USE_DIR"; add2 video-use ;;
  *) say video-use stop "$(printf '%s' "$repo_report" | tr '\n' ' ')" ;;
esac

for dir in "$HOME/.agents/skills" "$HOME/.codex/skills" "$HOME/.claude/skills"; do
  [ -d "$dir" ] || continue
  link="$dir/video-use"
  if [ -L "$link" ]; then
    target=$(readlink "$link")
    if [ "$target" = "$VIDEO_USE_DIR" ]; then say video-use-skill ok "$link -> $target"
    else say video-use-skill stop "$link points to $target"; fi
  elif [ -e "$link" ]; then
    say video-use-skill stop "$link exists and is not a symlink"
  else
    say video-use-skill missing "$link"; add2 video-use-skill
  fi
done

# --- step 2: subtitle font -----------------------------------------------------
case "$os" in
  Darwin) font_dir="$HOME/Library/Fonts" ;;
  Linux) font_dir="$HOME/.local/share/fonts" ;;
  *) font_dir="" ;;
esac
if [ -n "$font_dir" ]; then
  for weight in Regular Bold; do
    font_file="$font_dir/SourceHanSansTW-$weight.otf"
    if [ -f "$font_file" ] && [ ! -L "$font_file" ]; then say "font-$weight" ok "$font_file"
    elif [ -e "$font_file" ] || [ -L "$font_file" ]; then say "font-$weight" stop "$font_file is not a regular file"
    else say "font-$weight" missing "$font_file"; add2 font; fi
  done
else
  say font stop "unsupported platform; font not checked"
fi

# --- step 2: ElevenLabs API key for word-level Scribe v2 timestamps (presence only)
env_file="$VIDEO_USE_DIR/.env"
if [ -n "${ELEVENLABS_API_KEY:-}" ]; then
  say elevenlabs-key ok "environment variable present"
elif [ -f "$env_file" ] && [ ! -L "$env_file" ] && grep -q '^ELEVENLABS_API_KEY=..*' "$env_file" 2>/dev/null; then
  case "$os" in
    Darwin) mode=$(stat -f '%Lp' "$env_file") ;;
    Linux) mode=$(stat -c '%a' "$env_file") ;;
    *) mode=unknown ;;
  esac
  if [ "$mode" = 600 ]; then say elevenlabs-key ok "protected local file present (mode 600)"
  else say elevenlabs-key info "local file present but mode is $mode; tighten to 600"; add2 elevenlabs-key; fi
else
  say elevenlabs-key missing "needed for word-level transcripts"; add2 elevenlabs-key
fi

# --- step 2: captions and CSS effects (HyperFrames; Node.js 22+, its own Chrome)
if command -v node >/dev/null 2>&1; then
  node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)
  if [ "${node_major:-0}" -ge 22 ] 2>/dev/null; then say node ok "$(node --version)"
  else say node stop "found $(node --version 2>/dev/null); HyperFrames needs Node.js 22+. Do not replace the user's Node without asking"; fi
else
  say node missing "Node.js 22+ for HyperFrames captions and effects"; add2 node
fi
if command -v npx >/dev/null 2>&1 && npx --no-install "hyperframes@$HYPERFRAMES_VERSION" --version >/dev/null 2>&1; then
  say hyperframes ok "hyperframes@$HYPERFRAMES_VERSION cached"
  chrome=$(npx --no-install "hyperframes@$HYPERFRAMES_VERSION" browser path 2>/dev/null | tail -n 1)
  if [ -n "$chrome" ] && [ -e "$chrome" ]; then say hyperframes-chrome ok "$chrome"
  else say hyperframes-chrome missing "render browser not downloaded"; add2 hyperframes; fi
else
  say hyperframes missing "hyperframes@$HYPERFRAMES_VERSION (CSS captions and effects)"; add2 hyperframes
fi
if command -v ffmpeg >/dev/null 2>&1; then
  if ffmpeg -hide_banner -decoders 2>/dev/null | grep -q libvpx-vp9; then say ffmpeg-vp9-alpha ok "libvpx-vp9 decoder (reads the transparent effects layer)"
  else say ffmpeg-vp9-alpha stop "this FFmpeg cannot decode VP9 with alpha; the effects layer cannot be composited"; fi
fi

# --- optional reference downloader -------------------------------------------
if command -v yt-dlp >/dev/null 2>&1; then say yt-dlp ok "$(command -v yt-dlp)"
elif command -v uvx >/dev/null 2>&1; then say yt-dlp info "not on PATH; 'uvx yt-dlp' will be used"
else say yt-dlp missing "installed with uv in step 1"; fi

dedupe() { printf '%s\n' $1 | awk 'NF && !seen[$0]++' | tr '\n' ' ' | sed 's/ $//'; }
printf 'NEED_STEP1=%s\n' "$(dedupe "$need1")"
printf 'NEED_STEP2=%s\n' "$(dedupe "$need2")"
printf 'STOPS=%s\n' "$(dedupe "$stops")"
printf '%s\n' 'NOTE: read-only check; nothing was installed, uploaded, or transcribed.'
