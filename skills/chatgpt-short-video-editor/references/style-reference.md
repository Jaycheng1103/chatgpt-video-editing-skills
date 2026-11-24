# 第 6 步：參考影片的剪輯風格

Goal: turn one short video the user likes into a written style recipe for
their own footage. The reference is studied, never reused.

## 1. Get the reference

Accept one link from Instagram Reels, TikTok, YouTube Shorts, or X, or a video
file the user saved. Use the tools Agent Reach installed:

- `agent-reach read <url>` for the post's caption and basic information, when
  the platform is supported without login.
- `scripts/analyze_reference.sh <url-or-file> <source-directory>/edit` downloads
  with `yt-dlp` (from PATH, or `uvx yt-dlp`) into `edit/reference/` and measures it.

Instagram and X often require a logged-in session. If the download fails,
do not pull cookies from the user's browser on your own. Offer the easy path:
「Instagram 這支要登入才抓得到。你可以在手機或電腦上把影片存下來，直接拖進來給我嗎？」
Only use a browser-cookie option if the user explicitly asks for it and
understands it uses their logged-in session.

## 2. Measure it

`analyze_reference.sh` writes `edit/reference/analysis.txt` with duration,
resolution, frame rate, detected cut times, average shot length, and a contact
sheet `edit/reference/contact.jpg` plus frames in `edit/reference/frames/`.
Open the frames and the contact sheet and observe:

- 節奏：average shot length and where the cuts cluster (opening vs. middle).
- 字幕：position, size relative to frame, colour, outline or box, how many
  characters per line, keyword highlight colour, whether captions pop word by word.
- 鏡頭：punch-in zooms, jump cuts, framing (face position), B-roll inserts.
- 圖卡與動畫：title card, lower thirds, emoji or stickers, progress bar.
- 聲音：music presence and level (listen only if your tools allow; otherwise say
  it is not checked).
- 開頭：how the first 3 seconds hook (text on screen, motion, question).

Report only what you observed; mark anything you could not check.

## 3. Write the recipe

Create `edit/style/style-recipe.md`:

```markdown
# 風格配方
- 參考來源：<url 或檔名>（只研究風格，不使用其畫面、音樂、標誌或文字）
- 節奏：平均 X 秒一個鏡頭；開頭 3 秒內 N 刀
- 字幕：位置／字級／顏色／外框；每行最多 N 字；重點字 <顏色>
- 鏡頭：每 N 句推近一次（約 110–120%）／不推近
- 圖卡：<有／無，樣式>
- 音樂：<有／無／未檢查>；我們的做法：<不加或使用者提供的音樂>
- 無法照做的部分與原因：
```

Map each item to something the toolkit can do with FFmpeg, Pillow, and the
Source Han Sans TW font. Use HyperFrames only if the user approves an animation
that needs it. Music is added only if the user supplies or approves a track
they have the right to use.

## 4. Rules

- Keep reference files only under `edit/reference/`; never put any of their
  frames, audio, or text into the output.
- Do not imitate a creator's logo, watermark, catchphrase, or face.
- If no reference is given, use the clean default: cuts on sentence boundaries,
  light punch-ins every few sentences, white subtitles with a dark outline in the
  lower-middle safe area, no music.
