-- =====================================================
-- 09-create-teams-squads.sql
-- 為「對齊主程式設計師 0425 版」change 重建 teams / squads 兩張主表
--
-- 適用 change：align-with-main-dev-0425
-- 產出時間：2026-04-25
--
-- 背景：
--   既有 teams / squads 表（建於更早 migration，原檔 02 已不在 repo）
--   schema 與 0425 主路線「大隊對照表」「小隊架構表」對不上：
--     - teams 缺 team_order（排名用）、form_label（LINE 來源）
--     - squads 缺 squad_code 前綴必須等於 teams.team_code 的約束
--   採 destructive 重建：DROP CASCADE → CREATE 新版 → 由 11 SQL 重新匯入
--
-- 執行順序：
--   09 (本檔，建空表) → 10 (改 members 型別) → 11 (匯入名單) → 12 (拆 PIN 殘餘)
-- =====================================================

BEGIN;


-- ========== Part 1: 拆掉相依物件（順序 reverse-dependency） ==========

-- 1.1 拆 view / function 先（它們可能 reference squads / teams / members）
DROP VIEW   IF EXISTS members_public CASCADE;
DROP FUNCTION IF EXISTS authenticate_member(TEXT, TEXT) CASCADE;

-- 1.2 拆 squads（依賴 teams）
DROP TABLE IF EXISTS squads CASCADE;

-- 1.3 拆 teams
DROP TABLE IF EXISTS teams CASCADE;
-- 注意：CASCADE 也會清掉 members.team_id / members.squad_id 的 FK constraint
--       members 表本身保留，10 SQL 會處理它的 id 型別變更


-- ========== Part 2: teams 主表 ==========

CREATE TABLE teams (
    id           BIGSERIAL PRIMARY KEY,
    team_code    TEXT      NOT NULL UNIQUE
                           CHECK (team_code ~ '^T[0-9]{2}$'),
    team_name    TEXT      NOT NULL,
    team_order   SMALLINT  NOT NULL CHECK (team_order BETWEEN 1 AND 50),
    leader_name  TEXT      NOT NULL,
    form_label   TEXT,
    is_active    BOOLEAN   NOT NULL DEFAULT true,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  teams IS
    '大隊主表（18 大隊）。對齊 0425 副本「大隊對照表」結構。';
COMMENT ON COLUMN teams.team_code   IS '大隊代號 T01-T18';
COMMENT ON COLUMN teams.team_name   IS '大隊命名 e.g. 嘉家久 / 乘願而行';
COMMENT ON COLUMN teams.team_order  IS '排名顯示順序 1-18';
COMMENT ON COLUMN teams.leader_name IS '大隊長暱稱 e.g. 平安 / 士騰';
COMMENT ON COLUMN teams.form_label  IS 'LINE 來源 / Form 名稱 e.g. （嘉義）平安，預留 Bot 整合';

CREATE INDEX idx_teams_active_order ON teams (team_order) WHERE is_active = true;


-- ========== Part 3: squads 主表 ==========

CREATE TABLE squads (
    id                 BIGSERIAL PRIMARY KEY,
    squad_code         TEXT      NOT NULL UNIQUE
                                 CHECK (squad_code ~ '^T[0-9]{3}$'),
    team_id            BIGINT    NOT NULL REFERENCES teams(id) ON DELETE RESTRICT,
    squad_leader_name  TEXT      NOT NULL,
    is_active          BOOLEAN   NOT NULL DEFAULT true,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE  squads IS '小隊主表（~76 小隊）。每個小隊隸屬一個 team。';
COMMENT ON COLUMN squads.squad_code        IS '小隊代號 T010-T184，前 3 碼必須等於 teams.team_code';
COMMENT ON COLUMN squads.squad_leader_name IS '小隊長姓名（denormalised 至 members.leader_name 供 UI 渲染）';

CREATE INDEX idx_squads_team ON squads (team_id);


-- ========== Part 4: squad_code 前綴與 team_code 一致性 trigger ==========
-- spec 要求：squad_code 前 3 碼必須等於關聯 teams 的 team_code
-- INSERT / UPDATE 時皆驗證

CREATE OR REPLACE FUNCTION enforce_squad_team_prefix()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_team_code TEXT;
BEGIN
    SELECT team_code INTO v_team_code FROM teams WHERE id = NEW.team_id;
    IF v_team_code IS NULL THEN
        RAISE EXCEPTION 'squads.team_id=% 找不到對應 teams', NEW.team_id;
    END IF;
    IF LEFT(NEW.squad_code, 3) <> v_team_code THEN
        RAISE EXCEPTION
            'squad_code 前綴 % 不等於 team_code %（squad_code=%）',
            LEFT(NEW.squad_code, 3), v_team_code, NEW.squad_code;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_squad_team_prefix
    BEFORE INSERT OR UPDATE OF squad_code, team_id ON squads
    FOR EACH ROW EXECUTE FUNCTION enforce_squad_team_prefix();


-- ========== Part 5: RLS policies ==========

ALTER TABLE teams  ENABLE ROW LEVEL SECURITY;
ALTER TABLE squads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "teams_read_all"  ON teams;
CREATE POLICY "teams_read_all"  ON teams  FOR SELECT USING (true);

DROP POLICY IF EXISTS "squads_read_all" ON squads;
CREATE POLICY "squads_read_all" ON squads FOR SELECT USING (true);

-- 寫入只給 service_role（無 INSERT / UPDATE / DELETE policy 即默認拒絕 anon/authenticated）


COMMIT;


-- ========== 驗證 ==========
DO $$
DECLARE
    v_team_count    BIGINT;
    v_squad_count   BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_team_count  FROM teams;
    SELECT COUNT(*) INTO v_squad_count FROM squads;
    RAISE NOTICE '✅ teams 表已建立（目前 % 筆，匯入由 11 SQL 進行）',  v_team_count;
    RAISE NOTICE '✅ squads 表已建立（目前 % 筆，匯入由 11 SQL 進行）', v_squad_count;
    RAISE NOTICE '✅ enforce_squad_team_prefix trigger 已套用';
    RAISE NOTICE '✅ RLS 已啟用（anon/authenticated 可 SELECT，寫入僅 service_role）';
    RAISE NOTICE '🚀 下一步：執行 10-alter-members-id-type.sql';
END $$;
