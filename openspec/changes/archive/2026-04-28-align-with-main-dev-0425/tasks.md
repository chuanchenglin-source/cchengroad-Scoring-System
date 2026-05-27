## 1. SQL — 建表 + 改 members.id 型別

- [x] 1.1 撰寫 `scripts/supabase-import/09-create-teams-squads.sql`：建立 Teams Master Table 與 Squads Master Table（Decision 2: teams + squads 兩張獨立表，不使用 self-referencing members），含 RLS policies 與 squad_code 前綴 CHECK
- [x] 1.2 撰寫 `scripts/supabase-import/10-alter-members-id-type.sql`：TRUNCATE daily_reports / daily_report_items / daily_report_item_options CASCADE、DROP 既有 FK、ALTER COLUMN 落實 Member Identifier as Composite Text Key（Decision 1: members.id 採用 TEXT `T011_周子維_嘉家久` 格式）並新增 Members Squad Foreign Key column
- [x] 1.3 從 0425 副本「人員總表」抽取 360+ 名單，產出 `scripts/supabase-import/11-import-real-roster.sql` 落實 Real Roster Import Migration（idempotent、結尾 RAISE NOTICE 報筆數）— 實際 418 筆，由 `/tmp/gen-roster-sql.py` 自動生成
- [x] 1.4 執行 1.3 前先跑同小隊同名檢查 SQL（`SELECT squad_code, name, COUNT(*) FROM raw_roster GROUP BY 1,2 HAVING COUNT(*) > 1`），有衝突就在 ID 後面加流水號（Risk 1）並回報 Johnson — **檢查結果：0 筆衝突，Risk 1 解除**

## 2. SQL — 拆 PIN 與既有 schema 連動修改

- [x] 2.1 撰寫 `scripts/supabase-import/12-remove-pin-auth.sql` 落實 PIN Authentication Removal（Decision 3: 拆 PIN 採「直接刪除」而非 deprecation）：DROP FUNCTION authenticate_member CASCADE、ALTER TABLE members DROP COLUMN pin_code、清掉相關 RLS policies
- [x] 2.2 修改 `scripts/supabase-import/04-normalize-schema.sql` 與 `05-save-report-rpc.sql`：反映 Daily Report Item Storage 新欄位型別（audited_by TEXT）與 Atomic Daily Report Write via RPC 的 p_member_id TEXT 簽章；加入 member 存在性檢查並 raise exception

## 3. 套用 SQL 到測試 Supabase（依嚴格順序）

- [x] 3.1 依 Decision 4: SQL 執行順序：先建新表 → 改 members 型別 → 匯入名單 → 刪 PIN，依序透過 MCP `apply_migration` 或 Supabase SQL Editor 套用 09 → 10 → 11 → 12
- [x] 3.2 套用 12 後**重新執行 05-save-report-rpc.sql** 重建 save_daily_report function（簽章已改 TEXT，10 SQL 已拆掉舊 BIGINT 版本）
- [x] 3.3 每步檢查 RAISE NOTICE 輸出；最後跑 `SELECT COUNT(*)` 驗證 teams=18、squads≥70、members≥360 — 實測 teams=18 / squads=76 / members=418 / orphan=0
- [x] 3.4 驗證 PIN 已徹底拆除：`SELECT proname FROM pg_proc WHERE proname='authenticate_member'` 與 `SELECT column_name FROM information_schema.columns WHERE table_name='members' AND column_name='pin_code'` 都應回 0 筆 — 實測兩者皆 0、save_daily_report 簽章=`p_member_id text`

## 4. 前端 — supabase-client.html 改寫

- [x] 4.1 落實 Decision 5: 前端 PIN 拆除採「整段刪除 supabase-client 的 authenticate 函式」 — 移除 `scoringAPI.authenticate(name, pin)`，並依 Client-Side Member Search Identification 新增 client-side datalist filter（重用既有 `getMemberList()`，不新增 RPC）
- [x] 4.2 更新 `scoringAPI.saveReport(payload)` 與 `scoringAPI.getPersonalHistory(memberId)`：memberId 改 TEXT 並加格式檢查，對齊 Submission via Client API 與 History Retrieval via Join 的 spec

## 5. 前端 — Index.html 改寫

- [x] 5.1 移除 PIN input 區塊；新增 `<input type="text" list="nameList">` + `<datalist id="nameList">`，照 Client-Side Member Search Identification 規格載入 360+ 人選項
- [x] 5.2 選定 member 後顯示 team_code、team_name、name、squad_leader_name、leader_name 確認區塊
- [x] 5.3 跳轉 main / history 時帶 URL params id/name/team/teamCode（URL-encoded），落實 URL Parameter Trust Model

## 6. 前端 — main.html 改寫

- [x] 6.1 落實 Decision 7: main.html 日期選擇器改為「當週 7 天」 — 重寫 `initDatePicker`，根據今天算當週週日後渲染 7 個日期按鈕
- [x] 6.2 移除 main.html 內任何 PIN 重新驗證殘留程式碼 — 原本就無 PIN 邏輯；改 `parseInt(memberId)` 為直接用 TEXT `user.id`，並從 webApp.js doGet 移除冗餘 `memberId` template var
- [x] 6.3 確認 `webApp.js doGet(e)` 已從 URL params 注入 `user.id / name / team / teamCode` 到 main.html template — URL Parameter Trust Model 端到端串通

## 7. 前端 — history.html 重寫

- [x] 7.1 落實 Decision 6: history.html 套用主路線「W1-W7 切換 + 卡片每日表格」結構 — 頂部 sticky header 含 W1-W7 按鈕、每週切換時渲染 7 天 × 40 box 卡片（既有實作已對齊，本次只更新 memberId 為 TEXT）
- [x] 7.2 套用主路線綠色航海主題 CSS（`#059669` primary green、`#facc15` accent yellow）與字體 1.15rem 提升年長使用者可讀性 — 既有實作已對齊

## 8. 推送與 smoke test

- [x] 8.1 `npm run env:status` 確認【測試】DEV，`npm run push:dev` 推送 supabase-client.html / Index.html / main.html / history.html 4 個檔案 — 推 9 個檔案成功（含 webApp.js / config.js / helper.js / schedule.js / appsscript.json）
- [x] 8.2 手動 smoke test：開 web app → datalist 載入 360 人 → 搜尋姓名 → 跳轉 main → 填表提交 → 跳 history 看到剛填紀錄 — Johnson 2026-04-26 完成測試。Bonus 改動：依使用者反饋將 datalist 排序從「依姓名」改為「依 squad_code 再依姓名」
- [x] 8.3 驗證 daily_reports 寫入：`SELECT member_id, report_date FROM daily_reports ORDER BY submitted_at DESC LIMIT 5`，member_id 應為 TEXT 格式 `T<NNN>_<姓名>_<隊名>` — 實測寫入 `T122_林泉成_婕個厲害` total=85，7 個 items 加總=85（atomic 寫入正確），7 個 selected options 進 junction 表

## 9. 風險檢查與文件更新

- [x] 9.1 風險檢查（Risk 3）：`grep -rn "scoringAPI.authenticate\|pin_code\|authenticate_member" .` 確認前端與 SQL 無 PIN 殘留 — Index.html 殘留為 view 註解（intentional）；03-rls-and-auth.sql 加 SUPERSEDED header；其他匹配為 spec/design/SQL DROP 語句（intentional）
- [x] 9.2 更新 `CLAUDE.md`「技術架構」章節：補上 `teams` / `squads` 表與 `members.id` 新格式、移除 PIN 相關描述
- [x] 9.3 更新 `CLAUDE.md`「技術債」章節第 3 點：「PIN 明文存」改為「PIN 已拆除（2026-04-25 主辦方決議）」

## 10. Open Questions 處置

- [x] 10.1 確認 Open Question 1（同小隊同名衝突）的處理結果並記錄到 design.md 末尾或 archive 時並入 spec — 實測 0 筆衝突，已記錄於 11-import-real-roster.sql 的 header
- [x] 10.2 評估 Open Question 2（teams.form_label 是否值得建）— 已決議「先建空欄位」，於 1.1 SQL 落實
- [x] 10.3 執行前確認 Open Question 3（demo daily_reports 可丟）— 跑 `SELECT COUNT(*) FROM daily_reports` 留檔記到 PR 描述。實測 = 2 筆（4/21 demo 試填、total=20），Johnson 確認可丟，已 TRUNCATE
- [x] 10.4 執行 Open Question 4 決議：本 change 內同步更新 CLAUDE.md（已列為 9.2、9.3）
