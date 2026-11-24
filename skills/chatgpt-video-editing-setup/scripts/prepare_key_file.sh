#!/bin/sh
# Prepare ~/Developer/video-use/.env for the user's ElevenLabs API key, or verify it.
#   prepare_key_file.sh --open     # ensure .env is git-ignored, create it empty (600), open it in an editor
#   prepare_key_file.sh --verify   # regular file, mode 600, has an ELEVENLABS_API_KEY= line (value never printed)
# The agent never reads, prints, or receives the key. The user types it in the editor.
set -u

repo="$HOME/Developer/video-use"
env_file="$repo/.env"
mode_arg=${1:-}

file_mode() {
  case "$(uname -s)" in
    Darwin) mode=$(stat -f '%Lp' "$env_file") ;;
    Linux) mode=$(stat -c '%a' "$env_file") ;;
    *)
      printf '%s\n' 'STOP: unsupported platform; .env mode was not verified.' >&2
      exit 1
      ;;
  esac
  printf '%s' "$mode"
}

case "$mode_arg" in
  --open)
    git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
      printf '%s\n' "STOP: $repo is not a Git worktree; use an ELEVENLABS_API_KEY environment variable instead." >&2
      exit 1
    }
    if ! git -C "$repo" check-ignore -q .env; then
      exclude=$(git -C "$repo" rev-parse --path-format=absolute --git-path info/exclude) || {
        printf '%s\n' 'STOP: Git cannot resolve the repository-local exclude path; use an environment variable.' >&2
        exit 1
      }
      case "$exclude" in /*) ;; *) exit 1 ;; esac
      [ -f "$exclude" ] && [ ! -L "$exclude" ] || {
        printf '%s\n' 'STOP: exclude path is not a verifiable regular file; use an environment variable.' >&2
        exit 1
      }
      grep -qxF '.env' "$exclude" || printf '%s\n' '.env' >> "$exclude"
      git -C "$repo" check-ignore -q .env || {
        printf '%s\n' 'STOP: .env is still not ignored by Git; use an environment variable.' >&2
        exit 1
      }
    fi
    if [ -L "$env_file" ] || { [ -e "$env_file" ] && [ ! -f "$env_file" ]; }; then
      printf '%s\n' 'STOP: .env must be a regular file and not a symlink.' >&2
      exit 1
    fi
    if [ ! -e "$env_file" ]; then
      (umask 077 && printf '%s\n' '# Paste one line below, save, and close: ELEVENLABS_API_KEY=your-key' > "$env_file")
    fi
    chmod 600 "$env_file"
    [ "$(file_mode)" = 600 ] || { printf '%s\n' 'STOP: .env permissions are not 600.' >&2; exit 1; }
    case "$(uname -s)" in
      Darwin) open -e "$env_file" && printf '%s\n' "OPENED $env_file in TextEdit" ;;
      *) printf '%s\n' "OPEN THIS FILE IN AN EDITOR: $env_file" ;;
    esac
    ;;
  --verify)
    [ -f "$env_file" ] && [ ! -L "$env_file" ] || {
      printf '%s\n' 'STOP: .env must be a regular file and not a symlink.' >&2
      exit 1
    }
    chmod 600 "$env_file"
    [ "$(file_mode)" = 600 ] || { printf '%s\n' 'STOP: .env permissions are not 600.' >&2; exit 1; }
    if grep -q '^ELEVENLABS_API_KEY=..*' "$env_file"; then
      printf '%s\n' 'KEY_PRESENT protected local file (value not shown)'
    else
      printf '%s\n' 'KEY_MISSING the file has no ELEVENLABS_API_KEY= line yet'
      exit 2
    fi
    ;;
  *) printf '%s\n' 'usage: prepare_key_file.sh --open|--verify' >&2; exit 64 ;;
esac
