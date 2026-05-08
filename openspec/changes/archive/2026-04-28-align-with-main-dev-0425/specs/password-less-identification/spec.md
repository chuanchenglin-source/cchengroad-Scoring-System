## ADDED Requirements

### Requirement: Member Identifier as Composite Text Key

The system SHALL use a composite text identifier of the form `<squad_code>_<name>_<team_name>` as the `members.id` primary key, replacing the prior `BIGSERIAL` numeric identifier.

The identifier format MUST be: `T011_周子維_嘉家久` where `T011` is the four-character squad code, `周子維` is the member's display name, and `嘉家久` is the team's descriptive name, joined by underscore characters.

The `members.id` column type MUST be `TEXT NOT NULL PRIMARY KEY`.

All foreign keys previously referencing `members(id)` (including `daily_reports.member_id` and `daily_report_items.audited_by`) MUST be updated to type `TEXT` and continue to reference `members(id)`.

#### Scenario: Member identifier construction

- **WHEN** a member named `周子維` belonging to squad `T011` (in team `嘉家久`) is inserted
- **THEN** the inserted row has `id = 'T011_周子維_嘉家久'`

#### Scenario: Identifier propagation to daily reports

- **WHEN** a `daily_reports` row is inserted referencing a member
- **THEN** the row's `member_id` column accepts and stores the text identifier

### Requirement: PIN Authentication Removal

The system SHALL NOT include any PIN-based authentication mechanism.

The migration MUST drop the `authenticate_member` PL/pgSQL function via `DROP FUNCTION IF EXISTS authenticate_member(...) CASCADE`.

The migration MUST drop the `members.pin_code` column via `ALTER TABLE members DROP COLUMN IF EXISTS pin_code`.

Any RLS policies referencing `pin_code` MUST be dropped or rewritten to remove the reference.

The frontend `supabase-client.html` SHALL NOT expose any function named `authenticate`, `authenticateMember`, or any equivalent PIN-validation API.

#### Scenario: Verifying PIN function is removed

- **WHEN** a developer queries `SELECT proname FROM pg_proc WHERE proname = 'authenticate_member'` after the migration is applied
- **THEN** the query returns zero rows

#### Scenario: Verifying PIN column is removed

- **WHEN** a developer queries `SELECT column_name FROM information_schema.columns WHERE table_name = 'members' AND column_name = 'pin_code'`
- **THEN** the query returns zero rows

### Requirement: Client-Side Member Search Identification

The system SHALL identify the active user via client-side search of the member roster, without any password or PIN entry.

The `Index.html` page MUST:
- Load the full active member roster on page load via `supabase-client.html:scoringAPI.getMemberList()`
- Render an `<input type="text" list="nameList">` paired with a `<datalist id="nameList">` populated with one option per member, using the member's text `id` as `option.value` and a label combining `name` and `team_name`
- Allow the user to select a member by typing either the name, the squad_code, or the full id
- Display the selected member's `team_code`, `team_name`, `name`, `squad_leader_name`, `leader_name` in a confirmation block before navigation
- Navigate to the next page (`main` or `history`) by setting `window.top.location.href` to a URL containing query parameters `id`, `name`, `team`, `teamCode`, all URL-encoded

#### Scenario: User searches and selects a member

- **WHEN** the user types `周子維` into the search input on Index.html and the datalist auto-completes to `T011_周子維_嘉家久`
- **THEN** the confirmation block displays the team code `T01`, team name `嘉家久`, name `周子維`, squad leader name, and big team leader name

#### Scenario: Navigation passes identification via URL

- **WHEN** the user clicks the submit button after selecting member `T011_周子維_嘉家久`
- **THEN** the browser navigates to a URL of the form `<webAppUrl>?page=main&id=T011_%E5%91%A8%E5%AD%90%E7%B6%AD_%E5%98%89%E5%AE%B6%E4%B9%85&name=%E5%91%A8%E5%AD%90%E7%B6%AD&team=%E5%98%89%E5%AE%B6%E4%B9%85&teamCode=T01`

### Requirement: URL Parameter Trust Model

The Apps Script `doGet(e)` handler SHALL accept `id`, `name`, `team`, `teamCode` query parameters as the authoritative user identity for the current page request, without server-side verification against any credential store.

Pages downstream of `doGet` (i.e., `main.html` and `history.html`) MUST receive these parameters via the templating mechanism (`<?= user.id ?>` etc.) and use them directly when calling Supabase APIs that require a member identifier.

The system SHALL NOT validate the URL parameters against any session, cookie, or credential. Trust is rooted entirely in the assumption that the user navigated through `Index.html`'s search-and-select flow.

#### Scenario: Receiving identity via URL params

- **WHEN** `doGet(e)` is invoked with `e.parameter` containing `id=T011_周子維_嘉家久&name=周子維&team=嘉家久&teamCode=T01&page=main`
- **THEN** the rendered `main.html` template has `user.id`, `user.name`, `user.team`, `user.teamCode` populated with the URL-decoded values
- **AND** no further authentication check occurs before allowing the user to interact with the page
