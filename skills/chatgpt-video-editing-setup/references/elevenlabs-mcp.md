# ElevenLabs MCP：檢查與串接

ElevenLabs's official local MCP package (`elevenlabs-mcp`, repository
`elevenlabs/elevenlabs-mcp`) is archived and deprecated. Use the hosted server:

- URL: `https://api.elevenlabs.io/v1/mcp`
- Sign-in: OAuth with the user's ElevenLabs account. No API key is copied into
  the agent's MCP configuration.
- Data-residency workspaces use their own URL (for example
  `https://api.eu.residency.elevenlabs.io/v1/mcp`); use it only when the user
  says their workspace is in that region.

## 1. Is it already connected?

Check in this order and stop at the first positive answer:

1. **Your own tool list.** If tools from an ElevenLabs MCP server are available
   to you now, it is connected. Connectors added in the ChatGPT or Claude app
   settings only show up this way.
2. **Codex:** `codex mcp get elevenlabs` shows the URL; `codex mcp list` shows
   whether it is signed in.
3. **Claude Code:** `claude mcp get elevenlabs`, or `/mcp` inside a session.

`scripts/check_env.sh` performs checks 2–3 and reports `mcp-codex` /
`mcp-claude`. A configured but signed-out server still needs step 3 below.

## 2. Add it

`scripts/install_missing.sh --step 1 --yes` adds the entry for each agent CLI
found on the machine:

```sh
codex mcp add elevenlabs --url https://api.elevenlabs.io/v1/mcp
claude mcp add --transport http --scope user elevenlabs https://api.elevenlabs.io/v1/mcp
```

In the ChatGPT or Claude desktop/web app without a CLI, guide the user through
the app's own settings instead: add a custom connector (or MCP server) named
`ElevenLabs` with the URL above. Describe the clicks; do not change app
settings for them.

## 3. Sign in

- Codex: run `codex mcp login elevenlabs`. A browser page opens; the user signs
  in to ElevenLabs and clicks Allow.
- Claude Code: `/mcp` → `elevenlabs` → Authenticate.

Say what will happen before it happens:
「等一下會跳出 ElevenLabs 的登入頁，你登入後按『允許』，再回來跟我說一聲。」

Never type the user's password, never click Allow for them, and never ask them
to paste tokens into the chat. If sign-in fails, report the exact message and
offer the app-settings connector route instead. A new chat may be needed before
newly added MCP tools appear; tell the user plainly.

## 4. What the MCP is used for, and why the API key is still needed

ElevenLabs's documentation lists transcription among the hosted MCP's
capabilities, but it does not document the transcription tool's input format
or say whether it returns word-level timestamps. Editing needs word-level
timestamps to cut on word boundaries. Therefore:

- Use the MCP connection to confirm the user's ElevenLabs account is connected
  and, when its tools offer it, for account-level tasks the user asks for.
- Produce the editing transcript with ElevenLabs Scribe v2 through the
  video-use helper, which uses `ELEVENLABS_API_KEY` and returns word-level
  timestamps. If an MCP transcription tool is available and its own result
  shows word-level start/end times, it may be used instead; record which path
  was used in `edit/project.md`.
- Both paths spend the user's ElevenLabs credits. Ask before every first
  upload of a file (see the editor Skill).
