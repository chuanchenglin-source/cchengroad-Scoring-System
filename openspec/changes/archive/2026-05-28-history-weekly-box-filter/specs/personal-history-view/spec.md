## ADDED Requirements

### Requirement: Per-week box visibility filtering on personal history page

The personal history page SHALL render box cards as the union of two sets: (a) a fixed box set that appears every week regardless of the selected week, and (b) a week-specific theme box set determined by the currently selected week.

The fixed box set MUST contain exactly the box numbers `[1, 2, 21, 22, 23, 24, 25, 26, 27, 41]`. These correspond to 主修打拳, 選修定課, 聯誼會會籍, 高階課程, 傳愛完款, 傳愛訂金, 進階課程, 全部高階完款, 上課出席, and 團隊動能.

The week-to-theme-boxes mapping MUST be exactly:

- W1: `[]`
- W2: `[3]`
- W3: `[4, 5, 6, 7]`
- W4: `[8, 9, 10, 11]`
- W5: `[12, 13, 14]`
- W6: `[15, 16]`
- W7: `[17, 18, 19]`
- W8: `[20]`

Box numbers 28 through 40 (加分題3 to 加分題15) MUST NOT be rendered on the history page, because their corresponding entries in the data submission form are placeholder shells without options.

The previous hard-coded `visibleBoxes` array on the history page MUST be removed.

#### Scenario: User views the W3 history page

- **WHEN** the user switches to week 3 on the personal history page
- **THEN** the page renders exactly 14 box cards: Box 1, 2 (fixed daily practice), Box 4, 5, 6, 7 (W3 theme), Box 21, 22, 23, 24, 25, 26, 27 (fixed bonus categories), and Box 41 (team momentum)
- **AND** no other box cards are rendered (in particular, no Box 3, no Box 8 to 20, no Box 28 to 40)

##### Example: W3 card list

| Position | Box | Title |
| -------- | --- | --- |
| 1 | 1 | 主修打拳 |
| 2 | 2 | 選修定課 |
| 3 | 4 | 電影行動方案 |
| 4 | 5 | 火寶藏-親證分享文 |
| 5 | 6 | 火寶藏-心得回饋反思 |
| 6 | 7 | 火寶藏-天使通話 |
| 7 | 21 | 聯誼會會籍 |
| 8 | 22 | 高階課程 |
| 9 | 23 | 傳愛完款 |
| 10 | 24 | 傳愛訂金 |
| 11 | 25 | 進階課程 |
| 12 | 26 | 全部高階完款 |
| 13 | 27 | 上課出席 |
| 14 | 41 | 團隊動能 |

#### Scenario: User views the W1 history page (a week without theme boxes)

- **WHEN** the user switches to week 1 on the personal history page
- **THEN** the page renders exactly 10 box cards drawn only from the fixed set: Box 1, 2, 21, 22, 23, 24, 25, 26, 27, and 41
- **AND** no theme cards from Box 3 to Box 20 are rendered, and no placeholder cards from Box 28 to Box 40 are rendered

#### Scenario: User views the W8 history page

- **WHEN** the user switches to week 8 on the personal history page
- **THEN** the page renders exactly 11 box cards: Box 1, 2 (fixed daily), Box 20 (W8 theme: 互助合作-天使通話心得), Box 21, 22, 23, 24, 25, 26, 27 (fixed bonus), and Box 41 (team momentum)

#### Scenario: Card counts per week summary

##### Example: Card count by selected week

| Week | Fixed cards | Theme cards | Total cards rendered |
| ---- | ----------- | ----------- | -------------------- |
| W1 | 10 | 0 | 10 |
| W2 | 10 | 1 | 11 |
| W3 | 10 | 4 | 14 |
| W4 | 10 | 4 | 14 |
| W5 | 10 | 3 | 13 |
| W6 | 10 | 2 | 12 |
| W7 | 10 | 3 | 13 |
| W8 | 10 | 1 | 11 |

### Requirement: 8-week navigation on personal history page

The personal history page SHALL provide a week selector that renders exactly eight buttons, one per week W1 through W8 inclusive. Week 8 MUST be included even though its scores do not count toward final ranking, because users still need to review historical entries for the final week.

The weekly score accumulator MUST aggregate per-week scores for weeks 1 through 8 inclusive. The score-rendering loop that updates the per-week score badges MUST iterate from week 1 through week 8 inclusive.

#### Scenario: Week selector contains eight buttons

- **WHEN** the user opens the personal history page
- **THEN** the week picker renders eight buttons in order, labeled "第 1 週" through "第 8 週"
- **AND** each button displays its date range (start and end dates derived from `campaignConfig.startDate`) and its accumulated weekly score

#### Scenario: Week 8 accumulator processes W8 records

- **WHEN** the personal history page calculates per-week score summaries from `allHistoryData`
- **THEN** records whose computed `weekNum` equals 8 contribute to the W8 entry in the per-week score map
- **AND** the W8 score badge on the week selector displays the resulting total
