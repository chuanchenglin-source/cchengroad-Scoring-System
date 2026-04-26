## Context

#### 為什麼需要 design.md

本 change 有 7 個獨立的技術決策必須在實作前定錨：

1. 密碼如何 hash（演算法、儲存欄位、PostgreSQL extension 依賴）
2. Session 模型（token vs per-call password verify vs cookie）
3. 第一筆 admin 怎麼來（bootstrap 機制與 git 存放策略）
4. 自鎖防呆規則的觸發點（RPC 內 vs application layer）
5. admin_credentials 與 members 的關係（FK 關聯 vs 完全獨立）
6. permission_matrix 與既有 v_squad_scope function 的銜接時程
7. Admin.html 內部分頁結構（單頁 + JS 切換 vs 多 HTML 檔）

任何一項做錯都會影響後續 Dashboard change 的可行性，design 在這裡作為避免「實作中才發現決策衝突」的定錨。

#### 既有架構限制

- `members.pin_code` 與 `authenticate_member` function 才剛在 `align-with-main-dev-0425` change 拆乾淨；本 change 引入新的密碼欄位必須**完全不污染 members 表**
- Apps Script Web App 沒有原生 server-side session 機制；UserProperties 是 per-Google-account scoped，3 個 admin 共用同一 sandbox 不適用；只能 client-side
- Supabase RLS + RPC SECURITY DEFINER 是既有模式，admin RPC 也走同樣模式
- pgcrypto extension 在 Supabase free tier 預設可啟用，無額外成本
- 進行中 change `add-scoring-rules-and-role-access` 還有 14 個 task 未完成，其中包括 `v_squad_scope` 套用到測試 Supabase 與最終 archive；本 change 不能修改該 change 的 spec 內容

#### 利害關係人

- **Johnson**：第一個 bootstrap admin、所有 SQL 透過 MCP `apply_migration` 執行、承擔 admin password 遺失風險
- **主程式設計師（陳啟林 / chuanchenglin@gmail.com）**：bootstrap 預設 admin_id 對象、未來可能成為實際使用 admin 的人之一
- **未來加入的後台維護者**（第 3+ 個 admin）：透過第一個 admin 從 UI 加入
- **一般 360+ 隊員**：完全不受本 change 影響（admin 後台是獨立入口、URL 帶 `?page=Admin` 才會看到）

## Goals / Non-Goals

**Goals:**

- 提供 3+ 人後台維運團隊「不寫 SQL 也能改規則」的能力
- 把硬編碼在 SQL function 裡的權限邏輯資料化（permission_matrix），未來可即時 toggle
- 為 Dashboard 開發鋪好「驗證身分 + 控管動作」的基礎，不在 Dashboard change 內重複造輪子
- 自鎖防呆讓 admin 即使誤操作也不會把系統鎖死

**Non-Goals:**

- 本 change 不引入 OAuth / SSO / Supabase Auth — 只做最簡單的密碼登入
- 本 change 不重構 v_squad_scope（既有 hardcoded CASE WHEN 維持原樣，等 add-scoring-rules-and-role-access archive 後再開新 change 處理）
- 本 change 不做 audit log（誰改了什麼）— 加 column 容易，但 UI 顯示與查詢功能擴大太多
- 本 change 不做密碼 reset email 流程
- 本 change 不對 admin RPC 做 rate limit（內部 3 人不需要）

## Decisions

### Decision 1: 密碼用 pgcrypto bcrypt 在資料庫端 hash

**選擇**：啟用 Supabase 的 `pgcrypto` extension，密碼存 `password_hash TEXT`，用 `crypt(password, gen_salt('bf'))` 寫入、用 `crypt(input, password_hash) = password_hash` 比對。

**為什麼**：

- bcrypt 是業界標準，內建 salt + 計算成本控制
- pgcrypto 是 PostgreSQL 內建 extension，Supabase free tier 一行 SQL 即可啟用
- hash 在資料庫端產生 = 前端不必載入 bcrypt JS library（少一個依賴 + 少一個攻擊面）
- `crypt(input, password_hash) = password_hash` 是 pgcrypto 標準比對寫法，timing-safe

**alternatives considered**：

- ❌ **前端 JS 用 bcryptjs hash**：增加 60KB+ 的 npm 依賴、Apps Script 引入第三方 lib 麻煩；前端拿到 plaintext 後 hash 再傳給後端跟「直接傳 plaintext + 後端 hash」安全性差不多（HTTPS 都加密了），但複雜度高很多
- ❌ **SHA256 + salt 自己實作**：bcrypt 內建的工作因子調整能力是 SHA256 沒有的；自己實作 salt 容易出錯
- ❌ **Argon2**：Supabase 預設 extension 沒有 Argon2，安裝麻煩；bcrypt 對內部 3 人團隊已足夠

**trade-off**：

- ⚠️ pgcrypto 的 bcrypt 計算成本固定（gen_salt('bf') 預設 cost=6），未來若需要提升要修改 RPC code

### Decision 2: Session 採「sessionStorage 存密碼 + 每次 RPC 重驗」

**選擇**：admin 登入成功後，前端把 `admin_id` 與**明文密碼**存進 `sessionStorage`（單一 tab 範圍）。每個 admin RPC（如 `admin_update_permission`）都把 `(admin_id, password)` 帶入，後端每次重 hash 比對。

**為什麼**：

- 完全不需要 token / session 表 / expire 機制
- sessionStorage 在 tab 關閉時自動清空，不會污染下次開啟
- HTTPS 確保密碼在傳輸過程不被竊聽
- 每次 RPC 重驗不會有「token 過期但前端不知道」的麻煩
- 內部 3 人團隊使用，不在公共電腦操作 → sessionStorage 風險可接受

**alternatives considered**：

- ❌ **JWT token + 24h expire**：要建 sessions 表、要做 expire 檢查、要做 refresh、要做 revoke...
- ❌ **Cookie session**：Apps Script Web App 的 cookie 機制混亂（iframe + cross-origin），會撞牆
- ❌ **One-time token + Supabase Realtime channel**：殺雞用牛刀
- ❌ **localStorage**：跨 tab 永久存活，比 sessionStorage 風險更高

**trade-off**：

- ⚠️ admin 在同一 device 與其他人共用瀏覽器 tab 時有風險 → 在 Admin.html 顯眼位置加「請使用無痕視窗」提示
- ⚠️ 每個 RPC 多一次 bcrypt 比對開銷（~50ms），可接受（管理動作不頻繁）

### Decision 3: 第一筆 admin 用 SQL bootstrap、檔案 gitignored

**選擇**：建立 `scripts/supabase-import/bootstrap-admin.sql.example` 範本（內含示範 INSERT，密碼欄位寫 `'__REPLACE_ME__'`），Johnson 複製為 `bootstrap-admin.sql` 填上真實密碼後跑一次。`bootstrap-admin.sql` 加入 `.gitignore` 不進版本控制。

**為什麼**：

- service_role 跑 INSERT 繞過 RLS，最簡單可靠
- example 檔在 git 裡，未來新環境可參照建立
- `bootstrap-admin.sql` gitignored = 真實密碼不會 leak 到 GitHub
- 第一筆建好後其餘 admin 都從 UI 加，不再需要直接寫 SQL

**alternatives considered**：

- ❌ **環境變數讀密碼**：Supabase SQL 沒有讀 env var 的乾淨機制
- ❌ **首次開 Admin.html 時引導建立**：要解決「沒有任何 admin 時誰有權建立」的雞生蛋問題，反而更複雜
- ❌ **寫死預設帳密在 SQL**（如 admin/admin）：第一個進入測試環境的人就是 admin，安全災難

**trade-off**：

- ⚠️ Johnson 要記得自己跑 bootstrap，且不能誤 commit `bootstrap-admin.sql`（gitignore 是防呆）

### Decision 4: 自鎖防呆寫在 RPC 內、用 PostgreSQL exception 拋出

**選擇**：兩條硬規則直接寫在 `admin_set_active` RPC 內，違反時 `RAISE EXCEPTION` 中止 transaction：
- 規則 A：`p_target_admin_id = p_acting_admin_id` → 拒絕「停用自己」
- 規則 B：`(SELECT COUNT(*) FROM admin_credentials WHERE is_active = true) <= 1 AND p_set_active = false` → 拒絕「停用最後一位 active admin」

前端收到 RPC error 時顯示「不能停用自己」「至少要保留 1 個 active admin」。

**為什麼**：

- 寫在 RPC 內 = 不論前端 UI 怎麼 bypass，都擋得住（前端純粹是友善訊息）
- PostgreSQL 在同一個 transaction 內 SELECT + UPDATE 是原子的，不會有「我看到 2 個 active 結果別人剛改成 1 個」的 race condition

**alternatives considered**：

- ❌ **CHECK constraint**：CHECK 不能跨 row 計算 COUNT
- ❌ **TRIGGER BEFORE UPDATE**：可以、但 trigger 邏輯散在多處難維護；統一在 RPC 入口管控比較清楚
- ❌ **前端 disabled button**：可被 DevTools bypass，不是真正的防呆

**trade-off**：

- ⚠️ 兩個 admin 同時點「停用對方」時，第二個會被擋（規則 B 觸發），這是預期行為

### Decision 5: admin_credentials 與 members 完全獨立、無 FK 關聯

**選擇**：`admin_credentials.admin_id` 是**自由字串**（如 `chuanchenglin@gmail.com` 或 `johnson` 或 `pm-helper`），與 `members.id` 完全無關。即使一個 admin 同時也是 member（例如 Johnson 也填表），兩邊各自有資料、不互相 reference。

**為什麼**：

- admin 是「維運帳號」、member 是「填表者身分」，邏輯層級不同；混用會讓「停用一個 admin」的語意變成「也要從 members 名單拿掉」嗎？這是一條混亂的路
- 主程式設計師可能根本不在 members 表（他不是親證班學員）
- admin_id 用 email 格式時，跟 members.id 的 `T011_周子維_嘉家久` 格式天差地遠，不會誤認

**alternatives considered**：

- ❌ **admin_id REFERENCES members(id)**：強迫 admin 必須是 member，牴觸主程式設計師案例
- ❌ **members 加 is_admin BOOLEAN + admin_password 欄位**：又把密碼放回剛拆乾淨的 members 表，反悔意味濃

**trade-off**：

- ⚠️ 同一個人可能 admin_credentials 與 members 表都各有一筆，名字要分別維護

### Decision 6: permission_matrix 表先建、暫不接 v_squad_scope（解耦）

**選擇**：本 change 建立 `permission_matrix` 表並 seed 預設權限矩陣資料；前端 Admin.html 提供 toggle UI；但**v_squad_scope function 維持原 hardcoded 邏輯**，不在本 change 內改寫成查 permission_matrix。

**為什麼**：

- 進行中的 `add-scoring-rules-and-role-access` change 還沒 archive、其 spec 還沒進 `openspec/specs/`，現在去 modify 會撞 Spectra 的 spec 模型
- 等 add-scoring-rules-and-role-access archive 完，另開 `refactor-role-scope-to-data-driven` change 把 v_squad_scope 改成讀 permission_matrix
- 解耦也讓本 change 範圍更聚焦：admin 後台基礎 + 矩陣 toggle UI 先上線（toggle 不會立刻影響行為，這是預期的）

**alternatives considered**：

- ❌ **本 change 連 v_squad_scope 一起改**：會撞既有 in-progress change，且本 change 範圍會超過 15 個 task
- ❌ **等 add-scoring-rules-and-role-access archive 後才開本 change**：admin 後台被卡很久，與 Johnson「現在就建立後台」的需求衝突

**trade-off**：

- ⚠️ permission_matrix 在「下一個 change refactor v_squad_scope 之前」對行為無實際影響 — toggle UI 會讓人誤以為改了會生效；UI 內加註「目前矩陣資料僅供未來重構參考，尚未實際生效」

### Decision 7: Admin.html 採單頁 + JS 切換分頁

**選擇**：所有 admin 功能放在**單一** `Admin.html`，內含 4 個 `<section>` + tab navigation 用 JS 切換顯示。不分成 `AdminPermissions.html` / `AdminRules.html` 等多檔。

**為什麼**：

- Apps Script Web App 每換 page 都要重新 doGet → 重新 fetch supabase-client → 重新登入驗證；多檔 = 重複 4 次相同流程
- 單頁 SPA-style 切換瞬時、共享同一個 sessionStorage 狀態
- 4 個分頁各自的 JS 邏輯雖然不同，但 share 共通的 `adminVerifyAndCall(rpc, params)` helper

**alternatives considered**：

- ❌ **多檔分頁**：上述 doGet 重複問題
- ❌ **動態 include subpage HTML**：Apps Script 的 `include('subpage')` 模式可行但會讓 Admin.html 結構複雜

**trade-off**：

- ⚠️ Admin.html 會比較長（預估 800+ 行），但結構清晰（4 個區塊 + 共用 helper）

## Risks / Trade-offs

#### Risk 1: 第一筆 admin 密碼忘記 + 沒有其他 active admin

- **觸發條件**：唯一一位 admin 改了密碼忘掉，或 bootstrap 後沒登入過就忘了密碼
- **影響**：無法登入後台、無法靠 UI 重設
- **Mitigation**：rollback 路徑明確 — 直接在 Supabase SQL Editor 跑 `UPDATE admin_credentials SET password_hash = crypt('新密碼', gen_salt('bf')) WHERE admin_id = '...'`；CLAUDE.md 的「管理後台」章節記下這個救援 SQL

#### Risk 2: sessionStorage 密碼洩漏

- **觸發條件**：admin 在公用電腦或共享瀏覽器登入後忘記關 tab、其他人開 DevTools 看到 sessionStorage
- **影響**：洩漏 admin 帳密
- **Mitigation**：Admin.html 顯眼位置加「⚠️ 請使用無痕視窗 / 用完請關閉瀏覽器」提示；CLAUDE.md 的「管理後台」章節同步寫；admin RPC 失敗時不洩漏「是 admin_id 錯還是 password 錯」

#### Risk 3: 自鎖規則被同時觸發的 race condition

- **觸發條件**：兩個 admin A B 同時各自點「停用對方」按鈕
- **影響**：理論上 A 把 B 停了、B 也把 A 停了 → active admin 數變 0 → 系統鎖死
- **Mitigation**：規則 B 在同一 transaction 內 SELECT COUNT 後 UPDATE，PostgreSQL 預設的 row-level lock 會讓第二個操作 wait + 重新 evaluate；最後一個 active admin 不會被停掉

#### Risk 4: pgcrypto extension 啟用失敗

- **觸發條件**：Supabase 環境問題或權限不足
- **影響**：13 SQL 跑不過、後續全部卡住
- **Mitigation**：13 SQL 開頭 `CREATE EXTENSION IF NOT EXISTS pgcrypto`；若失敗 Supabase Dashboard → Database → Extensions 手動啟用 pgcrypto；CLAUDE.md 記下這個 fallback

#### Risk 5: 前端誤把 sessionStorage 寫成 localStorage

- **觸發條件**：實作時打字錯
- **影響**：密碼跨 tab + 永久保留 = 安全降級
- **Mitigation**：tasks.md 內強調 sessionStorage 不是 localStorage；code review 時重點檢查；smoke test 包含「關 tab 重開應要求重登」

#### Risk 6: permission_matrix UI toggle 對行為無實效（Decision 6 的副作用）

- **觸發條件**：admin 切換某 toggle、預期立即生效但其實不會（要等下個 change refactor v_squad_scope）
- **影響**：誤以為功能壞掉
- **Mitigation**：權限切換分頁標題加大字「⚠️ 此分頁的 toggle 目前為設定預覽，實際權限仍由 v_squad_scope function 決定（將於下一個 change 接通）」

## Migration Plan

#### 部署順序（Johnson 在測試 Supabase 上手動執行）

```
1. git pull → 拿到 13、14 SQL 與前端 4 檔
2. apply_migration: 13-create-admin-credentials.sql  （含 pgcrypto 啟用）
3. apply_migration: 14-create-permission-matrix.sql  （含 seed 預設矩陣資料）
4. 複製 bootstrap-admin.sql.example → bootstrap-admin.sql
   填入真實密碼（chuanchenglin@gmail.com 為 admin_id）
5. execute_sql: 跑 bootstrap-admin.sql 一次
6. npm run push:dev 推送 Admin.html / supabase-client.html / webApp.js
7. 開測試 web app /exec?page=Admin → 用 chuanchenglin@gmail.com + 剛設密碼登入
8. 4 個分頁逐一 smoke test：
   - 權限切換：toggle 一格、確認後端 permission_matrix 有變
   - 計分規則：改一筆 rule_value、確認 scoring_rules 有變
   - 名單管理：把某 member role 從 'member' 改成 'squad_leader'、確認 members.role 有變
   - Admin 管理：加第二個 admin、登出 → 用第二個帳號登入、確認可進
9. 驗證自鎖：用 admin A 嘗試停用自己 → 應顯示錯誤；接著用 admin A 嘗試停用 admin B（剩 admin A）→ 應成功；再嘗試停用 admin A（變 0 active）→ 應顯示錯誤
```

#### 失敗時的 Rollback

| 階段 | Rollback 方式 |
|---|---|
| 13 SQL 失敗 | `DROP TABLE admin_credentials CASCADE; DROP EXTENSION pgcrypto`（pgcrypto 不影響其他物件） |
| 14 SQL 失敗 | `DROP TABLE permission_matrix CASCADE; DROP FUNCTION get_role_scope` |
| bootstrap-admin.sql 失敗 | 通常是 SQL 語法錯，修正後重跑（INSERT 失敗不影響表結構） |
| 前端推送失敗 | git revert + npm run pull:dev 把 Apps Script 拉回前一版 |
| 進入 Admin.html 但登入失敗 | 開 SQL Editor 跑 `SELECT admin_id, is_active FROM admin_credentials` 確認資料；用 救援 SQL 重設密碼 |

#### 整個 change 在 demo 階段執行，沒有「正式環境受影響」的後果。

## Open Questions

1. **admin_id 命名規範**：用 email（`chuanchenglin@gmail.com`）vs 用短 ID（`main-dev`）？本 change 採 email 格式（首位 admin = `chuanchenglin@gmail.com`），但若未來覺得太長可在 UI 加「顯示名」欄位。確認是否同意。

2. **scoring_rules 編輯 UI 的範圍**：14 筆 rule 中有 6 筆 rule_value 為 NULL（待主辦方確認）。UI 要讓 admin 可以「填入」或「修改」，還是只能修改已有值的 8 筆？建議**前者**（NULL 可變、變了還能改回 NULL），更彈性。

3. **名單管理分頁能否新增 / 刪除 member**：本 change 預設只支援「改 role」與「停用 / 啟用」。新增 member 走另開 change `add-roster-self-service` 處理（牽涉名單匯入流程）。確認是否同意。

4. **Admin 操作的 audit log**：列入 Non-Goals 暫不做，未來若需要追溯「誰改了什麼」要另開 change `add-admin-audit-log`。確認是否暫時可接受「沒人知道誰改的」。
