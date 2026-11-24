# Security and verification

## ElevenLabs credential handling

Use `ELEVENLABS_API_KEY` only from the process environment or from
`~/Developer/video-use/.env`. Never ask the user to paste a key into a chat
transcript, command-line argument, public file, commit message, shell history,
or log. Never print a key or a redacted-looking substitute.

If the key is absent, say that setup cannot complete the credential check.
Preparing local secret storage is an item on the step-2 approval list;
`scripts/prepare_key_file.sh --open` verifies that `.env` is ignored *before*
asking the user to write anything, creates it empty with mode 600, and opens it
for the user. `--verify` reports presence only. Prefer an environment variable when
that is practical. For an approved local file, first run:

```sh
git -C "$HOME/Developer/video-use" check-ignore -q .env
```

If that fails, do not create the file or ask the user for a key. Prefer the
environment-variable option, or, only after explicit approval, add the exact
`.env` entry to the repository-local exclude file. Resolve that file through
Git so this also works in linked worktrees; never guess `$repo/.git/...`:

```sh
repo="$HOME/Developer/video-use"
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
git -C "$repo" check-ignore -q .env
```

If `--path-format=absolute` is unsupported, the result is not absolute, or the
resolved path cannot be verified as a regular non-symlink file, stop and use an
environment variable instead of guessing a path. This internal exclude change
does not dirty the third-party repository. If the second ignore check fails,
stop and use an environment variable instead. Only after ignore verification
succeeds may the user write.
They do so through an editor or secure terminal outside the conversation. The
agent never reads file contents. After the user confirms the file exists,
tighten and verify only its permission bits. Reject a symlink, directory, or
other non-regular path before `chmod`, then select the platform's `stat`
syntax without reading the file:

```sh
env_file="$HOME/Developer/video-use/.env"
[ -f "$env_file" ] && [ ! -L "$env_file" ] || {
  printf '%s\n' 'STOP: .env must be a regular file and not a symlink.' >&2
  exit 1
}
chmod 600 "$env_file"
case "$(uname -s)" in
  Darwin) mode=$(stat -f '%Lp' "$env_file") ;;
  Linux) mode=$(stat -c '%a' "$env_file") ;;
  *)
    printf '%s\n' 'STOP: unsupported platform; .env mode was not verified.' >&2
    exit 1
    ;;
esac
[ "$mode" = 600 ] || {
  printf '%s\n' 'STOP: .env permissions are not 600.' >&2
  exit 1
}
```

Do not create a credential file until that mutation is included in the approval
list. Do not use `cat`, `env`, or similar output that could expose its contents.

## Credential checks without paid transcription

Confirm only that one approved credential source is present and that a local
file has mode `600`. A safe report can say “environment variable present” or
“protected local file present”; it must not disclose its value, length, prefix,
or account details. Do not send a test transcription, upload a sample, inspect
cloud quota, or call an endpoint as part of setup.

Before the first later media upload, obtain a new, specific consent. State the
filename, that it will be uploaded to ElevenLabs for ElevenLabs Scribe v2
transcription, the intended use, and that quota or charges may apply. Do not
upload unless the user confirms that exact action.

## Evidence required for readiness

Report observations, not assumptions:

| Check | Evidence to report |
| --- | --- |
| video-use source | stable path, origin URL, clean Git status, helpers directory; after a repair, the backup paths and the stash name |
| runtime | paths or versions for Python/uv, FFmpeg, and ffprobe |
| subtitle font | `SourceHanSansTW-Regular.otf` and `SourceHanSansTW-Bold.otf` present as regular files in the platform font directory, `OTTO` magic verified, and the `fc-list` match where fontconfig exists |
| video-use registration | agent Skills path and symlink target, if one was approved |
| credential | source present and `.env` mode/ignore check, without value |
| HyperFrames By HeyGen skills | `hyperframes skills check --json` reports `coreMissing` 0 and `outdated` 0 (or the Codex plugin "HyperFrames by HeyGen" shows as added) |
| captions and CSS effects | Node.js 22+, `hyperframes@0.9.86` runs from the npx cache, its render browser path exists, FFmpeg lists the `libvpx-vp9` decoder |
| Agent Reach | `agent-reach version` prints JSON (1.6+); a 1.5 install was upgraded, not left as is |
| no-cost boundary | confirmation that no media was uploaded, transcribed, edited, previewed, or rendered |

If a check fails, report it as incomplete with the next proposed mutation; do
not call the environment “ready.” Do not alter original media in setup. The
later editing workflow keeps new artifacts adjacent to its source under `edit/`.
An existing Node.js older than 22 is a stop, not something to replace: report
it and propose a separate version-manager setup.
