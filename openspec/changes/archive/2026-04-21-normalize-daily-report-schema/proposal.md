## Why

目前 `daily_reports.box_data` 以 JSONB 儲存 40 格回報資料（`{ box1: {score, content}, ..., box40: {score, content} }`），其中 `content` 甚至是逗號串（`"a,b,c"`）。此設計是 Google Sheets 時期的妥協產物 — 因為 Sheets 一格只能存單一字串，只好把結構化資料壓成 JSON。

系統已遷移至 Supabase (PostgreSQL)，JSONB 的理由消失，卻帶來三個具體痛點：

1. **違反資料庫正規化原則**：單格非原子（違反 1NF），欄位查詢、索引、約束都無法正常運作
2. **阻擋審計官逐格審核功能**：CLAUDE.md 既有需求是對單格截圖/心得打勾審核，JSONB 內無法乾淨地加 `audit_status` / `audited_by` / `audited_at` 欄位
3. **錯過最佳重構時機**：demo 階段尚未上線、無歷史資料，現在改 schema 成本最低；拖到上線後重構成本指數成長

主工程師明確提出「資料庫正規化」訴求，專案負責人要求「最正規 + 可擴大 + 活動結束後重複使用」。

## What Changes

- **BREAKING** 移除 `daily_reports.box_data` JSONB 欄位
- 新增 `box_definitions` 表：記錄每個 box 的元資料（box_no, week_no, title, input_type, max_score），取代寫死在 HTML 的 box 定義
- 新增 `box_options` 表：勾選類 box 的選項（選項標籤、分數權重）
- 新增 `daily_report_items` 表：取代 JSONB，每格一筆紀錄，含 `score`、`content_text`，並預留審計欄位（`audit_status`, `audited_by`, `audited_at`, `audit_notes`）
- 新增 `daily_report_item_options` junction 表：記錄使用者勾選的選項
- 所有主表增加 `activity_id BIGINT DEFAULT 1`（不設 FK）預留多活動升級路徑
- 新增 `save_daily_report` RPC function：以 atomic transaction 一次寫入 `daily_reports` + 1..N 筆 `daily_report_items`（+選項）
- 改寫 `supabase-client.html` 的 `saveReport` / `getPersonalHistory`，封裝新的多表存取邏輯
- 改寫 `history.html` 的扁平化邏輯，從 JOIN 後資料重組成既有前端格式
- RLS policy 擴充涵蓋新表，維持 demo 階段寬鬆設定
- 新增資料遷移腳本：讀既有測試環境 `daily_reports.box_data` JSON → 展開寫入新表（若測試資料已清，可跳過）

## Capabilities

### New Capabilities

- `daily-report-scoring`: 每日回報的完整資料模型 — box 定義、選項、回報項目、選項關聯、審計狀態欄位，以及 atomic 寫入與歷史查詢介面

### Modified Capabilities

(none)

## Impact

- **Affected specs**: 新建 `openspec/specs/daily-report-scoring/spec.md`
- **Affected code**:
  - `scripts/supabase-import/04-normalize-schema.sql`（新檔，DDL + 索引 + RLS）
  - `scripts/supabase-import/05-save-report-rpc.sql`（新檔，atomic 寫入 function）
  - `scripts/supabase-import/06-migrate-box-data.sql`（新檔，資料遷移；測試資料已清可省略執行）
  - `supabase-client.html`（改寫 `saveReport` 改呼叫 RPC；改寫 `getPersonalHistory` 加入 JOIN/重組邏輯）
  - `history.html`（扁平化邏輯從讀 `box_data` JSONB 改為讀重組後結構）
  - `main.html`（前端收集 box 資料的 payload 結構調整，從 `{ box1: {...}, box2: {...} }` 改為 `{ items: [{box_no, score, content_text, selected_option_ids}, ...] }`）
  - `CLAUDE.md`（更新「技術架構」章節，記錄新 schema 骨架）
- **Affected Supabase DB**:
  - 新表：`box_definitions`、`box_options`、`daily_report_items`、`daily_report_item_options`
  - 移除欄位：`daily_reports.box_data`
  - 新欄位：`activity_id` on 所有主表
  - 新 function：`save_daily_report(...)`
  - 新 RLS policies 覆蓋上述新表
- **Affected workflow**: 寫入動作從 `INSERT INTO daily_reports` 單筆改為 RPC 呼叫；讀取動作從單表變為 JOIN 多表；前端 HTML 不變（輸入介面不變）但背後 payload 結構變化
