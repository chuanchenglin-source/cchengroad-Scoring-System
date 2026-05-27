## 1. 前置確認

- [ ] 1.1 確認 `members.role` 欄位已存在且包含預期值（`member` / `squad_leader` / `team_leader` / `auditor` / `admin` / `executive`）— 跑 `SELECT DISTINCT role FROM members` 確認
- [ ] 1.2 確認 `members_public` view 存在並已授權 anon SELECT — 跑 `SELECT COUNT(*) FROM members_public` 應回 414
- [ ] 1.3 確認目前 `activity_id = 1` 於 `box_definitions` 已 seed 完成 — 跑 `SELECT COUNT(*) FROM box_definitions WHERE activity_id = 1` 應回 40

> **狀態**：1.1–1.3 需要 Johnson 連到測試 Supabase 才能驗證，暫留未勾。

## 2. `scoring_rules` 表與 helper function

- [x] 2.1 建立 `scripts/supabase-import/06-scoring-rules.sql` 起始骨架，含 BEGIN/COMMIT 與「drop if exists」安全區（對應設計決定「規則儲存在表而非 JS 檔」）
- [x] 2.2 在 `06-scoring-rules.sql` 內建立 `scoring_rules` 表（Scoring Rules Storage Table），含 `(activity_id, rule_key) UNIQUE` 約束與 `updated_by` / `updated_at` 審計欄位
- [x] 2.3 於 `scoring_rules` 表啟用 RLS 並建立 policies：`SELECT` 允許 anon/authenticated；`INSERT`/`UPDATE`/`DELETE` 只允許 service_role（Row-Level Security for Scoring Rules）
- [x] 2.4 於 `06-scoring-rules.sql` 內定義 `get_rule(p_activity_id BIGINT, p_rule_key TEXT) RETURNS JSONB` function（Rule Reading Helper Function），SECURITY DEFINER + GRANT EXECUTE TO anon/authenticated
- [x] 2.5 確保 `get_rule` 對 `is_active = false` 的 row 回傳 NULL（不是 rule_value）
- [x] 2.6 於 `06-scoring-rules.sql` 尾部 INSERT **14 筆** seed rule（2026-04-23 更新，從原 7 筆擴充）：
  - **原 7 問（5 筆已於 2026-04-22 LINE 回答後填入 value）**：
    - `w7_leadership_bonus_enabled` → `true`（4/22 已答：W7、W8 都有加分）
    - `full_completion_definition` → `{"min_per_person": 270, ...}`（4/22 已答）
    - `team_bonus_target` → `"individual"`（原已答）
    - `half_completion_method` → `"ceil"`（4/22 已答）
    - `team_ranking_method` → `"average"`（原已答）
    - `include_leaders_in_average` → `{"squad_leader": true, "team_leader": true}`（4/22 已答）
    - `audit_missing_item_action` → `{"default_action": "manual_report_to_organizer", ...}`（4/22 已答）
  - **1 筆衍生**：
    - `w8_leadership_bonus_enabled` → `true`（從 4/22 Q1 答案衍生）
  - **6 筆 2026-04-23 新增待確認（U1-U6 全部 NULL）**：
    - `weekly_total_scores`（U1+U2 合併）
    - `leader_call_bonus_amounts`（U3）
    - `icebreaking_bonus`（U4）
    - `retraining_scoring`（U5）
    - `auditor_allocation`（U6）
  - **1 筆副本加分（已有明確數值）**：
    - `extra_course_bonus` → 含聯誼會會籍、高階/傳愛大課、進階課程、課後課全勤
- [x] 2.7 腳本結尾加驗證 `DO $$ ... RAISE NOTICE` 區塊：`scoring_rules` 共 14 筆、驗證多筆關鍵 rule 的 value

## 3. Role-scoped views 與 RPC

- [x] 3.1 建立 `scripts/supabase-import/07-role-scoped-views.sql` 起始骨架
- [x] 3.2 定義 `v_squad_scope(p_viewer_id BIGINT) RETURNS SETOF members_public` function（Squad Scope View），根據 viewer role 回傳可見 member 清單
- [x] 3.3 在 `v_squad_scope` 內以 `CASE viewer_role WHEN ... THEN ...` 實作四種角色分支：`member` / `squad_leader` / `team_leader` / (`auditor`/`admin`/`executive`)
- [x] 3.4 未知 role 或 viewer 不存在時回傳空 set（不 raise exception，讓呼叫端自行判斷）
- [x] 3.5 SECURITY DEFINER + GRANT EXECUTE TO anon/authenticated
- [x] 3.6 定義 `get_visible_reports(p_viewer_id BIGINT, p_start_date DATE DEFAULT NULL, p_end_date DATE DEFAULT NULL)` RPC（Visible Reports RPC），回傳扁平化後的報表清單
- [x] 3.7 `get_visible_reports` 內部先呼叫 `v_squad_scope(p_viewer_id)` 取可見 member_ids，再 JOIN `daily_reports` 過濾
- [x] 3.8 套用 `p_start_date` / `p_end_date` 過濾（NULL 時不套用）
- [x] 3.9 腳本結尾加驗證 `DO $$ ... RAISE NOTICE` 區塊

> **狀態**：3.x 全部為 SQL 草稿層面的工作，已於初稿寫完；待 Johnson 套用時再現場驗證。

## 4. RLS 收斂（延後，本 change 暫不執行）

- [x] 4.1 建立 `scripts/supabase-import/08-tighten-rls.sql`（**僅寫腳本，不執行到 Supabase**；根據 design.md Risks 結論，此步驟延後）
- [x] 4.2 在 SQL 檔頭註解標明「執行前必須驗證既有 `getPersonalHistory` 與 `getCompletedDates` 已改走 RPC，否則會壞掉前端讀取」
- [x] 4.3 腳本內容：`DROP POLICY daily_reports_read_all`、`CREATE POLICY "daily_reports_no_direct_read" ON daily_reports FOR SELECT USING (false)` 以及對應的 `daily_report_items` / `daily_report_item_options` 同步收斂
- [x] 4.4 腳本尾部放 rollback 區塊（commented out），方便緊急回退

## 5. 測試驗收（僅 Johnson 回來後執行）

- [ ] 5.1 Johnson 執行 `06-scoring-rules.sql` 到測試 Supabase，確認無錯
- [ ] 5.2 Johnson 執行 `07-role-scoped-views.sql` 到測試 Supabase，確認無錯
- [ ] 5.3 驗證 seed：`SELECT rule_key, rule_value, category FROM scoring_rules ORDER BY category, rule_key` 應回 14 筆
- [ ] 5.4 驗證 `get_rule`：`SELECT get_rule(1, 'team_ranking_method')` 應回 `'"average"'::jsonb`；`SELECT get_rule(1, 'half_completion_method')` 應回 `'"ceil"'::jsonb`（4/22 已 seed）
- [ ] 5.5 驗證 `v_squad_scope`：找一個 `squad_leader`（例如周子維，id 待查），`SELECT * FROM v_squad_scope(<id>)` 應回其小隊成員
- [ ] 5.6 驗證 `v_squad_scope` 的 admin/executive 分支：找一個 `executive` 角色，`SELECT COUNT(*) FROM v_squad_scope(<id>)` 應回全部活躍成員數
- [ ] 5.7 驗證 `get_visible_reports`：以 squad_leader 身份呼叫，確認只看到自己小隊的報表

## 6. 文件與記憶更新

- [x] 6.1 更新 `CLAUDE.md` 的「核心 Schema」章節，加入 `scoring_rules` 表與 `get_rule` / `v_squad_scope` / `get_visible_reports` function 描述（2026-04-23 完成）
- [x] 6.2 更新 memory `project_pending_todos.md` 與 `project_supabase_migration.md`：記錄 rule_key 的 seed 狀態、哪些已答 / 哪些待主辦方確認（2026-04-23 完成）
- [x] 6.3 在 `docs/` 建立「規則未定清單」檔案（`docs/規則未定清單-2026-04-21.md`，已隨 4/22 + 4/23 答案滾動更新）

## 7. 後續 change 分解（不在本 change 執行）

- [ ] 7.1 撰寫 `extend-audit-workflow` change 的 proposal 骨架（審計官四動作：approve/reject/request_supplement/deduct + 補件流程 + audit_logs 表）
- [ ] 7.2 撰寫 `add-role-dashboards` change 的 proposal 骨架（五個 Dashboard 頁：個人/小隊長/大隊長/審計官/公開排名）
- [ ] 7.3 撰寫 `add-angel-assignment-tracking` change 的 proposal 骨架（傳愛名單回報：需要先 `/spectra-discuss` 搞清楚需求）
- [ ] 7.4 撰寫 `migrate-to-supabase-auth` change 的 proposal 骨架（PIN 登入 → Supabase Auth JWT，讓 RLS 能用 `auth.uid()`）

> **狀態**：後續 change 骨架需要 Johnson 先對需求做少量對齊（特別是 7.3 傳愛名單、7.2 Dashboard 欄位清單），未與他討論前 Claude 不主動寫 proposal。
