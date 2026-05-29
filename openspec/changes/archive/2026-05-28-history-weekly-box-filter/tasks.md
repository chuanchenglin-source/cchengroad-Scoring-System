## Spec coverage

- 第 1-3 組任務實作 spec requirement "Per-week box visibility filtering on personal history page"（常數定義、`getVisibleBoxNumbers` 改寫、`renderBoxes` 使用當前週）
- 第 4-5 組任務實作 spec requirement "8-week navigation on personal history page"（週選單擴展為 W1~W8、`calculateSummary` 累計範圍擴為 8）
- 第 6 組任務透過瀏覽器逐週點選驗證上述兩個 requirement 的場景（W1/W3/W5/W6/W7/W8 卡片數量、週選單 8 按鈕、W8 累計分數）
- 第 7 組任務將實作結果提交版控

## 1. 加入 box 顯示常數

- [x] 1.1 在副本 history.html 的 `<script>` 區段內、`campaignConfig` 定義之後，新增兩個模組層級常數：`FIXED_BOXES = [1, 2, 21, 22, 23, 24, 25, 26, 27, 41]`（每週都顯示的 10 個固定 box），以及 `WEEK_TO_THEME_BOXES = {1:[], 2:[3], 3:[4,5,6,7], 4:[8,9,10,11], 5:[12,13,14], 6:[15,16], 7:[17,18,19], 8:[20]}`（每週對應的主題 box 對照表）。對應 Requirement: Per-week box visibility filtering on personal history page

## 2. 重寫 box 篩選邏輯

- [x] 2.1 改寫 `getVisibleBoxNumbers` 函數使其接受 `weekNum` 參數（型別：整數 1~8），回傳一個 box 編號陣列，內容是 `FIXED_BOXES` 與 `WEEK_TO_THEME_BOXES[weekNum]` 的聯集。`weekNum` 不在 1~8 範圍時 fallback 回傳 `FIXED_BOXES`。
- [x] 2.2 從 `campaignConfig` 物件移除 `visibleBoxes` 屬性與其原本寫死的 18 個 box 陣列，確認沒有其他位置仍引用 `campaignConfig.visibleBoxes`。

## 3. renderBoxes 改用當前週

- [x] 3.1 修改 `renderBoxes` 函數內呼叫 `getVisibleBoxNumbers()` 的兩處（render 主流程與計算流程），都改傳入 `currentWeek` 作為參數；確認 forEach 迴圈 iterate 的是該週聯集 box 清單。

## 4. 週選單擴展為 8 週

- [x] 4.1 將 `initWeekPicker` 函數內產生週按鈕的迴圈條件從只跑到 7 改為跑到 8，使 DOM 內出現 id 為 `week-1` 到 `week-8` 共 8 個 `.week-btn` 元素，每個按鈕的內容含「第 N 週」標題、起迄日期區間文字（從 `campaignConfig.startDate` 推算）以及 `weekScore-N` span 元素。對應 Requirement: 8-week navigation on personal history page

## 5. calculateSummary 擴展為 8 週

- [x] 5.1 在 `calculateSummary` 函數內：（a）將 `weekScores` 物件初始化從 `{1:0,...,7:0}` 擴為 `{1:0,...,8:0}`；（b）將累計分數的判斷條件 `weekNum >= 1 && weekNum <= 7` 改為 `weekNum >= 1 && weekNum <= 8`；（c）將更新 `weekScore-N` DOM 內容的 for 迴圈條件從跑到 7 改為跑到 8。三處都改完，確保 W8 的記錄會累加到 `weekScores[8]` 並寫入 `#weekScore-8` 元素。

## 6. 部署與驗證

- [x] 6.1 在 fork 目錄（`C:\Coding Project\Corporate Website\cchengroad-Scoring-System-fork-0527`）執行 `npx clasp push`（須先載入 fnm 之 node 至 PATH），確認 stdout 顯示「Pushed 11 files.」且 11 個檔案路徑被列出，無錯誤。
- [x] 6.2 在瀏覽器開啟副本 Web App @HEAD 部署 URL（部署 ID `AKfycbyaHvmGwMVY4SQ4bwXzBXh0PRyQT_np3KIDK1yVWQAd`），用副本人員總表內任一人員 ID（例：`T011_周子維_嘉家久`）通過 Index 登入，並點「查看歷史紀錄與分數」進入歷史頁面。
- [x] 6.3 在歷史頁面切到第 1 週，肉眼計數 box 卡片必為 10 張，且依序為：主修打拳、選修定課、聯誼會會籍、高階課程、傳愛完款、傳愛訂金、進階課程、全部高階完款、上課出席、團隊動能。確認頁面**沒有**「火寶藏」「土寶藏」「金寶藏」「水寶藏」「互助合作」任一主題親證卡片。
- [x] 6.4 切換到第 3 週，肉眼計數 box 卡片必為 14 張，新增的 4 張依序為：電影行動方案、火寶藏-親證分享文、火寶藏-心得回饋反思、火寶藏-天使通話。確認頁面沒有 W2、W4、W5、W6、W7、W8 任一週的主題親證卡片。
- [x] 6.5 依序切到 W5、W6、W7、W8 四週，box 卡片總數依序為 13、12、13、11；對應主題 box 出現：W5 顯示「金寶藏」三張、W6 顯示「水寶藏」兩張、W7 顯示「互助合作-天使通話/三道菜/破冰加碼」三張、W8 顯示「互助合作-天使通話心得」一張。
- [x] 6.6 確認週選單列出 8 個按鈕、滾動可看到第 8 週按鈕，每個按鈕顯示對應日期區間與累計分數值（W8 按鈕也可點擊並切換）。

## 7. 提交版本控制

- [x] 7.1 在 fork 目錄執行 `git add history.html` 與 `git commit`，commit 訊息：`feat(history): 按週切換顯示對應的 box（W1-W8）`。確認 `git status` 顯示 working tree clean。
- [x] 7.2 如已建立 GitHub fork repo `cchengroad-Scoring-System-fork-0527` 且 remote `origin` 已設定，執行 `git push origin main` 將 commit 推到遠端；若 remote 尚未建立，本任務改記為「待 GitHub repo 建立後補推」並結束本 change。
