## ADDED Requirements

### Requirement: Teams Master Table

The system SHALL store team-level (大隊) master data in a dedicated `teams` table.

The table MUST include columns: `id BIGSERIAL PRIMARY KEY`, `team_code TEXT NOT NULL UNIQUE` (matching the pattern `T[0-9]{2}`, e.g., `T01` through `T18`), `team_name TEXT NOT NULL` (descriptive name such as `嘉家久`), `team_order SMALLINT NOT NULL` (1-18, used for ranking order), `leader_name TEXT NOT NULL` (the team leader's display name, e.g., `平安`), `form_label TEXT` (nullable; the LINE/Form source label such as `（嘉義）平安`, reserved for future LINE Bot integration), `is_active BOOLEAN NOT NULL DEFAULT true`.

Row-Level Security MUST be enabled with a policy allowing `anon` and `authenticated` roles to SELECT all rows. Write operations are restricted to `service_role`.

#### Scenario: Querying all active teams

- **WHEN** a client using the anon key queries `SELECT team_code, team_name, leader_name FROM teams WHERE is_active = true ORDER BY team_order`
- **THEN** the system returns up to 18 rows in team order, each describing one team

#### Scenario: Attempting to insert duplicate team_code

- **WHEN** a caller attempts to insert two rows with `team_code = 'T01'`
- **THEN** the system rejects the second insert with a UNIQUE constraint violation

### Requirement: Squads Master Table

The system SHALL store squad-level (小隊) master data in a dedicated `squads` table, where each squad belongs to exactly one team.

The table MUST include columns: `id BIGSERIAL PRIMARY KEY`, `squad_code TEXT NOT NULL UNIQUE` (matching the pattern `T[0-9]{2}[0-9]`, e.g., `T010` through `T184`, where the first three characters MUST equal a valid `teams.team_code`), `team_id BIGINT NOT NULL REFERENCES teams(id) ON DELETE RESTRICT`, `squad_leader_name TEXT NOT NULL` (the squad leader's display name), `is_active BOOLEAN NOT NULL DEFAULT true`.

A CHECK constraint MUST verify that `LEFT(squad_code, 3) = (SELECT team_code FROM teams WHERE id = team_id)` either via a database trigger or via application-level validation in the import script.

Row-Level Security MUST be enabled with a policy allowing `anon` and `authenticated` roles to SELECT all rows. Write operations are restricted to `service_role`.

#### Scenario: Querying squads under a team

- **WHEN** a client queries `SELECT squad_code, squad_leader_name FROM squads WHERE team_id = (SELECT id FROM teams WHERE team_code = 'T01') ORDER BY squad_code`
- **THEN** the system returns all squads belonging to team T01 in squad_code order

#### Scenario: Attempting to insert squad with mismatched team prefix

- **WHEN** a caller attempts to insert a row with `squad_code = 'T020'` and `team_id` referencing the row where `team_code = 'T01'`
- **THEN** the system rejects the insert because the squad_code prefix does not match the team's team_code

### Requirement: Members Squad Foreign Key

The `members` table SHALL include `squad_id BIGINT NOT NULL REFERENCES squads(id) ON DELETE RESTRICT` linking each member to exactly one squad.

The `members` table MUST also include `leader_name TEXT NOT NULL` denormalising the squad leader's display name for fast UI rendering without additional joins.

#### Scenario: Querying members in a squad

- **WHEN** a client queries `SELECT name, leader_name FROM members WHERE squad_id = (SELECT id FROM squads WHERE squad_code = 'T011') ORDER BY name`
- **THEN** the system returns all members belonging to squad T011 with their squad leader's name

### Requirement: Real Roster Import Migration

The change MUST include an idempotent SQL migration script that imports the 360+ real members from the source spreadsheet (副本0425 「人員總表」), populating `teams`, `squads`, and `members` tables with the production roster.

The migration script MUST:
- Be safely re-runnable: prior data in the three tables MUST be cleared (TRUNCATE CASCADE) before insertion
- Insert exactly 18 rows into `teams`
- Insert all squads (approximately 80 rows, exact count derived from the source) into `squads`
- Insert all members (approximately 360+ rows) into `members` with correct `squad_id` foreign keys
- Verify post-conditions via a `DO $$ ... RAISE NOTICE ... $$` block at end of script: report the inserted row counts for each table

#### Scenario: Fresh import on empty schema

- **WHEN** a developer applies the migration on a freshly migrated schema (after teams/squads tables created)
- **THEN** `SELECT COUNT(*) FROM teams` returns 18
- **AND** `SELECT COUNT(*) FROM squads` returns the expected total (≥ 70)
- **AND** `SELECT COUNT(*) FROM members` returns the expected total (≥ 360)
- **AND** every member row's `squad_id` resolves to a valid `squads.id`

#### Scenario: Re-running migration on populated schema

- **WHEN** the migration is executed a second time after data already exists
- **THEN** prior rows in `members`, `squads`, `teams` are removed via TRUNCATE CASCADE
- **AND** the same final row counts are produced as a fresh import
