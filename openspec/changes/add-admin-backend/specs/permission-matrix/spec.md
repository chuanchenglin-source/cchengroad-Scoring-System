## ADDED Requirements

### Requirement: Permission Matrix Table

The system SHALL store the role × capability permission matrix as data in a dedicated `permission_matrix` table, replacing the prior pattern of hardcoding role checks inside SQL functions.

The table MUST include columns: `id BIGSERIAL PRIMARY KEY`, `role TEXT NOT NULL` (matching one of `'member'`, `'squad_leader'`, `'team_leader'`, `'auditor'`, `'admin'`, `'executive'`), `capability TEXT NOT NULL` (a snake_case identifier such as `'read_scores'` or `'audit_items'`), `scope TEXT` (nullable; one of `'self'`, `'squad'`, `'team'`, `'all'`, `'assigned'`, or NULL when not applicable), `is_enabled BOOLEAN NOT NULL DEFAULT true`, `description TEXT`, `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`, `updated_by TEXT REFERENCES admin_credentials(admin_id)`.

A UNIQUE constraint MUST exist on `(role, capability)`.

A CHECK constraint MUST verify that `role` is one of the six allowed values.

Row-Level Security MUST be enabled with a policy allowing `anon` and `authenticated` roles to SELECT all rows. Write operations MUST be restricted to SECURITY DEFINER RPCs invoked by authenticated admins.

#### Scenario: Querying permission_matrix is publicly readable

- **WHEN** a client using the anon key queries `SELECT role, capability, scope, is_enabled FROM permission_matrix WHERE is_enabled = true`
- **THEN** the query succeeds and returns the seeded matrix rows

#### Scenario: Direct write to permission_matrix is denied

- **WHEN** a client using the anon key attempts `INSERT INTO permission_matrix (...) VALUES (...)`
- **THEN** the insert is rejected by RLS

### Requirement: Default Permission Matrix Seed

The change MUST seed the `permission_matrix` table with at least the following rows derived from the design discussion's permission matrix:

- `('member', 'read_scores', 'self', true)`
- `('squad_leader', 'read_scores', 'squad', true)`
- `('team_leader', 'read_scores', 'team', true)`
- `('auditor', 'read_scores', 'assigned', true)`
- `('admin', 'read_scores', 'all', true)`
- `('executive', 'read_scores', 'all', true)`
- `('member', 'submit_report', 'self', true)`
- `('squad_leader', 'submit_report', 'self', true)`
- `('team_leader', 'submit_report', 'self', true)`
- `('auditor', 'submit_report', 'self', true)`
- `('admin', 'submit_report', 'self', true)`
- `('executive', 'submit_report', 'self', false)`
- `('auditor', 'audit_items', 'assigned', true)`
- `('admin', 'audit_items', 'all', true)`
- (other roles, 'audit_items', NULL, false)
- `('admin', 'manage_scoring_rules', 'all', true)`
- (other roles, 'manage_scoring_rules', NULL, false)
- `('admin', 'manage_roster', 'all', true)`
- (other roles, 'manage_roster', NULL, false)

Total seed rows MUST cover at least 30 (role, capability) combinations spanning the capabilities `read_scores`, `submit_report`, `audit_items`, `manage_scoring_rules`, `manage_roster`.

#### Scenario: Fresh seed contains expected combinations

- **WHEN** a developer applies the migration on a clean database
- **THEN** `SELECT COUNT(*) FROM permission_matrix` returns at least 30
- **AND** `SELECT scope FROM permission_matrix WHERE role = 'squad_leader' AND capability = 'read_scores'` returns `'squad'`

### Requirement: Get Role Scope Helper Function

The system SHALL provide a `get_role_scope(p_role TEXT, p_capability TEXT) RETURNS TEXT` STABLE function that returns the `scope` value for the given (role, capability) combination when `is_enabled = true`, and NULL otherwise.

The function MUST be granted EXECUTE to `anon` and `authenticated` roles.

#### Scenario: Scope lookup for enabled permission

- **WHEN** `get_role_scope('squad_leader', 'read_scores')` is called and the matrix has the row `('squad_leader', 'read_scores', 'squad', true)`
- **THEN** the function returns `'squad'`

#### Scenario: Scope lookup for disabled permission returns NULL

- **WHEN** `get_role_scope('member', 'audit_items')` is called and the matrix has `('member', 'audit_items', NULL, false)`
- **THEN** the function returns NULL

#### Scenario: Scope lookup for missing combination returns NULL

- **WHEN** `get_role_scope('member', 'nonexistent_capability')` is called
- **THEN** the function returns NULL

### Requirement: Admin Update Permission RPC

The system SHALL provide an `admin_update_permission(p_acting_admin_id TEXT, p_acting_password TEXT, p_role TEXT, p_capability TEXT, p_is_enabled BOOLEAN, p_scope TEXT)` SECURITY DEFINER RPC that begins by calling `admin_verify` and aborts with exception on failure.

The RPC MUST UPDATE the existing `permission_matrix` row matching `(p_role, p_capability)` to set `is_enabled = p_is_enabled`, `scope = p_scope`, `updated_at = now()`, `updated_by = p_acting_admin_id`.

If no matching row exists, the RPC MUST raise an exception identifying the missing combination.

The RPC MUST be granted EXECUTE to the `anon` role.

#### Scenario: Authenticated admin updates a permission row

- **WHEN** an authenticated admin calls `admin_update_permission(A, password_A, 'squad_leader', 'audit_items', true, 'squad')`
- **THEN** the matching row's `is_enabled` becomes `true`, `scope` becomes `'squad'`, `updated_by` becomes `A`
- **AND** `updated_at` is updated to the current timestamp

#### Scenario: Updating non-existent combination raises exception

- **WHEN** an authenticated admin calls `admin_update_permission(A, password_A, 'member', 'nonexistent_capability', true, NULL)`
- **THEN** the RPC raises an exception identifying the missing combination
- **AND** no row is inserted or modified

### Requirement: Permission Matrix Decoupled From Existing Scope Functions

For the duration of this change, the existing `v_squad_scope` and `get_visible_reports` functions (defined in `scripts/supabase-import/07-role-scoped-views.sql`) MUST continue to use their hardcoded role-checking logic and MUST NOT be modified to read `permission_matrix`.

The data in `permission_matrix` is stored for future consumption by a separate change that will refactor `v_squad_scope` to be data-driven. Until that refactor is applied, toggling `permission_matrix` rows MUST NOT alter the runtime behavior of `v_squad_scope` or `get_visible_reports`.

#### Scenario: Toggling matrix does not affect existing scope function

- **GIVEN** the matrix has `('squad_leader', 'read_scores', 'squad', true)`
- **WHEN** an admin toggles that row to `is_enabled = false`
- **AND** a viewer with `role = 'squad_leader'` calls `v_squad_scope(viewer_id)`
- **THEN** the viewer still receives squad-scoped member rows (same behavior as before the toggle)
