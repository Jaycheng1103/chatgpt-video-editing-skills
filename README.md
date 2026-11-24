# ChatGPT 剪短影音 Skills

一組給可操作本機檔案與終端機的 AI Agent（Codex／ChatGPT、Claude Code 等）使用的繁體中文 Skills。裝好之後，你只要跟著 Agent 的問題一步一步回答，就能把自己拍的影片剪成直式短影音：它會自動檢查電腦、幫你裝好需要的工具、串接 ElevenLabs、裝好 Agent Reach，再陪你從放影片走到正式成片。

它會保護原始素材、上傳前先問你、不印出金鑰，並以實際輸出與 QA 證據為準，不把計畫或沒驗證的檔案說成完成品。

## 七步驟

| 步驟 | 你會做什麼 | Agent 會做什麼 |
| --- | --- | --- |
| 1. 串接 ElevenLabs 和安裝 Agent Reach | 在跳出的 ElevenLabs 登入頁按「允許」 | 自動檢查環境，裝好或升級 Agent Reach，把 ElevenLabs 官方雲端 MCP 加到你的 Agent |
| 2. 安裝 AI 剪輯工具包並完成下載配置 | 說一次「好」，再把 API 金鑰貼進它幫你打開的檔案 | 一次裝好 FFmpeg、video-use、思源黑體字幕字體、做字幕與 CSS 特效的 HyperFrames，並建立受保護的金鑰檔 |
| 3. 放入想要剪輯的影片 | 把影片拖進來 | 檢查影片規格，原檔不動，在旁邊建立 `edit/` |
| 4. 取得剪輯建議並用 ElevenLabs 拿到逐字稿 | 同意上傳 | 用 ElevenLabs Scribe v2 轉出逐字時間碼，整理成編號段落，給你 4–8 句剪輯建議 |
| 5. 詢問是否刪減逐字稿 | 說要刪哪幾段 | 只刪減與換位置，不改你說過的話 |
| 6. 提供想參考的剪輯風格 | 貼一支 IG、TikTok、YouTube Shorts 或 X 的短影音連結 | 下載並量測節奏、看字幕樣式，寫成「風格配方」 |
| 7. 剪輯出品 | 看 720p 預覽，說「可以」或要改哪裡 | 粗剪、一行最多 8 字的字幕、跟著內容出現的 CSS 特效、混音、預覽 QA，核准後輸出並驗證 1080×1920 正式檔 |

每一步結束，Agent 都會用一個問題帶你進下一步。

## 兩個 Skills 的分工

| Skill | 負責 | 不會做的事 |
| --- | --- | --- |
| [`chatgpt-video-editing-setup`](skills/chatgpt-video-editing-setup/SKILL.md) | 第 1–2 步：自動檢查（`scripts/check_env.sh`）、一次核准後安裝（`scripts/install_missing.sh`）、ElevenLabs MCP 串接、Agent Reach、video-use、FFmpeg、思源黑體 TW、HyperFrames、金鑰檔（`scripts/prepare_key_file.sh`） | 不上傳素材、不轉寫、不剪輯 |
| [`chatgpt-short-video-editor`](skills/chatgpt-short-video-editor/SKILL.md) | 第 3–7 步：素材檢查、逐字稿、剪輯建議、刪減、參考風格分析（`scripts/analyze_reference.sh`）、粗剪、字幕（`scripts/build_captions.py`）、CSS 特效（`scripts/build_effects.py`）、合成（`scripts/compose_video.py`）、預覽、QA 與正式輸出 | 不自己安裝或修環境；缺東西時帶你回第 1–2 步 |

## 安裝

在你的專案目錄執行：

```sh
npx skills add Jaycheng1103/chatgpt-video-editing-skills --full-depth
```

安裝器會讓你選擇要安裝的 Skills 與偵測到的 Agent。若確定要一次選取全部 Skills 並安裝到所有偵測到的 Agent：

```sh
npx skills add Jaycheng1103/chatgpt-video-editing-skills --all --full-depth
```

手動複製時，每個 Skill 都要連同 `references/` 與 `scripts/` 一起保留，不能只複製 `SKILL.md`。

更新與移除：

```sh
npx skills update chatgpt-video-editing-setup chatgpt-short-video-editor
npx skills remove chatgpt-video-editing-setup chatgpt-short-video-editor
```

全域安裝時請加上 `--global`。

## 開始使用

裝好後，對 Agent 說一句就好：

> 請用 `chatgpt-video-editing-setup` 帶我開始剪短影音。

它會先自動檢查你的電腦（不改任何東西），告訴你缺什麼，問你一次要不要裝，然後一路帶你走到第 7 步。已經設定好的人可以直接說：

> 請用 `chatgpt-short-video-editor` 幫我剪這支影片：`/完整/路徑/原始影片.mov`

想一次給完整規格，可以複製 [`examples/完整提示詞.md`](examples/完整提示詞.md)。

## 前置需求

- 能讀寫本機檔案並執行終端機指令的 Agent。
- macOS 或 Linux。缺 FFmpeg 時，macOS 用 Homebrew 安裝；沒有 Homebrew 或 Linux 需要 `sudo` 時，Agent 會給你指令請你自己在終端機輸入密碼。
- [ElevenLabs](https://elevenlabs.io) 帳號：官方雲端 MCP（`https://api.elevenlabs.io/v1/mcp`，用 OAuth 登入）負責串接帳號；逐字稿用 [Scribe v2](https://elevenlabs.io/docs/capabilities/speech-to-text) API 金鑰取得每個字的時間碼。兩者都會用到你帳號的額度，免費帳號每月額度有限，實際額度以 ElevenLabs 後台為準。
- 其餘由第 1–2 步自動安裝：[uv](https://docs.astral.sh/uv/)、[Agent Reach](https://github.com/Panniantong/Agent-Reach)（只從官方 GitHub release 安裝，不用 PyPI 上同名套件）、[video-use](https://github.com/browser-use/video-use) 完整 Repo、[FFmpeg](https://ffmpeg.org/) 與 `ffprobe`、[思源黑體（Source Han Sans）](https://github.com/adobe-fonts/source-han-sans) TW 子集 OTF（SIL Open Font License 1.1）、[Pillow](https://python-pillow.github.io/)。
- [HyperFrames](https://github.com/heygen-com/hyperframes)（固定版本 0.9.86）在第 2 步一起安裝，用 HTML、CSS 與 GSAP 畫字幕和特效，需要 Node.js 22 或更新版本。沒有 Node.js 時 macOS 會用 Homebrew 安裝；已經有較舊的 Node.js 時 Agent 會停下來問你，不會自己換掉。

自動安裝不會越過這些安全底線：既有 video-use 有未提交修改或來源不是官方 Repo 時會停下；既有字體檔、Skill 連結不覆寫；金鑰只由你自己貼進檔案。

## 隱私、憑證與費用

- 不要把 API Key 貼進聊天、命令列參數、公開檔案、Git commit、shell history 或 log。
- `ELEVENLABS_API_KEY` 只能由本機環境變數，或受保護的 `~/Developer/video-use/.env` 提供。
- 使用 `.env` 前，Agent 必須先確認 Git 會忽略它；本機檔案權限應為 `600`。Agent 不應讀取或顯示檔案內容。
- 第一次把媒體傳給 ElevenLabs 前，Agent 必須說明具體檔名、用途是 Scribe v2 轉寫，以及會用到你帳號的額度，並等待你的明確同意。
- ElevenLabs MCP 用 OAuth 登入：你在官方頁面登入並按允許，Agent 不經手密碼或權杖。
- 若你不願上傳雲端，可明確選擇本機 Whisper 降級方案；它的時間碼信心較低，需要對每個剪接邊界做額外播放檢查，不能說成與 Scribe v2 同等精準。

詳細安全規則見 [`security-and-verification.md`](skills/chatgpt-video-editing-setup/references/security-and-verification.md)。

## 會保留的產物

所有新產物都放在原始影片旁的 `edit/`，原始檔不會被覆寫、移動、重新命名或刪除：

```text
edit/
├── project.md
├── transcripts/<source>.json
├── corrected-transcript.md
├── edl.json
├── style/style-recipe.md
├── reference/
├── master.srt
├── clips/
├── animations/slot_<id>/
├── qa/
├── preview.mp4
└── final.mp4
```

`final.mp4` 只有在 720p 預覽獲得核准、1080×1920 正式檔完成渲染，而且正式檔本身通過剪接點、代表畫面與完整解碼檢查後，才會被當成可交付成片。完整定義見 [`output-contract.md`](skills/chatgpt-short-video-editor/references/output-contract.md)。

## 常見問題

### Agent 說找不到 FFmpeg、ffprobe、video-use、字幕字體、憑證或 ElevenLabs

請改用 `chatgpt-video-editing-setup`。它會自動檢查、列出要裝的東西，你說一次「好」就一起裝完。若既有 Repo 有未提交修改，它會停下來，不會直接 pull、reset 或覆寫；既有字體檔也不會被重新下載或覆寫。

### 參考影片抓不下來

Instagram 和 X 常常要登入才能下載。Agent 會請你把影片存下來直接拖進來，不會自己去讀你瀏覽器的登入資料。參考影片只用來研究節奏和字幕樣式，不會放進成片。

### 沒有 ElevenLabs 額度，或不想上傳素材

完整精度流程以 Scribe v2 為主。你可以明確要求使用本機 Whisper 降級方案，但要接受較低信心的時間碼與額外邊界 QA；Agent 不應默默切換。

### 已經看到指令、轉寫文字或預覽，為什麼還沒算完成？

指令不等於已執行，畫面不等於完整 QA，預覽也不等於正式交付。正確順序是：完整預覽檢查 → 你核准預覽 → 渲染正式檔 → 驗證正式檔 → 交付。

### 字幕和特效長什麼樣子

字幕一次只有一行，每行最多 8 個字，超過就換成下一句，不會出現兩、三行疊在一起。每張字卡會輕輕彈出，重點詞換成強調色。特效跟著你講的內容出現：講到核心觀念時跳出大字重點，講「第一、第二、第三」時滑入步驟標籤，連續列舉時出現打勾清單，語氣加重的那句畫面推近。規則與時機見 [`captions-and-effects.md`](skills/chatgpt-short-video-editor/references/captions-and-effects.md)。

### 想加 B-roll、音樂或 CTA

請在第 5–6 步提出或核准。這些都是 opt-in 創意決策，不是預設自動加入。

## 第三方、授權與聲明

本 Repo 不內含第三方上游程式碼。相關工具、API 與服務仍受各自的條款與授權約束，詳見 [`THIRD_PARTY_NOTICE.md`](THIRD_PARTY_NOTICE.md)。

本專案以 [MIT License](LICENSE) 發布。歡迎先閱讀 [`CONTRIBUTING.md`](CONTRIBUTING.md) 與 [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) 再參與貢獻。

這是社群維護的非官方專案，與 OpenAI、ChatGPT、video-use、HyperFrames、ElevenLabs、FFmpeg、Pillow、Agent Reach 或 Adobe 的開發者及所屬公司沒有從屬、授權、背書或合作關係。產品名稱與商標屬各自權利人所有。
