## Why

主程式設計師 0425 版本確定為心成親證班計分系統的**主路線**（Google Sheets + Apps Script），Johnson 維護的 Supabase 架構轉為**備案**，必須與主路線達成功能與資料對齊才能在主路線出狀況時無縫頂替。當前 Supabase 版本與主路線存在三大缺口：

1. **人員資料嚴重落後**：主路線 0425 副本已收齊 360+ 真名單與 18 大隊 / ~80 小隊階層；Supabase `members` 表仍是 18 人 demo 資料、且無 `teams` / `squads` 表
2. **登入機制與主辦方決議衝突**：2026-04-25 主辦方明確決議「不使用 PIN 碼登入」，但 Supabase 版本仍掛著 `authenticate_member` RPC 與 `members.pin_code` 欄位
3. **UI 體驗與主路線脫節**：主路線 main.html 的日期選擇器只顯示「當週 7 天」聚焦使用者；Supabase 版的 W2-W8 主題卡片邏輯雖已就位，但與主路線的呈現方式未對齊

不先處理這三個缺口，後續「保底分 + 小隊加分」（下一個 change）的計分結果即使正確，也會因為 demo 時人員資料對不上、登入流程與主路線不同、UI 看起來不同步而失去備案價值。

## What Changes

- **新增 `teams` 表**：18 大隊主資料，欄位包含 `team_code` (T01-T18)、`team_name`、`leader_name`、`form_label`（對齊 0425「大隊對照表」）
- **新增 `squads` 表**：~80 小隊主資料，欄位包含 `squad_code` (T010-T184 4 碼)、`team_id`、`squad_leader_name`，FK 到 `teams`
- **`members` 表結構調整**：新增 `squad_id BIGINT REFERENCES squads`、`leader_name TEXT`（直接落地主路線「大隊長」「小隊長」欄位）；`id` 從 BIGSERIAL 改用主路線格式 `T011_周子維_嘉家久`（squad_code + name + team_name），保留 `legacy_id BIGSERIAL` 給 FK
- **匯入 360+ 真名單**：從 0425 副本「人員總表」分頁透過一次性 SQL migration 匯入（保留 `02-import-members.sql` 為歷史，新建 `09-import-real-roster.sql`）
- **BREAKING：移除 PIN 登入機制**：刪除 `authenticate_member` RPC、`members.pin_code` 欄位；前端 `Index.html` / `supabase-client.html` 改用「姓名 / 小隊編號 datalist 搜尋 + URL params 帶 ID」的識別方式
- **UI 對齊**：`main.html` 日期選擇器改為「當週 7 天聚焦」（與主路線 main.html `initDatePicker` 一致），歷史頁採用主路線 `history.html` 的「週次 1-7 切換 + 卡片每日表格」結構
- **不動 box_definitions 與計分邏輯**：保底分、小隊加分屬於下一個 change `add-baseline-and-team-bonus` 的範圍，本 change 純粹處理人員資料 + 登入 + UI 對齊

## Non-Goals

- **不做計分上限對齊**（保底分 70/140/週、其他週上限） — 屬於 `add-baseline-and-team-bonus` change
- **不做小隊加分計算**（全員 +500 / 半數 +350） — 屬於 `add-baseline-and-team-bonus` change
- **不做 W6 影片比賽前三名加分** — 屬於 `add-baseline-and-team-bonus` change
- **不修補主程式設計師既有 BUG**（W6 cap 30 vs UI 50、W3 電影行動方案 colName mismatch） — 我們對齊規則本意而不是 bug
- **不做 Dashboard / 審計官 / 傳愛名單回報** — 屬於後續 P2 範圍，將另開 change
- **不對齊主程式設計師的批次重算模型**（`rebuildSummaryReport`） — Supabase 維持「即時 RPC 寫入時計分」模型，計分時機差異是架構選擇，不是 gap
- **不引入 Supabase Auth JWT** — 與「不用 PIN」決議一致，保持 anon 識別模型；JWT 遷移屬於另一範圍
- **不變動 `daily_reports` / `daily_report_items` schema** — 既有 BCNF 結構不動

## Capabilities

### New Capabilities

- `member-roster-management`: 18 大隊 / ~80 小隊 / 360+ 隊員的階層資料管理與查詢介面（`teams`、`squads` 主表、與 `members` 的 FK 關係、查名單 RPC）
- `password-less-identification`: 不靠 PIN 的使用者識別機制 — 前端用姓名 / 小隊編號 datalist 搜尋鎖定 member，再以 URL params 帶 `id` / `name` / `team` / `teamCode` 跨頁識別

### Modified Capabilities

- `daily-report-scoring`: 移除 PIN 相關欄位與 RPC（`members.pin_code`、`authenticate_member`）；`members.id` 從 BIGINT 改用文字格式 `T011_周子維_嘉家久`；新增 `members.squad_id` 對 `squads` 表 FK

## Impact

- **Affected specs**:
  - 新建 `openspec/specs/member-roster-management/spec.md`
  - 新建 `openspec/specs/password-less-identification/spec.md`
  - 修改 `openspec/specs/daily-report-scoring/spec.md`（PIN 拆除、members.id 格式、squad_id FK 三段 delta）
- **Affected code**:
  - `scripts/supabase-import/02-import-members.sql`（標記為歷史，不執行）
  - `scripts/supabase-import/09-create-teams-squads.sql`（新檔：建表 + RLS）
  - `scripts/supabase-import/10-import-real-roster.sql`（新檔：360+ 人員 SQL）
  - `scripts/supabase-import/11-remove-pin-auth.sql`（新檔：DROP `authenticate_member` + ALTER TABLE drop `pin_code`）
  - `scripts/supabase-import/04-normalize-schema.sql`（修改：`members.id` 型別由 BIGSERIAL 改 TEXT；加 `squad_id` FK；不動 `daily_reports.member_id` 型別需同步處理）
  - `Index.html`（移除 PIN 輸入欄、改主路線風格 datalist）
  - `main.html`（日期選擇器收斂為當週 7 天）
  - `history.html`（套用主路線 W1-W7 切換 UI 結構）
  - `supabase-client.html`（移除 `authenticate` 函式，新增 `searchMembers` / 名單載入函式）
- **Affected Supabase DB**:
  - 新表：`teams`、`squads`
  - 變更表：`members`（id 型別、新欄位、刪欄位）、`daily_reports`（member_id 型別跟著變）、`daily_report_items`（同上連動）
  - 刪除 RPC：`authenticate_member`
  - 新增 RPC（非必要，看 spec 決定）：`get_squad_scope` 與 `get_member_directory`
- **Affected workflow**:
  - 名單變動：直接 `UPDATE`/`INSERT` `members`、`squads`、`teams`，不再依賴一次性匯入腳本
  - 登入流程：使用者開啟 web app → datalist 搜尋姓名 → 跳轉 `?id=...&name=...`，無密碼步驟
- **Affected docs**:
  - `CLAUDE.md` 技術債章節：第 3 點「PIN 明文存」改為「PIN 已拆除」
  - `CLAUDE.md` 技術架構章節：補上 `teams` / `squads` 表
