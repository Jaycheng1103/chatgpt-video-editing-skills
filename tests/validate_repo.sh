#!/bin/sh
# Repository acceptance checks for the public package. Keep this POSIX-sh.
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

fail() {
  printf '%s\n' "ERROR: $1" >&2
  exit 1
}

require_file() {
  [ -f "$1" ] || fail "missing required file: $1"
}

# Check the public artifacts first so an incomplete checkout has one clear,
# actionable failure rather than a cascade of content-check errors.
require_file "README.md"
require_file "skills/chatgpt-video-editing-setup/SKILL.md"
require_file "skills/chatgpt-video-editing-setup/references/setup-runbook.md"
require_file "skills/chatgpt-video-editing-setup/references/security-and-verification.md"
require_file "skills/chatgpt-short-video-editor/SKILL.md"
require_file "skills/chatgpt-short-video-editor/references/seven-step-guide.md"
require_file "skills/chatgpt-short-video-editor/references/style-reference.md"
require_file "skills/chatgpt-short-video-editor/scripts/analyze_reference.sh"
require_file "skills/chatgpt-video-editing-setup/references/elevenlabs-mcp.md"
require_file "skills/chatgpt-video-editing-setup/scripts/check_env.sh"
require_file "skills/chatgpt-video-editing-setup/scripts/install_missing.sh"
require_file "skills/chatgpt-video-editing-setup/scripts/prepare_key_file.sh"
require_file "skills/chatgpt-short-video-editor/references/production-rules.md"
require_file "skills/chatgpt-short-video-editor/references/output-contract.md"
require_file "examples/完整提示詞.md"
require_file "LICENSE"

# Inspect every public text-like file, including tests and evals. Only local
# workflow artifacts are excluded. grep -I prevents binary assets from causing
# scan noise.
TEXT_FILES=$(find . \
  \( -path './.git' -o -path './.git/*' \
    -o -path './.superpowers' -o -path './.superpowers/*' \
    -o -path './docs/superpowers' -o -path './docs/superpowers/*' \) -prune -o \
  -type f -print | while IFS= read -r file; do
    if grep -I -F '' "$file" >/dev/null 2>&1; then
      printf '%s\n' "$file"
    fi
  done)

has_phrase() {
  phrase=$1
  while IFS= read -r file; do
    if grep -F "$phrase" "$file" >/dev/null 2>&1; then
      return 0
    fi
  done <<EOF
$TEXT_FILES
EOF
  return 1
}

require_phrase() {
  phrase=$1
  has_phrase "$phrase" || fail "missing required contract phrase: $phrase"
}

require_file_phrase() {
  file=$1
  phrase=$2
  grep -F "$phrase" "$file" >/dev/null 2>&1 ||
    fail "missing required contract phrase in $file: $phrase"
}

reject_file_phrase() {
  file=$1
  phrase=$2
  if grep -F "$phrase" "$file" >/dev/null 2>&1; then
    fail "forbidden legacy contract phrase in $file: $phrase"
  fi
}

require_phrase "ELEVENLABS_API_KEY"
require_phrase "~/Developer/video-use/.env"
require_phrase "edit/"
require_phrase "approval"
require_phrase "ElevenLabs Scribe v2"
require_phrase "video-use"
require_phrase "FFmpeg"
require_phrase "ffprobe"
require_phrase "Pillow"
require_phrase "HyperFrames"
require_phrase "Source Han Sans TW"
for step in "串接 ElevenLabs 和安裝 Agent Reach" "安裝 AI 剪輯工具包並完成下載配置" "放入想要剪輯的影片" \
  "取得剪輯建議並用 ElevenLabs 拿到逐字稿" "詢問是否刪減逐字稿" "提供想參考的剪輯風格" "剪輯出品"; do
  require_file_phrase "skills/chatgpt-short-video-editor/references/seven-step-guide.md" "$step"
done
require_phrase "逐段粗剪 → 轉色／圖卡／字幕 → 混音與完整預覽 → QA 與正式定稿"
require_phrase "30–200ms"
require_phrase "30ms"
require_phrase "720p"
require_phrase "1080×1920"
require_phrase "QA"

# Setup safety regressions: these exact public contracts must remain visible in
# the executable runbook and user-facing prompt instead of being implied by
# generic prose.
SETUP_RUNBOOK="skills/chatgpt-video-editing-setup/references/setup-runbook.md"
SECURITY_RUNBOOK="skills/chatgpt-video-editing-setup/references/security-and-verification.md"
FULL_PROMPT="examples/完整提示詞.md"
EVALS="evals/evals.json"

for eval_id in \
  wrong-origin-hard-stop \
  linked-worktree-repository-inspection \
  hyperframes-node-too-old \
  linux-env-permission-verification \
  hyperframes-skipped-verification; do
  require_file_phrase "$EVALS" "\"id\": \"$eval_id\""
done

for file in "$SETUP_RUNBOOK" "$FULL_PROMPT"; do
  require_file_phrase "$file" 'git -C "$repo" rev-parse --is-inside-work-tree'
  require_file_phrase "$file" 'git -C "$repo" rev-parse --verify HEAD'
  require_file_phrase "$file" 'git -C "$repo" remote get-url origin'
  require_file_phrase "$file" 'https://github.com/browser-use/video-use.git'
  require_file_phrase "$file" 'https://github.com/heygen-com/hyperframes.git'
  require_file_phrase "$file" '[ "$actual_origin" = "$expected_origin" ] ||'
  require_file_phrase "$file" 'node_major=$(node -p'
  require_file_phrase "$file" '[ "$node_major" -ge 22 ] ||'
  require_file_phrase "$file" 'https://github.com/adobe-fonts/source-han-sans/raw/release/SubsetOTF/TW'
  require_file_phrase "$file" 'SourceHanSansTW-Regular.otf'
  require_file_phrase "$file" 'SourceHanSansTW-Bold.otf'
  require_file_phrase "$file" '[ "$magic" = 4f54544f ] ||'
done

require_file_phrase "$SETUP_RUNBOOK" 'HyperFrames 未要求'
require_file_phrase "$SETUP_RUNBOOK" 'if [ "$hyperframes_approved" = yes ] && [ "$hyperframes_installed" = yes ]; then'
require_file_phrase "$FULL_PROMPT" 'HyperFrames 未要求'
require_file_phrase "README.md" 'Node.js 22 或更新版本'
require_file_phrase "README.md" '思源黑體'
require_file_phrase "THIRD_PARTY_NOTICE.md" 'SIL Open Font License 1.1'

reject_file_phrase "$SETUP_RUNBOOK" '[ -d "$repo/.git" ]'
reject_file_phrase "$FULL_PROMPT" '[ -d "$repo/.git" ]'
reject_file_phrase "$SECURITY_RUNBOOK" 'exclude="$HOME/Developer/video-use/.git/info/exclude"'
reject_file_phrase "$FULL_PROMPT" 'exclude="$HOME/Developer/video-use/.git/info/exclude"'

for file in "$SECURITY_RUNBOOK" "$FULL_PROMPT"; do
  require_file_phrase "$file" 'git -C "$repo" rev-parse --path-format=absolute --git-path info/exclude'
  require_file_phrase "$file" '[ -f "$env_file" ] && [ ! -L "$env_file" ]'
  require_file_phrase "$file" "Darwin) mode=\$(stat -f '%Lp' \"\$env_file\") ;;"
  require_file_phrase "$file" "Linux) mode=\$(stat -c '%a' \"\$env_file\") ;;"
done

FORBIDDEN_DEPENDENCY=$(printf '%s%s' 'Open' 'Montage')
while IFS= read -r file; do
  if grep -n -i -F "$FORBIDDEN_DEPENDENCY" "$file"; then
    fail "forbidden dependency reference found in public package files"
  fi
done <<EOF
$TEXT_FILES
EOF

SECRET_PATTERN='(sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{16}|(ELEVENLABS_API_KEY|xi-api-key)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_-]{16,})'
while IFS= read -r file; do
  if grep -n -E "$SECRET_PATTERN" "$file"; then
    fail "secret-shaped value found in public package files"
  fi
done <<EOF
$TEXT_FILES
EOF

# Guided-setup contracts: automation scripts, hosted ElevenLabs MCP, official
# Agent Reach source, and the never-print-a-key rule.
CHECK_ENV="skills/chatgpt-video-editing-setup/scripts/check_env.sh"
INSTALL="skills/chatgpt-video-editing-setup/scripts/install_missing.sh"
KEYFILE="skills/chatgpt-video-editing-setup/scripts/prepare_key_file.sh"
for file in "$CHECK_ENV" "$INSTALL"; do
  require_file_phrase "$file" 'git -C "$repo" rev-parse --is-inside-work-tree'
  require_file_phrase "$file" '[ "$actual_origin" = "$expected_origin" ] ||'
  require_file_phrase "$file" 'https://github.com/browser-use/video-use.git'
  require_file_phrase "$file" 'https://api.elevenlabs.io/v1/mcp'
done
require_file_phrase "$INSTALL" 'https://github.com/Panniantong/Agent-Reach/releases/latest/download/agent-reach.zip'
require_file_phrase "$INSTALL" 'https://github.com/adobe-fonts/source-han-sans/raw/release/SubsetOTF/TW'
require_file_phrase "$INSTALL" '[ "$magic" = 4f54544f ]'
require_file_phrase "$INSTALL" 'DRY RUN: nothing will change.'
require_file_phrase "$KEYFILE" 'git -C "$repo" rev-parse --path-format=absolute --git-path info/exclude'
require_file_phrase "$KEYFILE" '[ -f "$env_file" ] && [ ! -L "$env_file" ]'
require_file_phrase "$KEYFILE" 'value not shown'
require_file_phrase "skills/chatgpt-video-editing-setup/references/elevenlabs-mcp.md" 'codex mcp login elevenlabs'
require_file_phrase "skills/chatgpt-video-editing-setup/SKILL.md" 'never the PyPI'
require_file_phrase "skills/chatgpt-short-video-editor/references/style-reference.md" 'do not pull cookies'
for script in "$CHECK_ENV" "$INSTALL" "$KEYFILE" "skills/chatgpt-short-video-editor/scripts/analyze_reference.sh"; do
  sh -n "$script" || fail "shell syntax error: $script"
done

printf '%s\n' "Repository contract checks passed."
