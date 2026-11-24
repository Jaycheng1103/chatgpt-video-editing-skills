# 字幕與 CSS 特效（第 7 步）

Captions and effects are drawn with HTML/CSS/GSAP in one transparent
HyperFrames layer and composited over the cut. The captions sit on the top
layer of that overlay, so they are still the last visual operation. This route
does not need FFmpeg's subtitle filter (libass), which current Homebrew FFmpeg
builds do not include.

## Order

1. Render the cut with video-use **without** its own subtitles:
   `cd ~/Developer/video-use && uv run python helpers/render.py "<edit>/edl.json" -o "<edit>/base_preview.mp4" --preview --no-subtitles`
   (`--draft` for a quick 720p check; no flag for the final).
2. Captions:
   `uv run --with opencc --with jieba python scripts/build_captions.py --edit-dir "<edit>" [--replace "<edit>/captions/replace.txt"]`
   writes `captions/master.srt` and `captions/captions.json` and must print
   `CAPTION_CHECK PASS`.
3. Effects plan: write `<edit>/effects/plan.json` by hand from the transcript
   and `captions.json` timings (format in `scripts/build_effects.py`).
4. Overlay project and render:
   `python3 scripts/build_effects.py --captions "<edit>/captions/captions.json" --plan "<edit>/effects/plan.json" --out "<edit>/effects/overlay"`
   `npx -y hyperframes@0.9.86 check "<edit>/effects/overlay" --json` (no errors)
   `npx -y hyperframes@0.9.86 render "<edit>/effects/overlay" --format webm -o "<edit>/effects/overlay.webm"`
5. Composite: `python3 scripts/compose_video.py --base "<edit>/base_preview.mp4" --overlay "<edit>/effects/overlay.webm" --plan "<edit>/effects/plan.json" -o "<edit>/preview.mp4" --preview`

For the final, rerun steps 1, 4 and 5 against the final base (the overlay is
already 1080×1920, so it is reused when nothing changed).

## 字幕規則（固定，不是風格選項）

- 一張字卡只有一行，絕不出現兩行或三行。
- 每行最多 8 個字（中文、全形字算 1，英文字母、數字、空白算 0.5）。超過就變成下一張字卡，一句一句接著出現。
- 斷在詞與詞之間（jieba 斷詞），不切開詞、英文單字或數字；標點只當斷點，不顯示。
- 字卡之間不重疊，不跨過剪接點；停頓超過 0.35 秒一定換下一張。
- 預設去掉「呃」「嗯」，使用者要保留時加 `--keep-fillers`。
- 逐字稿是簡體時自動轉繁體（OpenCC s2twp，台灣用語）。辨識錯的專有名詞寫進 `replace.txt`，一行一個 `錯字=正字`，例如 `chat gpt=ChatGPT`；只修真的聽錯的地方，不改講者的話。
- 字幕位置在 1050–1200 px 的字幕帶，略偏左，避開右側按鈕列與平台下方說明區。白字黑邊思源黑體 TW Bold。

`build_captions.py` 驗證失敗（`CAPTION_FAIL`）時不可繼續渲染；修正後重跑。

## 特效要活潑，但要有理由

特效跟著講話內容出現，不是每句都加。每個特效都要能回答「觀眾為什麼需要在這裡看到它」。

| 類型 | 什麼時候用 | 動起來的樣子 |
| --- | --- | --- |
| 字幕彈入 | 每張字卡（自動） | 從 84% 彈到 100%，0.18 秒，back.out |
| 重點字變色 | `plan.highlight` 列的詞出現在字幕裡 | 字幕裡那幾個字變成強調色 |
| `keyword` 大字重點 | 一句話的核心觀念、數字、反差 | 大字從模糊縮小彈出，底下黃色螢光筆由左往右刷過，結束時放大淡出 |
| `step` 步驟標籤 | 講者說「第一、第二、第三」 | 從左邊滑入，數字圓章轉一圈彈性落定 |
| `list` 清單卡 | 講者連續列出 2–4 個項目 | 卡片升起，項目一個一個打勾出現 |
| `punch` 推近 | 語氣加重、說結論的那一句 | 畫面直接推近 110–120%，句子結束跳回 |
| `progress` 進度條 | 整支影片（選用） | 頂端細條隨時間變長 |

Density and placement:

- Keyword, step and list never overlap each other; leave at least one caption
  between two effects. Under a minute, about one effect every 4–8 seconds.
- Do not put a list card over footage that is itself the subject (a screen
  being demonstrated); use a `keyword` or `step` there instead.
- Keyword text and list items: at most 8 characters; list title at most 10.
- Every ease is curved (`back.out`, `expo.out`, `power4.out`, `elastic.out`);
  only the progress bar moves linearly.
- No emoji, stickers, sound effects, or music unless the user asked for them.
- If the user chose a reference style in step 6, take the accent colour,
  highlight habit and effect density from the style recipe.

## QA additions

- `build_captions.py` printed `CAPTION_CHECK PASS`.
- `hyperframes check` reported 0 errors (warnings about silence, empty first
  frame and track density are expected for an overlay).
- In the preview, look at frames inside every effect window: text is readable,
  nothing covers the speaker's face or the demonstrated screen, captions are one
  line, and the effect leaves before the next one starts.
