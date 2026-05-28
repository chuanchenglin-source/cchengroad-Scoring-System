## Why

偵查官（=審計官）目前能查看各小隊填分狀況，但無法在系統內記錄扣分。違規案例現行流程是 LINE 群組通報主辦方手動處理，隨著活動進入中後段、扣分案例可能增加，這條路徑會變成主辦方的工作瓶頸。被扣分者也沒有正式管道查看「自己被扣什麼、為什麼」，導致申訴流程模糊。

本 change 是「偵查官扣分機制」雙系統設計的計分系統側（完整設計討論結論見 docs 設計討論文件），負責 history.html 讀取偵查官副本 Sheet 的「扣分記錄」分頁，並把扣分顯示給被扣分的隊員看。對應的偵查官端寫入流程在另一個 repo 處理，本 change 只涵蓋計分系統端的讀取與顯示。

## What Changes

- 在 `webApp.js` 的 `getPersonalHistory()` 加入跨 Sheet 讀取偵查官副本 Sheet 的「扣分記錄」分頁，過濾 `被扣人ID = userId` 且 `狀態 = active` 的記錄
- 把每筆扣分以 `(填分日期, Box編號)` 對應到該日的填分記錄，附加 `box{N}_deductions` 陣列到回傳結構（每筆含 `score`、`reason`、`monitor_id`）
- 修改 `history.html` 的 `renderBoxes()`：在對應 box 卡片的該日列下方，渲染紅色警示行「偵查官扣分 -X：原因（偵查官：XX）」
- 修改 `history.html` 的 `calculateSummary()`：總分計算扣除 active 扣分；週積分同步扣除
- `withdrawn` 狀態的扣分不顯示也不影響計算
- `config.js` 新增偵查官扣分 Sheet ID 常數
- 在副本測試環境（5 個副本資源 ID 已就緒）驗證後，透過 PR 給主工程師合併到正式

## Non-Goals

- **偵查官端的扣分輸入介面與撤回介面**：在另一個 repo `cchengroad-Monitor-System` 處理，不在本 change 範圍
- **history.html「按週切資料」重構**：截圖點 1、2 提到的歷史頁面抓資料問題，是獨立需求，需另開討論
- **被扣分者主動通知機制**：第一版靠使用者自己打開 history.html 查看；未來可在 Index.html 加未讀 badge，不在本 change 範圍
- **規則對齊**：CLAUDE.md 寫「扣分屬特殊案例 → 群組回報主辦方」，與本設計「立刻生效」不完全一致，需另行跟主辦方對齊。技術實作不阻塞規則對齊

## Capabilities

### New Capabilities

- `monitor-deduction-display`: 在計分系統的個人歷史頁面（history.html），讀取偵查官副本 Sheet 的扣分記錄，把每筆扣分顯示在對應 box 卡片內，並在總分與週積分計算時扣除 active 狀態的扣分

### Modified Capabilities

(none)

## Impact

- Affected specs: `monitor-deduction-display` (new)
- Affected code:
  - Modified: `webApp.js`、`history.html`、`config.js`
  - New: 無
  - Removed: 無
