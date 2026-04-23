## Context

心成親證班計分系統近期從 Google Sheets 後端遷移至 Supabase (PostgreSQL)。遷移過程中，原本「每列一筆回報、40 格壓成一個 JSON 字串」的 Sheets-era 結構直接搬進 Postgres，落地為 `daily_reports.box_data` JSONB 欄位。

**現況 schema（精簡）**：
```
daily_reports (id, member_id, report_date, total_score, box_data JSONB, remarks)
-- box_data 結構：{ box1: {score, content}, box2: {score, content}, ..., box40: {...} }
-- content 可能是逗號串 "a,b,c"（當 box 是多選勾選類型時）
```

**約束與 stakeholders**：
- **主工程師（宗瑋）**：擁有架構決策權。明確提出資料庫正規化訴求，指出 JSONB 設計是遷就 Sheets 的妥協產物
- **專案協作者（Johnson）**：中途加入，透過 PR 協作；明確要求「最正規 + 可擴大 + 活動結束後重複使用」
- **時程**：活動 2026-05-03 開訓，系統必須在此之前完成。現在（2026-04-20）距開訓約兩週
- **資料狀態**：測試環境資料可清空，正式環境尚未上線 — 此為零遷移成本視窗
- **現有需求**：CLAUDE.md 記錄審計官功能會對單格截圖/心得打勾審核

## Goals / Non-Goals

**Goals:**
- 以 BCNF 等級的正規化 schema 取代 JSONB，所有資料欄位原子化
- 建立 box 定義表（`box_definitions`）+ 選項表（`box_options`），讓規則變成資料而非程式碼
- 為審計官功能預留欄位（`audit_status` / `audited_by` / `audited_at` / `audit_notes`）於 item 層級
- 於所有主表預留 `activity_id BIGINT DEFAULT 1`，提供未來多活動升級路徑而不立即實作
- 寫入操作保持 atomicity（一次回報要嘛全部成功要嘛全部失敗）
- 既有前端使用者體驗（main.html 填表 UI、history.html 歷史查詢畫面）保持不變

**Non-Goals:**
- **不實作多活動功能**：只預留 `activity_id` 欄位，不建 `activities` 表、不設 FK、不做 activity 切換 UI
- **不重新設計計分規則**：規則仍參考現有 PPT + Excel，本次只改資料儲存形狀
- **不實作審計官審核流程**：只預留欄位，審核介面與工作流程留給後續 change
- **不做權限收緊**：RLS 維持 demo 階段寬鬆設定（anon INSERT/SELECT daily_reports），正式上線前另開 change 處理
- **不遷移正式環境資料**：正式環境 Script Properties 未指向新 Supabase，本次僅影響測試環境
- **不改 PIN 登入機制**：PIN 仍明文存 `members.pin_code`，hash/Supabase Auth 是另一個獨立議題

## Decisions

### Level 3 BCNF 正規化（而非 Level 2 / Level 4）

選擇在 `box_definitions` 之上再加 `box_options` + `daily_report_item_options` junction 表，讓勾選類 box 的每個選項成為獨立 row。

**理由**：
- Johnson 明確要求「最正規」。技術上最正規的停止點是 BCNF（4NF/5NF 對此領域無實質收益）
- 選項獨立建表後，可對選項加屬性（譬如 `score_value`、`is_active`），為規則調整預留彈性
- 保留 `daily_report_items.content_text` 供純文字類 box（如心得、備註）使用，避免強行把自由文字也塞進選項表

**替代方案**：
- **Level 2（只拆 items，content 用 TEXT[]）**：拒絕。TEXT[] 雖是 Postgres 原生，但無法對選項加屬性、無法 JOIN、無法為特定選項建索引
- **Level 4（加 activities 表 + 所有查詢帶 activity_id）**：拒絕。現在沒有多活動需求，強行加入會讓每個 query 都多一層條件，且沒明確收益。改為預留欄位（見下一個決定）

### `activity_id` 預留欄位（不建 `activities` 表、不設 FK）

所有主表（`box_definitions`、`daily_reports`、`daily_report_items` 等）新增 `activity_id BIGINT NOT NULL DEFAULT 1`，但不建 `activities` 表、不設 FK。

**理由**：
- 未來升 Level 4 成本：`CREATE TABLE activities` + 補 FK 約 5 分鐘
- 當下多寫一欄成本：每張表一個整數欄位，幾乎無儲存成本
- 不設 FK 避免誤以為 activities 表已存在

**替代方案**：
- **完全不預留，未來 ALTER ADD**：拒絕。有歷史資料後 backfill + ALTER 約 30 分鐘，且破壞 idempotent 的重建腳本
- **預留並立即建 activities 表只放一筆**：過度工程。

### 以 RPC function `save_daily_report` 做原子寫入

寫入一筆 daily_report + N 筆 items + M 筆 item_options 透過單一 PL/pgSQL function 完成，前端呼叫 `window.sb.rpc('save_daily_report', payload)`。

**理由**：
- Supabase JS Client 無跨表 transaction API；單一 RPC 是最直接的 atomic 保證
- 前端 payload 結構保持簡潔（一個巢狀物件），不用前端自己管 transaction 狀態
- 若中途失敗自動 rollback，不會留下孤兒 items 或 items 沒有 options 的半殘狀態

**替代方案**：
- **前端逐次 INSERT，失敗時補償 DELETE**：拒絕。補償邏輯複雜、錯誤處理多、非 atomic 窗口期存在
- **Supabase PostgREST 的 nested insert**：拒絕。PostgREST 無法跨 `report_id` → `item_id` 的二層 relation 做 atomic 巢狀插入

### `daily_report_items` 同時保留 `content_text` 與 options junction

某些 box 是純文字（心得、備註），某些是勾選（定課項目），少數可能混用。Schema 同時保留兩種儲存方式：

- 純文字類 box：`daily_report_items.content_text` 填文字，`daily_report_item_options` 無資料
- 勾選類 box：`content_text` NULL，`daily_report_item_options` 一筆對應一個選項
- 混用類 box：兩者都有資料

**理由**：
- 用 `box_definitions.input_type` 明確標記每個 box 的類型，避免歧義
- 比「所有文字都塞進 options 表」更符合直覺；不為了正規化潔癖犧牲可用性

### 不對 `(member_id, report_date)` 加 UNIQUE 約束

現有 `supabase-client.html:getPersonalHistory` 邏輯是「同一天多筆，只保留最新」，代表業務允許重複提交覆蓋。

**理由**：
- 加 UNIQUE 會阻擋覆蓋提交，改變既有 UX
- 若未來要改成「每天一筆」，需先定義「覆蓋」是 UPDATE 還是 DELETE+INSERT，屬另一個決策

### `(report_id, box_definition_id)` 與 `(item_id, option_id)` 加 UNIQUE

每份報告內，每個 box 只能有一筆 item；每個 item 內，同一選項只能勾一次。

**理由**：正規化的完整性約束，反映真實業務規則（不會同一格填兩次分數、不會勾同一個選項兩次）。

## Risks / Trade-offs

- **[前端 payload 結構改動 → 既有 main.html 收集邏輯需重寫]** → 集中在 `main.html:751-786` 的 `boxData` 組裝段落，影響範圍小；`supabase-client.html` 的 `saveReport` 同步改簽章
- **[`history.html` 歷史頁扁平化邏輯改動 → 畫面顯示可能回歸]** → 保留既有欄位命名（`box1_score`, `box1_content`, ...）作為扁平化輸出，畫面渲染碼不用動；扁平化邏輯加單元測試
- **[正規化後讀取要 JOIN 多表 → 效能降級可能]** → 合理建立索引（`daily_report_items.report_id`、`daily_report_item_options.item_id`）；小規模（每週 414 人 × 7 天 ≈ 2900 筆 reports × 40 格）不會有效能問題
- **[RPC function 寫錯 → 資料狀態不一致]** → function 內使用 `BEGIN ... EXCEPTION ... ROLLBACK` 確保失敗時不留殘資料；部署前以手動測試案例覆蓋「全部 box 勾滿」「完全沒勾」「部分 box 文字、部分勾選」三種情境
- **[`box_definitions` 預設資料需建立 → 缺資料會讓填表頁顯示空白]** → SQL 腳本中同時 INSERT 40 筆預設 box 定義（對應現有 main.html 硬編碼的 box 結構），作為 seed data
- **[測試環境 Supabase 無備份 → 錯誤 SQL 可能破壞測試資料]** → 執行前先在 Supabase Dashboard 手動匯出 members/teams/squads 表備份（測試資料本身可接受丟失）

## Migration Plan

1. **備份現有測試 Supabase 資料**：Dashboard 匯出 `members`、`teams`、`squads`、`daily_reports`（若有）為 CSV
2. **執行 DDL 腳本 `04-normalize-schema.sql`**：建新表、加 UNIQUE/CHECK 約束、建索引、擴充 RLS policies
3. **執行 seed 腳本**：INSERT 40 筆 `box_definitions`（對應現行 main.html 的 box 結構）、INSERT 每個勾選類 box 的 `box_options`
4. **執行 RPC 腳本 `05-save-report-rpc.sql`**：建立 `save_daily_report` function
5. **（可選）執行資料遷移 `06-migrate-box-data.sql`**：若測試環境已有 JSONB 資料，展開轉寫入新表；無資料則跳過
6. **移除 `daily_reports.box_data` 欄位**：確認所有遷移完成後 `ALTER TABLE ... DROP COLUMN box_data`
7. **前端同步改動**：`main.html` payload 重構、`supabase-client.html` API 重寫、`history.html` 扁平化邏輯重寫
8. **`npm run push:dev` 推到測試 Apps Script**
9. **測試 Web App 手動驗收**：登入 → 填一份表 → 提交 → 查歷史，確認資料進入新 schema 且前端顯示正常
10. **Rollback 策略**：若需回退，先保留 `04-normalize-schema.sql` 的 `DROP TABLE IF EXISTS` 區塊、手動執行；前端 git revert 對應 commit

## Open Questions

- **box_definitions 的 input_type 枚舉值**：初擬 `score_only` / `checkbox` / `text` / `mixed`，實際值要對照 main.html 40 個 box 的實際類型歸類 — 留在 tasks.md 分解時決定
- **`box_options.score_value` 是否真的需要**：目前 `scoresMap[boxN_SCORE]` 是前端計算後一次給出，沒看到「每勾一個選項加幾分」的規則。欄位先留，未來若完全用不到再於後續 change 移除
- **seed data 的來源**：40 個 box 的標題/週次/類型目前散在 main.html 的 HTML 結構內，需人工對照 PPT 歸納出來；如果對照成本太高，可先讓 seed 只寫 `box_no` 1-40，`title` 先留空待後續補
