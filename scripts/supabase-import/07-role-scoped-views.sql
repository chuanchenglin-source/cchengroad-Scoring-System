-- =====================================================
-- 心成親證班回報系統 — Role-scoped views 與 get_visible_reports RPC
-- 產出時間：2026-04-21
-- 對應 change：add-scoring-rules-and-role-access
-- 用途：
--   1. 建立 v_squad_scope(viewer_id)：封裝「viewer 依其 role 能看到哪些 member」
--   2. 建立 get_visible_reports(viewer_id, start_date, end_date)：Dashboard 查報表的統一入口
-- 執行前提：02-import-members.sql、03-rls-and-auth.sql、04-normalize-schema.sql、06-scoring-rules.sql 已執行
-- 已知限制：本 change 不做 Auth JWT，呼叫端必須自行傳 viewer_id（demo 階段妥協）
-- =====================================================

BEGIN;


-- ========== Part 1: v_squad_scope 表返回函式 ==========
-- 為何用 function 而非 view：view 無法接參數；PostgreSQL 慣例中，表返回函式用 v_ 前綴表達「視圖化」語意
-- 回傳型別沿用 members_public view 結構，確保 Dashboard 拿到的欄位一致

DROP FUNCTION IF EXISTS v_squad_scope(BIGINT);

CREATE OR REPLACE FUNCTION v_squad_scope(
    p_viewer_id BIGINT
)
RETURNS SETOF members_public
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
    v_role       TEXT;
    v_squad_id   BIGINT;
    v_team_id    BIGINT;
BEGIN
    -- 取 viewer 的 role 與所屬 squad/team
    SELECT m.role, m.squad_id, m.team_id
      INTO v_role, v_squad_id, v_team_id
      FROM members m
     WHERE m.id = p_viewer_id
       AND m.is_active = true
     LIMIT 1;

    -- viewer 不存在 / inactive：回傳空集合，不 raise exception
    IF v_role IS NULL THEN
        RETURN;
    END IF;

    -- 按 role 分發可見範圍
    IF v_role = 'member' THEN
        RETURN QUERY
        SELECT * FROM members_public
         WHERE id = p_viewer_id;

    ELSIF v_role = 'squad_leader' THEN
        RETURN QUERY
        SELECT * FROM members_public
         WHERE squad_id = v_squad_id;

    ELSIF v_role = 'team_leader' THEN
        RETURN QUERY
        SELECT * FROM members_public
         WHERE team_id = v_team_id;

    ELSIF v_role IN ('auditor', 'admin', 'executive') THEN
        RETURN QUERY
        SELECT * FROM members_public;

    ELSE
        -- 未知 role：保守回傳空集合
        RETURN;
    END IF;
END;
$$;

COMMENT ON FUNCTION v_squad_scope(BIGINT) IS
'封裝 role → 可見 member 範圍。呼叫端：SELECT * FROM v_squad_scope(viewer_id)。'
'已知限制：demo 階段 viewer_id 由 client 傳，可被偽造；正式上線前切到 Supabase Auth 讓 RLS 用 auth.uid()。';

GRANT EXECUTE ON FUNCTION v_squad_scope(BIGINT) TO anon, authenticated;


-- ========== Part 2: get_visible_reports RPC ==========
-- Dashboard 查報表的統一入口。內部先呼叫 v_squad_scope 取可見 member_ids，
-- 再 JOIN daily_reports 並套用可選日期範圍過濾。

DROP FUNCTION IF EXISTS get_visible_reports(BIGINT, DATE, DATE);

CREATE OR REPLACE FUNCTION get_visible_reports(
    p_viewer_id   BIGINT,
    p_start_date  DATE DEFAULT NULL,
    p_end_date    DATE DEFAULT NULL
)
RETURNS TABLE (
    report_id      BIGINT,
    member_id      BIGINT,
    member_name    TEXT,
    squad_id       BIGINT,
    team_id        BIGINT,
    report_date    DATE,
    total_score    INTEGER,
    remarks        TEXT,
    submitted_at   TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id             AS report_id,
        r.member_id,
        vs.name          AS member_name,
        vs.squad_id,
        vs.team_id,
        r.report_date,
        r.total_score,
        r.remarks,
        r.submitted_at
      FROM v_squad_scope(p_viewer_id) vs
      JOIN daily_reports r ON r.member_id = vs.id
     WHERE (p_start_date IS NULL OR r.report_date >= p_start_date)
       AND (p_end_date   IS NULL OR r.report_date <= p_end_date)
     ORDER BY r.report_date DESC, r.submitted_at DESC;
END;
$$;

COMMENT ON FUNCTION get_visible_reports(BIGINT, DATE, DATE) IS
'Dashboard 查報表的統一 RPC。根據 viewer role 自動限制可見範圍；'
'可選 start_date/end_date 做日期過濾，兩者皆 NULL 時回全部可見資料。';

GRANT EXECUTE ON FUNCTION get_visible_reports(BIGINT, DATE, DATE) TO anon, authenticated;


-- ========== Part 3: 驗證 ==========

DO $$
DECLARE
    v_sample_member_id    BIGINT;
    v_sample_squad_leader BIGINT;
    v_sample_exec         BIGINT;
    v_self_count          INTEGER;
    v_squad_count         INTEGER;
    v_all_count           INTEGER;
BEGIN
    -- 取樣：一般成員
    SELECT id INTO v_sample_member_id
      FROM members
     WHERE role = 'member' AND is_active = true
     LIMIT 1;

    -- 取樣：小隊長
    SELECT id INTO v_sample_squad_leader
      FROM members
     WHERE role = 'squad_leader' AND is_active = true
     LIMIT 1;

    -- 取樣：executive/admin
    SELECT id INTO v_sample_exec
      FROM members
     WHERE role IN ('executive', 'admin') AND is_active = true
     LIMIT 1;

    -- 測試 1：member 只能看到自己
    IF v_sample_member_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_self_count FROM v_squad_scope(v_sample_member_id);
        IF v_self_count <> 1 THEN
            RAISE WARNING '⚠️  member role 預期回 1 筆，實際 %（member_id=%）', v_self_count, v_sample_member_id;
        ELSE
            RAISE NOTICE '✅ v_squad_scope(member %) 回 1 筆（只看到自己）', v_sample_member_id;
        END IF;
    ELSE
        RAISE NOTICE 'ℹ️  找不到 role=member 的樣本，跳過測試 1';
    END IF;

    -- 測試 2：squad_leader 看到自己小隊
    IF v_sample_squad_leader IS NOT NULL THEN
        SELECT COUNT(*) INTO v_squad_count FROM v_squad_scope(v_sample_squad_leader);
        IF v_squad_count < 1 THEN
            RAISE WARNING '⚠️  squad_leader 預期至少回 1 筆（至少包含自己），實際 %', v_squad_count;
        ELSE
            RAISE NOTICE '✅ v_squad_scope(squad_leader %) 回 % 筆（自己小隊）', v_sample_squad_leader, v_squad_count;
        END IF;
    ELSE
        RAISE NOTICE 'ℹ️  找不到 role=squad_leader 的樣本，跳過測試 2';
    END IF;

    -- 測試 3：executive/admin 看到全部活躍成員
    IF v_sample_exec IS NOT NULL THEN
        SELECT COUNT(*) INTO v_all_count FROM v_squad_scope(v_sample_exec);
        IF v_all_count < 100 THEN
            RAISE WARNING '⚠️  executive 預期看到大量成員（>100），實際 %', v_all_count;
        ELSE
            RAISE NOTICE '✅ v_squad_scope(executive %) 回 % 筆（全部活躍成員）', v_sample_exec, v_all_count;
        END IF;
    ELSE
        RAISE NOTICE 'ℹ️  找不到 role=executive/admin 的樣本，跳過測試 3';
    END IF;

    -- 測試 4：不存在的 viewer_id 回空集合
    SELECT COUNT(*) INTO v_self_count FROM v_squad_scope(9999999);
    IF v_self_count <> 0 THEN
        RAISE EXCEPTION '❌ 不存在的 viewer_id 應回空集合，實際 %', v_self_count;
    END IF;
    RAISE NOTICE '✅ v_squad_scope(不存在 id) 回 0 筆';

    RAISE NOTICE '🚀 07-role-scoped-views.sql 執行完成';
END $$;


COMMIT;


-- =====================================================
-- 使用範例（供 Dashboard 代碼參考）
-- =====================================================
--
-- 小隊長 Dashboard：取自己小隊的今日報表
--   SELECT * FROM get_visible_reports(
--       (SELECT id FROM members WHERE name='周子維'),
--       CURRENT_DATE, CURRENT_DATE
--   );
--
-- 大隊長 Dashboard：取自己大隊本週所有報表
--   SELECT * FROM get_visible_reports(
--       <team_leader_id>,
--       CURRENT_DATE - INTERVAL '7 days', CURRENT_DATE
--   );
--
-- 審計官 Dashboard：取全部 pending 報表（後續 extend-audit-workflow change 會補 pending 過濾版本）
--   SELECT * FROM get_visible_reports(<auditor_id>, NULL, NULL);
--
-- =====================================================
