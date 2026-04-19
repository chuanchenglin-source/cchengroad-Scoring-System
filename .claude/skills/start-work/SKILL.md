---
name: 開工
description: >
  每次開啟新 session 時的開場自動化。讀取專案狀態、拉最新程式碼、確認環境、摘要報告。
  當使用者說「開工」、「繼續」、「開始工作」、「接手」、「回來了」、「新 session」，
  或任何表示要開始今天工作的意圖時，使用這個 skill。
  也適用於從另一台電腦（Windows/Mac）切換過來要接續工作的情境。
---

# /開工 — 新 Session 開場自動化

這個 skill 在每次開新 session 時自動執行一系列檢查，讓 Johnson 快速了解目前專案狀態。

## 執行步驟

按照以下順序執行，每一步都要執行，不要跳過。所有指令在 Mac 和 Windows（Git Bash / PowerShell）都能正常運作。

### Step 1：讀取專案規範

讀取專案根目錄的 `CLAUDE.md`，了解專案規範與協作模式。不需要輸出內容，內化即可。

### Step 2：讀取 Memory

檢查是否存在 memory 檔案。如果有，讀取了解上次的工作進度與待辦。

找到 memory 目錄的方式：用 Glob 搜尋 `**/.claude/projects/*/memory/MEMORY.md`，讀取找到的 MEMORY.md 以及它引用的所有 memory 檔案。

如果找不到 memory 檔案，跳過這步即可。

### Step 3：拉取最新程式碼

```bash
git pull origin develop
```

如果有衝突，**停下來告訴 Johnson**，不要自動解決。

### Step 4：確認環境

```bash
npm run env:status
```

**關鍵檢查**：
- 看到 `【測試】DEV` → 正常，繼續
- 看到 `【正式】PROD` → **立刻停下來警告 Johnson**，不要繼續任何操作
- 看到 `未知` → 告訴 Johnson，建議執行 `npm run env:dev` 切回測試環境

### Step 5：最近的 commit

```bash
git log --oneline -5
```

記下最近幾筆 commit 的內容，稍後摘要用。

### Step 6：檢查工作區狀態

```bash
git status
```

注意是否有：
- 未 commit 的改動（可能是從另一台機器切過來的殘留）
- 未追蹤的新檔案
- 合併衝突

### Step 7：檢查待辦/問題清單

用 Glob 搜尋 `docs/*問題清單*` 和 `docs/*待辦*`，讀取最新日期的那份。
如果找不到，跳過。

也檢查是否有 Spectra 進行中的 change：
```bash
ls openspec/changes/ 2>/dev/null
```

### Step 8：摘要報告

用中文、白話，把以上結果整理成簡潔的摘要報告，格式如下：

```
## 開工摘要

- **分支**：develop
- **環境**：【測試】DEV ✓
- **最近 commit**：[最近一筆的訊息]
- **工作區**：[乾淨 / 有未 commit 的改動（列出）]
- **上次進度**：[從 memory 讀到的，如果有的話]
- **待辦/已知問題**：[從問題清單讀到的，如果有的話]

等你的指示，今天要做什麼？
```

## 注意事項

- **不要代為決定下一步**，摘要完等 Johnson 給指示
- **不要執行任何修改檔案的操作**，這個 skill 只做「讀取 + 報告」
- **不要碰正式環境**，如果 env:status 不是 DEV，停下來
- 所有指令都是跨平台的（Mac / Windows Git Bash / PowerShell），不要用平台特定指令
