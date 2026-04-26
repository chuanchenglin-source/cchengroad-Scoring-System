-- =====================================================
-- 05-save-report-rpc.sql
-- save_daily_report: atomic 寫入 daily_reports + items + item_options
--
-- 呼叫方式（前端 supabase-js）：
--   await sb.rpc('save_daily_report', {
--     p_member_id: 'T011_周子維_嘉家久',
--     p_activity_id: 1,
--     p_report_date: '2026-05-03',
--     p_total_score: 250,
--     p_remarks: null,
--     p_items: [
--       { box_definition_id: 1, score: 10, content_text: null,  selected_option_ids: [5] },
--       { box_definition_id: 2, score: 20, content_text: null,  selected_option_ids: [8, 9] },
--       { box_definition_id: 23, score: 0, content_text: '王小明,李小花', selected_option_ids: [] }
--     ]
--   });
--
-- 回傳：新建立的 daily_reports.id (BIGINT)
--
-- 產出時間：2026-04-20
-- 2026-04-25 修改（change：align-with-main-dev-0425）：
--   - p_member_id 由 BIGINT 改 TEXT（對應 members.id 改 TEXT）
--   - 新增 member 存在性檢查並 raise exception
-- =====================================================

-- 拆掉所有可能殘留的舊簽章（含 BIGINT 版本以防止重跑時 ambiguous）
DROP FUNCTION IF EXISTS save_daily_report(BIGINT, BIGINT, DATE, INTEGER, TEXT, JSONB);
DROP FUNCTION IF EXISTS save_daily_report(TEXT,   BIGINT, DATE, INTEGER, TEXT, JSONB);

CREATE OR REPLACE FUNCTION save_daily_report(
    p_member_id    TEXT,
    p_activity_id  BIGINT,
    p_report_date  DATE,
    p_total_score  INTEGER,
    p_remarks      TEXT,
    p_items        JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_report_id BIGINT;
    v_item      JSONB;
    v_item_id   BIGINT;
    v_option_id BIGINT;
    v_member_exists BOOLEAN;
BEGIN
    -- 基本驗證
    IF p_member_id IS NULL OR length(trim(p_member_id)) = 0 THEN
        RAISE EXCEPTION '缺少 member_id';
    END IF;
    IF p_report_date IS NULL THEN
        RAISE EXCEPTION '缺少 report_date';
    END IF;
    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
        RAISE EXCEPTION 'p_items 必須是 JSONB array';
    END IF;

    -- 驗證 member_id 存在於 members 表（明確錯誤訊息，避免 FK 違反時的隱晦錯誤）
    SELECT EXISTS (SELECT 1 FROM members WHERE id = p_member_id)
      INTO v_member_exists;
    IF NOT v_member_exists THEN
        RAISE EXCEPTION '找不到 member_id: %', p_member_id;
    END IF;

    -- 1. 寫入 daily_reports 主紀錄
    INSERT INTO daily_reports (member_id, activity_id, report_date, total_score, remarks)
    VALUES (p_member_id, COALESCE(p_activity_id, 1), p_report_date, COALESCE(p_total_score, 0), p_remarks)
    RETURNING id INTO v_report_id;

    -- 2. 逐筆展開 p_items 寫入 daily_report_items 與 daily_report_item_options
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        -- 每筆 item 寫入 daily_report_items
        INSERT INTO daily_report_items (
            report_id,
            box_definition_id,
            score,
            content_text
        ) VALUES (
            v_report_id,
            (v_item->>'box_definition_id')::BIGINT,
            COALESCE((v_item->>'score')::INTEGER, 0),
            v_item->>'content_text'
        )
        RETURNING id INTO v_item_id;

        -- 展開 selected_option_ids，寫入 junction 表
        IF (v_item ? 'selected_option_ids')
           AND jsonb_typeof(v_item->'selected_option_ids') = 'array' THEN
            FOR v_option_id IN
                SELECT (jsonb_array_elements_text(v_item->'selected_option_ids'))::BIGINT
            LOOP
                INSERT INTO daily_report_item_options (item_id, option_id)
                VALUES (v_item_id, v_option_id);
            END LOOP;
        END IF;
    END LOOP;

    RETURN v_report_id;

    -- PL/pgSQL 函式本身即為一個 atomic transaction；
    -- 任何 INSERT 失敗（FK 違反、UNIQUE 違反等）都會自動 rollback 整個呼叫，
    -- 不會有部分 item / option 殘留。
EXCEPTION
    WHEN OTHERS THEN
        -- 包成可讀性較好的例外訊息，向上拋出（前端會收到 RPC error）
        RAISE EXCEPTION 'save_daily_report 失敗：% (SQLSTATE %)', SQLERRM, SQLSTATE;
END;
$$;

-- 授權 anon 與 authenticated 角色可呼叫
GRANT EXECUTE ON FUNCTION save_daily_report(TEXT, BIGINT, DATE, INTEGER, TEXT, JSONB)
    TO anon, authenticated;

COMMENT ON FUNCTION save_daily_report IS
    'Atomic 寫入一筆 daily_report + N 筆 daily_report_items + M 筆 daily_report_item_options。任一失敗整筆 rollback。回傳新 daily_reports.id。p_member_id 為 TEXT 格式 <squad_code>_<name>_<team_name>，會驗證存在於 members 表。';
