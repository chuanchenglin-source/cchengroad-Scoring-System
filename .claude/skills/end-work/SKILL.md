---
name: 收工
description: >
  結束今天工作時的收尾自動化。Commit 改動、自動 push（非 main 分支）、更新待辦清單、摘要進度。
  當使用者說「收工」、「今天到這」、「先這樣」、「結束」、「下班」、「同步一下」、
  「幫我 commit」、「我要換電腦了」，或任何表示要結束當前工作階段的意圖時，使用這個 skill。
---

# /收工 — 結束工作收尾自動化

> **2026-05-29 更新**：已對齊現況。專案方向 **GAS only**（Supabase 已停止），不再用 `push:prod` / 環境切換。工作分支目前是 `chore/restore-baseline-2026-05-27`（不是 develop）。

## 執行步驟

### Step 1：盤點工作區與未推送 commit

```bash
git branch --show-current
git status
git log @{u}..HEAD --oneline
```

`@{u}` 是「目前分支的遠端追蹤分支」（不寫死 develop）。若出現 `no upstream` 錯誤 → 表示這分支還沒推過，視為「有未推送 commit」，Step 3 會用 `-u` 建立追蹤。

分流：
- **有改動** → 走 Step 2
- **工作區乾淨但有未推送 commit** → 跳到 Step 3
- **都沒有** → 跳到 Step 4

### Step 2：Commit 改動（含安全偵測）

**先做安全偵測**：掃描 `git status` 輸出，若有以下可疑檔案，**先停下來逐個跟 Johnson 確認**才繼續：

- `.env*`（環境變數，可能含密鑰）
- `*.key` / `*.pem` / `*credentials*` / `*secret*`（憑證）
- `給Claude*/`（個人參考資料，不應上 git）
- `.clasp.*.json` / `.clasp.json`（含 Script ID）
- `.claude/settings.json`（可能是 machine-local 設定，預設不 commit）
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

### Step 3：自動 Push（2026-04-23 起 Johnson 授權 auto-push）

```bash
git branch --show-current
```

**分流**：
- **`main`** → **絕對不 push**，停下告訴 Johnson 當前在 main（異常狀態，紅線）
- **其他任何分支**（develop、feature/*、chore/*、目前的 `chore/restore-baseline-*` 等）→ **直接** push，不問：
  - 有 upstream → `git push origin <branch>`
  - 無 upstream → `git push -u origin <branch>`

push 失敗時：顯示錯誤訊息，**不自動 retry / force**，等 Johnson 判斷。

**背景**：2026-04-23 Johnson 授權 auto-push，因此非 main 分支不再逐次確認。唯一紅線是 main。

### Step 3.5：fork 改動提醒（只在今天動過 fork 時）

⚠️ 如果今天動的是 **fork**（`cchengroad-Scoring-System-fork-0527`，40-box 版），注意：

- fork **沒有 git remote**，上面的 git push **不會**把它同步出去
- fork 要同步到副本 GAS 是用 **clasp**：`eval "$(fnm env)"` 後 `npx clasp push -f`（先確認 `.clasp.json` 指向副本 `1iBj0Wl3`，不是正式）
- 推 fork 到 GAS 前建議先做飄移檢查（拉遠端比對），確認沒蓋掉主工程師的改動

今天沒動 fork → 略過這步。

### Step 4：更新待辦清單

從 auto-loaded `MEMORY.md` 找待辦 memory（檔名類似 `project_pending_todos.md`）。
**找不到就建立一個**（type=project）放在 `MEMORY.md` 同層的 memory 目錄。

根據今天的對話：

1. **勾掉今天完成的項目**（已完成的可直接刪除，不需保留）
2. **新增今天發現但未做完的待辦**
3. **保留尚未處理的舊待辦**

更新前**先列出「異動清單」給 Johnson 確認**，避免誤刪。

> 跨機器接手：memory 在 `~/.claude`，不一定跨機器同步。**若今天要換機**，把關鍵待辦也寫一份到 `docs/換機交接-YYYY-MM-DD.md`（會隨 git 同步，最可靠）。

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
- push (git): ✓ 已 push 到 origin/<branch> / ✗ 因 <原因> 未 push
- fork (clasp): ✓ 已 clasp push 到副本 GAS / 今天沒動 fork
- 待辦 memory: ✓ 已更新 / 無變動
```

如果 Johnson 提到要換電腦繼續，最後加一句：
「另一台接手：先 `git checkout <目前分支> && git pull` 拿到最新（含交接note），再 `/開工`。**fork 要另外 `clasp clone/pull`**（它沒 git remote）。」

## 注意事項

- 非 main 分支自動 push，**不需要問**（2026-04-23 Johnson 授權）
- **絕對不**直接 push main；在 main 分支時停下問
- 不碰正式環境（計分 Sheet `1CFTaHN`、計分 GAS `19ZCMtO64`、偵查官 GAS `1y2NcmR9`）
- fork 同步走 clasp（非 git），且 clasp push 前先確認指向副本
