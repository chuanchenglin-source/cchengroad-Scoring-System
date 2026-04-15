# 專案背景

這是一個為期 8 週的活動積分管理系統「**心成親證班回報系統**」，目前由臨時團隊遠端協作開發。我（Johnson）是中途加入的開發協作者，非主導者，透過 Claude Code 協助撰寫程式碼。

---

# 相關資源

以下兩個資料來源**並行**使用，需要專案背景資料時兩邊都可查找：

- **專案共用 Google Drive**（網站主導者建立，團隊共用）：https://drive.google.com/drive/folders/1-37xaAxIOEmZaQGk6vGat4NQAVbqIWPn
- **`給Claude讀取的資料/`**（本機資料夾，Johnson 個人維護）：放置供 Claude 參考的檔案（PPT、截圖、規則文件、會議記錄等）。

## 測試環境資源（Johnson 專用沙盒）

| 項目 | 連結 / ID |
|---|---|
| 測試 Google Sheets | `12H5V6FKByPzXwqOlE1KrDHMdxDI3tLRZ9b5U9alJtvE` |
| 測試 Apps Script | `1xR7aWeaeAzUjzoQMO1m6cWkkJrCW85-2IlU0_NHU-IPReOX4mtg0ttxY` |
| 測試 Web App URL | https://script.google.com/macros/s/AKfycbzRgBYH6RsnPs8j7m5k2vr4DT7I_UU_qA3e2SfGrMr8iX705EUwJiRsOsHLJpqvAbg/exec |

**正式環境資源**（僅供 Claude 參考，Johnson 不應直接操作）：
| 項目 | ID |
|---|---|
| 正式 Google Sheets | `1CFTaHNqlaVQOC7Bpuk7KMznFRuAYNHmBMxeDvA19wtw` |
| 正式 Apps Script | `19ZCMtO64t7drgu-MVY-kbCJpOcW8kvpjDjsu0mfBFszyjRmP6ghqc8NV` |

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
SS_ID_MEMBER = 12H5V6FKByPzXwqOlE1KrDHMdxDI3tLRZ9b5U9alJtvE
SS_ID_SCORE  = 12H5V6FKByPzXwqOlE1KrDHMdxDI3tLRZ9b5U9alJtvE
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
