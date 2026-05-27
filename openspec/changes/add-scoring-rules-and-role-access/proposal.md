## Why

Dashboard 開發即將展開，但設計討論暴露兩個阻擋：

1. **主辦方計分規則未定稿**（7 個待確認問題：W7 領袖通話、半數定義、隊長計入、審計缺件處理等）。如果把規則硬編碼到前端或後端函式，每次改規則都要重新部署；demo 時規則若與假設不同，呈現錯誤數字會損害信任。

2. **`members.role` 欄位已存在**（`member` / `squad_leader` / `team_leader` / `auditor` / `admin` / `executive`），但整個系統沒有任何「按角色過濾資料」的機制 — 現有 RLS 對 `daily_reports` 寬鬆開放 anon 讀寫，Dashboard 若直接查就會洩漏所有人的分數。

這兩個缺口是 Dashboard 開發的**地基**。不先處理，後續 Dashboard 代碼會到處 hardcode 規則、到處 hardcode 權限判斷，規則一變就得改多處；角色權限判斷寫在前端 = 安全漏洞。

## What Changes

- 新增 `scoring_rules` 表：以 `(activity_id, rule_key)` 為 key，`rule_value JSONB` 存規則內容；支援 `updated_by` / `updated_at` 審計軌跡
- 新增 `get_rule(p_activity_id, p_rule_key)` helper function：單一入口讀規則值，找不到時回傳 `NULL`（讓呼叫端決定 default 行為）
- Seed 7 個已知 rule key（根據目前待確認規則清單），`rule_value` 先留 `NULL` 或保守預設值，並在 `description` 欄記錄主辦方的原問題文字
- 新增 `v_squad_scope(viewer_id)` / `v_team_scope(viewer_id)` 兩個 VIEW：封裝「這個 viewer 依其角色能看到哪些 member」的邏輯，Dashboard 查分數時一律 JOIN 這兩個 view
- 新增 `get_visible_reports(p_viewer_id)` RPC：根據 viewer 的 role 回傳其可見的 `daily_reports`，encapsulate 權限邊界
- 收斂 `daily_reports` 與 `daily_report_items` 的 SELECT RLS — 從「anon 全讀」改為「只能透過 RPC 讀」（INSERT 仍走 `save_daily_report` RPC，不變）
- 不動現有 `authenticate_member` 機制（PIN 登入維持），也不引入 Supabase Auth JWT（那是獨立的大範圍 change）

## Capabilities

### New Capabilities

- `scoring-rules`: 計分規則的資料化儲存與讀取介面；規則調整不需部署代碼
- `role-based-access`: 以 `members.role` 為基礎的可見資料範圍封裝，Dashboard 查詢統一走 role-scoped views / RPCs

### Modified Capabilities

- `daily-report-scoring`（from `normalize-daily-report-schema`）：SELECT RLS 從「anon 全讀」收斂為「RPC-only 讀」

## Impact

- **Affected specs**:
  - 新建 `openspec/specs/scoring-rules/spec.md`
  - 新建 `openspec/specs/role-based-access/spec.md`
  - 修改 `openspec/specs/daily-report-scoring/spec.md`（RLS 描述收斂）
- **Affected code**:
  - `scripts/supabase-import/06-scoring-rules.sql`（新檔）
  - `scripts/supabase-import/07-role-scoped-views.sql`（新檔）
  - `scripts/supabase-import/08-tighten-rls.sql`（新檔；RLS 收斂）
  - 不動前端代碼（本 change 純資料層；Dashboard 屬後續 change）
- **Affected Supabase DB**:
  - 新表：`scoring_rules`
  - 新 function：`get_rule(BIGINT, TEXT)`、`get_visible_reports(BIGINT)`
  - 新 view：`v_squad_scope`、`v_team_scope`
  - 收斂 RLS：`daily_reports`、`daily_report_items`、`daily_report_item_options` 的 SELECT policy
- **Affected workflow**:
  - 規則變動：主辦方確認後，直接 `UPDATE scoring_rules SET rule_value = ...` 即時生效，無需部署
  - Dashboard 開發：必須透過 `get_visible_reports` / `v_*_scope` 讀資料，不得直接 `SELECT * FROM daily_reports`

## Non-Goals

- **不做**前端 Dashboard 頁面（另開 change：`add-role-dashboards`）
- **不做**審計工作流擴充（通過/拒絕/補件/扣分）（另開 change：`extend-audit-workflow`）
- **不做**傳愛名單回報功能（另開 change：`add-angel-assignment-tracking`）
- **不做**Supabase Auth JWT 遷移（另開 change：`migrate-to-supabase-auth`）
- **不填入**主辦方未確認的 rule_value（只 seed key 與 description，value 留 NULL 或保守預設）
- **不新增**`members.role` 枚舉值（已足夠）
