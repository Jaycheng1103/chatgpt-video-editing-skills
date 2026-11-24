#!/bin/sh
# Install only what check_env.sh reports as missing, for one guided step.
#   install_missing.sh --step 1            # dry run: print what would change
#   install_missing.sh --step 1 --yes      # run it after the user's one approval
# Step 1: uv, Agent Reach (official GitHub release), hosted ElevenLabs MCP entry.
# Step 2: FFmpeg, video-use (official repo) + uv sync, Skill links, subtitle font,
#         Node.js (only if absent) + HyperFrames CLI and its render browser,
#         and an empty protected .env for the ElevenLabs API key.
# Hard stops (dirty repo, wrong origin, non-regular font path, foreign symlink)
# are never overridden. Nothing here uploads media or prints a credential.
set -u

STEP=""
YES=no
while [ $# -gt 0 ]; do
  case "$1" in
    --step) STEP=${2:-}; shift 2 ;;
    --yes) YES=yes; shift ;;
    *) printf '%s\n' "unknown argument: $1" >&2; exit 64 ;;
  esac
done
case "$STEP" in 1|2) ;; *) printf '%s\n' 'usage: install_missing.sh --step 1|2 [--yes]' >&2; exit 64 ;; esac

VIDEO_USE_DIR="$HOME/Developer/video-use"
VIDEO_USE_ORIGIN=https://github.com/browser-use/video-use.git
AGENT_REACH_RELEASE=https://github.com/Panniantong/Agent-Reach/releases/latest/download/agent-reach.zip
ELEVENLABS_MCP_URL=https://api.elevenlabs.io/v1/mcp
FONT_SOURCE=https://github.com/adobe-fonts/source-han-sans/raw/release/SubsetOTF/TW
HYPERFRAMES_VERSION=${HYPERFRAMES_VERSION:-0.9.86}
OS=$(uname -s)

failed=""
done_items=""
todo() { printf 'PLAN %s\n' "$1"; }
ok() { [ "$YES" = yes ] || return 0; printf 'DONE %s\n' "$1"; done_items="$done_items $1"; }
stop() { printf 'STOP %s\n' "$1" >&2; failed="$failed $2"; }
run() {
  if [ "$YES" = yes ]; then "$@"; else printf 'WOULD RUN %s\n' "$*"; return 0; fi
}

inspect_repo() {
  repo=$1
  expected_origin=$2
  if [ ! -e "$repo" ] && [ ! -L "$repo" ]; then
    printf '%s\n' "missing repository: $repo"
    return 2
  fi
  inside=$(git -C "$repo" rev-parse --is-inside-work-tree 2>/dev/null) || return 1
  [ "$inside" = true ] || return 1
  commit=$(git -C "$repo" rev-parse --verify HEAD) || return 1
  branch=$(git -C "$repo" branch --show-current) || return 1
  [ -n "$branch" ] || branch="(detached at $commit)"
  actual_origin=$(git -C "$repo" remote get-url origin) || return 1
  [ "$actual_origin" = "$expected_origin" ] || {
    printf '%s\n' "STOP: unexpected origin for $repo: $actual_origin" >&2
    return 1
  }
  status=$(git -C "$repo" status --short) || return 1
  printf '%s\n' "repo=$repo" "origin=$actual_origin" \
    "branch=$branch" "commit=$commit" "status=${status:-clean}"
  [ -z "$status" ] || return 1
}

ensure_uv() {
  command -v uv >/dev/null 2>&1 && return 0
  todo "install uv with the official installer (no admin password)"
  case "$OS" in
    Darwin|Linux) run sh -c 'curl -LsSf https://astral.sh/uv/install.sh | sh' || { stop "uv install failed" uv; return 1; } ;;
    *) stop "unsupported platform for uv; install it manually" uv; return 1 ;;
  esac
  [ "$YES" = yes ] || return 0
  PATH="$HOME/.local/bin:$PATH"; export PATH
  command -v uv >/dev/null 2>&1 && ok uv || { stop "uv installed but not on PATH; open a new terminal" uv; return 1; }
}

step1() {
  ensure_uv || return 0

  # Agent Reach: never from PyPI; only the official GitHub release.
  ar_state=missing
  if command -v agent-reach >/dev/null 2>&1; then
    case "$(agent-reach version 2>/dev/null | head -n 1)" in \{*) ar_state=ok ;; *) ar_state=old ;; esac
  fi
  case "$ar_state" in
    ok) printf '%s\n' 'SKIP agent-reach already 1.6+' ;;
    missing) todo "install Agent Reach from $AGENT_REACH_RELEASE and run agent-reach setup"
      run uv tool install "$AGENT_REACH_RELEASE" && run agent-reach setup && ok agent-reach || stop "Agent Reach install failed" agent-reach ;;
    old) todo "upgrade Agent Reach 1.5 to 1.6+ (keys and settings are kept) and run agent-reach setup"
      run uv tool install --force "$AGENT_REACH_RELEASE" && run agent-reach setup && ok agent-reach || stop "Agent Reach upgrade failed" agent-reach ;;
  esac

  # Hosted ElevenLabs MCP: add the entry; OAuth sign-in happens in the browser afterwards.
  if command -v codex >/dev/null 2>&1; then
    if codex mcp get elevenlabs >/dev/null 2>&1; then printf '%s\n' 'SKIP codex already has an elevenlabs MCP entry'
    else todo "codex mcp add elevenlabs --url $ELEVENLABS_MCP_URL"
      run codex mcp add elevenlabs --url "$ELEVENLABS_MCP_URL" && ok mcp-codex || stop "codex mcp add failed" mcp-codex; fi
  fi
  if command -v claude >/dev/null 2>&1; then
    if [ -f "$HOME/.claude.json" ] && grep -q "$ELEVENLABS_MCP_URL" "$HOME/.claude.json" 2>/dev/null; then
      printf '%s\n' 'SKIP claude already has the hosted ElevenLabs MCP'
    else todo "claude mcp add --transport http --scope user elevenlabs $ELEVENLABS_MCP_URL"
      run claude mcp add --transport http --scope user elevenlabs "$ELEVENLABS_MCP_URL" && ok mcp-claude || stop "claude mcp add failed" mcp-claude; fi
  fi
  printf '%s\n' "NEXT sign in: codex mcp login elevenlabs  (Claude Code: /mcp -> elevenlabs -> Authenticate). The user signs in and clicks Allow in the browser."
}

step2() {
  # FFmpeg
  if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
    if [ "$OS" = Darwin ] && command -v brew >/dev/null 2>&1; then
      todo "brew install ffmpeg"
      run brew install ffmpeg && ok ffmpeg || stop "brew install ffmpeg failed" ffmpeg
    elif [ "$OS" = Darwin ]; then
      stop "FFmpeg needs Homebrew. Ask the user to install Homebrew from https://brew.sh (it asks for their Mac password), then rerun" ffmpeg
    else
      stop "run in a terminal: sudo apt-get update && sudo apt-get install -y ffmpeg (needs the user's password)" ffmpeg
    fi
  fi

  ensure_uv || return 0

  # video-use: clone when absent; never pull, reset, or overwrite an existing checkout.
  inspect_repo "$VIDEO_USE_DIR" "$VIDEO_USE_ORIGIN" >/dev/null 2>&1
  r=$?
  if [ "$r" -eq 2 ]; then
    todo "git clone $VIDEO_USE_ORIGIN $VIDEO_USE_DIR"
    run mkdir -p "$HOME/Developer" && run git clone "$VIDEO_USE_ORIGIN" "$VIDEO_USE_DIR" && ok video-use || { stop "clone failed" video-use; return 0; }
    [ "$YES" = yes ] || { todo "uv sync in $VIDEO_USE_DIR"; r=dry; }
  elif [ "$r" -ne 0 ]; then
    stop "$VIDEO_USE_DIR is not the clean official checkout; not touching it (see check_env.sh)" video-use
    r=stopped
  fi
  if [ "$r" = 0 ] || [ "$r" = 2 ]; then
    if [ ! -d "$VIDEO_USE_DIR/.venv" ]; then
      inspect_repo "$VIDEO_USE_DIR" "$VIDEO_USE_ORIGIN" >/dev/null 2>&1 || { stop "repository changed before uv sync" video-use-deps; return 0; }
      todo "uv sync in $VIDEO_USE_DIR (uv.lock it creates is added to the repo-local Git exclude so the checkout stays clean)"
      if [ "$YES" = yes ]; then
        exclude=$(git -C "$VIDEO_USE_DIR" rev-parse --path-format=absolute --git-path info/exclude) &&
          case "$exclude" in /*) ;; *) false ;; esac &&
          { [ -e "$exclude" ] || : > "$exclude"; } &&
          [ -f "$exclude" ] && [ ! -L "$exclude" ] &&
          { grep -qxF 'uv.lock' "$exclude" || printf '%s\n' 'uv.lock' >> "$exclude"; } ||
          { stop "cannot resolve the repo-local exclude file; uv.lock would dirty the checkout" video-use-deps; return 0; }
      fi
      run sh -c "cd \"$VIDEO_USE_DIR\" && uv sync" && ok video-use-deps || stop "uv sync failed" video-use-deps
    fi
  fi

  # Register the whole repository (helpers must stay next to SKILL.md).
  if [ "$r" != stopped ]; then
    for dir in "$HOME/.agents/skills" "$HOME/.codex/skills" "$HOME/.claude/skills"; do
      [ -d "$dir" ] || continue
      link="$dir/video-use"
      if [ -L "$link" ]; then
        [ "$(readlink "$link")" = "$VIDEO_USE_DIR" ] || stop "$link points elsewhere; left unchanged" video-use-skill
      elif [ -e "$link" ]; then
        stop "$link exists and is not a symlink; left unchanged" video-use-skill
      else
        todo "ln -s $VIDEO_USE_DIR $link"
        run ln -s "$VIDEO_USE_DIR" "$link" && ok "video-use-skill:$dir"
      fi
    done
  fi

  # Subtitle font from the official Adobe repository; never overwrite.
  case "$OS" in
    Darwin) font_dir="$HOME/Library/Fonts" ;;
    Linux) font_dir="$HOME/.local/share/fonts" ;;
    *) font_dir="" ;;
  esac
  if [ -n "$font_dir" ]; then
    for weight in Regular Bold; do
      font_file="$font_dir/SourceHanSansTW-$weight.otf"
      if [ -e "$font_file" ] || [ -L "$font_file" ]; then continue; fi
      todo "download SourceHanSansTW-$weight.otf (~6 MB) from $FONT_SOURCE"
      run mkdir -p "$font_dir"
      run curl -fL --proto '=https' -o "$font_file" "$FONT_SOURCE/SourceHanSansTW-$weight.otf" || { stop "font download failed: $font_file" font; continue; }
      [ "$YES" = yes ] || continue
      magic=$(head -c 4 "$font_file" | od -An -tx1 | tr -d ' \n')
      [ "$magic" = 4f54544f ] && ok "font-$weight" || stop "not a valid OpenType font: $font_file (left in place for review)" font
    done
    if [ "$YES" = yes ] && [ "$OS" = Linux ] && command -v fc-cache >/dev/null 2>&1; then fc-cache -f "$font_dir" >/dev/null 2>&1; fi
  fi

  # Captions and CSS effects: HyperFrames CLI (pinned) and its own render browser.
  # An existing Node.js older than 22 is never replaced here (hard stop).
  if ! command -v node >/dev/null 2>&1; then
    if [ "$OS" = Darwin ] && command -v brew >/dev/null 2>&1; then
      todo "brew install node (Node.js for HyperFrames captions and effects)"
      run brew install node && ok node || stop "brew install node failed" node
    else
      stop "Node.js 22+ is missing. Ask the user to install the LTS from https://nodejs.org, then rerun" node
    fi
  fi
  node_major=$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)
  if command -v node >/dev/null 2>&1 && [ "${node_major:-0}" -lt 22 ] 2>/dev/null; then
    stop "Node.js $(node --version) is older than 22; ask before installing a newer one beside it" hyperframes
  elif command -v npx >/dev/null 2>&1 || [ "$YES" != yes ]; then
    if npx --no-install "hyperframes@$HYPERFRAMES_VERSION" browser path >/dev/null 2>&1; then
      :
    else
      todo "download hyperframes@$HYPERFRAMES_VERSION (npm) and its render browser (about 320 MB on disk, measured on macOS arm64)"
      run npx -y "hyperframes@$HYPERFRAMES_VERSION" --version >/dev/null && \
        run npx -y "hyperframes@$HYPERFRAMES_VERSION" browser ensure && ok hyperframes || stop "HyperFrames setup failed" hyperframes
    fi
  fi

  # API key file: prepared empty and protected; the user types the key themselves.
  if [ -z "${ELEVENLABS_API_KEY:-}" ] && [ "$r" != stopped ]; then
    script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
    if [ -f "$VIDEO_USE_DIR/.env" ] && grep -q '^ELEVENLABS_API_KEY=..*' "$VIDEO_USE_DIR/.env" 2>/dev/null; then
      :
    else
      todo "prepare protected $VIDEO_USE_DIR/.env and open it for the user to paste the key"
      run sh "$script_dir/prepare_key_file.sh" --open || stop "key file not prepared" elevenlabs-key
    fi
  fi
}

[ "$YES" = yes ] || printf '%s\n' 'DRY RUN: nothing will change. Rerun with --yes after the user approves this list.'
"step$STEP"
printf 'RESULT done=%s failed=%s\n' "$(printf '%s' "$done_items" | sed 's/^ //')" "$(printf '%s' "$failed" | sed 's/^ //')"
[ -z "$failed" ]
