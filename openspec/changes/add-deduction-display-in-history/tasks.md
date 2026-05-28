## 1. 基礎設定與環境準備

- [x] 1.1 在 `config.js` 新增 `SS_ID_MONITOR_DEDUCTION` 常數對應副本偵查官 Sheet ID（副本環境的 Sheet ID 設定方式）。完成條件：副本 GAS Editor 執行 `Logger.log(SS_ID_MONITOR_DEDUCTION)` 輸出與副本偵查官 Sheet ID `1_bkaXcApXPKe9I1kF0DL4gne06e__8YiC5yy5FOgT3Y` 完全一致。

- [x] 1.2 確認副本偵查官 Sheet 「扣分記錄」分頁 12 欄結構與設計討論文件一致（範圍邊界 in-scope 檢查）。完成條件：以肉眼或 `getDataRange().getValues()[0]` 確認 A1 至 L1 依序是「扣分編號、被扣人ID、填分日期、Box編號、扣分數值、扣分原因、偵查官ID、扣分時間、狀態、撤回者ID、撤回時間、撤回原因」，第二列空白。

## 2. 後端跨 Sheet 讀取（webApp.js:getPersonalHistory）

- [x] 2.1 實作 Cross-Sheet Read of Active Deductions：在 `getPersonalHistory(userId)` 加入跨 Sheet 讀取邏輯，開啟 `SS_ID_MONITOR_DEDUCTION` 指向的 Sheet 的「扣分記錄」分頁，過濾 `被扣人ID == userId AND 狀態 == 'active'`，並按 `扣分時間` 升冪排序（跨 Sheet 讀取時機與快取策略：即時讀取無快取）。完成條件：在副本 Sheet 加一筆 `T011_周子維_嘉家久` 的 active 扣分後，在 GAS Editor 執行 `getPersonalHistory('T011_周子維_嘉家久')` 並 `Logger.log` 結果，確認讀到該筆且時間排序正確。

- [x] 2.2 實作 Deduction Payload Shape 與後端 API 契約：把符合條件的扣分以 `box{N}_deductions` 陣列形式（每筆含 `score`、`reason`、`monitor_id`、`deduction_id` 四個 key）附加到每筆 history record，無扣分時為空陣列 `[]`（扣分資料在回傳結構的形狀）。完成條件：在 GAS Editor 執行 `getPersonalHistory` 並 `Logger.log` 一筆 record，確認 `box1_deductions` 至 `box14_deductions` 皆為陣列、無扣分時等於 `[]` 而非 `undefined` 或 `null`、既有欄位（`date`、`box{N}_score` 等）形狀與值未改變。

- [x] 2.3 實作 Withdrawn Deductions Do Not Affect Display or Calculation：跳過 `狀態 == 'withdrawn'` 的記錄，不寫入回傳結構（撤回扣分的顯示與計算行為）。完成條件：副本 Sheet 加一筆 active 加一筆 withdrawn（同使用者、同日、同 box），執行 `getPersonalHistory` 後 `box{N}_deductions` 只包含 active 那筆。

- [x] 2.4 實作 Graceful Failure on Sheet Read Errors（失敗模式）：處理 `SS_ID_MONITOR_DEDUCTION` 空字串、Sheet 不存在、分頁不存在、單列欄位缺失或型別錯誤等情境，全部 fallback 為空扣分。完成條件：把 `SS_ID_MONITOR_DEDUCTION` 暫時設為 `''` 後執行 `getPersonalHistory` 不拋例外、每筆 record 的 `box{N}_deductions` 全為 `[]`、`console.error` 輸出明確錯誤訊息；恢復 Sheet ID 後行為復原。

## 3. 前端渲染與計算（history.html）

- [x] 3.1 實作 Box-Card Embedded Deduction Display 與前端 render 契約：修改 `renderBoxes()`，為每張 box 卡片每一日列檢查 `record.box{N}_deductions`，長度大於 0 時於該日列正下方插入紅色背景警示列（建議背景 `#fef2f2`、文字 `#991b1b`、左側紅色 border-left），顯示「偵查官扣分 −{score}：{reason}（偵查官：{monitor_id}）」；多筆按陣列順序逐列渲染（history.html 扣分顯示位置）。完成條件：在副本 GAS push 後打開測試帳號 history.html，副本 Sheet 加一筆扣分並重新整理，紅色警示列正確出現在對應 box 卡片的對應日期下方且文字格式正確。

- [x] 3.2 實作 Net Score Calculation（對外可觀察行為）：修改 `calculateSummary()` 累計 `totalDeduction` 與 `weekDeductions[w]`，將頂部 `grandTotal` 顯示為 `total − totalDeduction`、各週 `weekScore-{w}` 顯示為 `weekScores[w] − weekDeductions[w]`。完成條件：副本 Sheet 加一筆 W3 5/12 box5 扣分 20 分，打開 history.html 頂部「全期累計總分」較先前減 20、W3 積分顯示較先前減 20、其他週積分不變。

## 4. 副本環境驗收（驗收條件 4 個情境，對應設計討論結論）

- [ ] 4.1 驗收情境 1 — 無扣分時行為與改動前等同：清空副本 Sheet 「扣分記錄」分頁所有資料列（保留標題列），打開測試帳號 history.html。完成條件：所有 box 卡片無紅色警示列；頂部「全期累計總分」等於所有 record `score` 加總；各週積分等於該週 `score` 加總，與改動前完全一致。

- [ ] 4.2 驗收情境 2 — active 扣分顯示與計算：副本 Sheet 加一筆 `被扣人ID = T011_周子維_嘉家久, 填分日期 = 2026-05-12, Box編號 = 5, 扣分數值 = 20, 扣分原因 = 心得疑似 AI 生成, 偵查官ID = T021_某偵查官_某大隊, 狀態 = active`。打開該帳號 history.html W3。完成條件：box5 卡片 5/12 列下方出現紅色警示列「偵查官扣分 −20：心得疑似 AI 生成（偵查官：T021_某偵查官_某大隊）」；頂部累計總分減少 20；W3 積分減少 20。

- [ ] 4.3 驗收情境 3 — withdrawn 撤回後恢復：把 4.2 加的扣分狀態改為 `withdrawn`，補齊「撤回者ID、撤回時間、撤回原因」三欄。重新整理 history.html。完成條件：box5 卡片 5/12 下方紅色警示列消失；頂部累計總分恢復為改動前值；W3 積分恢復為原值。

- [ ] 4.4 驗收情境 4 — 同 box 多筆 active 扣分：副本 Sheet 加兩筆 active 扣分給同一使用者、同日 2026-05-12、同 box 5、不同偵查官、扣分時間相隔 4 小時（10:00 扣 10 分、14:00 扣 20 分）。打開 history.html。完成條件：box5 卡片 5/12 列下方出現兩列紅色警示列、順序為 10 分在前、20 分在後（按扣分時間升冪）；頂部累計總分減 30；W3 積分減 30。
