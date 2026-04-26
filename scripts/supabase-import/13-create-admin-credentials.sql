-- =====================================================
-- 13-create-admin-credentials.sql
-- 後台維運帳號的儲存、認證、自鎖防呆機制
--
-- 適用 change：add-admin-backend
-- 產出時間：2026-04-26
--
-- 對應 spec：openspec/changes/add-admin-backend/specs/admin-credentials/spec.md
--
-- 設計決策（design.md）：
--   - Decision 1: 密碼用 pgcrypto bcrypt 在資料庫端 hash
--   - Decision 4: 自鎖防呆寫在 RPC 內、用 PostgreSQL exception 拋出
--   - Decision 5: admin_credentials 與 members 完全獨立、無 FK 關聯
--
-- 前置條件：無（本檔可獨立執行；pgcrypto extension 由本檔啟用）
--
-- 執行順序：13 (本檔) → 14 → bootstrap-admin.sql
-- =====================================================

BEGIN;


-- ========== Part 1: 啟用 pgcrypto extension ==========
-- 提供 crypt() 與 gen_salt() 函式（bcrypt 雜湊用）

CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ========== Part 2: admin_credentials 表 ==========

DROP TABLE IF EXISTS admin_credentials CASCADE;

CREATE TABLE admin_credentials (
    id              BIGSERIAL PRIMARY KEY,
    admin_id        TEXT      NOT NULL UNIQUE,
    name            TEXT      NOT NULL,
    password_hash   TEXT      NOT NULL,
    is_active       BOOLEAN   NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_login_at   TIMESTAMPTZ
);

COMMENT ON TABLE admin_credentials IS
    '後台維運帳號。獨立於 members 表，admin_id 為自由字串（如 email 或短代碼）。'
    'password_hash 為 pgcrypto bcrypt 格式（$2 開頭）。';
COMMENT ON COLUMN admin_credentials.admin_id      IS '登入用識別字串，如 chuanchenglin@gmail.com 或 johnson';
COMMENT ON COLUMN admin_credentials.password_hash IS 'bcrypt hash via crypt(plaintext, gen_salt(''bf''))';
COMMENT ON COLUMN admin_credentials.is_active     IS 'false 即無法登入；自鎖規則保證至少留 1 個 true';
COMMENT ON COLUMN admin_credentials.last_login_at IS '由 admin_login 成功時更新';

CREATE INDEX idx_admin_credentials_active ON admin_credentials (admin_id) WHERE is_active = true;


-- ========== Part 3: RLS — 全拒絕，只允許 SECURITY DEFINER RPC ==========
-- 不建任何 policy = anon/authenticated 完全無法直接 SELECT/INSERT/UPDATE/DELETE

ALTER TABLE admin_credentials ENABLE ROW LEVEL SECURITY;

-- 故意不建任何 policy。SECURITY DEFINER RPC 以 owner（service_role）身份繞過 RLS。


-- ========== Part 4: admin_login RPC ==========
-- spec scenario：
--   - 成功：回傳 1 筆 (admin_id, name)，更新 last_login_at
--   - 失敗（id 錯 / 密碼錯 / inactive）：回傳 0 筆，不區分失敗原因
-- 防 enumeration：失敗時也跑一次 dummy bcrypt 避免 timing attack 推測 admin_id 是否存在

DROP FUNCTION IF EXISTS admin_login(TEXT, TEXT);

CREATE OR REPLACE FUNCTION admin_login(
    p_admin_id   TEXT,
    p_password   TEXT
)
RETURNS TABLE(admin_id TEXT, name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_dummy_hash TEXT := '$2a$06$abcdefghijklmnopqrstuuLT7YGN1lXUPiM4nNV.ZFcpL/3BnAXk6';
BEGIN
    -- 第一階段：找出 active 且密碼相符的 row（用標準 bcrypt 比對）
    -- 找不到 → 也跑一次 dummy crypt 確保 timing 一致（防 admin_id enumeration）
    IF NOT EXISTS (
        SELECT 1 FROM admin_credentials ac
         WHERE ac.admin_id = p_admin_id
           AND ac.is_active = true
           AND ac.password_hash = crypt(p_password, ac.password_hash)
    ) THEN
        -- 補一次 dummy crypt 讓 timing 與成功 path 接近
        PERFORM crypt(p_password, v_dummy_hash);
        RETURN;
    END IF;

    -- 第二階段：更新 last_login_at + 回傳 admin info
    UPDATE admin_credentials
       SET last_login_at = now()
     WHERE admin_credentials.admin_id = p_admin_id
       AND admin_credentials.is_active = true
       AND admin_credentials.password_hash = crypt(p_password, admin_credentials.password_hash);

    RETURN QUERY
        SELECT ac.admin_id, ac.name
          FROM admin_credentials ac
         WHERE ac.admin_id = p_admin_id
           AND ac.is_active = true;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_login(TEXT, TEXT) TO anon, authenticated;

COMMENT ON FUNCTION admin_login(TEXT, TEXT) IS
    '驗證 admin 密碼。成功回傳 1 筆 (admin_id, name) 並更新 last_login_at；失敗回傳 0 筆且不區分失敗原因。';


-- ========== Part 5: admin_verify RPC ==========
-- 給其他 admin RPC 當守門用：true=驗證通過、false=驗證失敗
-- 呼叫者收到 false 應 RAISE EXCEPTION 中止

DROP FUNCTION IF EXISTS admin_verify(TEXT, TEXT);

CREATE OR REPLACE FUNCTION admin_verify(
    p_admin_id  TEXT,
    p_password  TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM admin_credentials
         WHERE admin_id = p_admin_id
           AND is_active = true
           AND password_hash = crypt(p_password, password_hash)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_verify(TEXT, TEXT) TO anon, authenticated;

COMMENT ON FUNCTION admin_verify(TEXT, TEXT) IS
    '檢查 admin 密碼是否正確且 active；true=通過、false=拒絕。其他 admin RPC 呼叫此函式作守門。';


-- ========== Part 6: admin_list_admins RPC ==========
-- 列出所有 admin（不含 password_hash）

DROP FUNCTION IF EXISTS admin_list_admins(TEXT, TEXT);

CREATE OR REPLACE FUNCTION admin_list_admins(
    p_acting_admin_id  TEXT,
    p_acting_password  TEXT
)
RETURNS TABLE(
    admin_id      TEXT,
    name          TEXT,
    is_active     BOOLEAN,
    created_at    TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    IF NOT admin_verify(p_acting_admin_id, p_acting_password) THEN
        RAISE EXCEPTION '未通過 admin 驗證';
    END IF;

    RETURN QUERY
        SELECT ac.admin_id, ac.name, ac.is_active, ac.created_at, ac.last_login_at
          FROM admin_credentials ac
         ORDER BY ac.created_at;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_list_admins(TEXT, TEXT) TO anon, authenticated;


-- ========== Part 7: admin_create RPC ==========

DROP FUNCTION IF EXISTS admin_create(TEXT, TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION admin_create(
    p_acting_admin_id  TEXT,
    p_acting_password  TEXT,
    p_new_admin_id     TEXT,
    p_new_name         TEXT,
    p_new_password     TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    IF NOT admin_verify(p_acting_admin_id, p_acting_password) THEN
        RAISE EXCEPTION '未通過 admin 驗證';
    END IF;
    IF p_new_admin_id IS NULL OR length(trim(p_new_admin_id)) = 0 THEN
        RAISE EXCEPTION '新 admin_id 不可為空';
    END IF;
    IF p_new_password IS NULL OR length(p_new_password) < 4 THEN
        RAISE EXCEPTION '新密碼長度至少 4 字元';
    END IF;

    INSERT INTO admin_credentials (admin_id, name, password_hash, is_active)
    VALUES (
        p_new_admin_id,
        COALESCE(p_new_name, p_new_admin_id),
        crypt(p_new_password, gen_salt('bf')),
        true
    );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_create(TEXT, TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;


-- ========== Part 8: admin_change_password RPC ==========
-- 任何 active admin 可改任何 admin（含自己）的密碼

DROP FUNCTION IF EXISTS admin_change_password(TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION admin_change_password(
    p_acting_admin_id  TEXT,
    p_acting_password  TEXT,
    p_target_admin_id  TEXT,
    p_new_password     TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    IF NOT admin_verify(p_acting_admin_id, p_acting_password) THEN
        RAISE EXCEPTION '未通過 admin 驗證';
    END IF;
    IF p_new_password IS NULL OR length(p_new_password) < 4 THEN
        RAISE EXCEPTION '新密碼長度至少 4 字元';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM admin_credentials WHERE admin_id = p_target_admin_id) THEN
        RAISE EXCEPTION '找不到目標 admin: %', p_target_admin_id;
    END IF;

    UPDATE admin_credentials
       SET password_hash = crypt(p_new_password, gen_salt('bf'))
     WHERE admin_id = p_target_admin_id;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_change_password(TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;


-- ========== Part 9: admin_set_active RPC（含自鎖防呆 Rule A + B）==========

DROP FUNCTION IF EXISTS admin_set_active(TEXT, TEXT, TEXT, BOOLEAN);

CREATE OR REPLACE FUNCTION admin_set_active(
    p_acting_admin_id  TEXT,
    p_acting_password  TEXT,
    p_target_admin_id  TEXT,
    p_set_active       BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_active_count BIGINT;
BEGIN
    IF NOT admin_verify(p_acting_admin_id, p_acting_password) THEN
        RAISE EXCEPTION '未通過 admin 驗證';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM admin_credentials WHERE admin_id = p_target_admin_id) THEN
        RAISE EXCEPTION '找不到目標 admin: %', p_target_admin_id;
    END IF;

    -- Rule A：不能停用自己
    IF p_set_active = false AND p_target_admin_id = p_acting_admin_id THEN
        RAISE EXCEPTION '不能停用自己';
    END IF;

    -- Rule B：不能讓 active admin 數歸 0
    -- 鎖 row 後 SELECT COUNT 確保 race-safe
    IF p_set_active = false THEN
        SELECT COUNT(*) INTO v_active_count
          FROM admin_credentials
         WHERE is_active = true
         FOR UPDATE;
        IF v_active_count <= 1 THEN
            RAISE EXCEPTION '至少要保留 1 個 active admin';
        END IF;
    END IF;

    UPDATE admin_credentials
       SET is_active = p_set_active
     WHERE admin_id = p_target_admin_id;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_set_active(TEXT, TEXT, TEXT, BOOLEAN) TO anon, authenticated;


-- ========== Part 10: 業務 admin RPCs（給其他分頁用）==========
--   admin_update_scoring_rule  — 計分規則編輯
--   admin_set_member_role      — 名單管理 / 改 role
--   admin_set_member_active    — 名單管理 / 停用啟用
-- 全部開頭 admin_verify 守門

DROP FUNCTION IF EXISTS admin_update_scoring_rule(TEXT, TEXT, TEXT, JSONB);

CREATE OR REPLACE FUNCTION admin_update_scoring_rule(
    p_acting_admin_id  TEXT,
    p_acting_password  TEXT,
    p_rule_key         TEXT,
    p_rule_value       JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    IF NOT admin_verify(p_acting_admin_id, p_acting_password) THEN
        RAISE EXCEPTION '未通過 admin 驗證';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM scoring_rules WHERE rule_key = p_rule_key AND activity_id = 1) THEN
        RAISE EXCEPTION '找不到 rule_key: %', p_rule_key;
    END IF;

    -- 不寫 updated_by：scoring_rules.updated_by 是 BIGINT REFERENCES members(id)，
    -- 但 admin_id 是 email/短代碼不在 members 表（Decision 5: admin 與 members 完全獨立）。
    -- 暫不追蹤誰改的；未來若要 audit log 屬另一個 change（已列 Non-Goal）。
    UPDATE scoring_rules
       SET rule_value = p_rule_value,
           updated_at = now()
     WHERE rule_key = p_rule_key
       AND activity_id = 1;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_update_scoring_rule(TEXT, TEXT, TEXT, JSONB) TO anon, authenticated;


DROP FUNCTION IF EXISTS admin_set_member_role(TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION admin_set_member_role(
    p_acting_admin_id  TEXT,
    p_acting_password  TEXT,
    p_member_id        TEXT,
    p_new_role         TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    IF NOT admin_verify(p_acting_admin_id, p_acting_password) THEN
        RAISE EXCEPTION '未通過 admin 驗證';
    END IF;
    IF p_new_role NOT IN ('member','squad_leader','team_leader','auditor','admin','executive') THEN
        RAISE EXCEPTION '無效的 role: %', p_new_role;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM members WHERE id = p_member_id) THEN
        RAISE EXCEPTION '找不到 member: %', p_member_id;
    END IF;

    UPDATE members SET role = p_new_role WHERE id = p_member_id;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_set_member_role(TEXT, TEXT, TEXT, TEXT) TO anon, authenticated;


DROP FUNCTION IF EXISTS admin_set_member_active(TEXT, TEXT, TEXT, BOOLEAN);

CREATE OR REPLACE FUNCTION admin_set_member_active(
    p_acting_admin_id  TEXT,
    p_acting_password  TEXT,
    p_member_id        TEXT,
    p_is_active        BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    IF NOT admin_verify(p_acting_admin_id, p_acting_password) THEN
        RAISE EXCEPTION '未通過 admin 驗證';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM members WHERE id = p_member_id) THEN
        RAISE EXCEPTION '找不到 member: %', p_member_id;
    END IF;

    UPDATE members SET is_active = p_is_active WHERE id = p_member_id;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_set_member_active(TEXT, TEXT, TEXT, BOOLEAN) TO anon, authenticated;


COMMIT;


-- ========== 驗證 ==========
DO $$
DECLARE
    v_pgcrypto_enabled BOOLEAN;
    v_table_exists     BOOLEAN;
    v_login_exists     BOOLEAN;
    v_verify_exists    BOOLEAN;
    v_rpc_count        BIGINT;
BEGIN
    SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto')
      INTO v_pgcrypto_enabled;
    IF NOT v_pgcrypto_enabled THEN
        RAISE EXCEPTION '❌ pgcrypto extension 未啟用';
    END IF;

    SELECT EXISTS (SELECT 1 FROM information_schema.tables
                    WHERE table_name = 'admin_credentials')
      INTO v_table_exists;
    IF NOT v_table_exists THEN
        RAISE EXCEPTION '❌ admin_credentials 表未建立';
    END IF;

    SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'admin_login')
      INTO v_login_exists;
    SELECT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'admin_verify')
      INTO v_verify_exists;
    IF NOT v_login_exists OR NOT v_verify_exists THEN
        RAISE EXCEPTION '❌ admin_login / admin_verify function 未建立';
    END IF;

    SELECT COUNT(*) INTO v_rpc_count
      FROM pg_proc
     WHERE proname IN ('admin_login','admin_verify','admin_list_admins','admin_create',
                       'admin_change_password','admin_set_active','admin_update_scoring_rule',
                       'admin_set_member_role','admin_set_member_active');
    IF v_rpc_count <> 9 THEN
        RAISE EXCEPTION '❌ 預期 9 個 admin_* RPC 實際 %', v_rpc_count;
    END IF;

    RAISE NOTICE '✅ pgcrypto extension 已啟用';
    RAISE NOTICE '✅ admin_credentials 表已建立 + RLS enabled (no policies)';
    RAISE NOTICE '✅ 9 個 admin RPC 已建立並 grant execute to anon';
    RAISE NOTICE '🚀 下一步：執行 14-create-permission-matrix.sql';
END $$;
