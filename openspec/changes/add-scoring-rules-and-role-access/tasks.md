## 1. 前置確認

- [ ] 1.1 確認 `members.role` 欄位已存在且包含預期值（`member` / `squad_leader` / `team_leader` / `auditor` / `admin` / `executive`）— 跑 `SELECT DISTINCT role FROM members` 確認
- [ ] 1.2 確認 `members_public` view 存在並已授權 anon SELECT — 跑 `SELECT COUNT(*) FROM members_public` 應回 414
- [ ] 1.3 確認目前 `activity_id = 1` 於 `box_definitions` 已 seed 完成 — 跑 `SELECT COUNT(*) FROM box_definitions WHERE activity_id = 1` 應回 40

## 2. `scoring_rules` 表與 helper function

- [ ] 2.1 建立 `scripts/supabase-import/06-scoring-rules.sql` 起始骨架，含 BEGIN/COMMIT 與「drop if exists」安全區（對應設計決定「規則儲存在表而非 JS 檔」）
- [ ] 2.2 在 `06-scoring-rules.sql` 內建立 `scoring_rules` 表（Scoring Rules Storage Table），含 `(activity_id, rule_key) UNIQUE` 約束與 `updated_by` / `updated_at` 審計欄位
- [ ] 2.3 於 `scoring_rules` 表啟用 RLS 並建立 policies：`SELECT` 允許 anon/authenticated；`INSERT`/`UPDATE`/`DELETE` 只允許 service_role（Row-Level Security for Scoring Rules）
- [ ] 2.4 於 `06-scoring-rules.sql` 內定義 `get_rule(p_activity_id BIGINT, p_rule_key TEXT) RETURNS JSONB` function（Rule Reading Helper Function），SECURITY DEFINER + GRANT EXECUTE TO anon/authenticated
- [ ] 2.5 確保 `get_rule` 對 `is_active = false` 的 row 回傳 NULL（不是 rule_value）
- [ ] 2.6 於 `06-scoring-rules.sql` 尾部 INSERT 7 筆 seed rule（Seed Rule Keys for Known Questions）：
  - `w7_leadership_bonus_enabled` → category=`leadership`, value=NULL
  - `full_completion_definition` → category=`completion`, value=NULL
  - `team_bonus_target` → category=`team_bonus`, value=`'"individual"'::jsonb`（已答）
  - `half_completion_method` → category=`team_bonus`, value=NULL
  - `team_ranking_method` → category=`ranking`, value=`'"average"'::jsonb`（已答）
  - `include_leaders_in_average` → category=`ranking`, value=NULL
  - `audit_missing_item_action` → category=`audit`, value=NULL
- [ ] 2.7 腳本結尾加驗證 `DO $$ ... RAISE NOTICE` 區塊：`scoring_rules` 共 7 筆、`get_rule(1, 'team_ranking_method')` 回 `"average"`

## 3. Role-scoped views 與 RPC

- [ ] 3.1 建立 `scripts/supabase-import/07-role-scoped-views.sql` 起始骨架
- [ ] 3.2 定義 `v_squad_scope(p_viewer_id BIGINT) RETURNS SETOF members_public` function（Squad Scope View），根據 viewer role 回傳可見 member 清單
- [ ] 3.3 在 `v_squad_scope` 內以 `CASE viewer_role WHEN ... THEN ...` 實作四種角色分支：`member` / `squad_leader` / `team_leader` / (`auditor`/`admin`/`executive`)
- [ ] 3.4 未知 role 或 viewer 不存在時回傳空 set（不 raise exception，讓呼叫端自行判斷）
- [ ] 3.5 SECURITY DEFINER + GRANT EXECUTE TO anon/authenticated
- [ ] 3.6 定義 `get_visible_reports(p_viewer_id BIGINT, p_start_date DATE DEFAULT NULL, p_end_date DATE DEFAULT NULL)` RPC（Visible Reports RPC），回傳扁平化後的報表清單
- [ ] 3.7 `get_visible_reports` 內部先呼叫 `v_squad_scope(p_viewer_id)` 取可見 member_ids，再 JOIN `daily_reports` 過濾
- [ ] 3.8 套用 `p_start_date` / `p_end_date` 過濾（NULL 時不套用）
- [ ] 3.9 腳本結尾加驗證 `DO $$ ... RAISE NOTICE` 區塊

## 4. RLS 收斂（延後，本 change 暫不執行）

- [ ] 4.1 建立 `scripts/supabase-import/08-tighten-rls.sql`（**僅寫腳本，不執行到 Supabase**；根據 design.md Risks 結論，此步驟延後）
- [ ] 4.2 在 SQL 檔頭註解標明「執行前必須驗證既有 `getPersonalHistory` 與 `getCompletedDates` 已改走 RPC，否則會壞掉前端讀取」
- [ ] 4.3 腳本內容：`DROP POLICY daily_reports_read_all`、`CREATE POLICY "daily_reports_no_direct_read" ON daily_reports FOR SELECT USING (false)` 以及對應的 `daily_report_items` / `daily_report_item_options` 同步收斂
- [ ] 4.4 腳本尾部放 rollback 區塊（commented out），方便緊急回退

## 5. 測試驗收（僅 Johnson 回來後執行）

- [ ] 5.1 Johnson 執行 `06-scoring-rules.sql` 到測試 Supabase，確認無錯
- [ ] 5.2 Johnson 執行 `07-role-scoped-views.sql` 到測試 Supabase，確認無錯
- [ ] 5.3 驗證 seed：`SELECT rule_key, rule_value FROM scoring_rules ORDER BY category` 應回 7 筆
- [ ] 5.4 驗證 `get_rule`：`SELECT get_rule(1, 'team_ranking_method')` 應回 `'"average"'::jsonb`；`SELECT get_rule(1, 'half_completion_method')` 應回 NULL
- [ ] 5.5 驗證 `v_squad_scope`：找一個 `squad_leader`（例如周子維，id 待查），`SELECT * FROM v_squad_scope(<id>)` 應回其小隊成員
- [ ] 5.6 驗證 `v_squad_scope` 的 admin/executive 分支：找一個 `executive` 角色，`SELECT COUNT(*) FROM v_squad_scope(<id>)` 應回全部活躍成員數
- [ ] 5.7 驗證 `get_visible_reports`：以 squad_leader 身份呼叫，確認只看到自己小隊的報表

## 6. 文件與記憶更新

- [ ] 6.1 更新 `CLAUDE.md` 的「核心 Schema」章節，加入 `scoring_rules` 表與 `get_rule` / `v_squad_scope` / `get_visible_reports` function 描述
- [ ] 6.2 更新 memory `project_dashboard_schedule.md` 或新建 `project_scoring_rules_state.md`：記錄 7 個 rule_key 的 seed 狀態、哪些已答 / 哪些待主辦方確認
- [ ] 6.3 在 `docs/` 新建「規則未定清單」檔案，列出 7 個 rule_key 與對應的主辦方問題文字，作為後續追蹤 artifact

## 7. 後續 change 分解（不在本 change 執行）

- [ ] 7.1 撰寫 `extend-audit-workflow` change 的 proposal 骨架（審計官四動作：approve/reject/request_supplement/deduct + 補件流程 + audit_logs 表）
- [ ] 7.2 撰寫 `add-role-dashboards` change 的 proposal 骨架（五個 Dashboard 頁：個人/小隊長/大隊長/審計官/公開排名）
- [ ] 7.3 撰寫 `add-angel-assignment-tracking` change 的 proposal 骨架（傳愛名單回報：需要先 `/spectra-discuss` 搞清楚需求）
- [ ] 7.4 撰寫 `migrate-to-supabase-auth` change 的 proposal 骨架（PIN 登入 → Supabase Auth JWT，讓 RLS 能用 `auth.uid()`）
