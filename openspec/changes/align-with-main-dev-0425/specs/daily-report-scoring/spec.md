## MODIFIED Requirements

### Requirement: Daily Report Item Storage

The system SHALL store each box entry of a daily report as one row in `daily_report_items`, replacing the previous `daily_reports.box_data` JSONB column which MUST be removed.

The `daily_report_items` table MUST include columns: `id BIGINT PRIMARY KEY`, `report_id BIGINT NOT NULL REFERENCES daily_reports(id) ON DELETE CASCADE`, `box_definition_id BIGINT NOT NULL REFERENCES box_definitions(id)`, `score INTEGER NOT NULL DEFAULT 0 CHECK (score >= 0)`, `content_text TEXT`, `audit_status TEXT NOT NULL DEFAULT 'pending' CHECK (audit_status IN ('pending','approved','rejected'))`, `audited_by TEXT REFERENCES members(id)`, `audited_at TIMESTAMPTZ`, `audit_notes TEXT`.

A UNIQUE constraint MUST exist on `(report_id, box_definition_id)`.

The `daily_reports` table MUST retain its existing columns (`id`, `report_date`, `total_score`, `remarks`, `submitted_at`) and gain `activity_id BIGINT NOT NULL DEFAULT 1`, but MUST NOT retain `box_data`. The `member_id` column type MUST be `TEXT REFERENCES members(id)` (changed from `BIGINT` because `members.id` is migrated to TEXT in this change).

#### Scenario: Writing a complete daily report

- **WHEN** a caller submits a daily report with 40 box entries
- **THEN** the system inserts one row into `daily_reports` and 40 rows into `daily_report_items` linked to it
- **AND** each `daily_report_items` row has `audit_status = 'pending'` by default

#### Scenario: Attempting duplicate box entry in same report

- **WHEN** a caller inserts two `daily_report_items` rows with the same `(report_id, box_definition_id)`
- **THEN** the system rejects the second insert with a UNIQUE constraint violation

#### Scenario: Auditing a report item references member by text id

- **WHEN** a caller updates a `daily_report_items` row with `audited_by = 'T011_周子維_嘉家久'`
- **THEN** the foreign key constraint accepts the value because it matches a row in `members(id)` of type TEXT

### Requirement: Atomic Daily Report Write via RPC

The system SHALL provide a PL/pgSQL function `save_daily_report(p_member_id TEXT, p_activity_id BIGINT, p_report_date DATE, p_total_score INTEGER, p_remarks TEXT, p_items JSONB)` that inserts one `daily_reports` row, N `daily_report_items` rows, and M `daily_report_item_options` rows in a single atomic transaction.

The `p_member_id` parameter MUST be of type `TEXT` (changed from `BIGINT` because `members.id` is migrated to TEXT in this change). The function body MUST validate that `p_member_id` exists in `members(id)` before insertion, raising an explicit exception if not found.

The `p_items` parameter MUST be a JSONB array where each element has shape `{ box_definition_id: BIGINT, score: INTEGER, content_text: TEXT or null, selected_option_ids: BIGINT[] }`.

If any insert fails, the entire transaction MUST roll back, leaving the database unchanged.

The function MUST return the new `daily_reports.id` on success.

The function MUST be granted EXECUTE to `anon` and `authenticated` roles.

#### Scenario: Successful atomic write with text member id

- **WHEN** a caller invokes `save_daily_report('T011_周子維_嘉家久', 1, '2026-05-10', 250, NULL, '[...]'::jsonb)` with valid payload containing 40 items
- **THEN** one row is inserted into `daily_reports` (with `member_id = 'T011_周子維_嘉家久'`) and 40 rows into `daily_report_items`
- **AND** any rows in `selected_option_ids` are inserted into `daily_report_item_options`
- **AND** the function returns the new `daily_reports.id`

#### Scenario: Partial failure triggers rollback

- **WHEN** a caller invokes `save_daily_report` and one `box_definition_id` is invalid (violates FK)
- **THEN** the transaction rolls back
- **AND** no rows are left in `daily_reports`, `daily_report_items`, or `daily_report_item_options` from this call
- **AND** the function raises an exception that the client receives

#### Scenario: Unknown member_id rejected explicitly

- **WHEN** a caller invokes `save_daily_report` with `p_member_id` that does not exist in `members(id)`
- **THEN** the function raises an exception with message identifying the missing member
- **AND** no rows are written to any table

### Requirement: Submission via Client API

The system SHALL expose daily report submission through `supabase-client.html:scoringAPI.saveReport(payload)` that invokes the `save_daily_report` RPC.

The `payload` parameter MUST have shape `{ memberId: TEXT, activityId: BIGINT (default 1), reportDate: TEXT (YYYY-MM-DD), totalScore: INTEGER, remarks: TEXT or null, items: Array<{box_definition_id, score, content_text, selected_option_ids}> }`. The `memberId` field MUST be of type TEXT (changed from BIGINT) and MUST contain a value matching the composite key format `<squad_code>_<name>_<team_name>`.

The API MUST return `{ success: true, reportId }` on success or `{ success: false, error: <message> }` on failure, without partial-state side effects on failure.

#### Scenario: Successful submission with text memberId

- **WHEN** `saveReport({ memberId: 'T011_周子維_嘉家久', ... })` is called with a well-formed payload
- **THEN** the API returns `{ success: true, reportId: <new id> }`
- **AND** subsequent `getPersonalHistory('T011_周子維_嘉家久')` calls reflect the new data

#### Scenario: Failed submission

- **WHEN** `saveReport(payload)` is called with an invalid `box_definition_id`
- **THEN** the API returns `{ success: false, error: <RPC error message> }`
- **AND** no partial data is persisted

### Requirement: History Retrieval via Join

The system SHALL expose personal history retrieval through `supabase-client.html:scoringAPI.getPersonalHistory(memberId)` that returns, for each report date, the report row joined with its items and selected options, reshaped into a flat object with keys `box1_score`, `box1_content`, ..., `box40_score`, `box40_content` so that `history.html` rendering code requires no change.

The `memberId` parameter MUST be of type TEXT (changed from BIGINT) and MUST contain a value matching the composite key format `<squad_code>_<name>_<team_name>`.

When multiple reports exist for the same `(member_id, report_date)`, the API MUST return only the most recent one (highest `submitted_at`).

#### Scenario: Retrieving history for a member with two reports on same day

- **WHEN** `getPersonalHistory('T011_周子維_嘉家久')` is called and the database has two `daily_reports` rows for that member on 2026-05-10
- **THEN** the API returns one entry for 2026-05-10 reflecting the later-submitted row's items and options

#### Scenario: Flattened output format

- **WHEN** `getPersonalHistory(memberId)` returns a record for a report containing items for box 1 (score 10, content "test") and box 2 (score 5, 2 options selected)
- **THEN** the record has keys `date`, `score`, `remark`, `box1_score = 10`, `box1_content = "test"`, `box2_score = 5`, `box2_content` as a comma-joined string of the selected option labels or content text
