# daily-report-scoring Specification

## Purpose

TBD - created by archiving change 'normalize-daily-report-schema'. Update Purpose after archive.

## Requirements

### Requirement: Normalized Box Definition Schema

The system SHALL store box metadata (number, week, title, input type, max score) in a dedicated `box_definitions` table instead of hardcoding it in frontend HTML.

The table MUST include columns: `id BIGINT PRIMARY KEY`, `activity_id BIGINT NOT NULL DEFAULT 1`, `box_no SMALLINT NOT NULL` (1-40), `week_no SMALLINT` (nullable; 1-8 for week-specific boxes, NULL for persistent/全期 boxes such as daily exercises and bonus items), `category TEXT` (nullable; one of '主修', '選修', '主題親證', '加分題'), `title TEXT NOT NULL`, `note TEXT`, `input_type TEXT NOT NULL CHECK (input_type IN ('score_only','checkbox','text','mixed'))`, `multi_select BOOLEAN NOT NULL DEFAULT true` (false for radio-style single-select UI), `max_score INTEGER NOT NULL DEFAULT 0 CHECK (max_score >= 0)`, `is_active BOOLEAN NOT NULL DEFAULT true`.

A UNIQUE constraint MUST exist on `(activity_id, box_no)`.

#### Scenario: Querying box metadata

- **WHEN** a client queries `SELECT * FROM box_definitions WHERE activity_id = 1 AND is_active = true ORDER BY box_no`
- **THEN** the system returns up to 40 rows, each describing one box with its week, title, input type, and max score

#### Scenario: Attempting to insert duplicate box number

- **WHEN** a client attempts to insert two rows with the same `(activity_id, box_no)` combination
- **THEN** the system rejects the second insert with a UNIQUE constraint violation


<!-- @trace
source: normalize-daily-report-schema
updated: 2026-04-21
code:
  - scripts/supabase-import/06-scoring-rules.sql
  - docs/待辦-手動測試驗收-2026-04-20.md
  - scripts/supabase-import/08-tighten-rls.sql
  - CLAUDE.md
  - docs/規則未定清單-2026-04-21.md
  - scripts/supabase-import/04b-seed-box-definitions.sql
  - main.html
  - scripts/supabase-import/07-role-scoped-views.sql
  - history.html
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - supabase-client.html
-->

---
### Requirement: Normalized Box Option Schema

The system SHALL store selectable options for checkbox-type boxes in a `box_options` table, one row per option.

The table MUST include columns: `id BIGINT PRIMARY KEY`, `box_definition_id BIGINT NOT NULL REFERENCES box_definitions(id)`, `option_label TEXT NOT NULL`, `score_value INTEGER NOT NULL DEFAULT 0`, `display_order SMALLINT NOT NULL DEFAULT 0`, `is_active BOOLEAN NOT NULL DEFAULT true`.

#### Scenario: Querying options for a checkbox box

- **WHEN** a client queries `SELECT * FROM box_options WHERE box_definition_id = <id> AND is_active = true ORDER BY display_order`
- **THEN** the system returns all active options for that box in display order


<!-- @trace
source: normalize-daily-report-schema
updated: 2026-04-21
code:
  - scripts/supabase-import/06-scoring-rules.sql
  - docs/待辦-手動測試驗收-2026-04-20.md
  - scripts/supabase-import/08-tighten-rls.sql
  - CLAUDE.md
  - docs/規則未定清單-2026-04-21.md
  - scripts/supabase-import/04b-seed-box-definitions.sql
  - main.html
  - scripts/supabase-import/07-role-scoped-views.sql
  - history.html
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - supabase-client.html
-->

---
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


<!-- @trace
source: align-with-main-dev-0425
updated: 2026-04-28
code:
  - .claspignore
  - Admin.html
  - CLAUDE.md
  - scripts/supabase-import/13-create-admin-credentials.sql
  - Index.html
  - main.html
  - scripts/supabase-import/03-rls-and-auth.sql
  - scripts/supabase-import/09-create-teams-squads.sql
  - scripts/supabase-import/12-remove-pin-auth.sql
  - scripts/supabase-import/14-create-permission-matrix.sql
  - scripts/supabase-import/bootstrap-admin.sql.example
  - scripts/supabase-import/11-import-real-roster.sql
  - webApp.js
  - history.html
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - supabase-client.html
  - scripts/supabase-import/10-alter-members-id-type.sql
-->

---
### Requirement: Daily Report Item Option Junction

The system SHALL record selected options for checkbox-type box entries in a `daily_report_item_options` junction table, one row per selected option.

The table MUST include columns: `item_id BIGINT NOT NULL REFERENCES daily_report_items(id) ON DELETE CASCADE`, `option_id BIGINT NOT NULL REFERENCES box_options(id)`, with PRIMARY KEY `(item_id, option_id)`.

#### Scenario: Recording selected options

- **WHEN** a caller records that a user selected 3 options for a checkbox box
- **THEN** the system inserts 3 rows into `daily_report_item_options`, each linking the item to one selected option

#### Scenario: Deleting a report cascades to items and options

- **WHEN** a `daily_reports` row is deleted
- **THEN** all referencing `daily_report_items` rows are automatically deleted
- **AND** all `daily_report_item_options` rows referencing those items are automatically deleted


<!-- @trace
source: normalize-daily-report-schema
updated: 2026-04-21
code:
  - scripts/supabase-import/06-scoring-rules.sql
  - docs/待辦-手動測試驗收-2026-04-20.md
  - scripts/supabase-import/08-tighten-rls.sql
  - CLAUDE.md
  - docs/規則未定清單-2026-04-21.md
  - scripts/supabase-import/04b-seed-box-definitions.sql
  - main.html
  - scripts/supabase-import/07-role-scoped-views.sql
  - history.html
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - supabase-client.html
-->

---
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


<!-- @trace
source: align-with-main-dev-0425
updated: 2026-04-28
code:
  - .claspignore
  - Admin.html
  - CLAUDE.md
  - scripts/supabase-import/13-create-admin-credentials.sql
  - Index.html
  - main.html
  - scripts/supabase-import/03-rls-and-auth.sql
  - scripts/supabase-import/09-create-teams-squads.sql
  - scripts/supabase-import/12-remove-pin-auth.sql
  - scripts/supabase-import/14-create-permission-matrix.sql
  - scripts/supabase-import/bootstrap-admin.sql.example
  - scripts/supabase-import/11-import-real-roster.sql
  - webApp.js
  - history.html
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - supabase-client.html
  - scripts/supabase-import/10-alter-members-id-type.sql
-->

---
### Requirement: Activity Identifier Reservation

All main domain tables (`box_definitions`, `daily_reports`, and optionally `daily_report_items`) MUST include a column `activity_id BIGINT NOT NULL DEFAULT 1`.

The system MUST NOT create an `activities` table in this change.

The system MUST NOT declare a foreign key on `activity_id` in this change.

#### Scenario: Default activity assignment

- **WHEN** a row is inserted without specifying `activity_id`
- **THEN** the system assigns `activity_id = 1` by default


<!-- @trace
source: normalize-daily-report-schema
updated: 2026-04-21
code:
  - scripts/supabase-import/06-scoring-rules.sql
  - docs/待辦-手動測試驗收-2026-04-20.md
  - scripts/supabase-import/08-tighten-rls.sql
  - CLAUDE.md
  - docs/規則未定清單-2026-04-21.md
  - scripts/supabase-import/04b-seed-box-definitions.sql
  - main.html
  - scripts/supabase-import/07-role-scoped-views.sql
  - history.html
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - supabase-client.html
-->

---
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


<!-- @trace
source: align-with-main-dev-0425
updated: 2026-04-28
code:
  - .claspignore
  - Admin.html
  - CLAUDE.md
  - scripts/supabase-import/13-create-admin-credentials.sql
  - Index.html
  - main.html
  - scripts/supabase-import/03-rls-and-auth.sql
  - scripts/supabase-import/09-create-teams-squads.sql
  - scripts/supabase-import/12-remove-pin-auth.sql
  - scripts/supabase-import/14-create-permission-matrix.sql
  - scripts/supabase-import/bootstrap-admin.sql.example
  - scripts/supabase-import/11-import-real-roster.sql
  - webApp.js
  - history.html
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - supabase-client.html
  - scripts/supabase-import/10-alter-members-id-type.sql
-->

---
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


<!-- @trace
source: align-with-main-dev-0425
updated: 2026-04-28
code:
  - .claspignore
  - Admin.html
  - CLAUDE.md
  - scripts/supabase-import/13-create-admin-credentials.sql
  - Index.html
  - main.html
  - scripts/supabase-import/03-rls-and-auth.sql
  - scripts/supabase-import/09-create-teams-squads.sql
  - scripts/supabase-import/12-remove-pin-auth.sql
  - scripts/supabase-import/14-create-permission-matrix.sql
  - scripts/supabase-import/bootstrap-admin.sql.example
  - scripts/supabase-import/11-import-real-roster.sql
  - webApp.js
  - history.html
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - supabase-client.html
  - scripts/supabase-import/10-alter-members-id-type.sql
-->

---
### Requirement: Row-Level Security for New Tables

The system SHALL enable RLS on `box_definitions`, `box_options`, `daily_report_items`, and `daily_report_item_options`, with demo-stage policies that allow `anon` to SELECT on all four tables and INSERT on `daily_report_items` and `daily_report_item_options` (because writes go through the SECURITY DEFINER RPC, but bypass-safety requires permissive policies during demo).

#### Scenario: Anonymous read of box definitions

- **WHEN** a client using the anon key queries `box_definitions`
- **THEN** the query succeeds and returns active rows

#### Scenario: Demo-stage permissive write policy

- **WHEN** a client using the anon key attempts to INSERT directly into `daily_reports` without going through `save_daily_report` RPC during the demo stage
- **THEN** the insert SHALL be permitted by the demo-stage RLS policy
- **AND** production-hardening (restricting direct writes) is out of scope and tracked as a separate future change


<!-- @trace
source: normalize-daily-report-schema
updated: 2026-04-21
code:
  - scripts/supabase-import/06-scoring-rules.sql
  - docs/待辦-手動測試驗收-2026-04-20.md
  - scripts/supabase-import/08-tighten-rls.sql
  - CLAUDE.md
  - docs/規則未定清單-2026-04-21.md
  - scripts/supabase-import/04b-seed-box-definitions.sql
  - main.html
  - scripts/supabase-import/07-role-scoped-views.sql
  - history.html
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - supabase-client.html
-->

---
### Requirement: Seed Data for Box Definitions

The change MUST include a seed SQL script that INSERTs 40 rows into `box_definitions` (one per box) with values derived from the current `main.html` box structure, and INSERTs `box_options` rows for every checkbox-type box covering all its selectable options.

#### Scenario: Fresh database after applying the change

- **WHEN** a developer runs all migration scripts on a clean Supabase project
- **THEN** `SELECT COUNT(*) FROM box_definitions WHERE activity_id = 1` returns 40
- **AND** every checkbox-type box has at least one corresponding row in `box_options`

<!-- @trace
source: normalize-daily-report-schema
updated: 2026-04-21
code:
  - scripts/supabase-import/06-scoring-rules.sql
  - docs/待辦-手動測試驗收-2026-04-20.md
  - scripts/supabase-import/08-tighten-rls.sql
  - CLAUDE.md
  - docs/規則未定清單-2026-04-21.md
  - scripts/supabase-import/04b-seed-box-definitions.sql
  - main.html
  - scripts/supabase-import/07-role-scoped-views.sql
  - history.html
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - supabase-client.html
-->