---
name: 收工
description: >
  結束今天工作時的收尾自動化。Commit 改動、詢問是否 push、更新 memory、摘要進度。
  當使用者說「收工」、「今天到這」、「先這樣」、「結束」、「下班」、「同步一下」、
  「幫我 commit」、「我要換電腦了」，或任何表示要結束當前工作階段的意圖時，使用這個 skill。
---

# /收工 — 結束工作收尾自動化

這個 skill 在每次結束工作時自動執行收尾步驟，確保進度被保存、同步、記錄。

## 執行步驟

### Step 1：檢查工作區狀態

```bash
git status
```

根據結果分兩條路：
- **有改動** → 繼續 Step 2
- **沒有改動（工作區乾淨）** → 跳到 Step 4

### Step 2：Commit 改動

先列出所有改動的檔案，讓 Johnson 確認。

然後執行：

```bash
git add -A
```

**自動產生 commit message**：根據改動的檔案內容，用中文寫一段簡潔的 commit message。格式：

```
[主要改動的一句話摘要]

- [改動1]
- [改動2]
- ...
```

執行 commit：

```bash
git commit -m "..."
```

**注意**：
- `.gitignore` 裡列出的檔案不會被 commit（包括 `給Claude讀取的資料/`、`.claude/`、`.clasp.*.json` 等）
- 如果不確定某個檔案該不該 commit，問 Johnson

### Step 3：詢問是否 Push

**一定要問，不要自動 push。** 用這個格式：

```
已 commit。要推到 GitHub 嗎？（git push origin develop）
```

等 Johnson 回覆：
- 「好」/「推」/「push」→ 執行 `git push origin develop`
- 「不用」/「先不要」→ 跳過，告訴他下次可以手動 push

**絕對不能 push 到 main 分支。** 如果當前分支不是 develop 或 feature branch，**停下來問 Johnson**。

### Step 4：更新 Memory

讀取現有的 memory 檔案，根據今天的工作內容更新。

更新的內容應包含：
- 今天做了什麼（簡述）
- 目前停在哪裡
- 下一步建議做什麼

Memory 檔案路徑用 Glob 搜尋 `**/.claude/projects/*/memory/MEMORY.md` 找到。
更新對應的 memory 檔案內容，以及 MEMORY.md 索引。

如果 memory 目錄不存在，建立它。

### Step 5：摘要今天進度

用中文、白話，整理今天的工作摘要：

```
## 收工摘要

**今天完成的事：**
- [做了什麼1]
- [做了什麼2]

**目前停在：**
[停在哪裡、什麼狀態]

**下次建議：**
[下一步可以做什麼]

**同步狀態：**
- commit: ✓ [commit hash 前7碼]
- push: ✓/✗
- memory: ✓ 已更新
```

## 注意事項

- **push 前一定要問**，這是對外動作
- **不能 push main**，只能 push develop 或 feature branch
- **不能用 push:prod**，不能碰正式環境
- 所有指令都是跨平台的（Mac / Windows Git Bash / PowerShell）
- 如果 Johnson 說「明天在另一台電腦繼續」，在摘要裡提醒他先 `git pull origin develop`
