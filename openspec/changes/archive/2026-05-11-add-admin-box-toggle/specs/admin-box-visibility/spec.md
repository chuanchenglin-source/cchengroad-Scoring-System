## ADDED Requirements

### Requirement: Admin can view all box toggle states

The admin page SHALL display a list of all 40 boxes with their checkbox name and a toggle (checkbox) for each. Each toggle SHALL reflect the current visibility state: checked = visible on main.html, unchecked = hidden.

#### Scenario: Admin opens the box visibility section

- **WHEN** admin navigates to admin.html (via 666666 shortcut)
- **THEN** admin sees a "Box 顯示設定" section below the existing "當週起始日" section
- **THEN** each of the 40 boxes is listed with its number and label (e.g., "1. 主修打拳", "2. 選修定課")
- **THEN** checkboxes reflect the saved state from Script Property `VISIBLE_BOXES`

#### Scenario: First load with no saved config

- **WHEN** admin opens admin.html and no `VISIBLE_BOXES` Script Property exists
- **THEN** all 40 boxes SHALL default to unchecked (hidden)

### Requirement: Admin can toggle box visibility

The admin page SHALL allow the admin to check or uncheck any box toggle. Changes SHALL NOT be persisted until the admin explicitly clicks a save button.

#### Scenario: Admin toggles a box on

- **WHEN** admin checks the checkbox for box 4 ("W3電影行動方案")
- **THEN** the checkbox shows as checked in the UI
- **THEN** no server call is made until the admin clicks save

#### Scenario: Admin toggles a box off

- **WHEN** admin unchecks the checkbox for box 1 ("主修打拳")
- **THEN** the checkbox shows as unchecked in the UI
- **THEN** no server call is made until the admin clicks save

### Requirement: Admin can save box visibility config

The admin page SHALL provide a save button for the box visibility section. On save, the system SHALL persist the list of checked box numbers to GAS Script Property `VISIBLE_BOXES` as a JSON array of integers.

#### Scenario: Save visible boxes

- **WHEN** admin has checked boxes 1, 2, 3, 21, 22 and clicks save
- **THEN** system calls `saveVisibleBoxes([1,2,3,21,22])` on the server
- **THEN** server writes `[1,2,3,21,22]` to Script Property `VISIBLE_BOXES`
- **THEN** admin sees a success toast notification

##### Example: Stored format

| Checked boxes | Stored value in Script Property |
|---|---|
| 1, 2, 3 | `[1,2,3]` |
| 1, 2, 3, 4, 5, 6, 7, 21, 22, 23, 24, 25, 26 | `[1,2,3,4,5,6,7,21,22,23,24,25,26]` |
| (none) | `[]` |

#### Scenario: Save fails

- **WHEN** the server call fails (e.g., network error)
- **THEN** admin sees an error toast notification with failure reason

### Requirement: Admin can use select-all and deselect-all

The admin page SHALL provide "全選" (select all) and "全不選" (deselect all) convenience buttons for the box toggles.

#### Scenario: Select all

- **WHEN** admin clicks "全選"
- **THEN** all 40 box checkboxes become checked
- **THEN** changes are NOT saved until the admin clicks save

#### Scenario: Deselect all

- **WHEN** admin clicks "全不選"
- **THEN** all 40 box checkboxes become unchecked
- **THEN** changes are NOT saved until the admin clicks save

### Requirement: Main page renders boxes based on visibility config

The main.html page SHALL call `getVisibleBoxes()` on page load to retrieve the list of visible box numbers. All 40 boxes SHALL exist in the HTML DOM. Boxes whose number is NOT in the visible list SHALL be hidden via `display:none`. Boxes in the visible list SHALL be displayed normally.

#### Scenario: Normal page load with config

- **WHEN** user opens main.html
- **THEN** system calls `getVisibleBoxes()` to get the visible box list
- **THEN** only boxes in the list are displayed; all others are hidden

##### Example: Selective display

- **GIVEN** `VISIBLE_BOXES` Script Property is `[1,2,3,21,22]`
- **WHEN** user opens main.html
- **THEN** boxes 1, 2, 3, 21, 22 are visible
- **THEN** boxes 4-20, 23-40 are hidden (`display:none`)

#### Scenario: No config exists

- **WHEN** user opens main.html and no `VISIBLE_BOXES` Script Property exists
- **THEN** all boxes SHALL be hidden (same default as admin page)

#### Scenario: Hidden boxes do not submit data

- **WHEN** user fills in visible boxes and submits the form
- **THEN** hidden boxes SHALL NOT contribute any data to the submission
- **THEN** only visible boxes with user selections are included in the saved form data

### Requirement: Server functions for box visibility

webApp.gs SHALL expose two server functions:

- `getVisibleBoxes()`: reads Script Property `VISIBLE_BOXES`, parses as JSON array, returns the array of integers. If property does not exist, returns an empty array `[]`.
- `saveVisibleBoxes(list)`: receives a JSON array of integers, validates that each element is an integer between 1 and 40, writes the JSON string to Script Property `VISIBLE_BOXES`, returns `{ ok: true, savedAt: <ISO timestamp> }`.

#### Scenario: getVisibleBoxes with existing config

- **WHEN** `VISIBLE_BOXES` Script Property is `[1,2,3]`
- **THEN** `getVisibleBoxes()` returns `[1, 2, 3]`

#### Scenario: getVisibleBoxes with no config

- **WHEN** `VISIBLE_BOXES` Script Property does not exist
- **THEN** `getVisibleBoxes()` returns `[]`

#### Scenario: saveVisibleBoxes with valid input

- **WHEN** `saveVisibleBoxes([1, 2, 3, 21])` is called
- **THEN** Script Property `VISIBLE_BOXES` is set to `[1,2,3,21]`
- **THEN** function returns `{ ok: true, savedAt: "2026-05-11T..." }`

#### Scenario: saveVisibleBoxes with invalid input

- **WHEN** `saveVisibleBoxes([1, 2, 99])` is called (99 is out of range)
- **THEN** function throws an error indicating invalid box number
