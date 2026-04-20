-- =====================================================
-- 心成親證班回報系統 — RLS policies + 認證 function
-- 產出時間：2026-04-20
-- 用途：讓前端（anon key）能正常運作 + 準備 PIN 登入機制
-- Demo 階段：policy 較寬鬆，正式上線前會再收緊
-- =====================================================


-- ========== Part 1: Schema 擴充 ==========

-- 1.1 role CHECK constraint 擴充（預留 executive 老大們角色）
ALTER TABLE members DROP CONSTRAINT IF EXISTS members_role_check;
ALTER TABLE members ADD CONSTRAINT members_role_check
  CHECK (role IN ('member', 'squad_leader', 'team_leader', 'auditor', 'admin', 'executive'));

-- 1.2 team_id 改為可空（讓 executive / 外部觀察者可不屬於任何大隊）
ALTER TABLE members ALTER COLUMN team_id DROP NOT NULL;


-- ========== Part 2: members_public VIEW（對外暴露，不含 pin_code）==========

CREATE OR REPLACE VIEW members_public AS
SELECT
    m.id,
    m.member_code,
    m.name,
    m.role,
    m.mentor,
    m.is_active,
    m.team_id,
    t.team_code,
    t.team_name,
    t.leader_name AS team_leader_name,
    t.region,
    m.squad_id,
    s.squad_code,
    s.squad_name,
    s.leader_name AS squad_leader_name
FROM members m
LEFT JOIN teams t ON t.id = m.team_id
LEFT JOIN squads s ON s.id = m.squad_id
WHERE m.is_active = true;

-- 授權 anon / authenticated 可讀 view
GRANT SELECT ON members_public TO anon, authenticated;


-- ========== Part 3: authenticate_member FUNCTION ==========
-- 登入驗證。前端傳 name + pin，後端比對後回傳使用者資訊
-- 使用 SECURITY DEFINER：以函式擁有者身份執行，繞過 RLS

CREATE OR REPLACE FUNCTION authenticate_member(
    p_name TEXT,
    p_pin TEXT
)
RETURNS TABLE (
    id BIGINT,
    member_code TEXT,
    name TEXT,
    role TEXT,
    team_id BIGINT,
    team_code TEXT,
    team_name TEXT,
    squad_id BIGINT,
    squad_code TEXT,
    squad_name TEXT,
    squad_leader_name TEXT,
    team_leader_name TEXT,
    mentor TEXT,
    region TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        m.id,
        m.member_code,
        m.name,
        m.role,
        m.team_id,
        t.team_code,
        t.team_name,
        m.squad_id,
        s.squad_code,
        s.squad_name,
        s.leader_name::TEXT AS squad_leader_name,
        t.leader_name::TEXT AS team_leader_name,
        m.mentor,
        t.region
    FROM members m
    LEFT JOIN teams t ON t.id = m.team_id
    LEFT JOIN squads s ON s.id = m.squad_id
    WHERE
        TRIM(m.name) = TRIM(p_name)
        AND m.pin_code = p_pin
        AND m.is_active = true
    LIMIT 1;
END;
$$;

-- 授權 anon / authenticated 可呼叫
GRANT EXECUTE ON FUNCTION authenticate_member(TEXT, TEXT) TO anon, authenticated;


-- ========== Part 4: RLS Policies（Demo 階段）==========
-- 原則：前端不直接查 members 表（會暴露 pin_code）
--      改從 members_public view 取名單；登入用 function
-- daily_reports：允許 anon 讀寫（demo 簡化；正式上線前會加入 member_id 驗證）

-- ---------- 4.1 teams：所有人可讀 ----------
DROP POLICY IF EXISTS "teams_read_all" ON teams;
CREATE POLICY "teams_read_all" ON teams
    FOR SELECT
    USING (true);

-- ---------- 4.2 squads：所有人可讀 ----------
DROP POLICY IF EXISTS "squads_read_all" ON squads;
CREATE POLICY "squads_read_all" ON squads
    FOR SELECT
    USING (true);

-- ---------- 4.3 members：不建立 SELECT policy ----------
-- 故意不給 anon SELECT 權限，改從 members_public view 取資料
-- members_public view 已排除 pin_code 欄位
-- 若需要登入驗證，改呼叫 authenticate_member(name, pin) function

-- ---------- 4.4 daily_reports：允許讀寫 ----------
DROP POLICY IF EXISTS "daily_reports_read_all" ON daily_reports;
CREATE POLICY "daily_reports_read_all" ON daily_reports
    FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "daily_reports_insert_all" ON daily_reports;
CREATE POLICY "daily_reports_insert_all" ON daily_reports
    FOR INSERT
    WITH CHECK (true);

-- ---------- 4.5 daily_scores：所有人可讀 ----------
DROP POLICY IF EXISTS "daily_scores_read_all" ON daily_scores;
CREATE POLICY "daily_scores_read_all" ON daily_scores
    FOR SELECT
    USING (true);

-- ---------- 4.6 auditor_assignments：所有人可讀 ----------
DROP POLICY IF EXISTS "auditor_assignments_read_all" ON auditor_assignments;
CREATE POLICY "auditor_assignments_read_all" ON auditor_assignments
    FOR SELECT
    USING (true);


-- ========== Part 5: 驗證測試（執行後可跑看看）==========
-- 執行成功後，可用這兩行驗證：
--   SELECT count(*) FROM members_public;                     -- 應該回傳 414
--   SELECT * FROM authenticate_member('周子維', '0000');     -- 應該回傳一筆（角色 squad_leader）


-- ========== 完成訊息 ==========
DO $$
BEGIN
    RAISE NOTICE '✅ Part 1: Schema 擴充完成（role 加 executive, team_id 可空）';
    RAISE NOTICE '✅ Part 2: members_public view 已建立';
    RAISE NOTICE '✅ Part 3: authenticate_member() function 已建立';
    RAISE NOTICE '✅ Part 4: RLS policies 已設定（teams/squads/daily_reports/daily_scores/auditor_assignments）';
    RAISE NOTICE '🚀 Supabase 端準備完成，可以開始改前端';
END $$;
