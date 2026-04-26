-- =====================================================
-- 12-remove-pin-auth.sql
-- 拆除 PIN 認證相關物件（防呆收尾）
--
-- 適用 change：align-with-main-dev-0425
-- 產出時間：2026-04-25
-- 主辦方決議：2026-04-25 不使用 PIN 碼登入
--
-- 大部分 PIN 拆除工作其實在 10 SQL 重建 members 表時已自然完成
-- 本檔的目的：
--   1. 防呆：確認 authenticate_member function 已拆除（10 已 DROP，這裡 IF EXISTS 安全）
--   2. 防呆：確認 members.pin_code 欄位已不存在（10 重建時自然不存在）
--   3. 拆掉任何遺漏的 RLS policy 或物件
--   4. 提供「PIN 已徹底移除」的 spec scenario 驗證 SQL
--
-- 執行順序：09 → 10 → 11 → 12 (本檔，最後一步)
-- =====================================================

BEGIN;


-- ========== Part 1: 拆除 authenticate_member function ==========
-- 用 CASCADE 一併拆掉任何依賴此 function 的物件
-- IF EXISTS 確保即使 10 SQL 已拆過，重跑本檔不會錯

DROP FUNCTION IF EXISTS authenticate_member(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS authenticate_member(BIGINT, TEXT) CASCADE;  -- 預防舊 BIGINT 簽章殘留


-- ========== Part 2: 拆除 members.pin_code 欄位（防呆） ==========
-- 10 SQL 重建 members 時已不含 pin_code，這裡 IF EXISTS 是雙重保險
-- 若該欄位真的存在，代表 10 沒重建成功 — DROP COLUMN 會把它拆掉

ALTER TABLE members DROP COLUMN IF EXISTS pin_code;


-- ========== Part 3: 拆除任何 reference pin_code 的 RLS policy ==========
-- 既有 policies（03-rls-and-auth.sql）沒有 reference pin_code，但保留邏輯防呆
-- pg_policies 找出 qual / with_check 字串含 'pin_code' 的 policy 並拆掉

DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT schemaname, tablename, policyname
          FROM pg_policies
         WHERE (qual LIKE '%pin_code%' OR with_check LIKE '%pin_code%')
    LOOP
        EXECUTE format(
            'DROP POLICY IF EXISTS %I ON %I.%I',
            rec.policyname, rec.schemaname, rec.tablename
        );
        RAISE NOTICE '🗑️  Dropped policy %.% reference pin_code',
                     rec.tablename, rec.policyname;
    END LOOP;
END $$;


COMMIT;


-- ========== 驗證（落實 spec PIN Authentication Removal scenarios） ==========
DO $$
DECLARE
    v_func_count   BIGINT;
    v_column_count BIGINT;
    v_policy_count BIGINT;
BEGIN
    -- spec scenario: Verifying PIN function is removed
    SELECT COUNT(*) INTO v_func_count
      FROM pg_proc
     WHERE proname = 'authenticate_member';
    IF v_func_count > 0 THEN
        RAISE EXCEPTION '❌ authenticate_member function 仍有 % 個 overload 殘留', v_func_count;
    END IF;

    -- spec scenario: Verifying PIN column is removed
    SELECT COUNT(*) INTO v_column_count
      FROM information_schema.columns
     WHERE table_name = 'members' AND column_name = 'pin_code';
    IF v_column_count > 0 THEN
        RAISE EXCEPTION '❌ members.pin_code 欄位仍存在';
    END IF;

    -- 額外：沒有 policy 還引用 pin_code
    SELECT COUNT(*) INTO v_policy_count
      FROM pg_policies
     WHERE qual LIKE '%pin_code%' OR with_check LIKE '%pin_code%';
    IF v_policy_count > 0 THEN
        RAISE EXCEPTION '❌ 仍有 % 個 RLS policy 引用 pin_code', v_policy_count;
    END IF;

    RAISE NOTICE '✅ authenticate_member function 已徹底拆除';
    RAISE NOTICE '✅ members.pin_code 欄位已徹底拆除';
    RAISE NOTICE '✅ 無任何 RLS policy 引用 pin_code';
    RAISE NOTICE '⚠️  下一步必做：重新執行 05-save-report-rpc.sql 重建 save_daily_report function';
    RAISE NOTICE '   （該 RPC 簽章已從 BIGINT 改 TEXT，舊版本已在 10 SQL 拆除）';
    RAISE NOTICE '🚀 12-remove-pin-auth.sql 完成';
END $$;
