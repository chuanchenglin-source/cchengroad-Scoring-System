-- =====================================================
-- 14-create-permission-matrix.sql
-- 資料化的 role × capability 權限矩陣
--
-- 適用 change：add-admin-backend
-- 產出時間：2026-04-26
--
-- 對應 spec：openspec/changes/add-admin-backend/specs/permission-matrix/spec.md
--
-- 設計決策（design.md）：
--   - Decision 6: permission_matrix 表先建、暫不接 v_squad_scope（解耦）
--     本檔僅建立資料、helper function、admin update RPC；
--     既有 07-role-scoped-views.sql 的 v_squad_scope / get_visible_reports
--     維持原 hardcoded 邏輯，未來另開 change 重構。
--
-- ⚠️ 重要：本檔生效後權限矩陣 toggle 並不會立即影響 v_squad_scope 行為。
--          Admin UI 內也會顯示「設定預覽，尚未接通」disclaimer。
--
-- 前置條件：13-create-admin-credentials.sql 已執行（admin_verify function 需存在）
-- 執行順序：13 → 14 (本檔) → bootstrap-admin.sql
-- =====================================================

BEGIN;


-- ========== Part 1: permission_matrix 表 ==========

DROP TABLE IF EXISTS permission_matrix CASCADE;

CREATE TABLE permission_matrix (
    id           BIGSERIAL PRIMARY KEY,
    role         TEXT NOT NULL
                 CHECK (role IN ('member','squad_leader','team_leader',
                                 'auditor','admin','executive')),
    capability   TEXT NOT NULL,
    scope        TEXT
                 CHECK (scope IS NULL OR scope IN ('self','squad','team','all','assigned')),
    is_enabled   BOOLEAN NOT NULL DEFAULT true,
    description  TEXT,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by   TEXT REFERENCES admin_credentials(admin_id) ON DELETE SET NULL,
    UNIQUE (role, capability)
);

COMMENT ON TABLE  permission_matrix IS
    'role × capability 權限矩陣。Decision 6: 本表已建但 v_squad_scope 尚未接通，'
    'toggle 此表的 row 暫不影響行為，等下一個 change refactor v_squad_scope 才會接通。';
COMMENT ON COLUMN permission_matrix.scope IS
    'self / squad / team / all / assigned，或 NULL（capability 與 scope 無關時）';
COMMENT ON COLUMN permission_matrix.updated_by IS
    'admin_credentials.admin_id，記錄上次是哪個 admin 改的；admin 被刪則設為 NULL';


-- ========== Part 2: RLS — anon 可讀、寫入只走 RPC ==========

ALTER TABLE permission_matrix ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "permission_matrix_read_all" ON permission_matrix;
CREATE POLICY "permission_matrix_read_all" ON permission_matrix
    FOR SELECT USING (true);

-- 不建 INSERT/UPDATE/DELETE policy = anon/authenticated 默認拒絕
-- 寫入只能透過 admin_update_permission RPC（SECURITY DEFINER 繞過）


-- ========== Part 3: Default Permission Matrix Seed ==========
-- spec 要求 ≥ 30 筆，覆蓋 5 個 capability × 6 個 role = 30 筆
-- 內容對齊 add-admin-backend/design.md「權限矩陣」章節

INSERT INTO permission_matrix (role, capability, scope, is_enabled, description) VALUES
-- ---------- capability: read_scores（看分數）----------
('member',       'read_scores', 'self',     true,  '一般隊員只能看自己分數'),
('squad_leader', 'read_scores', 'squad',    true,  '小隊長看自己小隊'),
('team_leader',  'read_scores', 'team',     true,  '大隊長看自己大隊（含底下小隊）'),
('auditor',      'read_scores', 'assigned', true,  '審計官看被指派的範圍'),
('admin',        'read_scores', 'all',      true,  '管理員看全部'),
('executive',    'read_scores', 'all',      true,  '老大們看全部'),

-- ---------- capability: submit_report（填自己報表）----------
('member',       'submit_report', 'self', true,  ''),
('squad_leader', 'submit_report', 'self', true,  ''),
('team_leader',  'submit_report', 'self', true,  ''),
('auditor',      'submit_report', 'self', true,  ''),
('admin',        'submit_report', 'self', true,  ''),
('executive',    'submit_report', 'self', false, '老大們純看不寫'),

-- ---------- capability: audit_items（審核被指派的小隊 items）----------
('member',       'audit_items', NULL,       false, '一般隊員不能審核'),
('squad_leader', 'audit_items', NULL,       false, '小隊長預設不能審核（對齊 0425：審計官另設）'),
('team_leader',  'audit_items', NULL,       false, ''),
('auditor',      'audit_items', 'assigned', true,  ''),
('admin',        'audit_items', 'all',      true,  ''),
('executive',    'audit_items', NULL,       false, ''),

-- ---------- capability: manage_scoring_rules（修改 scoring_rules）----------
('member',       'manage_scoring_rules', NULL,  false, ''),
('squad_leader', 'manage_scoring_rules', NULL,  false, ''),
('team_leader',  'manage_scoring_rules', NULL,  false, ''),
('auditor',      'manage_scoring_rules', NULL,  false, ''),
('admin',        'manage_scoring_rules', 'all', true,  ''),
('executive',    'manage_scoring_rules', NULL,  false, ''),

-- ---------- capability: manage_roster（管理人員名單）----------
('member',       'manage_roster', NULL,  false, ''),
('squad_leader', 'manage_roster', NULL,  false, ''),
('team_leader',  'manage_roster', NULL,  false, ''),
('auditor',      'manage_roster', NULL,  false, ''),
('admin',        'manage_roster', 'all', true,  ''),
('executive',    'manage_roster', NULL,  false, '');


-- ========== Part 4: get_role_scope helper function ==========
-- 單一入口讀矩陣；is_enabled = false 視為「無權限」回 NULL

DROP FUNCTION IF EXISTS get_role_scope(TEXT, TEXT);

CREATE OR REPLACE FUNCTION get_role_scope(
    p_role        TEXT,
    p_capability  TEXT
)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
    SELECT scope FROM permission_matrix
     WHERE role = p_role
       AND capability = p_capability
       AND is_enabled = true
     LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION get_role_scope(TEXT, TEXT) TO anon, authenticated;

COMMENT ON FUNCTION get_role_scope(TEXT, TEXT) IS
    '查 permission_matrix 回傳該 role 對該 capability 的 scope；'
    'is_enabled=false 或找不到 row 都回 NULL（呼叫端視為「無權限」）。';


-- ========== Part 5: admin_update_permission RPC ==========
-- admin_verify 守門 + UPDATE 既有 row（不允許新增）

DROP FUNCTION IF EXISTS admin_update_permission(TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT);

CREATE OR REPLACE FUNCTION admin_update_permission(
    p_acting_admin_id  TEXT,
    p_acting_password  TEXT,
    p_role             TEXT,
    p_capability       TEXT,
    p_is_enabled       BOOLEAN,
    p_scope            TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_rows_affected INTEGER;
BEGIN
    IF NOT admin_verify(p_acting_admin_id, p_acting_password) THEN
        RAISE EXCEPTION '未通過 admin 驗證';
    END IF;

    -- scope CHECK 已在 column constraint 內，這裡不重複；NULL 是允許的
    UPDATE permission_matrix
       SET is_enabled = p_is_enabled,
           scope      = p_scope,
           updated_at = now(),
           updated_by = p_acting_admin_id
     WHERE role = p_role
       AND capability = p_capability;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
    IF v_rows_affected = 0 THEN
        RAISE EXCEPTION '找不到 (role=%, capability=%) 的 permission_matrix 列', p_role, p_capability;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_update_permission(TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT) TO anon, authenticated;


COMMIT;


-- ========== 驗證 ==========
DO $$
DECLARE
    v_table_exists BOOLEAN;
    v_seed_count   BIGINT;
    v_helper_test  TEXT;
    v_disabled_test TEXT;
BEGIN
    SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='permission_matrix')
      INTO v_table_exists;
    IF NOT v_table_exists THEN RAISE EXCEPTION '❌ permission_matrix 表未建立'; END IF;

    SELECT COUNT(*) INTO v_seed_count FROM permission_matrix;
    IF v_seed_count < 30 THEN RAISE EXCEPTION '❌ seed 預期 ≥ 30 筆，實際 %', v_seed_count; END IF;

    -- spec scenario：scope lookup for enabled permission
    v_helper_test := get_role_scope('squad_leader', 'read_scores');
    IF v_helper_test <> 'squad' THEN
        RAISE EXCEPTION '❌ get_role_scope(squad_leader, read_scores) 應回 ''squad'' 實際 %', v_helper_test;
    END IF;

    -- spec scenario：scope lookup for disabled permission returns NULL
    v_disabled_test := get_role_scope('member', 'audit_items');
    IF v_disabled_test IS NOT NULL THEN
        RAISE EXCEPTION '❌ get_role_scope(member, audit_items) 應回 NULL 實際 %', v_disabled_test;
    END IF;

    RAISE NOTICE '✅ permission_matrix 表已建立 + RLS（anon SELECT only）';
    RAISE NOTICE '✅ Seed 完成 % 筆（5 個 capability × 6 個 role）', v_seed_count;
    RAISE NOTICE '✅ get_role_scope helper 通過 enabled/disabled 兩個 scenario';
    RAISE NOTICE '✅ admin_update_permission RPC 已建立';
    RAISE NOTICE '⚠️  Decision 6: v_squad_scope 仍是 hardcoded，permission_matrix toggle 暫不影響行為';
    RAISE NOTICE '🚀 下一步：複製 bootstrap-admin.sql.example → bootstrap-admin.sql 填密碼跑';
END $$;
