---
name: chatgpt-video-editing-setup
description: "Guide steps 1–2 of the seven-step AI short-video workflow: check the machine automatically, connect the hosted ElevenLabs MCP, install or upgrade Agent Reach, then install the editing toolkit (video-use, FFmpeg, Source Han Sans TW subtitle font, HyperFrames for one-line captions and CSS effects) and the ElevenLabs API key file in one approved pass. Use whenever a user wants to install, set up, fix, reconnect, or check the AI short-video editing environment, connect ElevenLabs, or install Agent Reach for this workflow. Do not use for Premiere or CapCut help, or to edit/transcribe media; hand those to chatgpt-short-video-editor once setup is verified."
---

# ChatGPT Video Editing Setup（第 1–2 步）

This Skill runs steps 1 and 2 of the seven-step flow in
[the guided flow](../chatgpt-short-video-editor/references/seven-step-guide.md).
It ends with an evidence-backed readiness report and a friendly question that
leads the user into step 3. It never uploads, transcribes, edits, or renders media.

## How to talk to the user

- Speak Traditional Chinese, warm and plain, like a patient friend sitting next
  to them. No jargon without a one-line plain explanation.
- Tell them where they are: 「我們一共 7 步，現在在第 1 步。」
- Ask exactly **one** question at a time and suggest the answer you recommend.
  End every step with a question that moves them to the next step.
- Do the work yourself. Only ask the user for what you cannot do: clicking
  Allow on a sign-in page, typing their API key into a file, or typing their
  Mac password into a terminal.

## Step 1：串接 ElevenLabs 和安裝 Agent Reach

1. Run the read-only check immediately (no permission needed; it changes nothing):
   `sh scripts/check_env.sh` from this Skill's directory. Read `NEED_STEP1`,
   `NEED_STEP2`, and `STOPS`.
2. **Check your own tool list first.** If ElevenLabs MCP tools are already
   available to you in this session, ElevenLabs is connected whatever the
   script says (connectors added in the app's settings are not visible to the
   script). Otherwise read [the ElevenLabs MCP guide](references/elevenlabs-mcp.md).
3. Show what is missing for step 1 in one short list, then ask once, e.g.:
   「我幫你檢查好了：還沒接上 ElevenLabs，Agent Reach 也還沒裝。我會一次幫你裝好，
   中間會跳出 ElevenLabs 登入頁，你登入後按『允許』就好。可以開始嗎？」
4. After a yes, run `sh scripts/install_missing.sh --step 1 --yes`, then start
   the OAuth sign-in (`codex mcp login elevenlabs`, or Claude Code `/mcp`).
   Agent Reach comes only from the official GitHub release (never the PyPI
   package named `agent-reach`); show its `installation_report.markdown` as is.
5. Verify: rerun `check_env.sh`; confirm ElevenLabs MCP tools appear for you
   (a new chat may be needed after adding an MCP; say so plainly if it is).
   Then lead on:
   「ElevenLabs 接好了，Agent Reach 也裝好了。第 2 步要下載剪輯工具包，
   要我現在一次幫你裝好嗎？」

## Step 2：安裝 AI 剪輯工具包並完成下載配置

1. Run `sh scripts/install_missing.sh --step 2` (dry run) and turn its `PLAN`
   lines into a plain list with rough sizes (FFmpeg via Homebrew, video-use
   repository plus Python packages, two ~6 MB font files, HyperFrames and its
   render browser for captions and CSS effects at about 320 MB, Node.js only if
   it is missing, the key file).
   Ask once for approval of the whole list. One yes covers that list only;
   anything new found later needs its own question.
2. After the yes, run `sh scripts/install_missing.sh --step 2 --yes`.
   - A `STOP` line is a hard stop: report the evidence and the exact fix; never
     pull, reset, overwrite, retarget a link, or rewrite a Git remote to get
     past it. Other items still install.
   - Homebrew or `sudo` needs the user's password: give the exact command for
     them to run in their own terminal, then wait.
3. API key for word-level transcripts. The script prepares an empty, Git-ignored
   `~/Developer/video-use/.env` with mode 600 and opens it in TextEdit. Say:
   「最後一件事：轉逐字稿要用你自己的 ElevenLabs API 金鑰。我幫你開了一個檔案，
   請貼上一行 `ELEVENLABS_API_KEY=你的金鑰`，存檔後跟我說『好了』。金鑰不要貼在聊天室。」
   Then run `sh scripts/prepare_key_file.sh --verify` (prints presence only).
   Free accounts have a small monthly allowance; never state prices from memory.
4. Rerun `check_env.sh`. Report each item as checked / installed / still missing
   / stopped, with evidence. Never call the environment ready if any required
   item is missing or stopped.
5. Hand off to step 3 with one question, e.g.:
   「工具都準備好了！第 3 步：把你想剪的影片放進資料夾，或直接把檔案拖進來給我。放好了嗎？」

## Rules that never relax

- Read [the setup runbook](references/setup-runbook.md) for the exact sources
  and hard stops, and [security and verification](references/security-and-verification.md)
  before touching credentials.
- Never ask for, print, log, or commit an API key; never read `.env` contents
  beyond the presence check.
- Setup does no paid work: no upload, transcription, or test call to ElevenLabs.
- HyperFrames is part of step 2: it draws the one-line captions and the CSS
  effects. It needs Node.js 22+. Never replace an existing older Node.js; report
  it as a stop and ask about a separate version-manager setup.
