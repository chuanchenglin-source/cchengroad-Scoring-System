---
name: 開工
description: >
  每次開啟新 session 時的開場自動化。拉最新程式碼、確認分支與工作區、列出未完成待辦、摘要報告。
  當使用者說「開工」、「繼續」、「開始工作」、「接手」、「回來了」、「新 session」，
  或任何表示要開始今天工作的意圖時，使用這個 skill。
  也適用於從另一台電腦（Windows/Mac）切換過來要接續工作的情境。
---

# /開工 — 新 Session 開場自動化

CLAUDE.md 與 MEMORY.md 已被系統自動載入，**不要重複讀**。

> **2026-05-29 更新**：本 skill 已對齊現況。專案方向是 **Google Sheets → GAS only**（Supabase 備案已停止），舊的 `npm run env:status`、dev/prod 環境切換、develop 固定分支等機制**都已移除**，不要再用。

## 執行步驟

### Step 1：確認分支並拉最新程式碼

先看目前在哪個分支，再拉該分支的最新：

```bash
git branch --show-current
git pull
```

**分流**：
- 成功（含 Already up to date）→ 繼續
- 衝突 → **停下**告訴 Johnson 有哪幾個檔案衝突，不要自動解決
- 錯誤（網路、認證、無 upstream）→ 停下顯示錯誤，不 retry
- **若目前在 `main` 分支** → 提醒 Johnson：工作分支通常不是 main（紅線：絕不 `git push origin main`），確認是否要切到工作分支（目前是 `chore/restore-baseline-2026-05-27`）

**背景**：2026-04-23 Johnson 明確說「將自動 push 及 pull 寫進收工及開工程序中」，因此 pull 是預設行為不問。

### Step 2：看工作區殘留

```bash
git status
git log --oneline -5
```

留意未 commit 的改動（可能是從另一台機器切過來的殘留）、未追蹤檔案，以及最近 5 筆 commit 在做什麼。

### Step 3：撈出待辦與交接note

兩個來源都要看：

1. **`docs/` 底下最新日期的「換機交接」或「進度」note**（例如 `docs/換機交接-YYYY-MM-DD.md`、`docs/夜間進度-YYYY-MM-DD.md`）— 主動讀完整檔案，這是跨機器接手最可靠的來源（memory 在 `~/.claude`，不一定跨機器同步）。
2. **auto-loaded `MEMORY.md`** 裡「待辦」/「pending」相關 memory — 主動讀完整檔案取得 checkbox 清單。

兩處都找不到 → 跳過此步。

### Step 4：fork 提醒（只在今天要動「偵查官扣分顯示」功能時）

⚠️ 偵查官扣分**顯示**功能不在這個 repo，而在 **fork**（`cchengroad-Scoring-System-fork-0527`，40-box 版，副本 GAS 實際跑的）。

- fork **沒有 git remote**，無法 `git pull`；要同步用 clasp：`npx clasp clone/pull 1iBj0Wl3...`（需先 `eval "$(fnm env)"` 載入 node）
- 細節見 memory `reference-test-environment-0527` 與最新的 `docs/換機交接-*.md`
- 如果今天的工作跟 fork 無關（例如只動 baseline / 文件），**略過這步**，不用主動 clone

### Step 5：摘要報告

```
## 開工摘要

- **Repo / 分支**：[repo 名] / [branch]（在 main 要警告）
- **pull 結果**：[Already up to date / 拉到 N 筆新 commit + 一句重點]
- **工作區**：[乾淨 / 有未 commit 的改動（列檔名）]
- **最近 commit**：[一句話帶過最近在做什麼]

**待辦 / 交接：**
- [ ] [從交接note或 MEMORY 撈到的待辦1]
- [ ] [待辦2]

要接續哪一項？或有其他指示？
```

沒有待辦清單時，最後兩段省略，改成「等你的指示，今天要做什麼？」。

## 注意事項

- 不要代為決定下一步
- 這個 skill 只做「讀取 + 報告」，**不修改任何檔案、不自動 clasp clone**（fork 同步要 Johnson 確認後才做）
- 不碰正式環境（計分 Sheet `1CFTaHN`、計分 GAS `19ZCMtO64`、偵查官 GAS `1y2NcmR9`）
