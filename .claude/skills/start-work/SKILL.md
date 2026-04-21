---
name: 開工
description: >
  每次開啟新 session 時的開場自動化。拉最新程式碼、確認環境、列出未完成待辦、摘要報告。
  當使用者說「開工」、「繼續」、「開始工作」、「接手」、「回來了」、「新 session」，
  或任何表示要開始今天工作的意圖時，使用這個 skill。
  也適用於從另一台電腦（Windows/Mac）切換過來要接續工作的情境。
---

# /開工 — 新 Session 開場自動化

CLAUDE.md 與 MEMORY.md 已被系統自動載入，**不要重複讀**。

## 執行步驟

### Step 1：拉最新程式碼

```bash
git pull origin develop
```

衝突就**停下**告訴 Johnson，不要自動解決。

### Step 2：確認環境

```bash
npm run env:status
```

- `【測試】DEV` → 繼續
- `【正式】PROD` 或「未知」→ **立刻停下**警告 Johnson，建議 `npm run env:dev` 切回

### Step 3：看工作區殘留

```bash
git status
```

留意未 commit 的改動（可能是從另一台機器切過來的殘留）、未追蹤檔案。

### Step 4：撈出上次未完成的待辦

從 auto-loaded 的 `MEMORY.md` 找「待辦」/「pending」相關 memory（檔名通常是 `project_pending_todos.md` 或類似）。
**主動讀完整檔案**取得 checkbox 清單（auto-load 只給簡述）。

找不到任何待辦 memory → 跳過此步。

### Step 5：摘要報告

```
## 開工摘要

- **分支**：[branch]
- **環境**：【測試】DEV ✓
- **pull 結果**：[Already up to date / 拉到 N 筆新 commit + 一句重點]
- **工作區**：[乾淨 / 有未 commit 的改動（列檔名）]

**上次留下的待辦：**
- [ ] [待辦1]
- [ ] [待辦2]

要接續哪一項？或有其他指示？
```

沒有待辦清單時，最後兩段省略，改成「等你的指示，今天要做什麼？」。

## 注意事項

- 不要代為決定下一步
- 這個 skill 只做「讀取 + 報告」，不修改任何檔案
- 不碰正式環境
