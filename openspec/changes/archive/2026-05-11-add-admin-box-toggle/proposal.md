## Why

目前計分系統（Scoring-Fork）main.html 的 40 個 box（計分項目），顯示與隱藏是靠**直接在 HTML 裡加 `<!-- -->` 註解**來控制。每次換週或調整項目時，主工程師必須進入程式碼手動修改 HTML 註解——容易出錯、不便於非技術人員操作。

需要在 admin.html 管理頁新增 box 顯示開關，讓管理員透過勾選 checkbox 即可控制 main.html 顯示哪些 box，無需碰程式碼。

## What Changes

- **admin.html 新增「Box 顯示設定」區塊**：在既有「當週起始日」功能下方，新增全部 40 個 box 的 checkbox 清單，管理員勾選後儲存
- **webApp.gs 新增 server function**：`getVisibleBoxes()` 讀取、`saveVisibleBoxes(list)` 儲存可見 box 清單，資料存在 Script Property `VISIBLE_BOXES`（JSON 陣列格式，例如 `[1,2,3,21,22]`）
- **main.html 改為動態顯示 box**：全部 40 個 box 取消 HTML 註解（讓 DOM 都存在），頁面載入時呼叫 `getVisibleBoxes()` 取得清單，不在清單內的 box 以 CSS `display:none` 隱藏

## Non-Goals

- **不做「按週自動切換」**：box 顯示不與當週起始日連動，兩個功能各自獨立，管理員手動控制
- **不做權限分層**：所有能進入 admin 頁面（輸入 666666）的人都能操作 box 開關
- **不改變計分邏輯**：隱藏的 box 只是 UI 不顯示，不影響後端計分規則或已提交的資料
- **不碰正式版 Scoring-System**：所有改動僅在 Scoring-Fork 副本上進行

## Capabilities

### New Capabilities

- `admin-box-visibility`: 管理員透過 admin 頁面勾選 checkbox 控制 main.html 顯示哪些 box（計分項目），設定存在 GAS Script Property

### Modified Capabilities

（無）

## Impact

- 受影響的程式碼（皆位於 `cchengroad-Scoring-Fork` 副本 repo）：
  - 修改：admin.html（新增 box 顯示設定 UI）
  - 修改：webApp.gs（新增 getVisibleBoxes / saveVisibleBoxes server function）
  - 修改：main.html（取消 40 個 box 的 HTML 註解，改為 JS 動態控制顯示）
- 儲存位置：GAS Script Property `VISIBLE_BOXES`
- 不影響：config.gs、helper.gs、schedule.gs、其他 HTML 頁面
