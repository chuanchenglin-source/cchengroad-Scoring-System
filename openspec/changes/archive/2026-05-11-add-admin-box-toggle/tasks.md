## 1. Server Functions（webApp.gs）

- [x] 1.1 在 webApp.gs 新增 `getVisibleBoxes()` function：讀取 Script Property `VISIBLE_BOXES` 並回傳 JSON 陣列（整數），屬性不存在時回傳空陣列 `[]`。滿足 requirement「Server functions for box visibility」的讀取端。驗證：在 GAS 編輯器 Run `getVisibleBoxes()` 確認回傳 `[]`（初始狀態）
- [x] 1.2 在 webApp.gs 新增 `saveVisibleBoxes(list)` function：接收整數陣列、驗證每個元素為 1-40 之間的整數、寫入 Script Property `VISIBLE_BOXES`、回傳 `{ ok: true, savedAt: <ISO> }`。超出範圍的數字須 throw error。滿足 requirement「Server functions for box visibility」的寫入端。驗證：呼叫 `saveVisibleBoxes([1,2,3])` 後，再呼叫 `getVisibleBoxes()` 確認回傳 `[1,2,3]`；呼叫 `saveVisibleBoxes([99])` 確認 throw error

## 2. Admin 頁面 UI（admin.html）

- [x] 2.1 在 admin.html 既有「當週起始日」區塊下方新增「Box 顯示設定」區塊，列出全部 40 個 box 的 checkbox（編號 + 名稱），滿足 requirement「Admin can view all box toggle states」。每個 checkbox 的 label 須包含 box 編號和對應的中文名稱（例如「1. 主修打拳」「3. W2天使通話心得」）。驗證：開啟 admin.html 確認 40 個 checkbox 全數顯示且名稱正確
- [x] 2.2 頁面載入時呼叫 `getVisibleBoxes()` 取得已儲存的可見 box 清單，並將對應的 checkbox 設為 checked 狀態。首次載入（無 Script Property）時全部 unchecked。滿足 requirement「Admin can view all box toggle states」的 Scenario「First load with no saved config」。驗證：手動設定 `VISIBLE_BOXES` 為 `[1,2,3]` 後開啟 admin.html，確認只有 box 1、2、3 被勾選
- [x] 2.3 新增「全選」和「全不選」按鈕，點擊後立即切換所有 40 個 checkbox 的 checked 狀態，但不觸發儲存。滿足 requirement「Admin can use select-all and deselect-all」。驗證：點「全選」確認 40 個全勾；點「全不選」確認 40 個全清
- [x] 2.4 新增「儲存設定」按鈕（可與既有的起始日儲存鈕分開），點擊後收集所有 checked 的 box 編號，呼叫 `saveVisibleBoxes(list)`，成功顯示 success toast、失敗顯示 error toast。滿足 requirement「Admin can save box visibility config」和「Admin can toggle box visibility」。驗證：勾選 box 1、2、21 後按儲存，確認 toast 顯示成功，再重新整理頁面確認 box 1、2、21 仍被勾選

## 3. Main 頁面動態顯示（main.html）

- [x] 3.1 將 main.html 中被 HTML 註解包住的 box 4-20、27-40 全部取消註解，讓全部 40 個 `<section data-box="N">` 都存在於 DOM 中。所有 box 預設以 `style="display:none"` 隱藏。滿足 requirement「Main page renders boxes based on visibility config」的前提（DOM 中須有全部 box）。驗證：開啟 main.html 原始碼確認 40 個 `<section data-box>` 都沒有 HTML 註解包裹，且頁面載入時全部不可見
- [x] 3.2 在 main.html 頁面載入流程中呼叫 `getVisibleBoxes()`，取得可見 box 清單後，將清單內的 box 設為 `display:''`（顯示），不在清單內的維持 `display:none`。無 Script Property 時全部隱藏。滿足 requirement「Main page renders boxes based on visibility config」和 Scenario「No config exists」。驗證：設定 `VISIBLE_BOXES` 為 `[1,2,3,21]` 後開啟 main.html，確認只有 box 1、2、3、21 可見；清除 Script Property 後重新整理，確認全部隱藏
- [x] 3.3 確保隱藏的 box 不會提交資料：在 main.html 的表單送出流程中（`saveForm` 呼叫前），排除 `display:none` box 的 input 值，只收集可見 box 的勾選資料。滿足 requirement「Main page renders boxes based on visibility config」的 Scenario「Hidden boxes do not submit data」。驗證：隱藏 box 3 但手動在 DOM 勾選 box 3 的 checkbox，送出表單後確認 box 3 資料未被包含在 payload 中
