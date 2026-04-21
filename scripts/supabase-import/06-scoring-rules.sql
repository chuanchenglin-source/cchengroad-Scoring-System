-- =====================================================
-- 心成親證班回報系統 — scoring_rules 表與 get_rule 函式
-- 產出時間：2026-04-21
-- 對應 change：add-scoring-rules-and-role-access
-- 用途：
--   1. 建立 scoring_rules 表，把所有可調計分規則從代碼搬到資料
--   2. 建立 get_rule(activity_id, rule_key) helper function
--   3. Seed 7 個已知 rule_key（對應 2026-04-21 主辦方 LINE 群組 7 個待確認問題）
-- 執行前提：02-import-members.sql、03-rls-and-auth.sql、04-normalize-schema.sql 已執行
-- =====================================================

BEGIN;


-- ========== Part 1: scoring_rules 表 ==========

DROP TABLE IF EXISTS scoring_rules CASCADE;

CREATE TABLE scoring_rules (
    id             BIGSERIAL PRIMARY KEY,
    activity_id    BIGINT NOT NULL DEFAULT 1,
    rule_key       TEXT NOT NULL,
    rule_value     JSONB,
    description    TEXT,
    category       TEXT CHECK (category IN (
                       'team_bonus', 'leadership', 'audit', 'ranking', 'completion'
                   )),
    is_active      BOOLEAN NOT NULL DEFAULT true,
    updated_by     BIGINT REFERENCES members(id),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (activity_id, rule_key)
);

CREATE INDEX idx_scoring_rules_lookup ON scoring_rules (activity_id, rule_key) WHERE is_active = true;

COMMENT ON TABLE scoring_rules IS
'計分規則的資料化儲存。rule_value NULL = 主辦方尚未確認；呼叫端應透過 get_rule() 讀取。';
COMMENT ON COLUMN scoring_rules.rule_value IS
'JSONB 型別允許結構化值，如 {"method":"ceil","threshold":0.5} 或單純 scalar "average"';
COMMENT ON COLUMN scoring_rules.description IS
'記錄此 rule_key 的原始問題文字，方便日後追溯';


-- ========== Part 2: RLS policies ==========
-- Demo 階段：SELECT 開放 anon/authenticated；寫入只允許 service_role
-- 正式上線前：SELECT 視情況調整（通常仍維持公開讀取）

ALTER TABLE scoring_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "scoring_rules_read_all" ON scoring_rules;
CREATE POLICY "scoring_rules_read_all" ON scoring_rules
    FOR SELECT
    USING (true);

-- 明確不建立 INSERT/UPDATE/DELETE policy，預設拒絕 anon/authenticated 修改
-- service_role 繞過 RLS，可在 Supabase Dashboard 或 SQL Editor 直接改


-- ========== Part 3: get_rule() helper function ==========

DROP FUNCTION IF EXISTS get_rule(BIGINT, TEXT);

CREATE OR REPLACE FUNCTION get_rule(
    p_activity_id BIGINT,
    p_rule_key    TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_value JSONB;
BEGIN
    SELECT rule_value
      INTO v_value
      FROM scoring_rules
     WHERE activity_id = p_activity_id
       AND rule_key    = p_rule_key
       AND is_active   = true
     LIMIT 1;

    RETURN v_value;  -- 找不到 / inactive / rule_value 本身為 NULL 都回 NULL
END;
$$;

COMMENT ON FUNCTION get_rule(BIGINT, TEXT) IS
'單一入口讀規則。回傳 NULL 表示「規則未設定」或「規則已停用」，呼叫端必須明確處理 NULL。';

GRANT EXECUTE ON FUNCTION get_rule(BIGINT, TEXT) TO anon, authenticated;


-- ========== Part 4: Seed 7 個已知 rule_key ==========
-- 對應 2026-04-21 主辦方在 LINE 群組提出的 7 個待確認問題
-- 已答的填入預設值（team_bonus_target、team_ranking_method）
-- 未答的留 rule_value = NULL，等主辦方確認後 UPDATE 即可

INSERT INTO scoring_rules (activity_id, rule_key, rule_value, description, category) VALUES
(
    1,
    'w7_leadership_bonus_enabled',
    NULL,
    '第七週還有領袖通話加分嗎？還是改成只有第八週呢？（Q1 待主辦方確認）',
    'leadership'
),
(
    1,
    'full_completion_definition',
    NULL,
    '全完成是指全部（定課+主題）都完成嗎？只要每個人填回報分數都達到那週最高分就算嗎？（Q2a 待主辦方確認）',
    'completion'
),
(
    1,
    'team_bonus_target',
    '"individual"'::jsonb,
    '團隊動能加分是加到個人還是整組團隊總分？（Q2b 已答：每個達成的人個別加分，不是隊伍總分加一次）',
    'team_bonus'
),
(
    1,
    'half_completion_method',
    NULL,
    '團隊半數認列：7人隊完成 3 人算過半嗎？還是一定要 4 人？要無條件進位還是剛好過半？（Q2c 待主辦方確認；預期 value 為 "ceil" / "floor" / "strict"）',
    'team_bonus'
),
(
    1,
    'team_ranking_method',
    '"average"'::jsonb,
    '團隊排名要用總分還是平均分？因為每隊人數不一致（Q3a 已答：平均分；計算方式為個人加總 ÷ 人數 + 整隊加分）',
    'ranking'
),
(
    1,
    'include_leaders_in_average',
    NULL,
    '小隊長和大隊長是否要計算入團隊總分（即是否計入平均分的分母）？（Q3b 待主辦方確認；預期 value 如 {"squad_leader": true, "team_leader": false}）',
    'ranking'
),
(
    1,
    'audit_missing_item_action',
    NULL,
    '審計官如果發現有缺件，要如何處理？扣分、補件、或兩者都支援？（Q3c 待主辦方確認；預期 value 如 {"default_action": "request_supplement", "deduct_amount": 0}）',
    'audit'
);


-- ========== Part 5: 驗證 ==========

DO $$
DECLARE
    v_rule_count  INTEGER;
    v_ranking     JSONB;
    v_half        JSONB;
    v_bonus       JSONB;
BEGIN
    SELECT COUNT(*) INTO v_rule_count FROM scoring_rules WHERE activity_id = 1;
    IF v_rule_count <> 7 THEN
        RAISE EXCEPTION '❌ scoring_rules seed 預期 7 筆，實際 %', v_rule_count;
    END IF;

    v_ranking := get_rule(1, 'team_ranking_method');
    IF v_ranking IS NULL OR v_ranking #>> '{}' <> 'average' THEN
        RAISE EXCEPTION '❌ get_rule(1, team_ranking_method) 預期 "average"，實際 %', v_ranking;
    END IF;

    v_half := get_rule(1, 'half_completion_method');
    IF v_half IS NOT NULL THEN
        RAISE EXCEPTION '❌ get_rule(1, half_completion_method) 預期 NULL（待主辦方確認），實際 %', v_half;
    END IF;

    v_bonus := get_rule(1, 'team_bonus_target');
    IF v_bonus IS NULL OR v_bonus #>> '{}' <> 'individual' THEN
        RAISE EXCEPTION '❌ get_rule(1, team_bonus_target) 預期 "individual"，實際 %', v_bonus;
    END IF;

    RAISE NOTICE '✅ scoring_rules 共 % 筆（應為 7）', v_rule_count;
    RAISE NOTICE '✅ get_rule(team_ranking_method) = %', v_ranking;
    RAISE NOTICE '✅ get_rule(half_completion_method) = NULL（如預期，待主辦方確認）';
    RAISE NOTICE '✅ get_rule(team_bonus_target) = %', v_bonus;
    RAISE NOTICE '🚀 06-scoring-rules.sql 執行完成';
END $$;


COMMIT;


-- =====================================================
-- 主辦方確認規則後的 UPDATE 範例（不在本腳本執行）
-- =====================================================
--
-- 例如主辦方確認「7 人隊 3 人算過半（無條件進位）」：
--   UPDATE scoring_rules
--      SET rule_value = '"ceil"'::jsonb,
--          updated_at = now()
--    WHERE activity_id = 1 AND rule_key = 'half_completion_method';
--
-- 例如主辦方確認「小隊長計入、大隊長不計入」：
--   UPDATE scoring_rules
--      SET rule_value = '{"squad_leader": true, "team_leader": false}'::jsonb,
--          updated_at = now()
--    WHERE activity_id = 1 AND rule_key = 'include_leaders_in_average';
--
-- 例如主辦方確認「審計缺件預設請補件，不扣分」：
--   UPDATE scoring_rules
--      SET rule_value = '{"default_action": "request_supplement", "deduct_amount": 0}'::jsonb,
--          updated_at = now()
--    WHERE activity_id = 1 AND rule_key = 'audit_missing_item_action';
--
-- =====================================================
