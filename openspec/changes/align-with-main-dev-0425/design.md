## Context

#### 為什麼需要 design.md

本 change 涵蓋四個技術面同時動：

1. **資料層**：新增 `teams` / `squads` 兩張表、`members` 主鍵型別由 `BIGSERIAL` 改 `TEXT`、連動修改 `daily_reports.member_id` / `daily_report_items` 的 FK 型別
2. **匯入層**：360+ 真名單一次性 SQL migration，必須在型別變更**之前**完成既有資料清空
3. **介面層**：刪除 `authenticate_member` RPC、`members.pin_code` 欄位（破壞性）
4. **前端層**：3 個 HTML 檔（Index、main、history）+ supabase-client.html 同時調整

四個面的執行順序錯了會造成「測試 Supabase 進入無法回頭的 broken state」。design 在這裡作為實作前的**技術決策定錨**，避免實作時來回 trial-and-error。

#### 既有架構限制

- `daily_reports.member_id` 目前是 `BIGINT REFERENCES members(id)`，members.id 改型別必須一併改
- `daily_report_items.report_id` 雖然不是直接 ref members，但 RLS policies 與 `save_daily_report` RPC 內部都假設 `BIGINT` member_id
- 現有 18 筆 demo `members` 已經有 `daily_reports` 寫入紀錄（測試用），需決定如何處置
- Supabase RLS 在欄位型別變更時不會自動失效，但 RPC 的 `SECURITY DEFINER` function 簽章會
- 前端 supabase-client.html 與所有 HTML 走 `inheritsFrom` template 模式，HTML 變更需配合 webApp.js 的 doGet 路由

#### 利害關係人

- **Johnson**：執行所有 SQL、push 前端到測試 Apps Script，承擔資料遺失風險
- **主程式設計師**：不參與本 change，但其 0425 schema 是對齊目標
- **主辦方**：已決議不用 PIN，本 change 落實此決議
- **未來測試使用者（demo 階段）**：360+ 學員若 demo 時切到 Supabase 版，需能用真名搜到自己

## Goals / Non-Goals

**Goals:**

- 把 Supabase 的 `members` 從 18 筆假資料升級到 360+ 真資料，且階層（大隊 / 小隊 / 隊員）關聯正確
- 拆除 PIN 機制，徹底移除 `authenticate_member` 與 `members.pin_code`，前端不再有任何 PIN 相關程式碼
- 前端 UI（Index / main / history）行為與主程式設計師路線一致，使用者切換兩個版本時體驗無感
- 一次性 SQL migration 可重複執行（idempotent），測試 Supabase 隨時可從零重建

**Non-Goals:**

- 不變動 `box_definitions`、`box_options`、`scoring_rules` 三表結構（保留給後續 change）
- 不導入計分上限 / 保底分 / 小隊加分（屬於 `add-baseline-and-team-bonus`）
- 不導入 Supabase Auth JWT 或 Row-Level 細粒度權限（用 anon + RLS 維持目前模型）
- 不保留 PIN 為「過渡期 fallback」 — 直接拆除，沒有 deprecation 階段
- 不對既有 daily_reports demo 資料做遷移（測試資料直接 TRUNCATE）

## Decisions

### Decision 1: members.id 採用 TEXT `T011_周子維_嘉家久` 格式

**選擇**：把 `members.id` 從 `BIGSERIAL` 改成 `TEXT PRIMARY KEY`，採主路線格式 `<squad_code>_<name>_<team_name>`，例如 `T011_周子維_嘉家久`。

**為什麼**：

- 主路線 0425 的 `getMemberList` / `getPersonalHistory` / `getUserStatus` / `saveForm` 全部用這個 ID 字串當 key；Supabase 備案要做到「主路線壞掉時 URL 換個 host 就能用」必須採同樣格式
- URL params `?id=T011_周子維_嘉家久&name=周子維` 直接餵進 Supabase 查詢，不用前端做 ID 轉換
- TEXT 型別也讓 ID 自帶語意（看到 ID 就知道隊伍與姓名），debug 友善

**alternatives considered**：

- ❌ **保留 BIGSERIAL，加 `external_id TEXT UNIQUE`**：會產生「兩個 ID 系統」的維運負擔，且每個 RPC / RLS 都要 join 多一層
- ❌ **用 UUID**：跟主路線完全不同，URL 不可讀

**trade-off**：

- ⚠️ TEXT PK 比 BIGINT 慢一點（索引大、join 慢），但 360+ rows 規模下差距可忽略
- ⚠️ 姓名重複的人會 collision（例：兩個「王雅慧」分屬 T033 與 T062）— ID 包含 `<squad>_<name>_<team>` 三段已可區分；但若同一小隊有同名兩人（極小機率）需特別處理 → 開 Open Questions

### Decision 2: teams + squads 兩張獨立表，不使用 self-referencing members

**選擇**：建獨立的 `teams (18 rows)` 與 `squads (~80 rows)` 兩表，`members` 透過 `squad_id BIGINT REFERENCES squads(id)` 加入；不採「在 members 上加 `is_leader`、`parent_id` 自指 FK」的方案。

**為什麼**：

- 主路線 0425「大隊對照表」與「小隊架構表」本就是兩張 lookup table，獨立建表保留主路線結構
- 大隊長 / 小隊長**也是隊員**（同一人在 members 表也有一筆），用「leader_name」欄位記錄誰是 leader 比 self-FK 簡單
- 後續 Dashboard 要做「整大隊排名」「整小隊統計」直接 GROUP BY squad_id / team_id 比 self-join 直觀

**alternatives considered**：

- ❌ **members 加 `parent_id` 自指**：需區分 leader vs member 的 role，且 SQL aggregation 要遞迴 CTE
- ❌ **只建 teams，不建 squads**（squad 用 members 的 4 碼前綴算）：違反正規化，每次查小隊都要字串切割

**trade-off**：

- ⚠️ leader_name 是字串（不 FK 到 members.id），改名要手動同步多處 — 但活動期間 leader 不會改名
- ⚠️ 多兩張表帶來 schema 複雜度，但這是不可避免的階層真實面

### Decision 3: 拆 PIN 採「直接刪除」而非 deprecation

**選擇**：在同一個 SQL migration 裡 `DROP FUNCTION authenticate_member` + `ALTER TABLE members DROP COLUMN pin_code`，不留 fallback、不標 `DEPRECATED`。

**為什麼**：

- 主辦方 2026-04-25 明確決議「不用 PIN」— 沒有「過渡期還想試試」的需求
- demo 階段資料可丟，不需考慮歷史用戶 session
- 留著 deprecated 欄位 / RPC 會讓未來 Claude 看到誤用

**alternatives considered**：

- ❌ **保留 RPC 但 raise exception**：徒增混淆
- ❌ **留欄位 NULL**：增加 schema 噪訊

**trade-off**：

- ⚠️ 一旦執行 SQL 11，pin_code 內容永久遺失 — demo 資料無關緊要，但要在 SQL 開頭備註「Destructive Migration」

### Decision 4: SQL 執行順序：先建新表 → 改 members 型別 → 匯入名單 → 刪 PIN

**選擇**：嚴格順序：

```
09-create-teams-squads.sql        ← 建 teams / squads 空表 + RLS（不依賴 members）
↓
10-alter-members-id-type.sql      ← TRUNCATE members + daily_reports + items
                                    DROP existing FKs → ALTER TYPE → 重建 FK
                                    新增 squad_id FK column
↓
11-import-real-roster.sql         ← INSERT teams (18) → INSERT squads (~80)
                                    → INSERT members (360+) with squad_id 對應
↓
12-remove-pin-auth.sql            ← DROP FUNCTION authenticate_member
                                    ALTER TABLE members DROP COLUMN pin_code
                                    DROP RLS policies that reference pin_code
```

**為什麼**：

- 改 members.id 型別前必須清空有 FK 指向它的 daily_reports/items，否則 ALTER TABLE 會失敗
- teams/squads 建在前，匯入名單時 squad_id FK 才有對應
- 拆 PIN 放最後，避免拆 PIN 過程出錯導致無法登入測試（雖然不需要，但隔離開來容易 rollback）

**alternatives considered**：

- ❌ **單一 SQL 全部包進 BEGIN…COMMIT**：失敗時整段 rollback 看不出哪裡錯
- ❌ **保留現有 18 筆 members + 加新 360 筆**：型別不一致無法共存

**trade-off**：

- ⚠️ 4 個檔案要按順序執行，Johnson 要嚴守順序（在 SQL 開頭加大字標示「prerequisite: 09 must be applied first」）

### Decision 5: 前端 PIN 拆除採「整段刪除 supabase-client 的 authenticate 函式」

**選擇**：刪 `supabase-client.html` 內的 `scoringAPI.authenticate(name, pin)` 函式整段；新增 `scoringAPI.findMember(searchTerm)` 替代（datalist 模糊搜尋姓名 / 小隊編號）。Index.html 不再有 PIN input 欄位。

**為什麼**：

- 主路線 Index.html 用 `<input list="nameList">` + `<datalist>` 模式，使用者輸入名字會 autocomplete
- 我們的 supabase-client.html 已有 `getMemberList()`，前端載入後存陣列做 client-side filter，不需新增 RPC
- 完全對齊主路線的搜尋 UX，使用者切換 Supabase 版時體感無差別

**alternatives considered**：

- ❌ **保留 PIN input 但讓它選擇性**：違反「主辦方決議不用 PIN」
- ❌ **用 server-side search RPC**：浪費 round-trip，360 人在 client-side 過濾很快

### Decision 6: history.html 套用主路線「W1-W7 切換 + 卡片每日表格」結構

**選擇**：history.html 改寫為主路線結構：頂部 sticky header 含週次按鈕（1-7）、每週切換時渲染當週 7 天 × 40 box 的卡片列表；用主路線的綠色航海主題。

**為什麼**：

- 字體 1.15rem 對年長使用者更友善（CLAUDE.md 提到目標族群是 360+ 親證班學員，年齡跨度大）
- 週切換 UI 跟使用者大腦對應「我這週做了什麼」直觀
- 主路線的 history.html 已經很完整，**抄結構而不是重寫**省時

**alternatives considered**：

- ❌ **保留我目前的歷史頁設計**：需要說服使用者為什麼兩版長得不一樣
- ❌ **只抄 CSS 不抄結構**：CSS 改完還是骨架不對等於沒改

### Decision 7: main.html 日期選擇器改為「當週 7 天」

**選擇**：移除目前主程式設計師也沒做的「跨週導覽」，採主路線 `initDatePicker` 邏輯：根據今天日期算出當週週日，渲染週日 → 週六 7 個按鈕，每個按鈕 click 後變 selectedDate。

**為什麼**：

- 主辦方規則：每週填單，超過當週就無法補登（避免事後造分）
- UX 簡單：使用者打開頁面看到的就是「我這週可以填的日子」，沒有混淆
- 主路線此設計已經 demo 過給主辦方，遵循已驗證設計

**trade-off**：

- ⚠️ 跨週補單要透過後台 SQL 處理，但這是規則限制不是技術限制

## Risks / Trade-offs

#### Risk 1: 360+ 名單匯入時若有姓名重複（同一小隊內），ID 會 collision

- **觸發條件**：同一個 4 碼 squad（例如 T011）內出現兩個同名隊員
- **影響**：`INSERT INTO members (id, ...)` 會 PRIMARY KEY violation
- **Mitigation**：匯入前先跑檢查 SQL：`SELECT squad_code, name, COUNT(*) FROM raw_roster GROUP BY squad_code, name HAVING COUNT(*) > 1`，發現衝突就在 ID 後面加流水號（例：`T011_王雅慧_2_嘉家久`）；同時記錄到 design 的 Open Questions 通知 Johnson 與主辦方

#### Risk 2: ALTER TABLE members.id 型別失敗，留下 broken state

- **觸發條件**：FK constraint 沒清乾淨、或 daily_reports 有殘留 row
- **影響**：測試 Supabase schema 半完成，後續匯入失敗
- **Mitigation**：每個 SQL 檔案結尾加驗證 block（`DO $$ ... RAISE NOTICE ...$$`）；10-alter-members-id-type.sql 要先 `TRUNCATE daily_reports, daily_report_items, daily_report_item_options CASCADE`

#### Risk 3: 前端拆 PIN 時，現有 supabase-client 還有別的呼叫者依賴 authenticate

- **觸發條件**：除了 Index.html 外，main.html / history.html 也用 PIN 重新驗證
- **影響**：拆 PIN 後 main.html 進入時報錯「authenticate is not a function」
- **Mitigation**：`grep -rn "scoringAPI.authenticate\|pin_code\|authenticate_member" .` 先盤點所有呼叫點，確保拆乾淨；前端推送前 push:dev 後手動 smoke test 三頁

#### Risk 4: 主程式設計師的 0425 schema 還會再變

- **觸發條件**：5/3 開訓前主辦方還會調名單、改欄位
- **影響**：本 change 完成後又要再對齊
- **Mitigation**：把 `09-12` SQL 寫成 idempotent（DROP IF EXISTS / TRUNCATE 再 INSERT），未來再 sync 就重跑一次；CLAUDE.md 加註「每週 Monday clasp pull 同步主程式設計師最新版」

#### Risk 5: history.html 重寫破壞既有測試使用者體驗

- **觸發條件**：Demo 階段已有測試使用者熟悉舊版歷史頁
- **影響**：使用者抱怨「為什麼長得不一樣」
- **Mitigation**：本 change 處於 demo 階段，使用者池小（Johnson 自己 + 少數測試者），UI 大改換來與主路線同步，trade-off 划算

## Migration Plan

#### 部署順序（Johnson 在測試 Supabase 上手動執行）

```
1. git pull → 拿到所有 SQL 檔案
2. Apps Script 端：先停止填表（暫時提示維護中）
3. 依序執行 SQL：
   3.1 09-create-teams-squads.sql
   3.2 10-alter-members-id-type.sql（destructive: TRUNCATE）
   3.3 11-import-real-roster.sql
   3.4 12-remove-pin-auth.sql
4. 每個 SQL 檔尾的 RAISE NOTICE 驗證 block 都跑過
5. npm run push:dev 推送 4 個前端檔案
6. 手動 smoke test：
   6.1 開 web app → 看到 datalist 載入 360 人
   6.2 搜尋一個名字 → 跳轉 main 頁
   6.3 在 main 頁選日期 → 提交 → 確認寫入 daily_reports
   6.4 跳到 history → 看到剛填的紀錄
```

#### 失敗時的 Rollback

每階段都有不同 rollback：

| 階段 | Rollback 方式 |
|---|---|
| SQL 09 失敗 | `DROP TABLE teams, squads CASCADE` 重來 |
| SQL 10 失敗 | 手動恢復 daily_reports schema（從 04-normalize-schema.sql 重跑），再 retry |
| SQL 11 失敗 | `TRUNCATE members, squads, teams CASCADE`，修 SQL 後重跑 |
| SQL 12 失敗 | PIN 拆除算最簡單的，失敗就手動 `DROP FUNCTION` + `ALTER TABLE DROP COLUMN` |
| 前端 push 失敗 | git revert 對應 commit + npm run push:dev |
| 前端有 bug | git revert 之後 `npm run pull:dev` 把測試 Apps Script 拉回 git 版本 |

整個 change 在 demo 階段執行，沒有「正式環境受影響」的後果。

## Open Questions

1. **同小隊同名隊員的 ID 衝突**：需先跑檢查 SQL 後再決定要在 ID 加流水號（`T011_王雅慧_2_嘉家久`）還是回主辦方確認名單修正。Johnson 在 SQL 11 執行前必須先確認檢查結果。

2. **`teams.form_label` 欄位是否值得建**：主路線「大隊對照表」有「收到的表單名」欄（例：「（嘉義）平安」），但目前 Supabase 不收 LINE Bot / Form 來源資料；建欄位是預留將來整合，是否值得多加？建議**先建空欄位**，省得未來再 ALTER TABLE。

3. **既有 demo daily_reports 是否真的能 truncate**：Johnson 確認測試環境沒有需要保留的歷史資料才執行 SQL 10。建議在執行前 `SELECT COUNT(*) FROM daily_reports` 留檔。

4. **是否在本 change 同步更新 CLAUDE.md**：本 change 動到「技術架構」「技術債」章節 — 在 tasks 內列出更新動作，還是另開 docs-only PR？建議併入本 change 的 tasks，避免 CLAUDE.md 跟 schema 脫節。
