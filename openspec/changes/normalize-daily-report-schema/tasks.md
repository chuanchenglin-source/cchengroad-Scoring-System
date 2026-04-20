## 1. 前置準備

- [x] 1.1 Supabase Dashboard 手動匯出測試環境現有資料（`members`/`teams`/`squads`/`daily_reports`）為 CSV 作為備份（實際上 daily_reports 為 0 筆、其他表也未變動，跳過備份）
- [x] 1.2 清點 `main.html` 現有 40 個 box 的標題、週次、輸入類型（score_only / checkbox / text / mixed）、勾選類 box 的選項清單，整理成對照表供 seed 腳本使用

## 2. Schema DDL（Level 3 BCNF 正規化）

- [x] 2.1 建立 `scripts/supabase-import/04-normalize-schema.sql` 起始骨架，含 BEGIN/COMMIT 區塊與「drop if exists」安全區（對應設計決定「Level 3 BCNF 正規化（而非 Level 2 / Level 4）」）
- [x] 2.2 在 `04-normalize-schema.sql` 內建立 `box_definitions` 表（Normalized Box Definition Schema），含 `activity_id` 預留欄位、`input_type` CHECK 約束、`(activity_id, box_no)` UNIQUE
- [x] 2.3 在 `04-normalize-schema.sql` 內建立 `box_options` 表（Normalized Box Option Schema），含 FK 至 `box_definitions` 與 `display_order` 排序欄位
- [x] 2.4 在 `04-normalize-schema.sql` 內建立 `daily_report_items` 表（Daily Report Item Storage），含審計欄位（`audit_status`/`audited_by`/`audited_at`/`audit_notes`）、`(report_id, box_definition_id)` UNIQUE 約束、`ON DELETE CASCADE`（對應設計決定「`(report_id, box_definition_id)` 與 `(item_id, option_id)` 加 UNIQUE」）
- [x] 2.5 在 `04-normalize-schema.sql` 內建立 `daily_report_item_options` junction 表（Daily Report Item Option Junction），含 composite primary key `(item_id, option_id)` 與 cascade delete（亦屬「`(report_id, box_definition_id)` 與 `(item_id, option_id)` 加 UNIQUE」設計的一部分）
- [x] 2.6 於 `daily_reports` 表新增 `activity_id BIGINT NOT NULL DEFAULT 1` 欄位（Activity Identifier Reservation — 對應設計決定「`activity_id` 預留欄位（不建 `activities` 表、不設 FK）」）
- [x] 2.7 針對新表建立查詢索引：`daily_report_items(report_id)`、`daily_report_items(box_definition_id)`、`daily_report_item_options(item_id)`、`box_definitions(activity_id, box_no)`
- [x] 2.8 確認本次不對 `(member_id, report_date)` 加 UNIQUE 約束，於 SQL 註解說明保留多次提交覆蓋行為（不對 `(member_id, report_date)` 加 UNIQUE 約束）
- [x] 2.9 於 `04-normalize-schema.sql` 結尾 `ALTER TABLE daily_reports DROP COLUMN IF EXISTS box_data` 移除舊 JSONB 欄位

## 3. RLS 政策

- [x] 3.1 為 `box_definitions` 啟用 RLS 並建立 anon/authenticated 可 SELECT 政策（Row-Level Security for New Tables）
- [x] 3.2 為 `box_options` 啟用 RLS 並建立 anon/authenticated 可 SELECT 政策
- [x] 3.3 為 `daily_report_items` 啟用 RLS 並建立 demo 階段寬鬆政策（anon 可 SELECT/INSERT），SQL 註解說明正式上線前收緊
- [x] 3.4 為 `daily_report_item_options` 啟用 RLS 並建立 demo 階段寬鬆政策（anon 可 SELECT/INSERT）

## 4. Seed Data 與 box_definitions 建檔

- [x] 4.1 建立 `scripts/supabase-import/04b-seed-box-definitions.sql`，依對照表 INSERT 40 筆 `box_definitions`（Seed Data for Box Definitions）
- [x] 4.2 於同檔案中為每個 checkbox 類型 box INSERT 對應的 `box_options` rows，含 `option_label` 與 `display_order`
- [x] 4.3 腳本結尾加驗證 `DO $$ ... RAISE NOTICE` 區塊，確認 `box_definitions` 共 40 筆且每個 checkbox 類型 box 至少有一筆 `box_options`

## 5. 原子寫入 RPC Function

- [x] 5.1 建立 `scripts/supabase-import/05-save-report-rpc.sql`，撰寫 `save_daily_report(p_member_id, p_activity_id, p_report_date, p_total_score, p_remarks, p_items JSONB)` PL/pgSQL 函式（以 RPC function `save_daily_report` 做原子寫入 — Atomic Daily Report Write via RPC）
- [x] 5.2 函式內以 `BEGIN ... EXCEPTION WHEN OTHERS THEN RAISE` 包住所有 INSERT，確保部分失敗時整筆交易 rollback
- [x] 5.3 函式迴圈展開 `p_items` JSONB 陣列，為每筆 item INSERT `daily_report_items`，再展開 `selected_option_ids` INSERT `daily_report_item_options`
- [x] 5.4 函式以 `SECURITY DEFINER` 宣告並 `GRANT EXECUTE TO anon, authenticated`
- [x] 5.5 函式回傳新建的 `daily_reports.id`

## 6. 前端 API 封裝層改寫（supabase-client.html）

- [x] 6.1 改寫 `supabase-client.html` 的 `scoringAPI.saveReport(payload)`：改呼叫 `rpc('save_daily_report', {...})`，payload 結構改為 `{ memberId, activityId, reportDate, totalScore, remarks, items: [{box_definition_id, score, content_text, selected_option_ids}, ...] }`（Submission via Client API）
- [x] 6.2 改寫 `supabase-client.html` 的 `scoringAPI.getPersonalHistory(memberId)`：以 `select(...)` 加 `daily_reports!inner(...)` + `daily_report_items(*, daily_report_item_options(option_id, box_options(option_label)))` nested select 讀取三層 JOIN（History Retrieval via Join）
- [x] 6.3 於 `getPersonalHistory` 內實作扁平化邏輯，將 JOIN 結果重組為 `{ date, score, remark, box1_score, box1_content, ..., box40_score, box40_content }` 結構，保持既有 `history.html` 渲染碼相容
- [x] 6.4 於 `getPersonalHistory` 內實作「同一天多筆只留最新（按 `submitted_at` DESC）」的去重邏輯
- [x] 6.5 新增 `scoringAPI.getBoxDefinitions(activityId = 1)` 方法供填表頁載入 box 元資料與選項清單

## 7. 填表頁前端改動（main.html）

- [x] 7.1 改寫 `main.html` 的送出邏輯，取消 `boxData = { box1: {...}, ... }` 的組裝，改為 `items = [{box_definition_id, score, content_text, selected_option_ids}, ...]` 陣列（`daily_report_items` 同時保留 `content_text` 與 options junction）
- [x] 7.2 確認每個 box 的 `box_definition_id` 來源：由 `getBoxDefinitions` 載入後對照 `data-box` 屬性取得
- [x] 7.3 純文字類 box（`input_type = 'text'` 或 `'mixed'`）填 `content_text`，勾選類 box（`input_type = 'checkbox'`）填 `selected_option_ids`，`score_only` 類只填 `score`
- [x] 7.4 呼叫 `scoringAPI.saveReport(...)` 後處理成功/失敗回饋（失敗時不造成部分寫入）

## 8. 歷史頁相容性驗證（history.html）

- [x] 8.1 檢查 `history.html` 渲染碼仍能用 `box1_score`/`box1_content` 等扁平化鍵讀取資料，確認無需改動
- [x] 8.2 若有任何欄位名不一致，於 `getPersonalHistory` 扁平化邏輯內修正，保持 `history.html` 不動（實務上：把 history.html 中已失效的 `r.box_data` 讀取段直接拔掉，因為 `getPersonalHistory` 已回傳扁平資料）

## 9. 測試驗收

- [x] 9.1 於 Supabase SQL Editor 依序執行 `04-normalize-schema.sql` → `04b-seed-box-definitions.sql` → `05-save-report-rpc.sql`，確認每個腳本無錯
- [x] 9.2 驗證 seed：`SELECT COUNT(*) FROM box_definitions WHERE activity_id = 1` 應回傳 40
- [x] 9.3 驗證 RPC：在 SQL Editor 手動呼叫 `save_daily_report(...)` 以「全部 box 都填」payload，確認回傳 id 且資料進入三張表
- [x] 9.4 驗證 RPC rollback：呼叫 `save_daily_report` 帶一個無效 `box_definition_id`，確認拋錯且三張表都沒有留下部分資料
- [x] 9.5 `npm run push:dev` 推到測試 Apps Script（Mac 端可存取的測試 Script ID 是 `1xR7aW...`，已更新 `.clasp.dev.json`；b484ac3 commit 換成的新 ID `1qridi...` 在 Mac clasp 登入帳號下沒權限）
- [ ] 9.6 開測試 Web App 手動跑一次完整流程：登入 → 填表（涵蓋 score_only/checkbox/text 三種類型）→ 送出 → 查歷史，確認畫面與資料都正確

## 10. 文件與記憶更新

- [x] 10.1 更新 `CLAUDE.md` 的「技術架構」章節，記錄新 schema 骨架與 RPC 存取模式
- [x] 10.2 更新 memory `project_supabase_migration.md`：將「Level 3 BCNF 已實作」、`activity_id` 預留、審計欄位預留寫入；技術債章節移除「JSONB」條目
