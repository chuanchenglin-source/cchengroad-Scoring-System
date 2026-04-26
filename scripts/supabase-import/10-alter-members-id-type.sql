-- =====================================================
-- 10-alter-members-id-type.sql
-- 重建 members 表，採 TEXT 主鍵（格式 T011_周子維_嘉家久），新增 squad_id / leader_name 欄位
-- 並連動更新 daily_reports.member_id 與 daily_report_items.audited_by 型別
--
-- 適用 change：align-with-main-dev-0425
-- 產出時間：2026-04-25
--
-- ⚠️  DESTRUCTIVE MIGRATION ⚠️
--   本檔會 TRUNCATE 既有 daily_reports / daily_report_items / daily_report_item_options
--   並 DROP TABLE members CASCADE，所有舊資料（含 18 人 demo）將遺失。
--   執行前請確認測試 Supabase 上沒有需要保留的歷史資料：
--     SELECT COUNT(*) FROM daily_reports;
--     SELECT COUNT(*) FROM members;
--
-- 執行順序：09 → 10 (本檔) → 11 → 12
-- 前置條件：teams / squads 空表已建立（09 SQL 完成）
-- =====================================================

BEGIN;


-- ========== Part 1: 清掉所有相依物件 ==========

-- view / function 拆乾淨（09 已先拆，這裡 defense-in-depth）
DROP VIEW     IF EXISTS members_public CASCADE;
DROP FUNCTION IF EXISTS authenticate_member(TEXT, TEXT) CASCADE;

-- daily_report 系列 TRUNCATE（清資料但保留表結構，後續 ALTER COLUMN 才不會碰到 row）
TRUNCATE TABLE daily_report_item_options, daily_report_items, daily_reports CASCADE;


-- ========== Part 2: 拆既有 daily_reports / daily_report_items 的 FK constraint ==========
-- ALTER COLUMN TYPE 前要先拆 FK，否則 PostgreSQL 會拒絕變更型別

ALTER TABLE daily_reports
    DROP CONSTRAINT IF EXISTS daily_reports_member_id_fkey;

ALTER TABLE daily_report_items
    DROP CONSTRAINT IF EXISTS daily_report_items_audited_by_fkey;


-- ========== Part 3: DROP TABLE members 並重建 ==========
-- 既有 members 包含 BIGINT id、pin_code、member_code 等舊欄位
-- 直接 DROP CASCADE 比 ALTER 多次更乾淨

DROP TABLE IF EXISTS members CASCADE;

CREATE TABLE members (
    -- spec: Member Identifier as Composite Text Key
    -- 格式：<squad_code>_<name>_<team_name>，由 11 SQL 匯入
    id           TEXT      NOT NULL PRIMARY KEY,
    name         TEXT      NOT NULL,

    -- spec: Members Squad Foreign Key
    squad_id     BIGINT    NOT NULL REFERENCES squads(id) ON DELETE RESTRICT,
    team_id      BIGINT    NOT NULL REFERENCES teams(id)  ON DELETE RESTRICT,
    leader_name  TEXT      NOT NULL,  -- denormalise squad_leader_name for UI

    -- 保留欄位（從舊 schema 移植，但 pin_code 已永久移除）
    role         TEXT      NOT NULL DEFAULT 'member'
                           CHECK (role IN ('member', 'squad_leader', 'team_leader',
                                           'auditor', 'admin', 'executive')),
    mentor       TEXT,
    is_active    BOOLEAN   NOT NULL DEFAULT true,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  members IS
    '隊員主資料。id 採 TEXT 格式 <squad_code>_<name>_<team_name>，與主程式設計師 0425 路線一致。pin_code 已永久移除（2026-04-25 主辦方決議）。';
COMMENT ON COLUMN members.id          IS 'e.g. T011_周子維_嘉家久';
COMMENT ON COLUMN members.squad_id    IS '所屬小隊（必填，刪除 squad 會被擋住）';
COMMENT ON COLUMN members.team_id     IS '所屬大隊 denorm（squad → team 也可推得，但保留欄位讓大隊查詢免 join）';
COMMENT ON COLUMN members.leader_name IS '小隊長姓名（denorm from squads.squad_leader_name）';

CREATE INDEX idx_members_squad ON members (squad_id);
CREATE INDEX idx_members_team  ON members (team_id);
CREATE INDEX idx_members_active ON members (is_active) WHERE is_active = true;


-- ========== Part 4: 連動修改 daily_reports.member_id 型別 ==========
-- TRUNCATE 後沒資料，ALTER COLUMN TYPE 直接成功

ALTER TABLE daily_reports
    ALTER COLUMN member_id TYPE TEXT USING member_id::TEXT;

ALTER TABLE daily_reports
    ADD CONSTRAINT daily_reports_member_id_fkey
    FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE;


-- ========== Part 5: 連動修改 daily_report_items.audited_by 型別 ==========

ALTER TABLE daily_report_items
    ALTER COLUMN audited_by TYPE TEXT USING audited_by::TEXT;

ALTER TABLE daily_report_items
    ADD CONSTRAINT daily_report_items_audited_by_fkey
    FOREIGN KEY (audited_by) REFERENCES members(id);


-- ========== Part 6: 重建 members_public view（無 pin_code）==========
-- 對外暴露名單（前端 datalist 用）；不再含 pin_code 欄位

CREATE OR REPLACE VIEW members_public AS
SELECT
    m.id,
    m.name,
    m.role,
    m.mentor,
    m.is_active,
    m.team_id,
    t.team_code,
    t.team_name,
    t.leader_name AS team_leader_name,
    t.form_label,
    m.squad_id,
    s.squad_code,
    s.squad_leader_name,
    m.leader_name
FROM members m
JOIN teams  t ON t.id = m.team_id
JOIN squads s ON s.id = m.squad_id
WHERE m.is_active = true;

COMMENT ON VIEW members_public IS
    '對外暴露的成員名單，不含已移除的 pin_code。前端 Index.html datalist 來源。';

GRANT SELECT ON members_public TO anon, authenticated;


-- ========== Part 7: members 表 RLS ==========
-- spec 要求：anon 可讀（前端要 datalist 載 360+ 人）

ALTER TABLE members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "members_read_all" ON members;
CREATE POLICY "members_read_all" ON members
    FOR SELECT
    USING (true);

-- 寫入只給 service_role（無 INSERT / UPDATE / DELETE policy）


COMMIT;


-- ========== 驗證 ==========
DO $$
DECLARE
    v_member_id_type    TEXT;
    v_report_member_type TEXT;
    v_audited_by_type   TEXT;
    v_pin_exists        BOOLEAN;
BEGIN
    -- 驗證 members.id 已是 TEXT
    SELECT data_type INTO v_member_id_type
      FROM information_schema.columns
     WHERE table_name = 'members' AND column_name = 'id';
    IF v_member_id_type <> 'text' THEN
        RAISE EXCEPTION '❌ members.id 型別應為 text 但實際為 %', v_member_id_type;
    END IF;

    -- 驗證 daily_reports.member_id 已是 TEXT
    SELECT data_type INTO v_report_member_type
      FROM information_schema.columns
     WHERE table_name = 'daily_reports' AND column_name = 'member_id';
    IF v_report_member_type <> 'text' THEN
        RAISE EXCEPTION '❌ daily_reports.member_id 型別應為 text 但實際為 %', v_report_member_type;
    END IF;

    -- 驗證 daily_report_items.audited_by 已是 TEXT
    SELECT data_type INTO v_audited_by_type
      FROM information_schema.columns
     WHERE table_name = 'daily_report_items' AND column_name = 'audited_by';
    IF v_audited_by_type <> 'text' THEN
        RAISE EXCEPTION '❌ daily_report_items.audited_by 型別應為 text 但實際為 %', v_audited_by_type;
    END IF;

    -- 驗證 pin_code 欄位已不存在
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_name = 'members' AND column_name = 'pin_code'
    ) INTO v_pin_exists;
    IF v_pin_exists THEN
        RAISE EXCEPTION '❌ members.pin_code 欄位仍存在（應在重建時移除）';
    END IF;

    RAISE NOTICE '✅ members 表已重建：id=TEXT、squad_id/leader_name 已加、pin_code 已移除';
    RAISE NOTICE '✅ daily_reports.member_id = TEXT，FK 已重建';
    RAISE NOTICE '✅ daily_report_items.audited_by = TEXT，FK 已重建';
    RAISE NOTICE '✅ members_public view 已重建（無 pin_code）';
    RAISE NOTICE '🚀 下一步：執行 11-import-real-roster.sql 匯入 360+ 名單';
END $$;
