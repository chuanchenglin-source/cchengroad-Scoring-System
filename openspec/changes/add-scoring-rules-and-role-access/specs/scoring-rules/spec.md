## ADDED Requirements

### Requirement: Scoring Rules Storage Table

The system SHALL store all runtime-configurable scoring rules in a dedicated `scoring_rules` table, allowing rule values to be changed via `UPDATE` without code deployment.

The table MUST include columns: `id BIGSERIAL PRIMARY KEY`, `activity_id BIGINT NOT NULL DEFAULT 1`, `rule_key TEXT NOT NULL`, `rule_value JSONB`, `description TEXT`, `category TEXT`, `is_active BOOLEAN NOT NULL DEFAULT true`, `updated_by BIGINT REFERENCES members(id)`, `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`.

A UNIQUE constraint MUST exist on `(activity_id, rule_key)`.

The `rule_value` column MAY be `NULL` to signal "not yet configured"; callers MUST treat `NULL` as a distinct state from any concrete value.

#### Scenario: Reading an unset rule

- **WHEN** a caller invokes `get_rule(1, 'half_completion_method')` and the row has `rule_value = NULL`
- **THEN** the function returns `NULL`
- **AND** the caller is expected to render a "rule not configured" state or fall back to a documented default

#### Scenario: Attempting duplicate rule key

- **WHEN** a client attempts to insert two rows with the same `(activity_id, rule_key)`
- **THEN** the system rejects the second insert with a UNIQUE constraint violation

### Requirement: Rule Reading Helper Function

The system SHALL expose a `get_rule(p_activity_id BIGINT, p_rule_key TEXT) RETURNS JSONB` PL/pgSQL function that returns the `rule_value` for a given `(activity_id, rule_key)` pair, or `NULL` if no row exists or `is_active = false`.

The function MUST be declared `SECURITY DEFINER` and `GRANT EXECUTE TO anon, authenticated`.

The function MUST NOT be the only mechanism to read rules (direct `SELECT` for admin / debugging is still allowed), but all Dashboard and scoring code paths SHALL use this function as the canonical reader.

#### Scenario: Rule exists and is active

- **WHEN** `get_rule(1, 'team_ranking_method')` is called and the row has `rule_value = '"average"'::jsonb`, `is_active = true`
- **THEN** the function returns `'"average"'::jsonb`

#### Scenario: Rule exists but is inactive

- **WHEN** `get_rule(1, 'deprecated_key')` is called and the row has `is_active = false`
- **THEN** the function returns `NULL`

### Requirement: Seed Rule Keys for Known Questions

The change MUST seed 7 rows into `scoring_rules` corresponding to the 7 outstanding scoring rule questions raised by the organizing team on 2026-04-21, with the following `rule_key` values:

- `w7_leadership_bonus_enabled`
- `full_completion_definition`
- `team_bonus_target`
- `half_completion_method`
- `team_ranking_method`
- `include_leaders_in_average`
- `audit_missing_item_action`

Each seeded row MUST have:
- `activity_id = 1`
- `description` explaining the original question in Chinese
- `category` set to one of `team_bonus`, `leadership`, `audit`, `ranking`, `completion`
- `rule_value = NULL` for keys whose answer is pending organizer confirmation
- `rule_value` set to a documented default for keys whose answer is already known:
  - `team_bonus_target = '"individual"'` (organizer confirmed: each qualifying person gets the bonus)
  - `team_ranking_method = '"average"'` (organizer confirmed: average, not total)

#### Scenario: Post-seed state of unknown rule

- **WHEN** a developer queries `SELECT rule_key, rule_value FROM scoring_rules WHERE rule_key = 'half_completion_method'`
- **THEN** the result shows `rule_value = NULL`
- **AND** the `description` column contains the original question text

#### Scenario: Post-seed state of known rule

- **WHEN** a developer queries `SELECT rule_value FROM scoring_rules WHERE rule_key = 'team_ranking_method'`
- **THEN** the result is `'"average"'::jsonb`

### Requirement: Activity Identifier Reservation on Rules

The `scoring_rules` table MUST include `activity_id BIGINT NOT NULL DEFAULT 1`, consistent with other main tables in the system.

The system MUST NOT declare a foreign key on `activity_id` in this change, consistent with the decision recorded in `normalize-daily-report-schema`.

#### Scenario: Multi-activity rule isolation

- **WHEN** a future activity is introduced by inserting rules with `activity_id = 2` for the same `rule_key` values
- **THEN** `get_rule(2, 'half_completion_method')` returns the value for activity 2, not activity 1
- **AND** existing queries with `activity_id = 1` are unaffected

### Requirement: Row-Level Security for Scoring Rules

The system SHALL enable RLS on `scoring_rules` with the following policies:

- `SELECT`: granted to `anon` and `authenticated` (rules are non-sensitive; Dashboard code needs read access)
- `INSERT` / `UPDATE` / `DELETE`: restricted to `service_role` only (rule changes require admin intervention via Supabase Dashboard or SQL Editor; `anon` / `authenticated` MUST NOT modify rules)

#### Scenario: Anonymous read of rules

- **WHEN** a client using the anon key queries `scoring_rules`
- **THEN** the query succeeds and returns all active rows for all activities

#### Scenario: Anonymous attempt to modify rule

- **WHEN** a client using the anon key attempts `UPDATE scoring_rules SET rule_value = ...`
- **THEN** the attempt is rejected by RLS
