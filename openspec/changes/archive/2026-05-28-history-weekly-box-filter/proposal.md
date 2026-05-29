## Why

副本 0527 的個人歷史頁面（history.html）在週次切換時固定顯示同一組 box 卡片，導致兩個現況問題：

1. **視覺雜訊**：W1 切過去也會看到 W2-W4 的「主題親證」box（如「火寶藏-親證分享文」「火寶藏-天使通話」），但 W1 沒有這些任務，卡片內容全部顯示「—」。
2. **W5-W8 主題從未顯示**：寫死的 visibleBoxes 清單僅 18 個 box，完全未納入 W5-W8 的主題親證 box（Box12-20）與 Box8（W4 天使通話心得）。使用者切到 W5/W6/W7/W8 時，根本看不到該週主題。
3. **週切換器只到 W7**：活動共 8 週（W8 不計分但仍是一週），但選單僅顯示 W1-W7。

主工程師（joanne19940224）2026-05-27 對齊「指定成分週別，去開啟不同 box」，需把顯示邏輯改成「每週固定 ∪ 該週主題」的動態組合。

## What Changes

- 引入「每週都顯示的固定 box 清單」（10 個：Box1-2 主修選修、Box21-27 加分題、Box41 團隊動能）。
- 引入「該週主題 box 對應表」：W1=`[]`、W2=`[3]`、W3=`[4,5,6,7]`、W4=`[8,9,10,11]`、W5=`[12,13,14]`、W6=`[15,16]`、W7=`[17,18,19]`、W8=`[20]`。
- `renderBoxes` 改為以「當前週」算出固定清單與該週主題清單的聯集後顯示，不再用寫死的 18 個 visibleBoxes。
- 週切換器迴圈從 7 擴為 8（W8 不計分但仍納入歷史檢視）。
- `calculateSummary` 的 weekScores 累計範圍從 1-7 擴為 1-8。
- 移除舊的 `visibleBoxes: [1,2,3,4,5,6,7,9,10,11,21,...,27,41]` 寫死陣列。

## Non-Goals

- 不改動 main.html 的填單邏輯（VISIBLE_BOXES 機制保留）。
- 不改動 schedule.js 的計分邏輯（小隊加分、上限規則皆不動）。
- 不顯示 Box28-40（加分題3-15）— main.html 上是空殼、永遠沒資料。
- 不對 W1 顯示「本週無主題」提示框 — 直接不渲染主題卡片即可。
- 不改動正式 GAS 與正式 Sheet — 本 change 僅針對副本 0527 環境。
- 不調整任何後端 GAS 函數（`getPersonalHistory` / `getVisibleBoxes` 等不動）。

## Capabilities

### New Capabilities

- `personal-history-view`: 個人歷史頁面顯示登入者過去 8 週的每日 box 分數與內容，按週切換時僅顯示該週適用的 box 卡片（每週固定 box 與該週主題 box 的聯集）。

### Modified Capabilities

(none)

## Impact

- Affected specs: personal-history-view (new)
- Affected code:
  - Modified: 副本 fork 目錄下的 history.html（位於 cchengroad-Scoring-System-fork-0527 目錄；不在主 repo 樹內、不影響本 openspec 所在的計分系統正式版）
- 不影響 main.html / webApp.js / schedule.js / config.js
- 不影響正式環境 GAS（Script ID 19ZCMtO64t7d...）與正式 Sheet（1CFTaHN...）
- 部署：本機 fork 目錄 → clasp push 至副本 GAS（Script ID 1iBj0Wl3UKPJrL...）→ 副本 Web App @HEAD 部署即時生效
