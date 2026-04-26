-- =====================================================
-- 04-normalize-schema.sql
-- Level 3 BCNF 正規化：將 daily_reports.box_data (JSONB) 展開成四張關聯表
--
-- 執行順序：
--   1. 先執行本檔（建表 + 索引 + RLS + 移除 box_data）
--   2. 再執行 04b-seed-box-definitions.sql（INSERT 40 筆 box 定義與選項）
--   3. 最後執行 05-save-report-rpc.sql（建立 atomic 寫入 function）
--
-- 產出時間：2026-04-20
-- 變更紀錄：openspec/changes/normalize-daily-report-schema/
-- 2026-04-25 修改：audited_by 由 BIGINT 改 TEXT（對應 members.id 改 TEXT）
--                 變更紀錄：openspec/changes/align-with-main-dev-0425/
-- =====================================================

BEGIN;


-- ========== Part 0: Drop if exists (safety zone，允許重複執行) ==========
-- 順序 reverse-dependency：先 junction，再 items，再 options，再 definitions
DROP TABLE IF EXISTS daily_report_item_options CASCADE;
DROP TABLE IF EXISTS daily_report_items CASCADE;
DROP TABLE IF EXISTS box_options CASCADE;
DROP TABLE IF EXISTS box_definitions CASCADE;


-- ========== Part 1: box_definitions（box 元資料） ==========
-- 取代原本寫死在 main.html 的 box 標題/週次/類型資訊
CREATE TABLE box_definitions (
    id             BIGSERIAL PRIMARY KEY,
    activity_id    BIGINT      NOT NULL DEFAULT 1,      -- 多活動預留（不設 FK）
    box_no         SMALLINT    NOT NULL CHECK (box_no BETWEEN 1 AND 40),
    week_no        SMALLINT    CHECK (week_no BETWEEN 1 AND 8), -- nullable: NULL 表示「全期 / 不綁週次」
    category       TEXT        CHECK (category IN ('主修', '選修', '主題親證', '加分題')),
    title          TEXT        NOT NULL,
    note           TEXT,                                 -- 填表頁顯示在標題下方的說明
    input_type     TEXT        NOT NULL
                               CHECK (input_type IN ('score_only', 'checkbox', 'text', 'mixed')),
    multi_select   BOOLEAN     NOT NULL DEFAULT true,    -- false = radio（單選 UI），true = checkbox（多選 UI）
    max_score      INTEGER     NOT NULL DEFAULT 0 CHECK (max_score >= 0),
    is_active      BOOLEAN     NOT NULL DEFAULT true,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (activity_id, box_no)
);

COMMENT ON TABLE box_definitions IS 'Box 元資料主表：每個活動有 40 筆';
COMMENT ON COLUMN box_definitions.activity_id IS '多活動預留；本次不建 activities 表，所有資料 default 1';
COMMENT ON COLUMN box_definitions.week_no IS 'NULL 表示不綁定週次（如每日定課、全期加分題）';
COMMENT ON COLUMN box_definitions.multi_select IS 'true=checkbox 多選 UI, false=radio 單選 UI';


-- ========== Part 2: box_options（勾選類 box 的選項） ==========
-- 用於 input_type IN ('checkbox', 'mixed') 且有選項的 box
CREATE TABLE box_options (
    id                 BIGSERIAL PRIMARY KEY,
    box_definition_id  BIGINT      NOT NULL REFERENCES box_definitions(id) ON DELETE CASCADE,
    option_label       TEXT        NOT NULL,
    score_value        INTEGER     NOT NULL DEFAULT 0 CHECK (score_value >= 0),
    display_order      SMALLINT    NOT NULL DEFAULT 0,
    is_active          BOOLEAN     NOT NULL DEFAULT true,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE box_options IS '勾選類 box 的選項，一個 box 多筆';
COMMENT ON COLUMN box_options.score_value IS '單勾此選項可得分數（填表頁分數計算參考用）';


-- ========== Part 3: daily_report_items（每格回報資料） ==========
-- 取代 daily_reports.box_data JSONB
-- 審計欄位（audit_*）為審計官逐格審核功能預留
CREATE TABLE daily_report_items (
    id                  BIGSERIAL PRIMARY KEY,
    report_id           BIGINT      NOT NULL REFERENCES daily_reports(id) ON DELETE CASCADE,
    box_definition_id   BIGINT      NOT NULL REFERENCES box_definitions(id),
    score               INTEGER     NOT NULL DEFAULT 0 CHECK (score >= 0),
    content_text        TEXT,                               -- 純文字類 / 混合類填此欄
    audit_status        TEXT        NOT NULL DEFAULT 'pending'
                                    CHECK (audit_status IN ('pending', 'approved', 'rejected')),
    audited_by          TEXT        REFERENCES members(id),
    audited_at          TIMESTAMPTZ,
    audit_notes         TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (report_id, box_definition_id)
);

COMMENT ON TABLE daily_report_items IS '每份 daily_report 展開成最多 40 筆 item';
COMMENT ON COLUMN daily_report_items.audit_status IS '審計官審核狀態：pending / approved / rejected';
COMMENT ON COLUMN daily_report_items.content_text IS '純文字類或混合類 box 的自由文字內容';


-- ========== Part 4: daily_report_item_options（勾選選項 junction） ==========
CREATE TABLE daily_report_item_options (
    item_id    BIGINT NOT NULL REFERENCES daily_report_items(id) ON DELETE CASCADE,
    option_id  BIGINT NOT NULL REFERENCES box_options(id),
    PRIMARY KEY (item_id, option_id)
);

COMMENT ON TABLE daily_report_item_options IS '勾選類 box 實際勾選的選項，一個 item 多筆';


-- ========== Part 5: daily_reports 擴充欄位 ==========
-- 新增 activity_id 預留欄位
ALTER TABLE daily_reports ADD COLUMN IF NOT EXISTS activity_id BIGINT NOT NULL DEFAULT 1;

COMMENT ON COLUMN daily_reports.activity_id IS '多活動預留；本次不建 activities 表';

-- 說明：本次「不」在 daily_reports 加 UNIQUE (member_id, report_date)
--       因為現有邏輯允許同一人同一天多次提交，getPersonalHistory 只保留最新
--       若未來要改為「每天唯一」，屬於另一個 change，需同時定義覆蓋語意


-- ========== Part 6: 查詢索引 ==========
CREATE INDEX IF NOT EXISTS idx_box_definitions_activity_box
    ON box_definitions(activity_id, box_no);

CREATE INDEX IF NOT EXISTS idx_box_options_definition
    ON box_options(box_definition_id);

CREATE INDEX IF NOT EXISTS idx_daily_report_items_report
    ON daily_report_items(report_id);

CREATE INDEX IF NOT EXISTS idx_daily_report_items_box_def
    ON daily_report_items(box_definition_id);

CREATE INDEX IF NOT EXISTS idx_daily_report_item_options_item
    ON daily_report_item_options(item_id);


-- ========== Part 7: RLS（Row-Level Security）==========
-- Demo 階段政策：較寬鬆，方便前端用 anon key 操作
-- 正式上線前會另開 change 收緊（例如改用 authenticated + member_id 驗證）

-- 7.1 box_definitions：所有人可讀
ALTER TABLE box_definitions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "box_definitions_read_all" ON box_definitions;
CREATE POLICY "box_definitions_read_all" ON box_definitions
    FOR SELECT USING (true);

-- 7.2 box_options：所有人可讀
ALTER TABLE box_options ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "box_options_read_all" ON box_options;
CREATE POLICY "box_options_read_all" ON box_options
    FOR SELECT USING (true);

-- 7.3 daily_report_items：demo 允許讀寫
--     注意：實際寫入路徑是透過 save_daily_report RPC（SECURITY DEFINER）
--     這裡開放 INSERT 是避免未來有需要直接寫入的場景被 RLS 擋住
--     TODO（另開 change）：正式上線前改為 WITH CHECK (report_id 對應的 member_id = auth.uid)
ALTER TABLE daily_report_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "daily_report_items_read_all" ON daily_report_items;
CREATE POLICY "daily_report_items_read_all" ON daily_report_items
    FOR SELECT USING (true);
DROP POLICY IF EXISTS "daily_report_items_insert_all" ON daily_report_items;
CREATE POLICY "daily_report_items_insert_all" ON daily_report_items
    FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "daily_report_items_update_all" ON daily_report_items;
CREATE POLICY "daily_report_items_update_all" ON daily_report_items
    FOR UPDATE USING (true) WITH CHECK (true);

-- 7.4 daily_report_item_options：demo 允許讀寫
ALTER TABLE daily_report_item_options ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "daily_report_item_options_read_all" ON daily_report_item_options;
CREATE POLICY "daily_report_item_options_read_all" ON daily_report_item_options
    FOR SELECT USING (true);
DROP POLICY IF EXISTS "daily_report_item_options_insert_all" ON daily_report_item_options;
CREATE POLICY "daily_report_item_options_insert_all" ON daily_report_item_options
    FOR INSERT WITH CHECK (true);


-- ========== Part 8: 移除舊 JSONB 欄位 ==========
-- 確認所有新表建立完畢後再移除
ALTER TABLE daily_reports DROP COLUMN IF EXISTS box_data;


COMMIT;


-- ========== 完成訊息 ==========
DO $$
BEGIN
    RAISE NOTICE '✅ Part 1: box_definitions 表已建立（含 week_no 可空、multi_select 旗標）';
    RAISE NOTICE '✅ Part 2: box_options 表已建立';
    RAISE NOTICE '✅ Part 3: daily_report_items 表已建立（含 audit_* 預留欄位）';
    RAISE NOTICE '✅ Part 4: daily_report_item_options junction 表已建立';
    RAISE NOTICE '✅ Part 5: daily_reports 新增 activity_id 預留欄位';
    RAISE NOTICE '✅ Part 6: 查詢索引已建立';
    RAISE NOTICE '✅ Part 7: RLS policies 已套用（demo 階段寬鬆，正式上線前需收緊）';
    RAISE NOTICE '✅ Part 8: daily_reports.box_data JSONB 欄位已移除';
    RAISE NOTICE '🚀 下一步：執行 04b-seed-box-definitions.sql 建立 box 主資料';
END $$;
