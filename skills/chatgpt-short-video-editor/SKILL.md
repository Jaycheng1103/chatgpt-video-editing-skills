---
name: chatgpt-short-video-editor
description: "Guide a user through steps 3–7 of the seven-step AI short-video workflow: take their video, transcribe it with ElevenLabs Scribe v2, suggest an edit, ask which transcript parts to delete, study a reference short (Instagram, TikTok, YouTube Shorts, X) for style, then cut a vertical Reel/Short/TikTok with subtitles, a 720p preview, and a verified 1080×1920 final. Use when the user provides or points to a video, or asks to transcribe, cut, subtitle, preview, or export a vertical short, or to edit 'in the style of' a short-video link. Do not use for environment-only setup or generic Premiere Pro or CapCut help."
---

# ChatGPT Short-video Editor（第 3–7 步）

Lead the user through the rest of the seven steps with one friendly question
at a time, until a verified final video exists. Read
[the seven-step guide](references/seven-step-guide.md) first; it has each
step's work, checkpoint, and closing question.

## Before step 3

Run the setup Skill's read-only `scripts/check_env.sh`. If `video-use`,
`FFmpeg`, `ffprobe`, the Source Han Sans TW font, Node.js 22+, HyperFrames (skills or
render CLI), the ElevenLabs key, the ElevenLabs MCP, or Agent Reach is missing,
old, dirty, or stopped, explain it in one plain
sentence and offer to go back to step 1 or 2 with `chatgpt-video-editing-setup`.
Never install, clone, update, or repair anything from this Skill.

## The five steps

3. **放入想要剪輯的影片**：inspect with `ffprobe`, keep the original untouched,
   put every new file in `<source-directory>/edit/`.
4. **取得剪輯建議並用 ElevenLabs 拿到逐字稿**：ask before the first upload of
   this file (name the file, say it goes to ElevenLabs Scribe v2 for
   transcription and uses the user's ElevenLabs credits), then get word-level
   timestamps, write numbered paragraphs, and give a 4–8 sentence plain-language
   editing suggestion.
5. **刪減逐字稿**：ask which paragraphs to delete; only delete or
   reorder, never rewrite what was said. The confirmed list is the approved
   strategy. Do not choose edit points or add B-roll, animation, music,
   effects, or CTA before this approval.
6. **提供想參考的剪輯風格的短影音**：ask for one IG/TikTok/YouTube Shorts/X link, run
   `scripts/analyze_reference.sh`, look at the frames, and write a style recipe
   per [the style reference guide](references/style-reference.md). Offer a clean
   default if they have none.
7. **剪輯出品**：逐段粗剪 → 轉色／圖卡／字幕 → 混音與完整預覽 → QA 與正式定稿, following
   [the production rules](references/production-rules.md) and
   [captions and effects](references/captions-and-effects.md). Render a complete
   720p preview, ask for approval, then render and verify the 1080×1920 final.

## Conversation rules

- Traditional Chinese, warm and plain. Tell the user which step they are on.
- One question per message, recommended answer first, and every step ends with
  the question that opens the next step.
- If the user goes off-path (asks for a different length, swaps the video,
  skips the reference), adjust and tell them which step you are now on.
- Do not upload without consent, and do not claim a transcript, preview, QA
  pass, or final exists until you have produced and checked it.

## Caption and effect rules

- 字幕一次一行，每行最多 8 個字；超過就變成下一句字幕，絕不出現兩、三行。用
  `scripts/build_captions.py` 產生並驗證，不要手寫 SRT 或沿用 video-use 內建字幕。
- 特效用 CSS（HyperFrames）做得活潑：字幕彈入、重點字變色、大字重點、步驟標籤、
  清單打勾、推近。特效要跟著講話內容出現，有理由才加，不遮臉、不遮正在示範的畫面。

## Edit-quality rules

Use word-level verbatim timestamps, cached per unchanged source. Never cut
inside a word. Keep 30–200ms padding around cut edges with about 30ms audio
fades, work per segment, and time subtitles on the output timeline.
Subtitles are the last visual operation. Make at most three evidence-based
self-fix passes on the preview. If the user declines cloud upload, offer the
lower-confidence local Whisper fallback only as an explicit choice.

## Delivery

Keep and report the artifacts in [the output contract](references/output-contract.md),
including `edit/style/style-recipe.md` when a reference was used. Present one
formal final with its evidence-backed QA report, then ask whether to cut the
next video in the same style.
