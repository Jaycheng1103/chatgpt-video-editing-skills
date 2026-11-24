# 七步引導剪輯流程

The user follows the agent's questions from step 1 to step 7. Each step has a
goal, the work the agent does, a checkpoint that must be true before moving on,
and a closing question. The sample lines show the tone; adapt them to what
actually happened and never claim a result that has not been observed.

Tone: Traditional Chinese, warm, short sentences, plain words. Say which step
you are on (「第 3 步／共 7 步」). Ask one question at a time and put your
recommended answer first. No emoji unless the user uses them.

| 步驟 | 名稱 | 負責 Skill |
| --- | --- | --- |
| 1 | 串接 ElevenLabs 和 HyperFrames By HeyGen | `chatgpt-video-editing-setup` |
| 2 | 安裝 AI 剪輯工具包並完成下載配置 | `chatgpt-video-editing-setup` |
| 3 | 放入想要剪輯的影片 | `chatgpt-short-video-editor` |
| 4 | 取得剪輯建議並用 ElevenLabs 拿到逐字稿 | `chatgpt-short-video-editor` |
| 5 | 刪減逐字稿 | `chatgpt-short-video-editor` |
| 6 | 提供想參考的剪輯風格的短影音 | `chatgpt-short-video-editor` |
| 7 | 剪輯出品 | `chatgpt-short-video-editor` |

If a user starts at step 3 or later, run the setup Skill's `check_env.sh`
first. If anything required is missing or stopped, say so in one sentence and
go back to step 1 or 2 with a question:
「開始剪之前，我發現還沒接上 ElevenLabs。要我先花兩分鐘幫你接好嗎？」

## 第 1–2 步

Run by `chatgpt-video-editing-setup`. They end with:
「工具都準備好了！第 3 步：把你想剪的影片放進資料夾，或直接把檔案拖進來給我。放好了嗎？」

## 第 3 步：放入想要剪輯的影片

- Work: accept a dragged-in file, an absolute path, or a folder; if there are
  several videos, list them and ask which one. Run `ffprobe` and record
  duration, resolution, orientation, frame rate, audio, and decode status.
  Create `<source-directory>/edit/` only after this check. Never move, rename,
  overwrite, or delete the original.
- Ask the essentials one at a time if unknown: target platform, then target length.
- Checkpoint: the source decodes and has an audio track (no audio means no
  transcript; say so and ask how to proceed).
- Closing question (also the upload consent):
  「收到，這支影片 3 分 12 秒、直式、聲音清楚。第 4 步我會把聲音傳到 ElevenLabs
  轉成逐字稿，會用到你 ElevenLabs 帳號的額度。可以上傳嗎？」

## 第 4 步：取得剪輯建議並用 ElevenLabs 拿到逐字稿

- Consent: upload only after an explicit yes for this exact file. Consent covers
  this file only.
- Work: transcribe with ElevenLabs Scribe v2 through video-use (word-level
  timestamps, cached in `edit/transcripts/`):
  `cd ~/Developer/video-use && uv run python helpers/transcribe.py "<source>" --edit-dir "<source-directory>/edit"`
  Then pack it (`helpers/pack_transcripts.py --edit-dir …`) and read it. See
  the setup Skill's `references/elevenlabs-mcp.md` for when an MCP transcription
  result may be used instead.
- Write `edit/corrected-transcript.md` as numbered paragraphs（①②③…）with a
  start time each, fixing only obvious misrecognitions (mark them). Never
  invent words the speaker did not say.
- Give the 剪輯建議: a 4–8 sentence plain-language strategy (who it is for,
  the hook, the story shape, what to keep, what to drop and why, estimated
  length). Suggest specific paragraph numbers to drop.
- Checkpoint: transcript file exists and was read; strategy given.
- Closing question leads to step 5.

## 第 5 步：刪減逐字稿

- Ask: 「逐字稿和建議都在上面了。我建議刪掉第 ③、⑦ 段（重複講的地方），
  剪完大約 70 秒。你想照這樣刪，還是有其他段落想刪或想留？」
- Rules: deletion and reordering only; never rewrite the speaker's words.
  Apply exactly what the user chose, then show the remaining paragraphs and the
  new estimated length. The user's confirmation is the approved strategy.
- Checkpoint: the kept list is confirmed and recorded in `edit/project.md`.
- Closing question:
  「刪好了，剩下大約 72 秒。第 6 步：有沒有哪支短影音的剪輯風格是你喜歡的？
  直接貼 IG、TikTok、YouTube Shorts 或 X 的連結給我，我照它的節奏和字幕樣式來剪。
  沒有的話我就用乾淨的口播風格，也可以。」

## 第 6 步：提供想參考的剪輯風格的短影音

- Follow [the style reference guide](style-reference.md): fetch the link with
  the tools Agent Reach installed, measure it with
  `scripts/analyze_reference.sh`, look at the frames, and write
  `edit/style/style-recipe.md`.
- Describe the recipe back in plain words (pace, subtitle look, zooms,
  B-roll, music) and say what you will **not** copy (their footage, music,
  logo, watermark, or words).
- Checkpoint: recipe written, or the user chose the clean default.
- Closing question:
  「我看完了：這支大約 1.8 秒換一個畫面，字幕在畫面中下方、白字黑邊，重點字放大變黃。
  我照這個方向剪，字幕一次一行、每行最多 8 個字，重點的地方加上彈出大字和步驟標籤，
  先給你一支 720p 預覽看看，可以開始嗎？」

## 第 7 步：剪輯出品

Follow [the production rules](production-rules.md) in this order:
逐段粗剪 → 轉色／圖卡／字幕 → 混音與完整預覽 → QA 與正式定稿.

1. Build `edl.json` from the kept paragraphs on word boundaries, render each
   segment without video-use's own subtitles, then follow
   [captions and effects](captions-and-effects.md): one-line captions of at most
   8 characters, CSS effects triggered by what is said, captions on top.
2. Render the complete 720p `preview.mp4`, run the preview QA, and fix at most
   three evidence-backed problems yourself.
3. Ask: 「預覽好了：<路徑>。看完告訴我哪裡要改，或回我『可以』，我就輸出正式版。」
4. After an explicit yes, render the 1080×1920 `final.mp4`, run final-file QA
   and a full decode, then deliver with the evidence report from
   [the output contract](output-contract.md).
5. Close the loop: 「正式版好了，放在 <路徑>。要不要用同樣的風格再剪下一支？」

Never call the preview or final done until the file exists and its checks pass.
