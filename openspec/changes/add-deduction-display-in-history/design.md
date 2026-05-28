## Context

「心成親證班回報系統」由「計分系統」（本 repo）與「偵查官系統」（姊妹 repo `cchengroad-Monitor-System`）兩個獨立的 GAS + Google Sheet 系統組成。偵查官原本只 read-only 讀計分系統 Sheet 顯示填分狀況；本 change 要在 history.html 加入「讀取偵查官 Sheet 的扣分記錄並顯示」的反向 read 流。

設計討論結論已落字到 `docs/偵查官扣分機制-設計討論-2026-05-29.md`，本 design 聚焦在計分系統端的技術契約與決策。

**現有架構**：
- `webApp.js` 是 Apps Script entry point，`getPersonalHistory(userId)` 從計分 Sheet 的「每日個人分數結算」分頁讀取使用者填分歷史回傳給前端
- `history.html` 用 `google.script.run.getPersonalHistory()` 拿資料，前端 `calculateSummary()` 算總分、`renderBoxes()` 渲染 14 張 box 卡片
- `config.js` 集中放 Sheet ID 常數（`SS_ID_SCORE`、`SS_ID_MEMBER`）

**新的契約對象**：
- 偵查官副本 Sheet `1_bkaXcApXPKe9I1kF0DL4gne06e__8YiC5yy5FOgT3Y` 的「扣分記錄」分頁，12 欄結構詳見 docs 設計討論文件

**副本測試環境（5 個資源已就緒）**：
- 計分系統副本 GAS `1iBj0Wl3UKPJrLErt5iqQ_NEwmDEMKntQO35WkyrEpjr8RVUgsP0crdfR`
- 計分系統副本 Sheet（人員/結算側）`1YNB7s-JjPRurGTrgAjPU0qwVyeSvyLo5c5I-K3uA1Gk`
- 計分系統副本 Sheet（填單回應側）`1R-0b_mcy97IbH8r485_BV6gUHJIjmDT-AFRk91zAGDU`
- 偵查官副本 GAS `1UGg3htqYDVRjJBewGdvNpZsj4fjmuSLSxvC9_3o_e5SSYfbVbkvFiI3-`
- 偵查官副本 Sheet `1_bkaXcApXPKe9I1kF0DL4gne06e__8YiC5yy5FOgT3Y`

## Goals / Non-Goals

**Goals:**

- 被扣分的隊員打開 history.html 時，能在對應 box 卡片內看到偵查官的扣分記錄（含扣多少分、原因、誰扣的）
- 頂部「全期累計總分」與週選取器的「積分」反映扣完後的淨分
- 被撤回（`withdrawn` 狀態）的扣分不顯示、不影響計算
- 在副本測試環境完整跑通流程後，透過 PR 合併到正式

**Non-Goals:**

- 不做偵查官端扣分輸入介面與撤回介面（在 `cchengroad-Monitor-System` repo 處理）
- 不重構 history.html 既有「按週切資料」邏輯（截圖點 1、2 提到的問題，另開討論）
- 不做主動通知機制（被扣分者要自己打開 history 才能看到）
- 不改 `saveForm()` / `getMemberList()` / `rebuildSummaryReport()` 等其他既有功能
- 不寫入任何 Sheet（本 change 計分系統端純 read-only）

## Decisions

### 跨 Sheet 讀取時機與快取策略

**選擇**：每次 `getPersonalHistory(userId)` 都即時讀偵查官 Sheet 一次，不做快取。

**理由**：
- 偵查官系統「立刻生效 + 撤回」的設計決策（見 docs 討論結論 5 個決策）要求扣分變動即時反映在 history.html
- 加快取會引入「扣分撤回但 history 還顯示」的不一致期，違反設計原則
- 單次讀取量小（一個 userId 對應的 active 扣分通常 < 20 筆），效能可接受
- GAS `SpreadsheetApp.openById()` + `getDataRange()` 是同步呼叫，不需特殊處理

**取代的選項**：時間快取（5 分鐘 TTL）— 拒絕原因：與「即時反映撤回」原則衝突。

### 扣分資料在回傳結構的形狀

**選擇**：在每筆 history record 上掛 `box{N}_deductions` 陣列（N=1~14），每個元素 `{score: number, reason: string, monitor_id: string, deduction_id: number}`。

**理由**：
- history.html 目前用 `record.box{N}_score` / `record.box{N}_content` 平鋪存取，扣分用同一 prefix 邏輯一致
- 用陣列而非單筆，支援同一 box 多筆扣分（不同偵查官、不同原因）
- 攜帶 `deduction_id` 讓未來如果要做「點扣分連結到偵查官系統」的擴充有 anchor

**取代的選項**：頂層 `record.deductions` 一個 flat 陣列再讓前端分組 — 拒絕原因：把 join 邏輯下推到後端，前端 render 邏輯更乾淨。

### history.html 扣分顯示位置

**選擇**：嵌入對應 box 卡片表格內，該日期列下方插入紅色警示行。

**理由**：
- 設計討論已確認此方案（問題 5 選 A）
- 跟原填分綁在一起看，因果關係一目了然
- 不脫節（vs 選 B 集中清單會強迫使用者跳來跳去對照）
- 改動範圍小，只動 box 卡片表格的渲染邏輯

**取代的選項**：
- 頁面頂部「扣分一覽」獨立區塊 — 拒絕：脫節
- 兩者都做 — 拒絕：第一版不需要這個複雜度

### 撤回扣分的顯示與計算行為

**選擇**：`withdrawn` 狀態的扣分**完全不顯示**，也**不參與**總分/週積分計算；只有 `active` 進入回傳結構。

**理由**：
- 被扣人不需要知道「我曾被扣但被撤回了」的中間狀態，避免困惑與誤解
- 從技術面看 `withdrawn` 等同未發生
- 撤回紀錄留在偵查官 Sheet 給審計用，被扣人介面不暴露

**取代的選項**：顯示 withdrawn 並標記為「已撤回」— 拒絕：UI 噪音，且被扣人不需要這個資訊。

### 副本環境的 Sheet ID 設定方式

**選擇**：在 `config.js` 新增 `SS_ID_MONITOR_DEDUCTION` 常數，副本環境設成副本偵查官 Sheet ID；正式環境提 PR 時改成正式偵查官 Sheet 對應的扣分 Sheet ID。

**理由**：
- 跟既有 `SS_ID_SCORE` / `SS_ID_MEMBER` 一致的命名與管理方式
- 環境切換靠改 config，不靠 Script Properties（demo 階段簡單為主）

**取代的選項**：用 Script Properties 動態覆寫 — 拒絕：增加部署複雜度，demo 階段不需要。

## Implementation Contract

### 對外可觀察行為

被扣分的隊員（例如 `T011_周子維_嘉家久`）打開 history.html 後：

1. **box 卡片內顯示扣分**：在被扣的那個 box 卡片中，對應 `填分日期` 的那一列下方，會出現紅色警示行，內容為「偵查官扣分 -{score}：{reason}（偵查官：{monitor_id}）」。同一日同一 box 有多筆 active 扣分時，按 `扣分時間` 升冪逐行顯示
2. **頂部「全期累計總分」反映淨分**：原本 `Σ score` 改為 `Σ score − Σ active_deduction.score`
3. **週選取器的「積分」反映淨分**：每週積分扣除該週內 active 扣分總和
4. **撤回的扣分完全消失**：`withdrawn` 不在 1/2/3 任何一處顯示或計算
5. **沒被扣分的使用者體驗完全一致**：UI 與行為與本 change 之前完全相同

### 後端 API 契約

回傳陣列每個 record 物件**保留**所有既有欄位（`date`, `team`, `userId`, `userName`, `score`, `originalTime`, `remark`, `box1_score`...`box13_score`, `box14_score`, `box1_content`...`box14_content`），**新增**：

- `box{N}_deductions`: `Array<{score: number, reason: string, monitor_id: string, deduction_id: number}>`，N = 1~14
  - 只包含 `狀態 = 'active'` 的扣分
  - 按 `扣分時間` 升冪排序
  - 沒有扣分時為空陣列 `[]`（不是 `undefined`）

### 前端 render 契約

- `renderBoxes()` 在原本 `${displayDate}` / `${score}` / `${content}` 列之後，若 `record.box{N}_deductions.length > 0`，**接續**插入一列：`<tr class="deduction-row">...</tr>`
- `.deduction-row` 樣式：紅色背景（建議 `#fef2f2`）、紅色文字（`#991b1b`）、左邊紅色 border-left 4px 強調
- 該列內容格式：`「偵查官扣分 −{score}：{reason}（偵查官：{monitor_id}）」`
- `calculateSummary()` 新增 `totalDeduction` 累計、`weekDeductions[w]` 累計
- `grandTotal` 顯示為 `total - totalDeduction`，`weekScore-{w}` 顯示為 `weekScores[w] - weekDeductions[w]`

### 失敗模式

- 偵查官 Sheet 讀取失敗（網路、權限、Sheet 不存在）：`getPersonalHistory` 回傳的 record 中 `box{N}_deductions` 全為 `[]`，log 錯誤到 `console.error`，但**不阻斷**整體歷史頁面渲染。前端看起來等同「沒有扣分」
- 偵查官 Sheet「扣分記錄」分頁不存在：同上
- 扣分記錄某欄位缺失或型別錯誤：該筆扣分被跳過（不掛到對應 box），log warning，其他扣分正常處理

### 驗收條件

在副本測試環境驗證以下情境通過：

1. 偵查官副本 Sheet 沒有任何扣分記錄時 → history.html 行為完全等同改動前
2. 為測試帳號（例如 `T011_周子維_嘉家久`）在副本偵查官 Sheet 加一筆 `active` 扣分（W3 5/12 box5 扣 20 分）→ 打開 history.html W3 → box5 卡片該日列下方有紅色扣分顯示；總分扣 20；W3 積分扣 20
3. 把該扣分狀態改為 `withdrawn` → 重新整理 history.html → 扣分行消失、總分與週積分恢復
4. 為同一 box 加兩筆 active 扣分（不同偵查官）→ 兩行扣分都顯示、總分扣兩次

### 範圍邊界

**In scope**：`webApp.js:getPersonalHistory()` 跨 Sheet 讀取邏輯、`history.html` 渲染與計算修改、`config.js` 新增 Sheet ID 常數、副本環境驗證

**Out of scope**：偵查官端寫入流程、history.html 既有按週切資料邏輯重構、Index.html 通知 badge、主辦方對齊規則衝突、扣分審核機制

## Risks / Trade-offs

- **每次載入 history.html 多一次 Sheet 讀取** → Mitigation：單次讀取量小（< 20 筆扣分），可接受；若未來扣分量爆增（例如 > 500 筆/使用者）再考慮 server-side cache
- **偵查官 Sheet ID 設定錯誤會讓所有使用者看不到扣分** → Mitigation：在 `getPersonalHistory` 加 sanity check（讀不到「扣分記錄」分頁時 log 明確錯誤），副本驗收條件 1 也會涵蓋
- **使用者看到扣分後可能直接 LINE 抗議主辦方** → Mitigation：UI 顯示「偵查官：{monitor_id}」讓使用者知道找誰；本 change 不負責申訴流程，由規則對齊處理
- **PR 合併前正式環境的偵查官 Sheet 還沒設定「扣分記錄」分頁** → Mitigation：失敗模式設計成「讀不到視為沒扣分」，不會打爛 history 頁面；PR 描述會註明合併前需先建分頁

## Migration Plan

1. **副本驗證階段**（本 change 主要工作）：在副本測試環境完成 4 個驗收情境
2. **正式環境準備**：合併 PR 前，請主工程師在正式偵查官 Sheet 新建「扣分記錄」分頁（12 欄結構，跟副本一致）
3. **正式環境部署**：主工程師 review PR、合併、`clasp push` 到正式計分系統 GAS
4. **回滾策略**：失敗時 revert PR + 把 `SS_ID_MONITOR_DEDUCTION` 設成空字串（失敗模式會 fallback 到「沒扣分」狀態），不影響既有功能
