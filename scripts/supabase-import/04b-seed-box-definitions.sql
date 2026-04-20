-- =====================================================
-- 04b-seed-box-definitions.sql
-- 依 main.html 現有 40 格結構建立 box_definitions + box_options 主資料
--
-- 執行前置：04-normalize-schema.sql 已執行完畢
-- 產出時間：2026-04-20
-- =====================================================

BEGIN;

-- 清空舊資料（避免重複 INSERT 衝突）
TRUNCATE box_options, box_definitions RESTART IDENTITY CASCADE;


-- ========== box_definitions 40 筆 ==========

INSERT INTO box_definitions (box_no, week_no, category, title, note, input_type, multi_select, max_score) VALUES
-- ---- 每日定課（全期，不綁週次）----
(1,  NULL, '主修',    '每日打拳定課',     '任選一項即得 10 分，每日上限 10 分',                                                   'checkbox', false, 10),
(2,  NULL, '選修',    '每日選修定課',     '勾選一項得 10 分，每日上限 20 分',                                                     'checkbox', true,  20),

-- ---- 主題親證（W2-W8）----
(3,  2,    '主題親證', 'W2天使通話',        '本週上限 60 分',                                                                        'checkbox', true,  60),
(4,  3,    '主題親證', 'W3行動方案',        '開訓當天電影行動方案，請放小組記事本，大隊長05/21 12:00PM前繳回，本週限 1 次，得 10 分', 'checkbox', true,  10),
(5,  3,    '主題親證', 'W3親證分享文',      '150字以上，本週限 1 次，得 20 分',                                                      'checkbox', true,  20),
(6,  3,    '主題親證', 'W3心得回饋+行動方案','100字以上，本週限 2 次，得 20 分',                                                      'checkbox', true,  20),
(7,  3,    '主題親證', 'W3天使通話',        '主題：鼓勵親證，本週上限 10 分',                                                        'checkbox', true,  10),
(8,  4,    '主題親證', 'W4天使通話',        '主題：鼓勵接觸大自然，本週上限 10 分',                                                  'checkbox', true,  10),
(9,  4,    '主題親證', 'W4接地體驗',        '接觸大自然+拍照記錄，本週上限 10 分',                                                   'checkbox', true,  10),
(10, 4,    '主題親證', 'W4心得回饋+行動方案','100字以上，本週限 2 次，得 20 分',                                                      'checkbox', true,  20),
(11, 4,    '主題親證', 'W4定課回顧分享文',  '300字以上，或錄影2.5-3分鐘，本週限 1 次，得 20 分',                                      'checkbox', true,  20),
(12, 5,    '主題親證', 'W5天使通話',        '本週上限 10 分',                                                                        'checkbox', true,  10),
(13, 5,    '主題親證', 'W5心得回饋+行動方案','100字以上，本週限 2 次，得 20 分',                                                      'checkbox', true,  20),
(14, 5,    '主題親證', 'W5持續力親證',      '每項15分，得 30 分',                                                                    'checkbox', true,  30),
(15, 6,    '主題親證', 'W6天使通話',        '本週上限 10 分',                                                                        'checkbox', true,  10),
(16, 6,    '主題親證', 'W6穿越黑暗、完成影片錄製', '本週上限 50 分',                                                                 'checkbox', true,  50),
(17, 7,    '主題親證', 'W7天使通話',        '本週上限 10 分',                                                                        'checkbox', true,  10),
(18, 7,    '主題親證', 'W7三道菜分享+回饋', '本週上限 50 分',                                                                        'checkbox', true,  50),
(19, 7,    '主題親證', 'W7破冰加碼三道菜',  '上限10分',                                                                              'checkbox', false, 10),
(20, 8,    '主題親證', 'W8天使通話',        '本週上限 30 分',                                                                        'checkbox', true,  30),

-- ---- 加分題（全期）----
(21, NULL, '加分題', '聯誼會會籍有效期',   '依有效期給分 (20~100分)',                                                               'checkbox', false, 10),
(22, NULL, '加分題', '報名【高階課程】',   '完款得 100 分 / 5000元訂金 得 50 分',                                                   'checkbox', true,  1000),
(23, NULL, '加分題', '傳愛完款',           '完款 1 位得 100 分！無上限（填人數與姓名）',                                            'mixed',    true,  0),
(24, NULL, '加分題', '傳愛訂金',           '5000元訂金 1 位得 50 分！無上限（填人數與姓名）',                                       'mixed',    true,  0),
(25, NULL, '加分題', '報名【進階課程】',   '含複訓，1堂課得 50 分',                                                                 'checkbox', true,  100),

-- ---- 加分題 placeholder（規則未定）----
(26, NULL, '加分題', '加分題1',            NULL, 'score_only', true, 0),
(27, NULL, '加分題', '加分題2',            NULL, 'score_only', true, 0),
(28, NULL, '加分題', '加分題3',            NULL, 'score_only', true, 0),
(29, NULL, '加分題', '加分題4',            NULL, 'score_only', true, 0),
(30, NULL, '加分題', '加分題5',            NULL, 'score_only', true, 0),
(31, NULL, '加分題', '加分題6',            NULL, 'score_only', true, 0),
(32, NULL, '加分題', '加分題7',            NULL, 'score_only', true, 0),
(33, NULL, '加分題', '加分題8',            NULL, 'score_only', true, 0),
(34, NULL, '加分題', '加分題9',            NULL, 'score_only', true, 0),
(35, NULL, '加分題', '加分題10',           NULL, 'score_only', true, 0),
(36, NULL, '加分題', '加分題11',           NULL, 'score_only', true, 0),
(37, NULL, '加分題', '加分題12',           NULL, 'score_only', true, 0),
(38, NULL, '加分題', '加分題13',           NULL, 'score_only', true, 0),
(39, NULL, '加分題', '加分題14',           NULL, 'score_only', true, 0),
(40, NULL, '加分題', '加分題15',           NULL, 'score_only', true, 0);


-- ========== box_options ==========
-- 透過 box_no 查回 id，確保順序不依賴 BIGSERIAL 值

-- Box 1: 每日打拳定課（單選）
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, '打拳', 10, 1 FROM box_definitions WHERE box_no = 1 AND activity_id = 1
UNION ALL
SELECT id, '當下之舞（僅限未學過打拳者）', 10, 2 FROM box_definitions WHERE box_no = 1 AND activity_id = 1;

-- Box 2: 每日選修定課（多選）
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, lbl, 10, ord FROM box_definitions,
  (VALUES ('丹氣慢跑', 1), ('五感恩', 2), ('觀心書', 3), ('大悲咒', 4), ('吃素一天', 5)) AS o(lbl, ord)
WHERE box_no = 2 AND activity_id = 1;

-- Box 3: W2 天使通話
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, lbl, sv, ord FROM box_definitions,
  (VALUES
    ('完成天使通話+截圖', 10, 1),
    ('心得分享-150字以上', 20, 2),
    ('回饋自己小天使+完成自己行動方案-100字以上', 15, 3),
    ('回饋別組夥伴+完成自己行動方案-100字以上', 15, 4)
  ) AS o(lbl, sv, ord)
WHERE box_no = 3 AND activity_id = 1;

-- Box 4: W3 行動方案
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, '完成行動方案，並放在小組記事本中', 10, 1 FROM box_definitions WHERE box_no = 4 AND activity_id = 1;

-- Box 5: W3 親證分享文
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, '完成親證分享文', 20, 1 FROM box_definitions WHERE box_no = 5 AND activity_id = 1;

-- Box 6: W3 心得回饋+行動方案
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, lbl, 10, ord FROM box_definitions,
  (VALUES ('回饋自己小天使+完成自己行動方案', 1), ('回饋別組夥伴+完成自己行動方案', 2)) AS o(lbl, ord)
WHERE box_no = 6 AND activity_id = 1;

-- Box 7: W3 天使通話
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, '完成天使通話+截圖', 10, 1 FROM box_definitions WHERE box_no = 7 AND activity_id = 1;

-- Box 8: W4 天使通話
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, '完成天使通話+截圖+接觸大自然的照片', 10, 1 FROM box_definitions WHERE box_no = 8 AND activity_id = 1;

-- Box 9: W4 接地體驗
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, '完成接地體驗+拍照記錄', 10, 1 FROM box_definitions WHERE box_no = 9 AND activity_id = 1;

-- Box 10: W4 心得回饋
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, lbl, 10, ord FROM box_definitions,
  (VALUES ('回饋自己小天使+完成自己行動方案', 1), ('回饋別組夥伴+完成自己行動方案', 2)) AS o(lbl, ord)
WHERE box_no = 10 AND activity_id = 1;

-- Box 11: W4 定課回顧分享文
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, '完成定課回顧分享', 20, 1 FROM box_definitions WHERE box_no = 11 AND activity_id = 1;

-- Box 12: W5 天使通話
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, '完成天使通話+截圖', 10, 1 FROM box_definitions WHERE box_no = 12 AND activity_id = 1;

-- Box 13: W5 心得回饋
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, lbl, 10, ord FROM box_definitions,
  (VALUES ('回饋自己小天使+完成自己行動方案', 1), ('回饋別組夥伴+完成自己行動方案', 2)) AS o(lbl, ord)
WHERE box_no = 13 AND activity_id = 1;

-- Box 14: W5 持續力親證
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, lbl, 15, ord FROM box_definitions,
  (VALUES ('卡關地方，再嘗試走一步', 1), ('已經很棒的地方，看見自己的光', 2)) AS o(lbl, ord)
WHERE box_no = 14 AND activity_id = 1;

-- Box 15: W6 天使通話
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, '完成天使通話+截圖', 10, 1 FROM box_definitions WHERE box_no = 15 AND activity_id = 1;

-- Box 16: W6 穿越黑暗
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, '完成自己的影片錄製+上傳小群', 50, 1 FROM box_definitions WHERE box_no = 16 AND activity_id = 1;

-- Box 17: W7 天使通話
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, '完成天使通話+截圖', 10, 1 FROM box_definitions WHERE box_no = 17 AND activity_id = 1;

-- Box 18: W7 三道菜
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, lbl, sv, ord FROM box_definitions,
  (VALUES ('完成三道菜', 30, 1), ('完成心得分享', 10, 2), ('回饋反思', 10, 3)) AS o(lbl, sv, ord)
WHERE box_no = 18 AND activity_id = 1;

-- Box 19: W7 破冰加碼三道菜（單選 radio）
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, lbl, 10, ord FROM box_definitions,
  (VALUES ('和父親完成', 1), ('和母親完成', 2), ('和師長完成', 3), ('和上級完成', 4), ('和關係陷入瓶頸者完成', 5)) AS o(lbl, ord)
WHERE box_no = 19 AND activity_id = 1;

-- Box 20: W8 天使通話
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, lbl, 10, ord FROM box_definitions,
  (VALUES
    ('完成天使通話+截圖', 1),
    ('心得分享-150字以上', 2),
    ('回饋自己小天使+完成自己行動方案-100字以上', 3)
  ) AS o(lbl, ord)
WHERE box_no = 20 AND activity_id = 1;

-- Box 21: 聯誼會會籍（單選 radio）
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, lbl, 10, ord FROM box_definitions,
  (VALUES
    ('超過115/12/31', 1),
    ('116/6/30-116/12/31', 2),
    ('超過116/12/31', 3)
  ) AS o(lbl, ord)
WHERE box_no = 21 AND activity_id = 1;

-- Box 22: 報名高階課程（多選）
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, lbl, sv, ord FROM box_definitions,
  (VALUES
    ('完款「二階」', 100, 1),
    ('完款「三階」', 100, 2),
    ('完款「四階」', 100, 3),
    ('賀！「五階」完款！', 100, 4),
    ('完款「五運班」', 100, 5),
    ('「二階」訂金5000元', 50, 6),
    ('「三階」訂金5000元', 50, 7),
    ('「四階」訂金5000元', 50, 8),
    ('「五階」訂金5000元', 50, 9),
    ('「五運班」訂金5000元', 50, 10)
  ) AS o(lbl, sv, ord)
WHERE box_no = 22 AND activity_id = 1;

-- Box 23/24: 傳愛完款/訂金（mixed，number+text，沒有選項；略）

-- Box 25: 報名進階課程
INSERT INTO box_options (box_definition_id, option_label, score_value, display_order)
SELECT id, lbl, 50, ord FROM box_definitions,
  (VALUES ('已報名「生命蛻變」', 1), ('已報名「生命數字」', 2)) AS o(lbl, ord)
WHERE box_no = 25 AND activity_id = 1;


COMMIT;


-- ========== 驗證 ==========
DO $$
DECLARE
    def_count INTEGER;
    checkbox_without_options INTEGER;
BEGIN
    SELECT COUNT(*) INTO def_count FROM box_definitions WHERE activity_id = 1;
    IF def_count <> 40 THEN
        RAISE EXCEPTION '❌ box_definitions 筆數不對：預期 40，實際 %', def_count;
    END IF;
    RAISE NOTICE '✅ box_definitions 共 % 筆', def_count;

    -- 檢查 checkbox 類型 box 是否都至少有一筆 options（排除 Box 23/24 的 mixed 類型 與 26-40 placeholder）
    SELECT COUNT(*) INTO checkbox_without_options
    FROM box_definitions d
    WHERE d.activity_id = 1
      AND d.input_type = 'checkbox'
      AND NOT EXISTS (SELECT 1 FROM box_options o WHERE o.box_definition_id = d.id);
    IF checkbox_without_options > 0 THEN
        RAISE EXCEPTION '❌ 有 % 個 checkbox 類 box 缺選項', checkbox_without_options;
    END IF;
    RAISE NOTICE '✅ 所有 checkbox 類 box 皆有對應選項';

    RAISE NOTICE '🚀 下一步：執行 05-save-report-rpc.sql 建立 atomic 寫入 function';
END $$;
