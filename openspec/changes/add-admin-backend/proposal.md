## Why

3+ 人後台維護團隊（Johnson + 主程式設計師 + 待加入的協作者）需要能透過 UI 即時調整系統行為，而非每次都手刻 SQL 或請對方代為操作。當前 Supabase 已具備完整資料層，但缺三大基礎能力：

1. **Admin 認證機制空缺**：剛拆掉 PIN（主辦方決議不用）後，整個系統沒有任何「需要驗證身分才能執行」的入口；任何人拿到 URL 就能填表，但「修改 scoring_rules、停用 member」這類管理動作不能也走相同信任模型
2. **權限矩陣寫死在 SQL function 裡**：`07-role-scoped-views.sql` 用 `IF role = 'squad_leader' THEN ...` 硬編碼，要改規則就得重新部署 SQL；3 人團隊維護時這代價過高
3. **沒有管理後台 UI**：scoring_rules 表雖然資料化、但要改 rule_value 還是得開 Supabase SQL Editor；同理 members.role 改變、停用名單也都靠手刻 SQL

不先處理這三個缺口，後續 Dashboard 開發會被卡住（規則改不動、權限調不動、增減 admin 還是要 Johnson 一個人開 SQL）。

## What Changes

- 新增 `admin_credentials` 表：bcrypt-hashed 密碼（透過 pgcrypto extension）、admin_id 為文字 key、`is_active` 旗標控管
- 啟用 Supabase 的 `pgcrypto` extension（用於 password hashing）
- 新增 `admin_login(admin_id, password)` RPC：驗證密碼、回傳 admin 基本資訊、更新 `last_login_at`
- 新增 `admin_verify(admin_id, password)` RPC：每個 admin 動作前重新驗證（簡化的 session 模型，避免 token / cookie 複雜度）
- 新增 admin CRUD RPCs：`admin_list_admins / admin_create / admin_set_active / admin_change_password`，內建自鎖防呆（不能停用自己、不能讓 active admin 數歸零）
- 新增 `permission_matrix` 表：role × capability 的 toggle 矩陣，每筆 `(role, capability, scope, is_enabled)`，未來改規則直接 UPDATE 即時生效
- 新增 `get_role_scope(role, capability)` helper function：單一入口讀矩陣
- 新增 bootstrap-admin SQL 範本（gitignored）：用於建立第一筆 admin（admin_id 預設 `chuanchenglin@gmail.com`）
- 新增 `Admin.html` 後台頁面：登入畫面 + 4 分頁殼（權限切換、計分規則、名單管理、Admin 管理）
- 新增 webApp.js 路由 `?page=Admin`
- 新增 `supabase-client.html:adminAPI` 區塊：封裝所有 admin RPC 呼叫，與既有 `scoringAPI` 區隔
- CLAUDE.md 補上「管理後台」章節：說明 admin_id / 密碼來源 / 自鎖規則 / pgcrypto 依賴

## Non-Goals

- **不**重構 `v_squad_scope` 讓它讀 `permission_matrix`（既有 `add-scoring-rules-and-role-access` change 還沒 archive，避免互相干擾；建立 `permission_matrix` 是為了**未來**重構作準備，本 change 內 v_squad_scope 維持原 hardcoded 邏輯）
- **不**做 Dashboard 頁面（小隊長/大隊長看分數那些）— 留給後續 `add-role-dashboards` change
- **不**做 token / cookie session — 採「sessionStorage 存密碼 + 每次 RPC 重驗」最簡模型
- **不**做密碼複雜度檢查（長度、大小寫等）— 內部團隊 3 人，把責任放在 admin 自己
- **不**做密碼遺忘恢復流程 — 真要忘了，請另一位 admin 重設；最後一位忘記就走 SQL Editor bootstrap 流程
- **不**引入 Supabase Auth JWT（與既有「不用 Supabase Auth」決議一致）
- **不**做 admin 操作的審計 log（誰在何時改了什麼規則）— 記在 OpenQuestion 留待 Dashboard change 一起處理
- **不**處理 admin 與 `members.role='admin'` 的關係（admin_credentials 是獨立機制，與 members 表毫無 FK 關聯）— 兩者邏輯層級不同，admin 是「維運帳號」、members.role='admin' 留給未來「以 member 身分擁有特殊權限」的場景
- **不**做前端密碼複雜度提示或 strength meter

## Capabilities

### New Capabilities

- `admin-credentials`: 後台維運帳號的儲存、認證、自鎖防呆機制；獨立於 `members` 表的 `admin_credentials` 表 + `pgcrypto` bcrypt + bootstrap SQL 範本
- `permission-matrix`: 資料化的 role × capability 矩陣表 `permission_matrix` + `get_role_scope` helper function；不寫死於 SQL CASE WHEN，可即時 UPDATE 切換
- `admin-backend-ui`: `Admin.html` 後台單頁（登入 + 4 分頁：權限切換 / 計分規則編輯 / 名單管理 / Admin 自管），Apps Script Web App `?page=Admin` 路由

### Modified Capabilities

(none)

## Impact

- **Affected specs**:
  - 新建 `openspec/specs/admin-credentials/spec.md`
  - 新建 `openspec/specs/permission-matrix/spec.md`
  - 新建 `openspec/specs/admin-backend-ui/spec.md`
- **Affected code**:
  - `scripts/supabase-import/13-create-admin-credentials.sql`（新檔：表 + pgcrypto + RLS + login/verify/CRUD RPCs）
  - `scripts/supabase-import/14-create-permission-matrix.sql`（新檔：表 + seed 預設矩陣 + helper function）
  - `scripts/supabase-import/bootstrap-admin.sql.example`（新檔：範本，gitignored 後 Johnson 複製為 `bootstrap-admin.sql` 填密碼跑）
  - `.gitignore`（修改：加入 `scripts/supabase-import/bootstrap-admin.sql`）
  - `Admin.html`（新檔：登入區 + 4 分頁殼 + 各分頁 UI）
  - `webApp.js`（修改：`doGet` 接受 `?page=Admin` 路由）
  - `supabase-client.html`（修改：新增 `window.adminAPI` 區塊）
  - `CLAUDE.md`（修改：補「管理後台」章節 + 技術架構章節提到 `admin_credentials` / `permission_matrix` 兩表）
- **Affected Supabase DB**:
  - 啟用 extension：`pgcrypto`
  - 新表：`admin_credentials`、`permission_matrix`
  - 新 RPCs：`admin_login`、`admin_verify`、`admin_list_admins`、`admin_create`、`admin_set_active`、`admin_change_password`、`get_role_scope`、`admin_update_permission`、`admin_update_scoring_rule`、`admin_set_member_role`、`admin_set_member_active`
- **Affected workflow**:
  - **第一次部署**：Johnson 跑 `13` 與 `14` SQL → 複製 `bootstrap-admin.sql.example` 為 `bootstrap-admin.sql` 填初始密碼 → 跑 → 第一筆 admin 就位 → 進 `?page=Admin` 登入後其餘 admin 透過 UI 加
  - **未來改權限**：admin 進後台 → 點權限切換分頁 → toggle 矩陣某格 → RPC `admin_update_permission` → 立即生效
  - **未來改規則**：admin 進後台 → 點計分規則分頁 → 改某 rule_value → RPC `admin_update_scoring_rule` → 立即生效
- **Affected docs**:
  - CLAUDE.md 「技術架構」章節補 `admin_credentials` / `permission_matrix`
  - CLAUDE.md 新增「管理後台」章節說明登入流程與 admin 自管規則
