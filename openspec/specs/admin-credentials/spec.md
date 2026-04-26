# admin-credentials Specification

## Purpose

TBD - created by archiving change 'add-admin-backend'. Update Purpose after archive.

## Requirements

### Requirement: Admin Credentials Storage

The system SHALL store backend administrator credentials in a dedicated `admin_credentials` table separate from the `members` table.

The table MUST include columns: `id BIGSERIAL PRIMARY KEY`, `admin_id TEXT NOT NULL UNIQUE`, `name TEXT NOT NULL`, `password_hash TEXT NOT NULL`, `is_active BOOLEAN NOT NULL DEFAULT true`, `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`, `last_login_at TIMESTAMPTZ`.

The `admin_credentials` table MUST NOT have any foreign key relationship to the `members` table; the two are administrative concerns at different conceptual layers.

The PostgreSQL `pgcrypto` extension MUST be enabled in the project to provide bcrypt hashing primitives (`crypt`, `gen_salt`).

Row-Level Security MUST be enabled with NO policies allowing SELECT, INSERT, UPDATE, or DELETE for `anon` or `authenticated` roles. All access MUST go through SECURITY DEFINER RPCs that operate via the `service_role`.

#### Scenario: Querying admin_credentials directly is denied

- **WHEN** a client using the anon key attempts `SELECT * FROM admin_credentials`
- **THEN** the query returns zero rows due to RLS

#### Scenario: Password is stored as bcrypt hash

- **WHEN** an admin row is inserted with `password_hash = crypt('plaintext', gen_salt('bf'))`
- **THEN** the stored value begins with `$2` (bcrypt prefix) and is at least 60 characters long
- **AND** the stored value is NOT equal to `'plaintext'`


<!-- @trace
source: add-admin-backend
updated: 2026-04-26
code:
  - scripts/supabase-import/14-create-permission-matrix.sql
  - scripts/supabase-import/bootstrap-admin.sql.example
  - scripts/supabase-import/03-rls-and-auth.sql
  - supabase-client.html
  - scripts/supabase-import/09-create-teams-squads.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - .claspignore
  - scripts/supabase-import/10-alter-members-id-type.sql
  - main.html
  - scripts/supabase-import/12-remove-pin-auth.sql
  - scripts/supabase-import/11-import-real-roster.sql
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/13-create-admin-credentials.sql
  - Admin.html
  - CLAUDE.md
  - history.html
  - Index.html
  - webApp.js
-->

---
### Requirement: Admin Login RPC

The system SHALL provide an `admin_login(p_admin_id TEXT, p_password TEXT)` SECURITY DEFINER PL/pgSQL function that returns rows of `(admin_id, name)` only when the supplied password matches the stored hash for an active admin.

When credentials match, the function MUST update the matched row's `last_login_at = now()` before returning.

When credentials do not match (wrong admin_id, wrong password, or `is_active = false`), the function MUST return zero rows. The function MUST NOT distinguish "wrong admin_id" from "wrong password" in any returned data, error message, or side effect to prevent enumeration attacks.

The function MUST be granted EXECUTE to the `anon` role.

#### Scenario: Successful login returns admin info

- **WHEN** `admin_login('chuanchenglin@gmail.com', 'correct_password')` is called and the row is active
- **THEN** the function returns one row containing `admin_id='chuanchenglin@gmail.com'` and the admin's `name`
- **AND** `last_login_at` for that row is updated to the current timestamp

#### Scenario: Wrong password returns nothing

- **WHEN** `admin_login('chuanchenglin@gmail.com', 'wrong_password')` is called
- **THEN** the function returns zero rows
- **AND** no error message distinguishing the failure cause is exposed to the caller

#### Scenario: Inactive admin cannot login

- **WHEN** `admin_login(...)` is called for an admin where `is_active = false`
- **THEN** the function returns zero rows even when the password is correct


<!-- @trace
source: add-admin-backend
updated: 2026-04-26
code:
  - scripts/supabase-import/14-create-permission-matrix.sql
  - scripts/supabase-import/bootstrap-admin.sql.example
  - scripts/supabase-import/03-rls-and-auth.sql
  - supabase-client.html
  - scripts/supabase-import/09-create-teams-squads.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - .claspignore
  - scripts/supabase-import/10-alter-members-id-type.sql
  - main.html
  - scripts/supabase-import/12-remove-pin-auth.sql
  - scripts/supabase-import/11-import-real-roster.sql
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/13-create-admin-credentials.sql
  - Admin.html
  - CLAUDE.md
  - history.html
  - Index.html
  - webApp.js
-->

---
### Requirement: Admin Verify RPC

The system SHALL provide an `admin_verify(p_admin_id TEXT, p_password TEXT) RETURNS BOOLEAN` SECURITY DEFINER function that returns `true` only when the supplied credentials match an active admin, and `false` otherwise.

This function MUST be invoked at the start of every other admin RPC (`admin_create`, `admin_set_active`, `admin_change_password`, `admin_update_permission`, `admin_update_scoring_rule`, `admin_set_member_role`, `admin_set_member_active`); if `admin_verify` returns `false`, the calling RPC MUST raise an exception and abort.

The function MUST be granted EXECUTE to the `anon` role.

#### Scenario: Verify succeeds for active admin with correct password

- **WHEN** `admin_verify('chuanchenglin@gmail.com', 'correct_password')` is called
- **THEN** the function returns `true`

#### Scenario: Verify fails for any mismatch

- **WHEN** `admin_verify(...)` is called with a wrong admin_id, wrong password, or inactive admin
- **THEN** the function returns `false`


<!-- @trace
source: add-admin-backend
updated: 2026-04-26
code:
  - scripts/supabase-import/14-create-permission-matrix.sql
  - scripts/supabase-import/bootstrap-admin.sql.example
  - scripts/supabase-import/03-rls-and-auth.sql
  - supabase-client.html
  - scripts/supabase-import/09-create-teams-squads.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - .claspignore
  - scripts/supabase-import/10-alter-members-id-type.sql
  - main.html
  - scripts/supabase-import/12-remove-pin-auth.sql
  - scripts/supabase-import/11-import-real-roster.sql
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/13-create-admin-credentials.sql
  - Admin.html
  - CLAUDE.md
  - history.html
  - Index.html
  - webApp.js
-->

---
### Requirement: Admin Self-Protection Rules

The system SHALL enforce two anti-lockout rules on the `admin_set_active(p_acting_admin_id TEXT, p_acting_password TEXT, p_target_admin_id TEXT, p_set_active BOOLEAN)` RPC:

- Rule A — No-self-deactivate: when `p_set_active = false` and `p_target_admin_id = p_acting_admin_id`, the RPC MUST raise an exception with message containing the phrase "不能停用自己" and abort without modifying any row.
- Rule B — At-least-one-active: when `p_set_active = false` and the count of currently active admins is less than or equal to 1, the RPC MUST raise an exception with message containing the phrase "至少要保留 1 個 active admin" and abort without modifying any row.

Both rules MUST be evaluated within the same transaction as the UPDATE statement to prevent race conditions.

#### Scenario: Self-deactivation rejected

- **WHEN** admin A calls `admin_set_active(A, password_A, A, false)`
- **THEN** the RPC raises an exception containing "不能停用自己"
- **AND** admin A's `is_active` remains `true`

#### Scenario: Last active admin cannot be deactivated

- **GIVEN** the database has exactly one active admin (admin A) and one inactive admin (admin B)
- **WHEN** admin A calls `admin_set_active(A, password_A, A, false)` (caught by Rule A first) OR a hypothetical caller targets admin A
- **THEN** the RPC raises an exception containing "至少要保留 1 個 active admin"
- **AND** admin A's `is_active` remains `true`

#### Scenario: Deactivating non-self when more than one active admin exists

- **GIVEN** admin A and admin B are both active
- **WHEN** admin A calls `admin_set_active(A, password_A, B, false)`
- **THEN** the RPC succeeds and admin B's `is_active` becomes `false`


<!-- @trace
source: add-admin-backend
updated: 2026-04-26
code:
  - scripts/supabase-import/14-create-permission-matrix.sql
  - scripts/supabase-import/bootstrap-admin.sql.example
  - scripts/supabase-import/03-rls-and-auth.sql
  - supabase-client.html
  - scripts/supabase-import/09-create-teams-squads.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - .claspignore
  - scripts/supabase-import/10-alter-members-id-type.sql
  - main.html
  - scripts/supabase-import/12-remove-pin-auth.sql
  - scripts/supabase-import/11-import-real-roster.sql
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/13-create-admin-credentials.sql
  - Admin.html
  - CLAUDE.md
  - history.html
  - Index.html
  - webApp.js
-->

---
### Requirement: Admin CRUD RPCs

The system SHALL provide the following SECURITY DEFINER RPCs that all begin by calling `admin_verify` and abort with an exception if verification fails:

- `admin_list_admins(p_acting_admin_id, p_acting_password) RETURNS TABLE(admin_id, name, is_active, last_login_at)` — return all rows from `admin_credentials` (no `password_hash`)
- `admin_create(p_acting_admin_id, p_acting_password, p_new_admin_id TEXT, p_new_name TEXT, p_new_password TEXT)` — insert a new admin with hashed password
- `admin_change_password(p_acting_admin_id, p_acting_password, p_target_admin_id TEXT, p_new_password TEXT)` — update target admin's `password_hash`
- `admin_set_active(p_acting_admin_id, p_acting_password, p_target_admin_id TEXT, p_set_active BOOLEAN)` — toggle `is_active` (subject to self-protection rules)

Each RPC MUST be granted EXECUTE to the `anon` role.

#### Scenario: Listing admins requires verification

- **WHEN** `admin_list_admins('bogus_id', 'bogus_pw')` is called
- **THEN** the RPC raises an exception due to failed `admin_verify`
- **AND** no admin rows are returned

#### Scenario: Listing admins returns no password hashes

- **WHEN** an authenticated admin calls `admin_list_admins(A, password_A)` and the database has 3 admins
- **THEN** the RPC returns 3 rows, each containing `admin_id`, `name`, `is_active`, `last_login_at`
- **AND** no row contains a `password_hash` column

#### Scenario: Creating admin produces hashed password

- **WHEN** an authenticated admin calls `admin_create(A, password_A, 'new-id', 'New Name', 'new_pw_plaintext')`
- **THEN** a new row is inserted into `admin_credentials` with `admin_id='new-id'`, `name='New Name'`, `is_active=true`
- **AND** the inserted `password_hash` value satisfies `crypt('new_pw_plaintext', password_hash) = password_hash`


<!-- @trace
source: add-admin-backend
updated: 2026-04-26
code:
  - scripts/supabase-import/14-create-permission-matrix.sql
  - scripts/supabase-import/bootstrap-admin.sql.example
  - scripts/supabase-import/03-rls-and-auth.sql
  - supabase-client.html
  - scripts/supabase-import/09-create-teams-squads.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - .claspignore
  - scripts/supabase-import/10-alter-members-id-type.sql
  - main.html
  - scripts/supabase-import/12-remove-pin-auth.sql
  - scripts/supabase-import/11-import-real-roster.sql
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/13-create-admin-credentials.sql
  - Admin.html
  - CLAUDE.md
  - history.html
  - Index.html
  - webApp.js
-->

---
### Requirement: Bootstrap Admin Migration

The change MUST include a template SQL file `scripts/supabase-import/bootstrap-admin.sql.example` containing a single INSERT statement that creates the first admin row with `admin_id = 'chuanchenglin@gmail.com'` and a placeholder password value `'__REPLACE_ME__'`.

The actual `scripts/supabase-import/bootstrap-admin.sql` file (with the real password) MUST be added to `.gitignore` so that real credentials never enter version control.

The example file MUST include comments explaining: (a) how to copy and edit it, (b) that the real file is gitignored, (c) the SQL pattern for resetting a forgotten password later.

#### Scenario: Bootstrap example file uses placeholder password

- **WHEN** a developer reads `bootstrap-admin.sql.example`
- **THEN** the file contains the literal string `'__REPLACE_ME__'` in the password parameter
- **AND** the file does NOT contain any usable bcrypt hash or plaintext password

#### Scenario: Real bootstrap file is gitignored

- **WHEN** a developer creates `scripts/supabase-import/bootstrap-admin.sql` and runs `git status`
- **THEN** the file does NOT appear in git's tracked changes

<!-- @trace
source: add-admin-backend
updated: 2026-04-26
code:
  - scripts/supabase-import/14-create-permission-matrix.sql
  - scripts/supabase-import/bootstrap-admin.sql.example
  - scripts/supabase-import/03-rls-and-auth.sql
  - supabase-client.html
  - scripts/supabase-import/09-create-teams-squads.sql
  - scripts/supabase-import/04-normalize-schema.sql
  - .claspignore
  - scripts/supabase-import/10-alter-members-id-type.sql
  - main.html
  - scripts/supabase-import/12-remove-pin-auth.sql
  - scripts/supabase-import/11-import-real-roster.sql
  - scripts/supabase-import/05-save-report-rpc.sql
  - scripts/supabase-import/13-create-admin-credentials.sql
  - Admin.html
  - CLAUDE.md
  - history.html
  - Index.html
  - webApp.js
-->