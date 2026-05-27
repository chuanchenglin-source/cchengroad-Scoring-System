# admin-backend-ui Specification

## Purpose

TBD - created by archiving change 'add-admin-backend'. Update Purpose after archive.

## Requirements

### Requirement: Admin Page Routing

The Apps Script `webApp.js:doGet(e)` handler SHALL accept `e.parameter.page = 'Admin'` and serve the `Admin.html` template, in addition to the existing `Index`, `main`, and `history` routes.

The `Admin.html` route MUST NOT receive any URL parameters (`id`, `name`, `team`, `teamCode`); admin identity is established by the in-page login flow, not by URL params.

#### Scenario: Admin route serves Admin.html

- **WHEN** the user navigates to `<webAppUrl>?page=Admin`
- **THEN** the rendered HTML originates from `Admin.html`
- **AND** the page does not display any member identification block from `Index.html`

#### Scenario: URL params on admin route are ignored

- **WHEN** the user navigates to `<webAppUrl>?page=Admin&id=T011_周子維_嘉家久`
- **THEN** `Admin.html` does not pre-populate any user identification from the URL
- **AND** the admin login form is shown as if no URL params were present


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
### Requirement: Admin Login Flow

The `Admin.html` page MUST present a login screen (admin_id input + password input + login button) before rendering any administrative content.

On login button click, the page MUST call `window.adminAPI.login(admin_id, password)` which invokes the `admin_login` RPC. On success (one row returned), the page MUST:
- Store `{ admin_id, password, name }` in `sessionStorage` under a single key (e.g., `cchg_admin_session`)
- Hide the login screen
- Show the 4-tab navigation and the default tab content

On failure (zero rows returned), the page MUST display a generic error message such as "登入失敗，請確認帳號與密碼" without distinguishing whether `admin_id` or `password` was wrong.

The page MUST display a prominent visible warning above the login form: "⚠️ 請使用無痕視窗登入，使用完畢請關閉瀏覽器".

#### Scenario: Successful login transitions to admin UI

- **WHEN** the admin enters correct credentials and clicks login
- **THEN** the login form is hidden
- **AND** sessionStorage contains a JSON object with keys `admin_id`, `password`, `name`
- **AND** the 4-tab navigation appears

#### Scenario: Failed login shows generic error

- **WHEN** the admin enters wrong credentials and clicks login
- **THEN** an error message containing "登入失敗" is displayed
- **AND** sessionStorage does NOT contain any admin session data
- **AND** the error message does NOT distinguish between wrong admin_id and wrong password

#### Scenario: Privacy warning is visible on login screen

- **WHEN** the admin lands on the login screen
- **THEN** a visible message containing "請使用無痕視窗" or equivalent privacy guidance is rendered above the login form


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
### Requirement: Admin Session Storage Lifecycle

The page MUST use the browser's `sessionStorage` API (NOT `localStorage`) to hold the admin session, ensuring that closing the browser tab clears credentials.

On every admin RPC invocation, the page MUST read the credentials from `sessionStorage` and pass them as `(admin_id, password)` parameters; the page MUST NOT cache credentials in any other location (no in-memory module-level variables that persist across navigation, no IndexedDB, no cookies).

If the page loads and `sessionStorage` does NOT contain a valid admin session, the login screen MUST be shown instead of the admin UI.

The page MUST provide a "登出" (logout) button that clears the entire `cchg_admin_session` key from `sessionStorage` and re-renders the login screen.

#### Scenario: Closing tab clears session

- **GIVEN** the admin has logged in and sessionStorage contains the session
- **WHEN** the user closes the browser tab and re-opens the same URL
- **THEN** sessionStorage is empty
- **AND** the login screen is shown

#### Scenario: Logout button clears session

- **GIVEN** the admin is logged in
- **WHEN** the user clicks the logout button
- **THEN** `sessionStorage.getItem('cchg_admin_session')` returns null
- **AND** the login screen is re-rendered


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
### Requirement: Four-Tab Navigation Structure

The admin UI MUST present exactly four tabs in fixed order: 「權限切換」「計分規則」「名單管理」「Admin 管理」.

Tabs MUST be implemented as in-page section toggling (single HTML file, JS-driven show/hide), not as separate HTML files or separate `?page=` routes.

Only one tab's content MUST be visible at a time. Switching tabs MUST NOT trigger a page reload or a new Supabase client load.

#### Scenario: Default tab is 權限切換

- **WHEN** the admin successfully logs in
- **THEN** the 「權限切換」 tab is the active visible content
- **AND** the other three tabs are hidden

#### Scenario: Tab switch is in-page

- **WHEN** the admin clicks the 「計分規則」 tab
- **THEN** the 「權限切換」 section is hidden
- **AND** the 「計分規則」 section is shown
- **AND** no network request to `webApp.js doGet` is made
- **AND** sessionStorage admin session remains intact


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
### Requirement: Permission Toggle Tab Content

The 「權限切換」 tab MUST render the contents of the `permission_matrix` table as a UI grid where each row represents one (role, capability) combination with controls to toggle `is_enabled` and select `scope`.

Each toggle action MUST invoke `window.adminAPI.updatePermission(role, capability, is_enabled, scope)` which calls the `admin_update_permission` RPC with the credentials from sessionStorage.

The tab MUST display a prominent visible disclaimer at the top: "⚠️ 此分頁的 toggle 目前為設定預覽，實際權限仍由 v_squad_scope function 決定（將於下一個 change 接通）".

#### Scenario: Toggling a row calls the update RPC

- **GIVEN** the matrix contains `('squad_leader', 'audit_items', NULL, false)`
- **WHEN** the admin toggles `is_enabled` to true and selects scope `'squad'` for that row
- **THEN** the page calls `admin_update_permission('squad_leader', 'audit_items', true, 'squad')` with admin credentials
- **AND** on RPC success the toggle UI reflects the new state

#### Scenario: Decoupling disclaimer is visible

- **WHEN** the admin views the 「權限切換」 tab
- **THEN** a visible message containing "尚未接通" or equivalent decoupling warning is rendered above the matrix grid


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
### Requirement: Scoring Rules Tab Content

The 「計分規則」 tab MUST list all rows from the `scoring_rules` table (created by the existing `add-scoring-rules-and-role-access` change) and provide an editable input per row for the `rule_value` JSONB field.

Each save action MUST invoke `window.adminAPI.updateScoringRule(rule_key, rule_value)` which calls the `admin_update_scoring_rule(p_acting_admin_id, p_acting_password, p_rule_key, p_rule_value)` RPC with the credentials from sessionStorage.

Rows where `rule_value IS NULL` (unanswered by the activity organiser) MUST be visually distinguished (e.g., yellow background) from rows with values.

The admin MUST be able to set `rule_value` back to NULL by clearing the input.

#### Scenario: Listing scoring rules

- **WHEN** the admin opens the 「計分規則」 tab
- **THEN** all rows from `scoring_rules` (~14 rows seeded by the related change) are displayed
- **AND** rows where `rule_value IS NULL` have a visually distinct background

#### Scenario: Updating a rule value

- **WHEN** the admin enters a JSONB value `'true'` for `rule_key='w7_leadership_bonus_enabled'` and clicks save
- **THEN** the page calls `admin_update_scoring_rule('w7_leadership_bonus_enabled', 'true'::jsonb)`
- **AND** on RPC success the row's display value is `'true'`


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
### Requirement: Roster Management Tab Content

The 「名單管理」 tab MUST list all rows from the `members` table (joined with `teams` and `squads` for display columns) and provide:
- A dropdown per row to change `role` to one of the six allowed values
- A toggle per row to set `is_active`

Each role change action MUST invoke `window.adminAPI.setMemberRole(member_id, new_role)` which calls `admin_set_member_role` RPC with the credentials.

Each active toggle action MUST invoke `window.adminAPI.setMemberActive(member_id, is_active)` which calls `admin_set_member_active` RPC with the credentials.

The tab MUST NOT provide UI for inserting new members or deleting members; those operations are out of scope for this change.

#### Scenario: Changing a member's role

- **WHEN** the admin selects role `'squad_leader'` for `member_id='T011_周子維_嘉家久'`
- **THEN** the page calls `admin_set_member_role('T011_周子維_嘉家久', 'squad_leader')`
- **AND** on RPC success the dropdown reflects the new role
- **AND** the database `members.role` for that row is updated

#### Scenario: No insert or delete UI is present

- **WHEN** the admin views the 「名單管理」 tab
- **THEN** no button or input for "新增 member" or "刪除 member" is rendered


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
### Requirement: Admin Management Tab Content

The 「Admin 管理」 tab MUST list all rows from `admin_credentials` (excluding `password_hash`) and provide:
- A button per row to toggle `is_active` (subject to self-protection rules — disabled in UI when row is the acting admin's own row)
- A button per row to change password (opens an inline input + save)
- A button at the top of the list to add a new admin (opens an inline form with `admin_id`, `name`, `password` inputs)

Each action MUST invoke the corresponding `window.adminAPI.*` wrapper, which calls the matching RPC (`admin_set_active`, `admin_change_password`, `admin_create`) with the acting admin's credentials.

When an RPC fails due to self-protection rules (Rules A and B from the admin-credentials capability), the page MUST display the exception message returned by the RPC verbatim to the user.

#### Scenario: Listing admins shows no password hashes

- **WHEN** the admin opens the 「Admin 管理」 tab and the database has 3 admins
- **THEN** 3 rows are displayed
- **AND** none of the rendered DOM contains `password_hash` values

#### Scenario: Self-row deactivate button is disabled

- **WHEN** admin A is logged in and views the 「Admin 管理」 tab
- **THEN** the deactivate button on the row where `admin_id = A` is rendered as disabled

#### Scenario: Self-protection error is shown to user

- **GIVEN** the database has only one active admin (admin A)
- **WHEN** admin A attempts to deactivate another admin causing the count to drop to 1, then attempts to deactivate the last one (the deactivate button targets self → shown as disabled, but a hypothetical bypass)
- **THEN** any RPC error message containing "至少要保留 1 個 active admin" is displayed verbatim to the admin


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
### Requirement: Admin API Client Wrapper

The `supabase-client.html` file MUST expose a `window.adminAPI` object containing the following methods, each forwarding to the corresponding Supabase RPC and reading session credentials from sessionStorage where applicable:
- `login(admin_id, password)` — calls `admin_login` (no session credentials needed)
- `logout()` — clears sessionStorage
- `getSession()` — returns the session object from sessionStorage or null
- `listAdmins()` — calls `admin_list_admins` with session credentials
- `createAdmin(new_admin_id, new_name, new_password)` — calls `admin_create` with session credentials
- `setAdminActive(target_admin_id, is_active)` — calls `admin_set_active` with session credentials
- `changePassword(target_admin_id, new_password)` — calls `admin_change_password` with session credentials
- `listPermissions()` — SELECT from `permission_matrix` (uses anon RLS read)
- `updatePermission(role, capability, is_enabled, scope)` — calls `admin_update_permission` with session credentials
- `listScoringRules()` — SELECT from `scoring_rules` (uses anon RLS read)
- `updateScoringRule(rule_key, rule_value)` — calls `admin_update_scoring_rule` with session credentials
- `listMembersFull()` — SELECT from `members_public` view (uses anon RLS read)
- `setMemberRole(member_id, new_role)` — calls `admin_set_member_role` with session credentials
- `setMemberActive(member_id, is_active)` — calls `admin_set_member_active` with session credentials

Each method that reads session credentials MUST throw a JavaScript error if no valid session exists, before attempting the RPC call.

#### Scenario: adminAPI methods throw without session

- **GIVEN** sessionStorage does not contain a `cchg_admin_session` key
- **WHEN** `window.adminAPI.listAdmins()` is called
- **THEN** the method throws a JavaScript error containing the substring "未登入" or equivalent
- **AND** no Supabase RPC is invoked

#### Scenario: adminAPI is separate from scoringAPI

- **WHEN** the page loads `supabase-client.html`
- **THEN** both `window.scoringAPI` and `window.adminAPI` are defined as distinct objects
- **AND** `window.scoringAPI` does NOT contain any admin-related method

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