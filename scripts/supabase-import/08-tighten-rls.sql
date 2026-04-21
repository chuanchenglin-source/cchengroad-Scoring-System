-- =====================================================
-- 心成親證班回報系統 — 收斂 daily_reports / daily_report_items SELECT RLS
-- 產出時間：2026-04-21
-- 對應 change：add-scoring-rules-and-role-access
--
-- ⚠️  警告：本腳本暫時不執行到 Supabase ⚠️
-- ---------------------------------------------------------------
-- 原因：現有 supabase-client.html 的 getPersonalHistory / getCompletedDates
-- 是直接 `SELECT * FROM daily_reports` + nested select，沒有走新的
-- get_visible_reports RPC。若直接關閉 SELECT RLS，會壞掉個人歷史頁。
--
-- 執行前提：
-- 1. Dashboard change 完成，所有讀取改走 get_visible_reports
-- 2. 或者 getPersonalHistory 改寫成呼叫 get_visible_reports(member_id, NULL, NULL)
-- 3. 或者保留「自己看自己」的 RLS exception（需要 JWT / auth.uid()，暫不可行）
--
-- 目前處置：腳本寫好放著，等上述前提之一完成後再執行
-- =====================================================

BEGIN;


-- ========== daily_reports：SELECT 改為 false（必須走 RPC）==========

-- 移除既有寬鬆 SELECT policy
DROP POLICY IF EXISTS "daily_reports_read_all" ON daily_reports;

-- 建立拒絕 policy，強迫呼叫走 SECURITY DEFINER RPC
DROP POLICY IF EXISTS "daily_reports_no_direct_read" ON daily_reports;
CREATE POLICY "daily_reports_no_direct_read" ON daily_reports
    FOR SELECT
    USING (false);

-- INSERT 不動（仍由 save_daily_report RPC 執行，繞過 RLS）
-- 若未來要連 INSERT 也收斂：DROP 既有 policy，依賴 SECURITY DEFINER 繞過


-- ========== daily_report_items：同步收斂 ==========

DROP POLICY IF EXISTS "daily_report_items_read_all" ON daily_report_items;

DROP POLICY IF EXISTS "daily_report_items_no_direct_read" ON daily_report_items;
CREATE POLICY "daily_report_items_no_direct_read" ON daily_report_items
    FOR SELECT
    USING (false);


-- ========== daily_report_item_options：同步收斂 ==========

DROP POLICY IF EXISTS "daily_report_item_options_read_all" ON daily_report_item_options;

DROP POLICY IF EXISTS "daily_report_item_options_no_direct_read" ON daily_report_item_options;
CREATE POLICY "daily_report_item_options_no_direct_read" ON daily_report_item_options
    FOR SELECT
    USING (false);


-- ========== 驗證 ==========
-- 收斂後，以 anon key 執行 `SELECT * FROM daily_reports LIMIT 1` 應回空集合
-- 但透過 `SELECT * FROM get_visible_reports(<valid_viewer_id>)` 應正常回資料

DO $$
BEGIN
    RAISE NOTICE '✅ daily_reports / daily_report_items / daily_report_item_options SELECT 已收斂';
    RAISE NOTICE 'ℹ️  後續所有讀取必須透過 get_visible_reports(viewer_id) RPC';
END $$;


COMMIT;


-- =====================================================
-- Rollback（若收斂後發現壞掉既有前端，立刻回退）
-- =====================================================
--
-- BEGIN;
--
-- DROP POLICY IF EXISTS "daily_reports_no_direct_read" ON daily_reports;
-- CREATE POLICY "daily_reports_read_all" ON daily_reports FOR SELECT USING (true);
--
-- DROP POLICY IF EXISTS "daily_report_items_no_direct_read" ON daily_report_items;
-- CREATE POLICY "daily_report_items_read_all" ON daily_report_items FOR SELECT USING (true);
--
-- DROP POLICY IF EXISTS "daily_report_item_options_no_direct_read" ON daily_report_item_options;
-- CREATE POLICY "daily_report_item_options_read_all" ON daily_report_item_options FOR SELECT USING (true);
--
-- COMMIT;
--
-- =====================================================
