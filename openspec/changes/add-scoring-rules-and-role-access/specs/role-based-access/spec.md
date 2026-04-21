## ADDED Requirements

### Requirement: Squad Scope View

The system SHALL expose a view `v_squad_scope(viewer_id BIGINT)` that returns the set of `members_public` rows visible to a given viewer based on their `role`.

The view MUST be implemented as a PL/pgSQL function returning `SETOF members_public` (since views cannot take parameters, the implementation is a table-returning function named `v_squad_scope` for API consistency).

Visibility rules:
- If viewer's `role = 'member'` → returns only the viewer's own row
- If viewer's `role = 'squad_leader'` → returns all members in viewer's `squad_id`
- If viewer's `role = 'team_leader'` → returns all members in viewer's `team_id`
- If viewer's `role IN ('auditor', 'admin', 'executive')` → returns all active members

If the viewer's `role` is unrecognized or the viewer's row is not found, the function MUST return an empty result set.

#### Scenario: Squad leader queries their scope

- **WHEN** `SELECT * FROM v_squad_scope(5)` is called where member 5 has `role = 'squad_leader'` and `squad_id = 3`
- **THEN** the result contains all active members with `squad_id = 3`
- **AND** does not contain members from other squads

#### Scenario: Member queries their scope

- **WHEN** `SELECT * FROM v_squad_scope(100)` is called where member 100 has `role = 'member'`
- **THEN** the result contains exactly one row with `id = 100`

#### Scenario: Auditor queries their scope

- **WHEN** `SELECT * FROM v_squad_scope(200)` is called where member 200 has `role = 'auditor'`
- **THEN** the result contains all active members across all squads and teams

### Requirement: Visible Reports RPC

The system SHALL expose an RPC `get_visible_reports(p_viewer_id BIGINT, p_start_date DATE DEFAULT NULL, p_end_date DATE DEFAULT NULL)` that returns `daily_reports` rows visible to the viewer, optionally filtered by date range.

The function MUST be declared `SECURITY DEFINER` and `GRANT EXECUTE TO anon, authenticated`.

The function MUST internally call `v_squad_scope(p_viewer_id)` to determine which member_ids the viewer can see, then return `daily_reports` rows matching those member_ids.

The returned rows MUST have columns: `report_id BIGINT`, `member_id BIGINT`, `member_name TEXT`, `squad_id BIGINT`, `team_id BIGINT`, `report_date DATE`, `total_score INTEGER`, `remarks TEXT`, `submitted_at TIMESTAMPTZ`.

When `p_start_date` is provided, only rows with `report_date >= p_start_date` are returned. When `p_end_date` is provided, only rows with `report_date <= p_end_date` are returned. Both NULL means no date filter.

#### Scenario: Squad leader retrieves squad reports

- **WHEN** `SELECT * FROM get_visible_reports(5, '2026-05-03', '2026-05-09')` is called and member 5 is a `squad_leader` of squad 3
- **THEN** the result contains only reports from members in squad 3 submitted between those dates
- **AND** joins `member_name` from `members_public`

#### Scenario: Regular member retrieves own reports only

- **WHEN** `SELECT * FROM get_visible_reports(100, NULL, NULL)` is called and member 100 has `role = 'member'`
- **THEN** the result contains only rows where `member_id = 100`

### Requirement: Client Must Supply Viewer ID

The system SHALL require callers of `v_squad_scope` and `get_visible_reports` to explicitly supply `p_viewer_id`. There is no session-derived `auth.uid()` available in the current PIN-based authentication scheme.

This requirement MUST be documented as a known security limitation: a malicious client may pass an arbitrary `viewer_id` to impersonate another user. Mitigation is deferred to a separate change that migrates authentication to Supabase Auth JWT.

#### Scenario: Known limitation acknowledged

- **WHEN** a developer reviews `design.md` of this change
- **THEN** the Risks section explicitly lists "Client can forge viewer_id → scope escalation" as an accepted demo-stage tradeoff
- **AND** the mitigation is cross-referenced to the future `migrate-to-supabase-auth` change
