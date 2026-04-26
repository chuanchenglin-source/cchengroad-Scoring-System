## 1. SQL — admin_credentials 表與認證 RPCs

- [x] 1.1 撰寫 `scripts/supabase-import/13-create-admin-credentials.sql` Part 1：`CREATE EXTENSION IF NOT EXISTS pgcrypto`、建立 Admin Credentials Storage 表（落實 Decision 1: 密碼用 pgcrypto bcrypt 在資料庫端 hash 與 Decision 5: admin_credentials 與 members 完全獨立、無 FK 關聯），含 RLS enable + no-policy
- [x] 1.2 13 SQL Part 2：實作 Admin Login RPC `admin_login(admin_id, password)` SECURITY DEFINER + 更新 last_login_at
- [x] 1.3 13 SQL Part 3：實作 Admin Verify RPC `admin_verify(admin_id, password) RETURNS BOOLEAN`
- [x] 1.4 13 SQL Part 4：實作 Admin CRUD RPCs（admin_list_admins / admin_create / admin_change_password / admin_set_active），全數開頭呼叫 admin_verify，Admin Self-Protection Rules 寫在 admin_set_active 內（落實 Decision 4: 自鎖防呆寫在 RPC 內、用 PostgreSQL exception 拋出）
- [x] 1.5 13 SQL Part 5：實作 admin_update_scoring_rule / admin_set_member_role / admin_set_member_active 三個業務 RPC，皆 admin_verify 守門
- [x] 1.6 13 SQL 結尾驗證 DO block：確認 pgcrypto 已 enabled、admin_credentials 表已建、所有 RPC 已 grant execute to anon

## 2. SQL — permission_matrix 表

- [x] 2.1 撰寫 `scripts/supabase-import/14-create-permission-matrix.sql` Part 1：建立 Permission Matrix Table + UNIQUE(role, capability) + RLS read-all
- [x] 2.2 14 SQL Part 2：執行 Default Permission Matrix Seed（≥30 筆覆蓋 read_scores / submit_report / audit_items / manage_scoring_rules / manage_roster 五個 capability）
- [x] 2.3 14 SQL Part 3：實作 Get Role Scope Helper Function `get_role_scope(role, capability) RETURNS TEXT STABLE`
- [x] 2.4 14 SQL Part 4：實作 Admin Update Permission RPC `admin_update_permission(...)` + admin_verify 守門
- [x] 2.5 14 SQL Part 5：明確不修改 `07-role-scoped-views.sql` — 落實 Permission Matrix Decoupled From Existing Scope Functions（Decision 6: permission_matrix 表先建、暫不接 v_squad_scope（解耦））；於 SQL 開頭 RAISE NOTICE 提醒讀者「v_squad_scope 仍是 hardcoded」
- [x] 2.6 14 SQL 結尾驗證 DO block：`SELECT COUNT(*) FROM permission_matrix` ≥ 30、`get_role_scope('squad_leader','read_scores')` = `'squad'`

## 3. Bootstrap admin 機制

- [x] 3.1 撰寫 `scripts/supabase-import/bootstrap-admin.sql.example` 範本檔案（落實 Bootstrap Admin Migration 與 Decision 3: 第一筆 admin 用 SQL bootstrap、檔案 gitignored），含 INSERT 模板（admin_id 預設 `chuanchenglin@gmail.com`、password 用 `'__REPLACE_ME__'` 佔位）+ 註解說明複製 + 跑法 + 救援 SQL 範例
- [x] 3.2 修改 `.gitignore`：加入 `scripts/supabase-import/bootstrap-admin.sql`（不含 .example）以防真實密碼意外進 git

## 4. 套用 SQL 到測試 Supabase

- [x] 4.1 透過 MCP `apply_migration` 套用 13-create-admin-credentials.sql、14-create-permission-matrix.sql — 兩個 migration 均成功，pgcrypto enabled、admin_credentials 表 + 9 RPC 就位、permission_matrix 表 30 筆 seed 就位、get_role_scope 兩個 scenario 通過
- [x] 4.2 Johnson 複製 bootstrap-admin.sql.example → bootstrap-admin.sql,填入真實密碼、admin_id 為 `chuanchenglin@gmail.com`，透過 Supabase SQL Editor 執行一次 — 已確認 1 row：chuanchenglin@gmail.com / 主程式設計師 / is_active=true
- [x] 4.3 驗證測試 Supabase：active_admins=1、permission_rows=30、get_role_scope('squad_leader','read_scores')='squad'、get_role_scope('member','read_scores')='self' 全部通過

## 5. 前端 — supabase-client.html 加 adminAPI

- [x] 5.1 在 `supabase-client.html` 新增 `window.adminAPI` 區塊，14 個 method 全部就位，sessionStorage key=`cchg_admin_session`，需 session 的 method 透過 `_requireSession()` 在無 session 時 throw `'未登入'`
- [x] 5.2 確認 `window.scoringAPI` 不含任何 admin method（與 adminAPI 完全區隔）

## 6. 前端 — Admin.html 殼層

- [x] 6.1 建立 `Admin.html` 新檔：登入螢幕（admin_id input + password input + 登入 button + 「⚠️ 請使用無痕視窗」警告）就位
- [x] 6.2 Session lifecycle：sessionStorage key=`cchg_admin_session`、登入成功寫 session、頁面 load 時 getSession() 判斷顯示登入 vs 後台、登出按鈕清 sessionStorage
- [x] 6.3 Four-Tab Navigation Structure：4 section + tab 按鈕、tab btn 點擊 lazy load 對應分頁資料、預設顯示權限切換

## 7. 前端 — Admin.html 4 個分頁內容

- [x] 7.1 Permission Toggle Tab：完整 grid 渲染（role / capability / enabled checkbox / scope dropdown / 儲存），頂端 alert-warn disclaimer 說明「v_squad_scope 仍為 hardcoded」
- [x] 7.2 Scoring Rules Tab：列全 scoring_rules，NULL 列 row-warning 黃底，textarea 編輯 JSON，前端做 JSON.parse 防呆，save 後 reload
- [x] 7.3 Roster Management Tab：listMembersFull join 顯示大隊+小隊+姓名，role select + is_active checkbox，搜尋框做 client-side filter，無新增/刪除 UI
- [x] 7.4 Admin Management Tab：列 admins、新增 admin 表單（折疊）、改密碼按鈕（prompt）、停用按鈕（self disabled），錯誤直接顯示 RPC exception 訊息

## 8. webApp.js 路由

- [x] 8.1 doGet 加 `isAdminPage = (page === 'Admin')` 判斷，Admin 頁 skip user params 注入 + skip storeCurrentUser，但仍注入 supabaseUrl/Key

## 9. 推送與 smoke test

- [x] 9.1 確認【測試】DEV ✓、`.claspignore` 補上 `!Admin.html`、push 成功 10 files（含 Admin.html / supabase-client.html / webApp.js）
- [ ] 9.2 手動 smoke test：開 `?page=Admin` → 用 chuanchenglin@gmail.com + 真實密碼登入 → 確認進入後看到 4 分頁 → 4 個分頁逐一試用（toggle 一個 permission、改一筆 scoring_rule、改一個 member role、加第二個 admin）
- [ ] 9.3 手動 smoke test 自鎖規則：用 admin A 嘗試停用自己（應顯示「不能停用自己」錯誤）；接著加 admin B、停用 B、回頭嘗試停用 A（剩 A 一個 active 時應顯示「至少要保留 1 個 active admin」錯誤）
- [ ] 9.4 手動 smoke test session：登入後關閉 tab、重開 `?page=Admin`，應回到登入畫面（驗證 sessionStorage 不是 localStorage）

## 10. 文件更新

- [x] 10.1 CLAUDE.md 核心 Schema 章節補上 admin_credentials 與 permission_matrix
- [x] 10.2 CLAUDE.md 資料存取模式章節補上 adminAPI 14 method、Admin 路由 skip user 注入
- [x] 10.3 CLAUDE.md 新增「管理後台」章節：進入方式、bootstrap、忘記密碼救援 SQL、sessionStorage 安全提醒、自鎖規則、權限矩陣解耦狀態
