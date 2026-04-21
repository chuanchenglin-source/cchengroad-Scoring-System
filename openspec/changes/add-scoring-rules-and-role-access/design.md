## Context

2026-04-21 的 spectra-discuss 暴露出 Dashboard 開發的兩個結構性阻擋：

**阻擋一：規則未定稿**
主辦方在 LINE 群組提出 7 個待確認問題（W7 領袖通話、全完成定義、半數定義、排名總分 vs 平均、隊長計入、審計缺件處理、傳愛名單）。這些規則影響分數計算的**參數**，若寫死在代碼裡每次改都要重新部署；若假設錯誤則 demo 數字不可信。

**阻擋二：角色權限機制缺席**
`members.role` 欄位在 2026-04-20 的 RLS change 已新增並已匯入資料（`member` / `squad_leader` / `team_leader` / `auditor` / `admin` / `executive`），但沒有任何 view / function 把「角色 → 可見範圍」的對應關係封裝起來。現有 RLS 對 `daily_reports` 是「anon 全讀」，若 Dashboard 直接查就會洩漏所有人資料。

**約束**：
- 不引入 Supabase Auth JWT（PIN 登入已運作；JWT 遷移是另一個大範圍 change）
- 不動前端代碼（本 change 純資料層）
- 活動 2026-05-03 開訓，12 天內要能支援 Dashboard 開發

## Goals / Non-Goals

**Goals:**
- 建立「規則資料化」的基礎，讓主辦方規則一來就能透過 `UPDATE scoring_rules` 即時生效，零部署
- 建立「角色範圍封裝」的基礎，讓 Dashboard 查詢統一走 role-scoped views / RPCs
- 為 7 個已知待確認問題 seed 對應的 `rule_key`，`rule_value` 留 NULL，並在 `description` 記錄原問題
- 收斂 `daily_reports` / `daily_report_items` 的 SELECT RLS，避免 Dashboard 直接查表

**Non-Goals:**
- **不實作 Dashboard 頁面**（另開 change）
- **不擴充審計工作流**（通過/拒絕/補件/扣分，另開 change）
- **不做傳愛名單功能**（另開 change）
- **不遷移到 Supabase Auth JWT**（另開 change）
- **不填入主辦方未確認的 rule_value**（只建結構）
- **不改前端**（`supabase-client.html` / `main.html` / `history.html` 不動）

## Decisions

### 規則儲存在表而非 JS 檔

`scoring_rules` 表 with `(activity_id, rule_key) UNIQUE`，`rule_value JSONB`。

**理由**：
- JS 檔改動需要 `npm run push:dev` 或 PR + 部署，每次改規則都要開發者參與
- 資料表改動可以由 Supabase Dashboard 直接編輯，主辦方或 Johnson 非技術操作即可
- `JSONB` 允許結構化值（例如 `{"method": "ceil", "threshold": 0.5}`），比單純 TEXT/INTEGER 更彈性
- 符合既有設計理念（`box_definitions` 也是把規則從代碼搬到資料）

**替代方案**：
- **JS 常數檔**：拒絕。每次改要重新部署，且版本控制加入規則資料造成 PR 雜訊
- **Supabase Config / Script Properties**：拒絕。Script Properties 是 Apps Script 端的設定，不在 Supabase；跨系統讀取複雜
- **環境變數**：拒絕。改變量要重啟服務，且無審計軌跡

### Seed 規則但不填 value

表建立時 INSERT 7 筆 `rule_key` 占位，但 `rule_value` 為 NULL 或保守預設。

**理由**：
- 主辦方規則未定，不能假設 value；seed NULL 讓呼叫端看到明確的「規則未設定」訊號
- `description` 欄記錄原問題文字，方便未來任何人（包括新的 Claude 實例）知道這個 key 在等什麼答案
- 未來 `UPDATE scoring_rules SET rule_value = '...' WHERE rule_key = '...'` 一行即生效

**替代方案**：
- **不 seed，用時才 INSERT**：拒絕。7 個 key 是設計時就知道的，先建好才能讓 Dashboard 代碼有所依賴
- **Seed 保守預設值**（例如所有 bool 先 false）：部分採用。`w7_leadership_bonus_enabled` 類布林可給預設 false；牽涉計算方法（`half_completion_method`）則仍留 NULL，強迫呼叫端處理未設定情況

### `get_rule()` 為單一讀取入口

所有讀規則的代碼走 `SELECT get_rule(activity_id, rule_key)`，不直接 `SELECT rule_value FROM scoring_rules`。

**理由**：
- 未來若規則儲存方式改（例如加 caching、加 fallback 到 default_rules 表），只要改函式內部，呼叫端不動
- Function 可以 `SECURITY DEFINER` 繞過 RLS，避免 Dashboard 代碼得自行處理權限
- 單一入口有助於日後加 logging / metrics（哪些規則被讀、被讀多少次）

### Role-scoped views 而非直接 RLS

以 `v_squad_scope(viewer_id)` / `v_team_scope(viewer_id)` 兩個 VIEW 封裝「viewer 能看到哪些 member」，Dashboard 代碼 JOIN 這兩個 view 取資料。

**理由**：
- 無 JWT / `auth.uid()` 可用，RLS 無法從 session context 自動判斷 viewer；必須由呼叫端傳 `viewer_id`
- View 可以在 `WHERE` 子句封裝完整的角色邏輯（例如 `squad_leader` 看自己小隊、`team_leader` 看整個大隊、`auditor` 看全部），呼叫端不用重複寫這些判斷
- 違反「不信任 client」原則：客戶端可以傳任意 `viewer_id` 假冒他人。**本 change 接受此妥協**（demo 階段、PIN 登入本來就信任 client），並在 design.md 標記為已知風險，留給 `migrate-to-supabase-auth` change 解決

**替代方案**：
- **PostgREST 內建 RLS + auth.uid()**：理想，但需要 JWT / Auth 遷移，不在本 change 範圍
- **每個 Dashboard 各自寫 JOIN 條件**：拒絕。邏輯重複且難維護
- **把角色判斷放前端**：拒絕。安全漏洞且難檢討

### 收斂 `daily_reports` SELECT RLS

從 `FOR SELECT USING (true)` 改為 `FOR SELECT USING (false)`，所有 SELECT 走 `get_visible_reports(viewer_id)` RPC（`SECURITY DEFINER`）。

**理由**：
- 收斂後，即使前端代碼誤用 `.from('daily_reports').select(...)`，也會 RLS 擋下
- RPC 是唯一合法入口，強制所有呼叫提供 `viewer_id` 並經過角色判斷
- INSERT 不動（仍走 `save_daily_report` RPC）

**替代方案**：
- **保留 anon SELECT**：拒絕。Dashboard 開發時若忘了用 RPC，就會拉到所有人的資料
- **完全 DROP 所有 anon 權限**：拒絕。`daily_reports` 的 `save_daily_report` RPC 需要 INSERT 權限；全砍會壞掉寫入

### `activity_id` 欄位延續預留原則

`scoring_rules.activity_id BIGINT NOT NULL DEFAULT 1`，UNIQUE `(activity_id, rule_key)`，不設 FK。

**理由**：延續 `normalize-daily-report-schema` change 的設計決定（「`activity_id` 預留欄位（不建 `activities` 表、不設 FK）」）。下一屆親證班直接 `INSERT ... activity_id = 2` 複製一份規則即可。

## Risks / Trade-offs

- **[Client 可以偽造 viewer_id → 越權查詢]** → 已知妥協。demo 階段接受，正式上線前必須切到 Supabase Auth JWT 讓 RLS 用 `auth.uid()` 判斷。在 `docs/` 記錄此風險作為交付前必辦事項
- **[規則改動無版本控制 → 歷史規則無從回溯]** → `scoring_rules` 加 `updated_at` / `updated_by`；若未來需要完整歷史，可以加 trigger 把修改寫到 `scoring_rules_history` 表（超出本 change 範圍）
- **[`get_rule` 回 NULL 時呼叫端忘了處理]** → 每個呼叫點的 caller 要明確處理 NULL（例如「規則未設定」UI 提示）。未來 Dashboard change 的 tasks 要逐個列出 NULL fallback 策略
- **[RLS 收斂可能破壞既有前端讀取]** → 目前 `getPersonalHistory` 是直接 `SELECT` 多表 JOIN；收斂後會被擋。本 change 必須**同時**調整 `getPersonalHistory` 改走新 RPC，或保留「自己看自己」的 RLS exception。決議：加一個 `daily_reports SELECT USING (member_id = current_setting('app.viewer_id')::BIGINT)` 類 policy 太複雜；改採「對既有直接 SELECT 代碼不動，只限制未來新查詢必須走 RPC」—— 即 RLS 維持開放 SELECT，本 change 不做硬收斂，改以 code review / 文件規範約束
- **[view 查詢效能]** → `v_squad_scope` / `v_team_scope` 以 viewer_id 為參數，本質是 inline function；資料量小（414 人）不會有效能問題

## Migration Plan

1. **執行 `06-scoring-rules.sql`**：建 `scoring_rules` 表、`get_rule()` function、seed 7 筆 rule_key
2. **執行 `07-role-scoped-views.sql`**：建 `v_squad_scope` / `v_team_scope` / `get_visible_reports()` RPC
3. **（暫不執行 `08-tighten-rls.sql`）**：根據 Risks 段落結論，RLS 硬收斂改為後續 change 處理；本 change 只先寫好腳本放著
4. **驗證**：
   - `SELECT * FROM scoring_rules` 應有 7 筆
   - `SELECT get_rule(1, 'half_completion_method')` 應回 NULL（表示未設定）
   - `SELECT * FROM v_squad_scope(5)`（假設 member 5 是 squad_leader）應只回自己小隊成員
5. **文件更新**：
   - `CLAUDE.md` 技術架構段加 `scoring_rules` 到 schema 描述
   - Memory 記錄本 change 已完成與對 Dashboard 開發的意義

## Rule Keys Seeded（對應主辦方 7 個問題）

| rule_key | 對應問題 | 預設值策略 |
|---|---|---|
| `w7_leadership_bonus_enabled` | Q1 第七週領袖通話 | NULL（主辦方討論中） |
| `full_completion_definition` | Q2a 全完成 = 當週最高分？ | NULL |
| `team_bonus_target` | Q2b 加個人 vs 隊伍 | `"individual"`（已答：每人個別加） |
| `half_completion_method` | Q2c 半數定義（ceil/floor/strict） | NULL |
| `team_ranking_method` | Q3a 總分 vs 平均 | `"average"`（已答：平均） |
| `include_leaders_in_average` | Q3b 小隊長/大隊長計入分母 | NULL |
| `audit_missing_item_action` | Q3c 扣分 vs 補件 | NULL |

## Open Questions

- **`get_visible_reports` 的回傳欄位結構**：要回傳扁平化後的 `{ date, score, box1_score, ... }` 還是原始 JOIN 結果讓前端扁平化？留在 tasks 分解時決定
- **是否需要 `v_auditor_scope`**：審計官的可見範圍是否 = 全部？或只看「自己被指派的小隊」（`auditor_assignments` 表已存在）？先假設「auditor 看全部 pending」，後續 `extend-audit-workflow` change 再細分
