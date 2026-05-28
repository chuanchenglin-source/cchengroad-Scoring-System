## ADDED Requirements

### Requirement: Cross-Sheet Read of Active Deductions

The system SHALL extend `webApp.js:getPersonalHistory(userId)` to read the deduction record sheet from the monitor system's spreadsheet (identified by the new `SS_ID_MONITOR_DEDUCTION` constant in `config.js`), filter rows where the 被扣人 ID equals `userId` AND the 狀態 column equals `active`, and attach the matching deductions to the response payload.

The system MUST sort matched deductions by 扣分時間 in ascending order before attaching them.

The system MUST exclude any rows where the 狀態 column equals `withdrawn` from the response.

#### Scenario: User has no active deductions

- **WHEN** `getPersonalHistory('T011_周子維_嘉家久')` is called and the deduction sheet contains zero rows matching the user with active status
- **THEN** the function returns the history records unchanged in shape compared to before this change
- **AND** every `box{N}_deductions` field on each record is an empty array

#### Scenario: User has one active deduction on one box

- **WHEN** `getPersonalHistory('T011_周子維_嘉家久')` is called and the deduction sheet contains exactly one matching active row with 填分日期 = 2026-05-12, Box 編號 = 5, 扣分數值 = 20
- **THEN** the returned record for date 2026-05-12 contains `box5_deductions` with length 1 and the element has the score, reason, monitor_id, and deduction_id keys
- **AND** all other `box{N}_deductions` arrays on that record are empty

#### Scenario: Withdrawn deductions are excluded

- **WHEN** the deduction sheet contains one active deduction and one withdrawn deduction for the same user on the same date and box
- **THEN** only the active deduction appears in `box{N}_deductions`
- **AND** the withdrawn deduction does not appear anywhere in the response

---

### Requirement: Deduction Payload Shape

For each history record returned by `getPersonalHistory`, the system MUST attach an array field named `box{N}_deductions` for every N in the range 1 to 14, even when the array is empty.

Each element of `box{N}_deductions` MUST contain exactly four keys: `score` (number, positive integer), `reason` (string), `monitor_id` (string), `deduction_id` (number, the deduction row unique identifier).

Pre-existing record fields including date, team, userId, userName, score, originalTime, remark, `box{N}_score`, and `box{N}_content` for N=1 through 14 MUST remain unchanged in shape and value.

#### Scenario: Empty deductions field is present even with no deductions

- **WHEN** a user with no deductions calls `getPersonalHistory`
- **THEN** each returned record has `box1_deductions` through `box14_deductions` all set to empty arrays
- **AND** none of these fields is undefined or null

#### Scenario: Multiple deductions on same box are sorted by time

- **WHEN** a user has two active deductions on date 2026-05-12 box 5, the first written at 10:00 with score 10, the second written at 14:00 with score 20
- **THEN** `box5_deductions` for that date has length 2
- **AND** the first element has score 10, the second element has score 20

##### Example: deduction array shape

- **GIVEN** a sheet row with 被扣人ID = T011_周子維_嘉家久, 填分日期 = 2026-05-12, Box 編號 = 5, 扣分數值 = 20, 扣分原因 = 心得疑似 AI 生成, 偵查官ID = T021_林某_嘉家久, 狀態 = active, 扣分編號 = 7
- **WHEN** `getPersonalHistory('T011_周子維_嘉家久')` is called
- **THEN** the record for 2026-05-12 contains `box5_deductions` of length 1, with the element having score 20, reason matching the input, monitor_id matching the input, and deduction_id equal to 7

---

### Requirement: Box-Card Embedded Deduction Display

The `history.html:renderBoxes()` function MUST, for each box card and each date row, render a deduction warning row directly below the original date row whenever the corresponding `box{N}_deductions` array has at least one element.

The deduction warning row MUST contain a visible red background, red foreground text, and a left border accent (recommended background #fef2f2, text #991b1b).

The deduction row text MUST display the deduction score with a leading minus sign, the reason, and the monitor identifier in a single line, formatted to clearly distinguish it from the regular filled-score row.

When multiple deductions exist for the same date and box, each deduction MUST be rendered on its own row in the same order as the array (ascending by deduction time).

#### Scenario: Deduction row appears below the original date row

- **WHEN** the box 5 card renders date 2026-05-12 and `box5_deductions` has one element with score 20, reason AI 文, monitor_id T021_林某_嘉家久
- **THEN** the table contains a row showing the date, the filled score, and the content
- **AND** immediately below it a red-styled row appears showing the deduction with negative sign, reason, and monitor identifier

#### Scenario: Multiple deductions render as separate rows

- **WHEN** `box5_deductions` for 2026-05-12 has two elements
- **THEN** two separate red-styled rows are rendered immediately below the date row, in array order

#### Scenario: No deductions means no extra rows

- **WHEN** `box5_deductions` for 2026-05-12 is an empty array
- **THEN** the table contains only the original date row with no additional row below

---

### Requirement: Net Score Calculation

The `history.html:calculateSummary()` function MUST compute the displayed total as the sum of all record scores minus the sum of all active deduction scores across all records and all box numbers.

Weekly score displayed in the week picker MUST equal the sum of scores for records within that week minus the sum of all active deduction scores within that same week.

The grand total displayed at the top of the page MUST be the same net value.

#### Scenario: Total reflects deduction

- **WHEN** a user has total filled score 780 across the campaign and total active deduction score 30
- **THEN** the grand total displayed shows 750

#### Scenario: Weekly score reflects deduction for that week only

- **WHEN** a user has 270 score in W3 with a 20-point active deduction on a W3 date, and 270 score in W4 with no W4 deductions
- **THEN** the W3 weekly score shows 250 and the W4 weekly score shows 270

##### Example: per-week deduction breakdown

| Week | Filled Score | Active Deductions | Displayed Week Score |
|------|--------------|-------------------|----------------------|
| W1   | 210          | 0                 | 210                  |
| W2   | 270          | 10                | 260                  |
| W3   | 270          | 20                | 250                  |
| W4   | 270          | 0                 | 270                  |

Grand total displayed equals the sum of displayed week scores (210 + 260 + 250 + 270 = 990).

---

### Requirement: Graceful Failure on Sheet Read Errors

When the system fails to open the monitor deduction sheet for any reason (the `SS_ID_MONITOR_DEDUCTION` constant is an empty string, the sheet does not exist, permission is denied, or any other error occurs), the system MUST log the error via `console.error` and return history records with all `box{N}_deductions` fields set to empty arrays.

The system MUST NOT throw an exception that prevents `history.html` from rendering.

When the monitor deduction sheet exists but the deduction record tab does not exist within it, the same fallback behavior applies.

When a specific row in the sheet has a missing or malformed required field (被扣人ID, 填分日期, Box編號, or 扣分數值), that row MUST be skipped, a warning logged via `console.warn`, and processing of other rows continued.

#### Scenario: Monitor sheet ID is empty string

- **WHEN** `SS_ID_MONITOR_DEDUCTION` is an empty string in config and `getPersonalHistory` is called
- **THEN** every returned record has all `box{N}_deductions` as empty arrays
- **AND** an error is logged
- **AND** the function returns successfully without throwing

#### Scenario: Malformed row is skipped

- **WHEN** the deduction sheet contains one valid active row and one row with the Box 編號 field missing
- **THEN** the valid row appears in the response
- **AND** the malformed row is skipped with a warning logged
- **AND** processing does not abort

---

### Requirement: Withdrawn Deductions Do Not Affect Display or Calculation

The system MUST treat rows where the 狀態 column equals `withdrawn` as if they did not exist: they MUST NOT appear in any `box{N}_deductions` array, MUST NOT be subtracted from grand total or weekly scores, and MUST NOT be rendered in any box card.

The system MUST NOT display any indication that a withdrawn deduction previously existed.

#### Scenario: Withdrawing a deduction restores the original score display

- **WHEN** a user has an active deduction of 20 points reducing W3 from 270 to 250, and the deduction status is changed to `withdrawn`
- **THEN** on the next call to `getPersonalHistory`, the W3 weekly score returns to 270
- **AND** the deduction row in the box 5 card disappears
- **AND** the grand total increases by 20
