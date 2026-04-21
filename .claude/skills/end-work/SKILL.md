---
name: 收工
description: >
  結束今天工作時的收尾自動化。Commit 改動、詢問是否 push、更新待辦清單、摘要進度。
  當使用者說「收工」、「今天到這」、「先這樣」、「結束」、「下班」、「同步一下」、
  「幫我 commit」、「我要換電腦了」，或任何表示要結束當前工作階段的意圖時，使用這個 skill。
---

# /收工 — 結束工作收尾自動化

## 執行步驟

### Step 1：盤點工作區與未推送 commit

```bash
git status
git log origin/develop..HEAD --oneline
```

分流：
- **有改動** → 走 Step 2
- **工作區乾淨但有未推送 commit** → 跳到 Step 3
- **都沒有** → 跳到 Step 4

### Step 2：Commit 改動（含安全偵測）

**先做安全偵測**：掃描 `git status` 輸出，若有以下可疑檔案，**先停下來逐個跟 Johnson 確認**才繼續：

- `.env*`（環境變數，可能含密鑰）
- `*.key` / `*.pem` / `*credentials*` / `*secret*`（憑證）
- `給Claude*/`（個人參考資料，不應上 git）
- `.clasp.*.json`（含 Script ID）
- 任何看起來像私密 / 大型 / 不該進 repo 的檔案

通過偵測後：

```bash
git add -A
git commit -m "<中文 commit message>"
```

Commit message 格式：

```
[主要改動的一句話摘要]

- [改動1]
- [改動2]
```

### Step 3：詢問是否 Push

確認當前分支：

```bash
git branch --show-current
```

非 `develop` 或 `feature/*` 分支 → **停下問 Johnson**，不要直接 push。

問：「已 commit。要推到 GitHub 嗎？（git push origin <branch>）」

- 同意 → `git push origin <branch>`
- 不同意 → 跳過，提醒下次可以手動 push

**絕對不能 push main。**

### Step 4：更新待辦清單

從 auto-loaded `MEMORY.md` 找待辦 memory（檔名類似 `project_pending_todos.md`）。
**找不到就建立一個**（type=project）放在 `MEMORY.md` 同層的 memory 目錄。

根據今天的對話：

1. **勾掉今天完成的項目**（已完成的可直接刪除，不需保留）
2. **新增今天發現但未做完的待辦**
3. **保留尚未處理的舊待辦**

更新前**先列出「異動清單」給 Johnson 確認**，避免誤刪。

待辦檔案格式建議：

```markdown
---
name: 待辦事項（跨 session）
description: 下次接手時要做的事，由 /收工 寫入、/開工 讀取
type: project
---

## 進行中
- [ ] [待辦項目，含足夠脈絡讓未來的 Claude 看懂]

## 等待外部回應
- [ ] [等誰、等什麼、何時跟進]
```

完成後若這個 memory 還沒在 `MEMORY.md` 索引裡，加上去。

### Step 5：摘要

```
## 收工摘要

**今天完成的事：**
- [事項1]
- [事項2]

**目前停在：** [狀態]

**留給下次的待辦：**
- [ ] [待辦1]
- [ ] [待辦2]

**同步狀態：**
- commit: ✓ [hash 前 7 碼] / 無改動
- push: ✓ / ✗（跳過）/ 不適用
- 待辦 memory: ✓ 已更新 / 無變動
```

如果 Johnson 提到要換電腦繼續，最後加一句：「另一台先 `git pull origin develop` 再開工。」

## 注意事項

- push 前一定要問
- 非 develop / feature 分支不能直接 push
- 不能用 `push:prod`，不碰正式環境
