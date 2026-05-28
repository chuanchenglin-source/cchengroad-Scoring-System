# 偵查官端 spectra change 草稿

**用途**：本檔案是「偵查官扣分機制」雙系統設計的**偵查官端**部分。本 repo 是計分系統端（顯示），偵查官端要在姊妹 repo `cchengroad-Monitor-System` 開另一個 spectra change。

**怎麼用**：早上 clone 完 `cchengroad-Monitor-System` 後，把本檔案內容當 `/spectra-propose` 的輸入，或者直接拿 proposal/design/spec 段落貼進去。

**對應的計分系統端 change**：[add-deduction-display-in-history](../openspec/changes/add-deduction-display-in-history/)（本 repo，已 apply 完代碼）

---

## 建議的 change 名稱

`add-deduction-write-flow`

## 建議分類

Feature

## Proposal 內容（可直接貼到偵查官 repo 的 proposal.md）

### Why

偵查官（審計官）目前在 `cchengroad-Monitor-System` 系統只能 read-only 查看各小隊的填分狀況，沒有任何寫入或記錄扣分的能力。違規案例現行流程是 LINE 群組通報主辦方手動處理，會變成主辦方的工作瓶頸。

本 change 是「偵查官扣分機制」雙系統設計的偵查官端，負責提供扣分輸入介面、撤回介面，並把扣分記錄寫入偵查官系統的「扣分記錄」分頁。對應的計分系統端 change（`add-deduction-display-in-history`）在另一個 repo `cchengroad-Scoring-System`，負責 history.html 讀取扣分並顯示給被扣分的隊員。

### What Changes

- 在偵查官系統的查看頁面，每筆填分記錄新增「扣分」按鈕（針對 box 維度）
- 點扣分按鈕開啟扣分對話框（modal），讓偵查官填寫扣分數值與原因
- 送出後寫一筆新記錄到偵查官 Sheet 「扣分記錄」分頁，狀態為 `active`
- 新增「我的扣分清單」頁面，列出當前偵查官扣的所有 active 扣分
- 在清單上提供「撤回」按鈕，點下後把該筆狀態改為 `withdrawn`、補上撤回者 ID / 撤回時間 / 撤回原因
- 新增「主辦方撤回介面」（限主辦方身分），可撤回任何偵查官扣的記錄
- 在偵查官系統的 config 新增 `SS_ID_DEDUCTION` 常數，指向偵查官 Sheet
- 副本測試環境（5 個資源 ID）驗證後 PR 給主工程師（或 Johnson 自己 review，視 repo 流程）

### Non-Goals

- **計分系統端 history.html 顯示扣分**：在 `cchengroad-Scoring-System` 已處理（change `add-deduction-display-in-history`）
- **被扣分者主動通知機制**：不在本 change 範圍
- **規則對齊**：跟主辦方對齊「立刻生效 + 撤回」流程是規則層面，技術不阻塞

### Capabilities

#### New Capabilities

- `deduction-write-flow`: 偵查官在系統內輸入扣分、寫入扣分記錄分頁、撤回自己扣的、主辦方撤回任意扣分

#### Modified Capabilities

(none — 偵查官原本沒有 spec，本 change 是純新增)

### Impact

- Affected specs: `deduction-write-flow` (new)
- Affected code（推測，視偵查官 repo 結構而定）:
  - Modified: `config.js`、`webApp.js`（或 `Code.gs`）、偵查官查看頁面 HTML
  - New: 扣分對話框 HTML 模板、撤回頁面 HTML
  - Removed: 無

---

## Design 內容要點（草稿）

### Context

偵查官系統原本只 read-only 讀計分系統的 Sheet 顯示填分狀況。本 change 打破「偵查官純讀」的限制，新增寫入路徑：偵查官 Sheet 新增「扣分記錄」分頁（12 欄結構），偵查官端介面操作後寫入這張分頁。

副本測試環境（2026-05-29 已就緒）：
- 副本偵查官 GAS: `1UGg3htqYDVRjJBewGdvNpZsj4fjmuSLSxvC9_3o_e5SSYfbVbkvFiI3-`
- 副本偵查官 Sheet: `1_bkaXcApXPKe9I1kF0DL4gne06e__8YiC5yy5FOgT3Y`（「扣分記錄」分頁已建好 12 欄結構）

### Decisions

#### 扣分流程的觸發點

選擇：在偵查官查看頁面，每筆填分記錄的每個 box 旁邊放「扣分」按鈕，點下後彈出 modal 填寫扣分數值 + 原因。
取代的選項：獨立「新增扣分」頁面要先選人再選日期再選 box — 拒絕：脫離偵查官「邊看邊扣」的自然工作流。

#### 身分驗證複用

選擇：複用偵查官系統現有的登入機制（小隊長 / 審計官登入），扣分時自動帶入 `偵查官 ID`。
取代的選項：扣分要再輸入密碼確認 — 拒絕：增加摩擦，副本階段先簡化。

#### 撤回介面分權

選擇：偵查官清單頁面只列出「自己扣的 active」，每筆有「撤回」按鈕；主辦方撤回是獨立頁面，列出「全部 active」可撤回任何一筆。
取代的選項：合併成同一頁面用角色篩選 — 拒絕：權限混淆風險。

#### 撤回紀錄不刪除

選擇：撤回不刪除 row，只把 `狀態` 從 `active` 改為 `withdrawn`、補三個撤回欄位。
取代的選項：刪除 row — 拒絕：無法稽核「扣了又撤」濫權情況。

### Implementation Contract（要點）

**扣分寫入 API**：
- 輸入：`{被扣人ID, 填分日期, Box編號, 扣分數值, 扣分原因}` + 從 session 取的偵查官 ID
- 行為：在「扣分記錄」分頁 append 一列，`扣分編號`流水號（取目前最大值+1）、`狀態 = 'active'`、`扣分時間 = new Date()`，撤回三欄留空
- 回傳：`{success: true, deduction_id: <new>}` 或 `{success: false, error: <msg>}`

**撤回 API**：
- 輸入：`{deduction_id, 撤回原因}` + 從 session 取的撤回者 ID
- 行為：找到該 row，檢查呼叫者權限（自己扣的或主辦方），通過則改 `狀態 = 'withdrawn'`、補三個撤回欄位
- 回傳：`{success: true}` 或 `{success: false, error: 'permission_denied' | 'not_found' | <msg>}`

**契約對齊**：扣分記錄分頁的 12 欄結構、欄位語意與 [計分系統端 design.md](../openspec/changes/add-deduction-display-in-history/design.md) 完全一致；雙端共用同一張 Sheet 同一個欄位定義。

### 範圍邊界

In scope：扣分輸入介面、撤回介面、寫入流程、主辦方撤回頁面、副本環境驗證
Out of scope：計分系統端顯示（已處理）、規則對齊、通知機制、扣分審核（已決定「立刻生效」）

---

## Spec 草稿要點（English required）

主要 requirements（細節請對齊本 repo `monitor-deduction-display` spec 的契約）：

- Requirement: Deduction Write API
- Requirement: Self-Withdraw Restriction (a monitor can only withdraw their own active deductions)
- Requirement: Organizer Withdraw All
- Requirement: Withdraw Does Not Delete
- Requirement: Sheet ID Configuration

每個 requirement 至少 1 個 scenario，4 hashtag (`####`)。

---

## Tasks 草稿要點

```
## 1. 環境設定
- [ ] 1.1 在偵查官 config 加 SS_ID_DEDUCTION 常數
- [ ] 1.2 確認副本偵查官 Sheet 「扣分記錄」分頁 12 欄已建好（已完成）

## 2. 後端寫入 API
- [ ] 2.1 實作 writeDeduction(payload) — append 到扣分記錄分頁
- [ ] 2.2 實作 withdrawDeduction(deductionId, reason) — 改狀態 + 補欄位 + 權限檢查

## 3. 前端介面
- [ ] 3.1 查看頁面每 box 加扣分按鈕 + 扣分 modal
- [ ] 3.2 「我的扣分清單」頁面 + 撤回按鈕
- [ ] 3.3 主辦方撤回頁面（限主辦方身分）

## 4. 副本驗收
- [ ] 4.1 扣分後副本 Sheet 出現新列、狀態 active
- [ ] 4.2 自己撤回後狀態變 withdrawn、撤回三欄填好
- [ ] 4.3 偵查官 A 試圖撤回偵查官 B 的扣分 → 失敗（權限拒絕）
- [ ] 4.4 主辦方撤回任意扣分 → 成功
- [ ] 4.5 端對端：偵查官副本扣分 → 計分系統副本 history.html 顯示
```

---

## 早上的執行步驟

1. clone repo:
   ```bash
   cd "C:/Coding Project/Corporate Website"
   gh repo clone <your-org>/cchengroad-Monitor-System
   # 或：git clone https://github.com/<your-org>/cchengroad-Monitor-System
   ```

2. 進入 repo 開 spectra change:
   ```bash
   cd cchengroad-Monitor-System
   claude
   ```
   然後告訴 Claude：「**請按照計分系統 repo 的 `docs/偵查官端-spectra-change-草稿-2026-05-29.md` 開一個 spectra change，名稱用 `add-deduction-write-flow`**」

3. Claude 會基於這份草稿做 propose → analyze → validate → park
