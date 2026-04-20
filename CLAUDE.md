<!-- SPECTRA:START v1.0.1 -->

# Spectra Instructions

This project uses Spectra for Spec-Driven Development(SDD). Specs live in `openspec/specs/`, change proposals in `openspec/changes/`.

## Use `/spectra:*` skills when:

- A discussion needs structure before coding → `/spectra:discuss`
- User wants to plan, propose, or design a change → `/spectra:propose`
- Tasks are ready to implement → `/spectra:apply`
- There's an in-progress change to continue → `/spectra:ingest`
- User asks about specs or how something works → `/spectra:ask`
- Implementation is done → `/spectra:archive`

## Workflow

discuss? → propose → apply ⇄ ingest → archive

- `discuss` is optional — skip if requirements are clear
- Requirements change mid-work? Plan mode → `ingest` → resume `apply`

## Parked Changes

Changes can be parked（暫存）— temporarily moved out of `openspec/changes/`. Parked changes won't appear in `spectra list` but can be found with `spectra list --parked`. To restore: `spectra unpark <name>`. The `/spectra:apply` and `/spectra:ingest` skills handle parked changes automatically.

<!-- SPECTRA:END -->

# 專案背景

這是一個為期 8 週的活動積分管理系統「**心成親證班回報系統**」，目前由臨時團隊遠端協作開發。我（Johnson）是中途加入的開發協作者，非主導者，透過 Claude Code 協助撰寫程式碼。

---

# 相關資源

以下兩個資料來源**並行**使用，需要專案背景資料時兩邊都可查找：

- **專案共用 Google Drive**（網站主導者建立，團隊共用）：https://drive.google.com/drive/folders/1-37xaAxIOEmZaQGk6vGat4NQAVbqIWPn
- **`給Claude讀取的資料/`**（本機資料夾，Johnson 個人維護）：放置供 Claude 參考的檔案（PPT、截圖、規則文件、會議記錄等）。**透過 Google Drive + symlink/junction 跨機器同步**（詳見下方「給Claude讀取的資料/ 跨機器同步機制」章節）。
  - **`給Claude讀取的資料/Claude回饋的檔案/`**：Claude 產出的報表、分析文件、整理結果等**輸出檔案的集中存放處**。當 Johnson 請 Claude「做一份報表」「整理一份清單」「產出分析文件」時，除非另有指定，預設存到這個資料夾。也會透過 Google Drive 跨機器同步，所以 Mac / Windows 上的 Claude 產出的檔案互通。

## 測試環境資源（Johnson 專用沙盒）

| 項目 | 連結 / ID |
|---|---|
| 測試 Google Sheets | `1JgDikkNEV0CKuiJNic4stTy57G-ltTzDCbzXFr5E1Ao` |
| 測試 Apps Script | `1qridiVIggaHyYUizQRWegCpLjQMowdaETY1_AiDRhUKkuohrS4KOVtte` |
| 測試 Web App URL | https://script.google.com/macros/s/AKfycbxmDqrEKYEM-HxpNtHa8nuvkePFe8GUBtj42l2YbRYV7cdTf8iv0l_Hk9Ud3TiKfafd/exec |

**正式環境資源**（僅供 Claude 參考，Johnson 不應直接操作）：
| 項目 | ID |
|---|---|
| 正式 Google Sheets | `1CFTaHNqlaVQOC7Bpuk7KMznFRuAYNHmBMxeDvA19wtw` |
| 正式 Apps Script | `19ZCMtO64t7drgu-MVY-kbCJpOcW8kvpjDjsu0mfBFszyjRmP6ghqc8NV` |

---

# Claude Code 行為指引（給所有 Claude 實例讀）

本章節是給任何打開此專案的 Claude Code 讀的「**怎麼跟 Johnson 合作**」指引，濃縮 2026-04-15 建立的所有協作模式。新的 Claude 實例（不論是 Windows / Mac / GUI / 終端機、不論是接續舊 session 還是全新開始）讀完這段後應該就能無縫接手，不需要從頭問。

## Johnson 是誰

中途加入本專案「心成親證班回報系統」的協作開發者，**非主導者**。主工程師已給予 Apps Script 共同編輯權限，但 Johnson 的工作方式是：

```
本機用 Claude Code 編輯程式碼
  ↓
git push 到 GitHub 自己的分支（develop 或 feature branch）
  ↓
發 Pull Request 給主工程師審核
  ↓
主工程師自行合併並部署到正式環境
```

### 技術背景
- **沒有程式設計背景**（他明確說過「我沒有程式設計背景」）
- 看得懂程式碼結構與意圖，但細節需要白話解釋
- 能執行指令、看懂錯誤訊息、做判斷決定
- 熟悉 Git/GitHub 基本概念，會用 Google Sheets / Apps Script 網頁介面

### 協作偏好
- 中文為主、技術名詞需要比喻說明
- 所有代為執行的動作**先跟他確認**
- Claude Code 是他的「實習生」不是「顧問」—— 他期待 Claude **實際動手做**，不是只給建議

---

## 溝通節奏：一步一步確認

Johnson 一致偏好「一步一步來」的節奏：**重要動作前先列出選項**（通常 A/B/C/D），標示推薦選項與理由，等他選擇後再執行。**不要代為決定**。

### 為什麼
他沒有程式設計背景，需要透過選項**理解決策的影響**。若 Claude 代為決定複雜選項，他會失去對流程的掌控感；而且這個專案要跟主工程師 PR 協作，重大架構選擇他自己要能解釋。`clasp-setup-plan.md` 最後一句就明確寫「請提供我選項而不是直接幫我決定」。

### 實作規則

**需要停下來列選項的情境**：
- 多個有效方案（例如：clasp v2 vs v3、本地安裝 vs 全域安裝）
- 架構決策（例如：測試環境放 iCloud 還是家目錄）
- 工作流程選擇（例如：先 commit 還是先測試）
- 要安裝新工具 / 修改系統設定 / 跨界操作

**列選項的格式**：
- 用**表格**呈現 A/B/C/D
- 每個選項標示「**優點 / 缺點 / 對他現有東西的影響**」
- 有推薦選項時**明確講出來**並給理由
- 每個技術決策**用比喻說明**（例如：「fnm symlink 像家門外貼的『請走後門』便條紙」）

**可以直接執行不用問的動作**（純執行性、低不可逆）：
- 編輯檔案
- `git commit`
- `npm run push:dev`（推到測試環境）
- 讀檔案、執行診斷指令

**永遠要問的動作**（不可逆或高影響）：
- `git push origin <branch>`（對外動作）
- `git reset --hard`、`git push --force`
- 刪除檔案
- 全域安裝工具
- 修改系統設定
- 部署到正式環境
- 動到其他專案（例如 interior-system）

---

## 絕對原則：不碰正式環境

Johnson 對「不碰正式環境」**極度嚴格**，曾主動要求移除 `npm run push:prod` 等可能觸及正式環境的 npm 指令，寧可日後需要時再請 Claude 加回來也不想留在 `package.json` 裡。

### 為什麼這麼嚴格
他是中途加入的協作者（非主導者），對主工程師管理的正式版資料有明確承諾——**絕不直接修改任何原始資料**。本專案已因此建立完整的雙環境隔離架構：

```
測試 Apps Script（Script ID: 1xR7aW...）
  + 測試 Sheets（12H5V6...）
  + Script Properties 覆寫機制
    ↓
Claude 所有工作都在這個測試沙盒完成
    ↓
透過 GitHub PR 給主工程師審核合併
```

**誤觸正式環境會破壞 Johnson 對主工程師的職場信任**，這是這個專案的**最高紅線**。

### 執行規則

| 規則 | 說明 |
|---|---|
| **永遠使用 `npm run push:dev`** | 不要用 `clasp push`（因為裸指令可能推到任何環境） |
| **永遠不要**加回 `push:prod` / `env:prod` / `pull:prod` | 除非 Johnson 明確說「我確定要加回」 |
| 執行前先 `npm run env:status` | 確認是 `【測試】DEV`，看到【正式】PROD 要立刻停下 |
| `.clasp.prod.json` 是刻意保留 | 含正式 Script ID 但沒有對應指令，**不要**用它當捷徑 |
| **絕對不** `git push origin main` | main 分支保留跟正式版一致的狀態，所有工作在 `develop` 或 feature 分支 |
| 如果未來真的需要從正式環境 `clasp pull` 比對差異 | **先問 Johnson**，手動複製 `.clasp.prod.json` 到 `.clasp.json`，做完動作**立刻切回** `.clasp.dev.json` |

---

## 新 Session 開場 SOP

當 Johnson 開啟新的 Claude Code session（任何機器、任何介面），Claude 應該**主動**做以下事情（如果使用者只說「繼續」「你好」「開始工作」這類模糊開場）：

1. **讀 `CLAUDE.md`**（本檔案）— 了解規範與專案狀態
2. **讀 `docs/` 底下最新日期的問題清單** — 了解已知 bug 與待辦（目前是 `現況問題清單-2026-04-15.md`）
3. **跑 `git log --oneline -10`** — 看最近的 commit 狀況
4. **跑 `npm run env:status`** — 確認環境是【測試】DEV
5. **跑 `git status`** — 看是否有未 commit 的改動（可能是從另一台機器切過來的）
6. **摘要告訴 Johnson**目前狀況（分支、環境、有無待辦、最近 commit），然後等他給下一步

### Session 歷史不跨機器 / 不跨介面同步

- Session `.jsonl` 檔案是**每台機器每個資料夾路徑**各自儲存
- Windows 的 session ≠ Mac 的 session ≠ GUI 的 session ≠ 終端機的 session
- **但** git repo、CLAUDE.md、memory 檔案、程式碼檔案**都會同步**
- 所以「新 Claude 實例讀 CLAUDE.md」就是跨機器協作的唯一可靠途徑
- 這就是**本章節存在的意義**：讓任何 Claude 實例都能透過這份文件無縫接手

---

# 技術架構

```
Google Sheets（資料庫）
        ↓
Google Apps Script（後端邏輯 + 網站）
        ↓
Looker Studio（報表 Dashboard，唯讀）
```

- 後端語言：JavaScript（Google Apps Script）
- 資料庫：Google Sheets
- 報表工具：Looker Studio（Google Data Studio）
- 版本控制：GitHub
- 本機開發工具：clasp（Google 官方 Apps Script CLI）

## 開發流程

1. clasp 從正式 Apps Script 專案下載程式碼到本機
2. 在本機用 Claude Code 編輯並測試
3. 推送到 GitHub 自己的分支
4. 發出 Pull Request 通知主工程師審核
5. 主工程師確認後自行合併並上傳到正式 Apps Script

**原則：不直接修改正式版程式碼，所有變更都經過 PR 審核。**

## 新機器 / Mac 首次設定（含給 Claude Code 的執行指示）

本專案可在多台電腦上協作（例如 Johnson 同時有 Windows 與 Mac）。在**新機器**首次 clone 本專案後，透過下方流程 5 分鐘內可完成環境設定。

### 使用者操作步驟（只有 3 個手動步驟）

1. **Clone 專案並切到 develop 分支**
   ```bash
   git clone https://github.com/chuanchenglin-source/cchengroad-Scoring-System.git
   cd cchengroad-Scoring-System
   git checkout develop
   ```

2. **在該目錄開啟 Claude Code**
   ```bash
   claude
   ```

3. **對 Claude Code 說這句話**：
   > 「請按照 CLAUDE.md 的『新機器 / Mac 首次設定』章節中的『給 Claude Code 的執行指示』完成環境設定」

剩下所有事情 Claude Code 會自動做，中途只會停下來要求你執行**一次** `npx clasp login`（瀏覽器 OAuth）。

### 給 Claude Code 的執行指示

**當使用者要求按照此章節執行新機器設定時，請依序執行以下步驟：**

#### 階段 1：本機環境建置（全自動）

1. **確認目前分支是 develop**
   ```bash
   git branch --show-current
   ```
   如果不是 develop，執行 `git checkout develop` 切過去。

2. **安裝 npm 相依套件**
   ```bash
   npm install
   ```
   預期輸出：`added XXX packages`。可能會出現 1 個 `high severity vulnerability` 警告，**忽略它**，不要跑 `npm audit fix`（會把 clasp 升級成 v3 導致壞掉，見本檔案下方「clasp 使用注意事項」章節）。

3. **執行環境設定腳本**
   ```bash
   node scripts/setup-env.mjs
   ```
   這會建立三個 gitignored 的檔案：`.clasp.dev.json`、`.clasp.prod.json`、`.clasp.json`。預設環境為【測試】DEV。

4. **驗證目前環境**
   ```bash
   npm run env:status
   ```
   **必須看到** `目前環境: 【測試】DEV`。如果看到【正式】PROD 或「未知」，**停下來問使用者**，不要繼續。

#### 階段 2：Google OAuth 授權（使用者手動）

5. **暫停並告訴使用者**：
   > 「本機環境已就緒。請在**另一個終端機**執行：
   >
   > ```bash
   > npx clasp login
   > ```
   >
   > 這會開啟瀏覽器進行 Google 帳號授權。完成後回來告訴我『登入完成』，我會繼續驗證。」

   **注意**：`clasp login` 會跳出「Google 尚未驗證此應用程式」警告，這是正常的，要引導使用者點「進階 → 前往 Apps Script（不安全）→ 允許」。

#### 階段 3：驗證測試環境連通（全自動，等使用者回報登入完成後）

6. **檢查 clasp 能連到測試 Apps Script**
   ```bash
   npx clasp status 2>&1 | head -20
   ```
   預期輸出：列出 `appsscript.json`、`config.js`、`helper.js` 等 8 個檔案在 `Not ignored files` 區塊。

7. **試跑一次 push（不會實際污染任何資料，只是把本機程式碼推到測試 Apps Script）**
   ```bash
   npm run push:dev
   ```
   預期輸出：`Pushed 8 files.`

8. **如果有 `User has not enabled the Apps Script API` 錯誤**：
   - 告訴使用者：「請到 https://script.google.com/home/usersettings 開啟 `Google Apps Script API`，等 1-2 分鐘後回來告訴我再試一次」

#### 階段 4：總結與下一步（全自動）

9. **總結給使用者**：
   > 「Mac 環境設定完成 ✓
   >
   > - 分支：develop
   > - 環境：【測試】DEV
   > - 測試 Web App：<從 CLAUDE.md 的「測試環境資源」章節抄 URL>
   >
   > 你現在可以：
   > - 編輯程式碼並用 `npm run push:dev` 推到測試環境
   > - 用瀏覽器打開測試 Web App 測試功能
   > - 完成後 `git commit` → `git push origin develop`
   >
   > 建議下一步：閱讀 `docs/現況問題清單-2026-04-15.md` 了解目前專案已知問題。」

### 常見問題排除

| 問題 | 原因 | 解法 |
|---|---|---|
| `npm install` 失敗，Node 版本錯誤 | Node < 20 | 裝 Node.js 20+ (`brew install node` on Mac) |
| `node scripts/setup-env.mjs` 找不到檔案 | 不在專案根目錄 | `cd` 到專案根目錄 |
| `clasp login` 卡在 `readline was closed` | 在非互動 shell 執行 | 開新的正式終端機視窗再跑一次 |
| `clasp push` 出現 `Cannot find module` | 全域裝了 clasp v3 | 移除全域 (`npm uninstall -g @google/clasp`)，本專案的 v2 本地版會自動接手 |
| `clasp push` 出現 `User has not enabled the Apps Script API` | Google 帳號未開 API | 到 https://script.google.com/home/usersettings 打開 `Google Apps Script API` 開關，等 1-2 分鐘 |
| `env:status` 顯示【正式】PROD | `.clasp.json` 跑偏了 | 執行 `npm run env:dev` 切回測試環境 |

### 跨機器同步的注意事項

**會自動同步**（透過 git）：
- 所有程式碼（8 個 Apps Script 檔案）
- 所有 markdown 文件（CLAUDE.md、docs/、clasp-setup-plan.md）
- `package.json`、`package-lock.json`
- `.gitignore`、`.claspignore`
- `scripts/setup-env.mjs`（本腳本）

**不會透過 git 同步**（gitignored，但有其他同步機制）：
- `.clasp.dev.json` / `.clasp.prod.json` / `.clasp.json`（含敏感 Script ID，由 `scripts/setup-env.mjs` 重建）
- `node_modules/`（由 `npm install` 重建）
- `給Claude讀取的資料/`（**已透過 Google Drive symlink/junction 跨機器同步**，詳見下方專章）

---

## `給Claude讀取的資料/` 跨機器同步機制

### 目的
Johnson 把個人參考資料（PPT、會議紀錄、活動方給的規則文件、截圖等）放在 `給Claude讀取的資料/` 讓 Claude Code 能讀取。這個資料夾**不能進 GitHub**（可能有私密內容、大檔案），但需要在 Windows 和 Mac 之間**自動同步**。

### 架構：Google Drive + symlink/junction

```
Google Drive 雲端
    ↕
Google Drive Desktop 客戶端（Windows + Mac 各裝一份）
    ↕
本機 Google Drive 資料夾（雲端同步的真實位置）
   - Windows: G:\我的雲端硬碟\ClaudeRef\cchengroad-scoring-system\
   - Mac:     ~/Library/CloudStorage/GoogleDrive-<email>/我的雲端硬碟/ClaudeRef/cchengroad-scoring-system/
    ↕
專案資料夾內的「給Claude讀取的資料/」（指向真實位置的 symlink/junction）
   - Windows: Junction（mklink /J 或 PowerShell New-Item）
   - Mac:     Symbolic Link（ln -s）
```

### 為什麼用 symlink/junction 而不直接把專案放 Google Drive
- Google Drive 同步整個專案 = 包括 `node_modules/` 幾十萬檔案 → 超慢、常壞
- 只同步 `給Claude讀取的資料/` 一個子資料夾 = 小、快、穩
- symlink/junction 讓 Claude Code 看起來覺得資料夾在專案內，實際上檔案在 Google Drive

### Windows 設定步驟（一次性）

```bash
# 1. Google Drive Desktop 必須運行（GoogleDriveFS.exe）
# 2. 確認 Google Drive 掛載點（通常是 G:\ 或 H:\）
ls "G:/我的雲端硬碟/"

# 3. 建立目標資料夾
mkdir -p "G:/我的雲端硬碟/ClaudeRef/cchengroad-scoring-system"

# 4. 刪除專案資料夾裡現有的空資料夾
rm -rf "給Claude讀取的資料"

# 5. 用 PowerShell 建立 junction（支援 UTF-8 中文）
powershell.exe -NoProfile -Command "New-Item -ItemType Junction -Path '給Claude讀取的資料' -Value 'G:\我的雲端硬碟\ClaudeRef\cchengroad-scoring-system'"
```

**⚠️ 踩坑警告**：**不要**用 Git Bash 直接呼叫 `cmd.exe //c 'mklink /J ...'` 傳中文路徑 — Git Bash 的 UTF-8 → CMD 的 CP950（Big5）編碼轉換會讓 junction 名稱變亂碼。**一定要透過 PowerShell**，它原生支援 Unicode。

### Mac 設定步驟（一次性）

```bash
# 1. Google Drive Desktop 必須運行並登入（跟 Windows 同一個 Google 帳號）
# 2. 確認 Google Drive 掛載點
ls ~/Library/CloudStorage/    # 應該看到 GoogleDrive-<你的email>

# 3. 確認 ClaudeRef 已同步到 Mac（等 Windows 建立完，Google Drive 同步過來）
ls ~/Library/CloudStorage/GoogleDrive-*/我的雲端硬碟/ClaudeRef/

# 4. 切到專案資料夾
cd ~/"Coding Project/Corporate Website/cchengroad-Scoring-System"

# 5. 刪除現有空資料夾
rm -rf "給Claude讀取的資料"

# 6. 建立 symlink
ln -s ~/Library/CloudStorage/GoogleDrive-<email>/我的雲端硬碟/ClaudeRef/cchengroad-scoring-system "給Claude讀取的資料"
```

**⚠️ 踩坑警告**：Mac 的 Google Drive Desktop **會本地化資料夾名稱**。中文系統看到的是 `我的雲端硬碟`，**不是** `My Drive`。路徑裡一定要寫 `我的雲端硬碟`，寫 `My Drive` 會找不到。

### 驗證雙向同步是否成功

在其中一台機器寫入測試檔：
```bash
echo "test from <machine>" > "給Claude讀取的資料/sync-test.txt"
```

等 10–30 秒後，在另一台機器讀取：
```bash
cat "給Claude讀取的資料/sync-test.txt"
```

兩台機器都能讀到 = 同步鏈路貫通 ✓

### 被同步的檔案類型建議
- ✅ 文件類（PPT、PDF、Word、Markdown）
- ✅ 截圖（PNG、JPG）
- ✅ 會議紀錄
- ✅ 活動方給的規則草案
- ⚠️ 避免大型影片 / 壓縮檔（Google Drive 會變慢）
- ❌ **不要**放敏感憑證、密碼（即使有個人帳號保護，盡量不要讓這類東西在雲端）

### 維運注意

- **刪檔時記得是刪 Google Drive 那邊**：即使透過 symlink 刪檔看起來只是本機操作，實際上會同步刪除 Google Drive 雲端與另一台機器的檔案。這是**預期行為**，但要意識到。
- **Google Drive 同步狀態**：Windows 系統列右下角 / Mac 選單列右上角有 Google Drive 圖示，點一下可以看同步進度、錯誤、最近同步的檔案清單。
- **如果兩台機器同時編輯同一個檔案**：Google Drive 會產生 `副本` 或 `conflict` 標記的檔案，要自己合併。非同時編輯則不會有問題。

---

## 測試環境 / 正式環境切換（重要）

本專案採**雙環境架構**：

| 環境 | 用途 | Script ID 檔案 |
|---|---|---|
| **測試（dev）** | Johnson 日常開發測試 | `.clasp.dev.json` |
| **正式（prod）** | 主工程師管理的線上版本 | `.clasp.prod.json` |

兩個檔案都被 `.gitignore` 排除（含敏感 Script ID，不上 GitHub）。

### 切換指令（使用 npm scripts）

```bash
npm run env:status   # 查看目前是哪個環境
npm run env:dev      # 切換到測試環境
npm run push:dev     # 切到測試 + clasp push（日常使用）
npm run pull:dev     # 切到測試 + clasp pull
```

**刻意移除的指令**：
- `env:prod` / `push:prod` / `pull:prod` — 已從 package.json 移除，避免手殘推送到正式環境
- 如果未來確實需要，告訴 Claude「把 push:prod 加回來」即可
- `.clasp.prod.json` 檔案本身**仍保留**（含正式 Script ID 作為備份），只是沒有快捷指令

**原則**：
- 本專案**只能**推送到測試環境
- 正式環境的部署由**主工程師**合併 PR 後自行處理
- 每次打開專案建議先 `npm run env:status` 確認當前環境

### config.js 支援 Script Properties 覆寫

`SS_ID_MEMBER` 與 `SS_ID_SCORE` 改為「**Script Properties 優先，正式值為 fallback**」：

```javascript
const PROPS = PropertiesService.getScriptProperties();
const SS_ID_SCORE = PROPS.getProperty('SS_ID_SCORE') || '1CFTaH...';
```

**效果**：
- **正式環境**（沒設定 Script Properties）→ 用預設值 → 行為跟原本完全一樣
- **測試環境**（在 Apps Script 設了 Script Properties）→ 用測試 Sheet ID

**測試環境的 Script Properties 設定**（在測試 Apps Script 左側「專案設定 ⚙️ → 指令碼屬性」）：
```
SS_ID_MEMBER = 1JgDikkNEV0CKuiJNic4stTy57G-ltTzDCbzXFr5E1Ao
SS_ID_SCORE  = 1JgDikkNEV0CKuiJNic4stTy57G-ltTzDCbzXFr5E1Ao
```

---

## clasp 使用注意事項（重要）

本專案 clasp 採用**本地安裝**（非全域），版本鎖定在 **v2.5.0**。

### 執行規則
- **所有 clasp 指令必須加 `npx` 前綴**（例：`npx clasp login`、`npx clasp push`）
- **不要**在本專案執行 `npm install -g @google/clasp`（全域安裝會壞）
- **不要**升級到 v3（例：`npm install @google/clasp@latest`）
- **不要**執行 `npm audit fix --force`（會把 clasp 升級成 v3 而壞掉）

### 為什麼這樣做
1. Johnson 的 Windows 用 **fnm** 管理 Node.js 版本
2. fnm 在 Windows 上建立的是 **MSYS2 symlink**（Git Bash 假 symlink）
3. 全域安裝的工具路徑會經過這個 symlink
4. **Node.js（Windows 原生）看不懂 MSYS2 symlink**，導致 `clasp: Cannot find module ...index.js` 錯誤
5. 改成本地安裝後，工具路徑是真實資料夾，完全避開 symlink 問題
6. clasp v3 用 ES Module 格式，問題更明顯；v2 是 CommonJS，相對穩定

### 已知警告（可忽略）
- `google-p12-pem@3.1.4 deprecated` — 依賴套件被標記不再維護，不影響功能
- `1 high severity vulnerability` — 內部依賴的已知問題，clasp 本身不受影響，忽略即可

---

# 活動架構

## 分組階層

```
大隊
 └── 小隊（多個）
      └── 隊員
```

- **大隊長**：管理整個大隊
- **小隊長**：管理小隊
- **隊員**：小隊成員
- 總人數：約 360 人

## 計分單位（三個層級）

1. 個人分數
2. 小隊分數 = 個人分數加總 ÷ 隊員人數 + 整隊加分
3. 大隊分數（同上邏輯，範圍更大）

---

# 計分規則

## 每週個人分數

| 週次 | 保底分 | Bonus | 最高分 | 備註 |
|------|--------|-------|--------|------|
| W1 | 210 | 無 | 210 | |
| W2 | 210 | 60 | 270 | |
| W3 | 210 | 60 | 270 | |
| W4 | 210 | 60 | 270 | |
| W5 | 210 | 環保70 + 天使30 | 310 | |
| W6 | 210 | 待確認（30或60）| 待確認 | PPT寫30，口頭說60 |
| W7 | 210 | 待確認 | 待確認 | 多了「天使10」待釐清 |
| W8 | 無計分 | 無 | 無 | 超越顛峰任務，體驗無條件付出 |

## 破冰加碼
- 個人總分再 +10
- 原本最高 270 → 完成後變 280

## 團隊動能（雙引擎加分）
- 計算方式：**每個達成的人個別加分**（不是隊伍總分加一次）
- 整隊每人都達成當週最高分 → 每人 **+500 分**
- 半數以上隊員達成 → 每人 **+350 分**
- 範例：5人隊全員達成 → 5 × 500 = 2500 分

## 領袖團隊加分（待確認）
- 大隊長互相天使通話：+200
- 小隊長互相天使通話：+100
- 加在整隊分數上

## 其他規則
- 高階複訓：不計分
- W8 超越顛峰任務：不計分

---

# 系統功能需求

## 已確認
- 對應規則調整 box
- 登入頁面的 card 加入小隊長
- 分數規則統計方式
- 統一格式（標題、按鈕、大小、用詞）
- 更改小幫手大頭照
- 分數計算做在資料端（Google Sheets 函數），Looker Studio 單純報表呈現

## Looker Studio Dashboard（四個）
1. 審計官 Dashboard
2. 各小隊長看分數的 Dashboard
3. 大隊長看分數的 Dashboard
4. 排名

## 審計官功能
- 從 W2 開始啟用
- 需要審核截圖和心得分享
- 注意：Looker Studio 只能呈現，審計官的**審核打勾**動作需要在 Apps Script 網站或 Google Sheets 直接操作

---

# 待確認事項

| 項目 | 問題 |
|------|------|
| W6 影片分數 | 30 分還是 60 分？以 PPT 為主（30分）但需再確認 |
| W7「天使10」 | 是破冰加碼的另一種說法，還是新的天使任務？ |
| W7 領袖加分 | 大隊長+200、小隊長+100 是否已更新進 PPT？ |
| 「半數以上」定義 | 5人隊，3人算過半嗎？無條件進位還是剛好過半？ |
| 小隊長是否計入隊員人數 | 影響平均分數計算 |
| 大隊長有無個人分數 | 還是只管理大隊？ |
| 審計官人數與分配 | 一人還是多人？每大隊有自己的審計官？ |
| 名單確定時間 | 目前只有大隊長確定，隊員名單還在變動 |

---

# 開發注意事項

- 我沒有程式設計背景，請用非技術語言解釋決策選項
- 每次修改請說明改了什麼、為什麼這樣改
- 優先確保不破壞現有功能
- 所有變更透過 GitHub PR，不直接動正式版
