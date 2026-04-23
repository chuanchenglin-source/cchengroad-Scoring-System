-- =====================================================
-- 心成親證班回報系統 — scoring_rules 表與 get_rule 函式
-- 初稿日期：2026-04-21（基於當時 7 個待確認問題）
-- 最後更新：2026-04-23（依 2026-04-22 LINE 答案 + 2026-04-23 參考資訊 Sheet 整合）
-- 對應 change：add-scoring-rules-and-role-access
-- 用途：
--   1. 建立 scoring_rules 表，把所有可調計分規則從代碼搬到資料
--   2. 建立 get_rule(activity_id, rule_key) helper function
--   3. Seed 14 筆 rule_key（7 筆原 LINE 問題 + 6 筆 2026-04-23 新增待確認項 + 1 筆衍生）
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
                       'team_bonus', 'leadership', 'audit', 'ranking',
                       'completion', 'weekly', 'personal', 'external_course'
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


-- ========== Part 4: Seed 14 筆 rule_key ==========
-- A. 原 LINE 7 問（2026-04-21 提出、2026-04-22 大多已答）：Q1-Q3c
-- B. W8 領袖加分（從 4/22 Q1 答案衍生）
-- C. 2026-04-23 新增 6 筆待確認項：U1-U6
--
-- 已答的填入 rule_value（2026-04-22 LINE 回覆）；未答的留 NULL 等主辦方確認後 UPDATE

INSERT INTO scoring_rules (activity_id, rule_key, rule_value, description, category) VALUES

-- ---------- A. 原 LINE 7 問 ----------

(
    1,
    'w7_leadership_bonus_enabled',
    'true'::jsonb,
    '第七週還有領袖通話加分嗎？（Q1 已答 2026-04-22：W7、W8 都有；但具體加分金額仍待確認，見 leader_call_bonus_amounts）',
    'leadership'
),
(
    1,
    'full_completion_definition',
    '{"min_per_person": 270, "composition": "保底 210 + 主題 60"}'::jsonb,
    '全完成的定義（Q2a 已答 2026-04-22：每隊每人需達當週最高分「保底 210 + 主題 60 = 270」）',
    'completion'
),
(
    1,
    'team_bonus_target',
    '"individual"'::jsonb,
    '團隊動能加分是加到個人還是整組團隊總分？（Q2b 已答：每個達成的人個別加分）',
    'team_bonus'
),
(
    1,
    'half_completion_method',
    '"ceil"'::jsonb,
    '團隊半數認列（Q2c 已答 2026-04-22：無條件進位，7 人隊 3 人算過半）',
    'team_bonus'
),
(
    1,
    'team_ranking_method',
    '"average"'::jsonb,
    '團隊排名用總分還是平均分？（Q3a 已答：平均分）',
    'ranking'
),
(
    1,
    'include_leaders_in_average',
    '{"squad_leader": true, "team_leader": true}'::jsonb,
    '小隊長和大隊長是否要計入團隊總分？（Q3b 已答 2026-04-22：大小隊長均要計入，以身作則）',
    'ranking'
),
(
    1,
    'audit_missing_item_action',
    '{"default_action": "manual_report_to_organizer", "deduct_amount": 0}'::jsonb,
    '審計官缺件處理（Q3c 已答 2026-04-22：扣分屬特殊案例，在群組跟主辦方回報，由主辦方協助處理，系統不自動扣分）',
    'audit'
),

-- ---------- B. 從 Q1 衍生：W8 領袖加分 ----------

(
    1,
    'w8_leadership_bonus_enabled',
    'true'::jsonb,
    'W8 領袖通話加分（從 4/22 Q1 答案衍生：第七、八週都有加分）',
    'leadership'
),

-- ---------- C. 2026-04-23 新增 6 筆待確認項 ----------

(
    1,
    'weekly_total_scores',
    NULL,
    'W1-W8 每週總分（U1+U2 待確認：LINE 原文 W4/W5/W6 寫 210 但加起來應為 270；W7 寫 270-280 但算起來應為 280-290；預期 value 為 [210, 270, 270, 270, 270, 270, 290, 240]）',
    'weekly'
),
(
    1,
    'leader_call_bonus_amounts',
    NULL,
    '領袖通話加分具體金額（U3 待確認：LINE 原文標「分數待確認」；預期 value 為 {"team_leader": <金額>, "squad_leader": <金額>}；加在團隊分數上）',
    'leadership'
),
(
    1,
    'icebreaking_bonus',
    NULL,
    '破冰加碼 +10 是否仍有效？（U4 待確認：舊 CLAUDE.md 有記錄、2026-04-23 新資料未提；預期 value 為 {"enabled": true|false, "amount": 10}）',
    'personal'
),
(
    1,
    'retraining_scoring',
    NULL,
    '高階複訓是否計分？（U5 待確認：舊 CLAUDE.md 寫「不計分」、2026-04-23 新資料卻列「生命蛻變/數字含複訓」，規則衝突；預期 value 為 {"high_level": true|false, "advanced_courses_include": true|false}）',
    'external_course'
),
(
    1,
    'auditor_allocation',
    NULL,
    '審計官人數與分配方式（U6 待確認：已知「小隊長跨隊互審」但每大隊配幾個審計官不明；預期 value 為 {"mode": "cross_squad_peer_review", "per_team_count": <number>}）',
    'audit'
),

-- ---------- D. 副本加分項目（2026-04-23 新資訊，已有明確數值，直接 seed）----------

(
    1,
    'extra_course_bonus',
    '{"angel_league": {"expire_after_115_12_31": 20, "expire_116_06_30_to_116_12_31": 50, "expire_after_116_12_31": 100}, "advanced_course": {"high_level_paid_full": 100, "pass_love_paid_full": 100, "high_level_deposit": 50, "pass_love_deposit": 50}, "advanced_courses": {"life_transform": 50, "life_numerology": 50}, "post_class_full_attendance": 500}'::jsonb,
    '副本加分項目（2026-04-23 新資訊）：聯誼會會籍、高階及傳愛大課、進階課程、參與課後課全勤。注意 retraining_scoring 是否 OK 仍待確認（見 U5）。',
    'external_course'
);


-- ========== Part 5: 驗證 ==========

DO $$
DECLARE
    v_rule_count  INTEGER;
    v_ranking     JSONB;
    v_half        JSONB;
    v_bonus       JSONB;
    v_full        JSONB;
    v_weekly      JSONB;
BEGIN
    SELECT COUNT(*) INTO v_rule_count FROM scoring_rules WHERE activity_id = 1;
    IF v_rule_count <> 14 THEN
        RAISE EXCEPTION '❌ scoring_rules seed 預期 14 筆，實際 %', v_rule_count;
    END IF;

    v_ranking := get_rule(1, 'team_ranking_method');
    IF v_ranking IS NULL OR v_ranking #>> '{}' <> 'average' THEN
        RAISE EXCEPTION '❌ get_rule(1, team_ranking_method) 預期 "average"，實際 %', v_ranking;
    END IF;

    v_half := get_rule(1, 'half_completion_method');
    IF v_half IS NULL OR v_half #>> '{}' <> 'ceil' THEN
        RAISE EXCEPTION '❌ get_rule(1, half_completion_method) 預期 "ceil"（4/22 已答），實際 %', v_half;
    END IF;

    v_bonus := get_rule(1, 'team_bonus_target');
    IF v_bonus IS NULL OR v_bonus #>> '{}' <> 'individual' THEN
        RAISE EXCEPTION '❌ get_rule(1, team_bonus_target) 預期 "individual"，實際 %', v_bonus;
    END IF;

    v_full := get_rule(1, 'full_completion_definition');
    IF v_full IS NULL OR (v_full->>'min_per_person')::INTEGER <> 270 THEN
        RAISE EXCEPTION '❌ get_rule(1, full_completion_definition).min_per_person 預期 270，實際 %', v_full;
    END IF;

    v_weekly := get_rule(1, 'weekly_total_scores');
    IF v_weekly IS NOT NULL THEN
        RAISE EXCEPTION '❌ get_rule(1, weekly_total_scores) 預期 NULL（U1/U2 待確認），實際 %', v_weekly;
    END IF;

    RAISE NOTICE '✅ scoring_rules 共 % 筆（應為 14：7 原問 + 1 衍生 + 6 新待確認 + 1 副本加分）', v_rule_count;
    RAISE NOTICE '✅ get_rule(team_ranking_method) = %', v_ranking;
    RAISE NOTICE '✅ get_rule(half_completion_method) = % （4/22 已答）', v_half;
    RAISE NOTICE '✅ get_rule(team_bonus_target) = %', v_bonus;
    RAISE NOTICE '✅ get_rule(full_completion_definition).min_per_person = 270 （4/22 已答）';
    RAISE NOTICE '✅ get_rule(weekly_total_scores) = NULL（如預期，U1/U2 待確認）';
    RAISE NOTICE '🚀 06-scoring-rules.sql 執行完成（2026-04-23 更新版）';
END $$;


COMMIT;


-- =====================================================
-- 主辦方確認剩餘 U1-U6 問題後的 UPDATE 範例（不在本腳本執行）
-- =====================================================
--
-- U1/U2 — W1-W8 每週總分確認後：
--   UPDATE scoring_rules
--      SET rule_value = '[210, 270, 270, 270, 270, 270, 290, 240]'::jsonb,
--          updated_at = now()
--    WHERE activity_id = 1 AND rule_key = 'weekly_total_scores';
--
-- U3 — 領袖通話加分金額（假設大隊長 +200、小隊長 +100）：
--   UPDATE scoring_rules
--      SET rule_value = '{"team_leader": 200, "squad_leader": 100}'::jsonb,
--          updated_at = now()
--    WHERE activity_id = 1 AND rule_key = 'leader_call_bonus_amounts';
--
-- U4 — 破冰加碼仍有效：
--   UPDATE scoring_rules
--      SET rule_value = '{"enabled": true, "amount": 10}'::jsonb,
--          updated_at = now()
--    WHERE activity_id = 1 AND rule_key = 'icebreaking_bonus';
--
-- U5 — 高階複訓計分規則：
--   UPDATE scoring_rules
--      SET rule_value = '{"high_level": false, "advanced_courses_include": true}'::jsonb,
--          updated_at = now()
--    WHERE activity_id = 1 AND rule_key = 'retraining_scoring';
--
-- U6 — 審計官配置：
--   UPDATE scoring_rules
--      SET rule_value = '{"mode": "cross_squad_peer_review", "per_team_count": 1}'::jsonb,
--          updated_at = now()
--    WHERE activity_id = 1 AND rule_key = 'auditor_allocation';
--
-- =====================================================
