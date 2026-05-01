# Create/Edit Current Work Session Feature

## Feature Overview

This feature enables users to create and edit work sessions for a specific job profile. A work session records the hours worked on a given date, including clock-in/clock-out times, breaks (0–5), an optional lunch break, optional notes, and validation against overlapping existing sessions.

Work sessions are persisted in two states:
1. **Draft** (temporary): Saved as the user types via `temp_work_sessions` table
2. **Finalized** (permanent): Saved to `work_sessions` table when explicitly finished

The feature is accessed via a button on the job profile details page, with a label that dynamically indicates whether a draft exists ("Edit Current Work Session" or "Create Current Work Session").

## Database Persistence

### Encrypted SQLite Storage
- Work sessions are stored in an encrypted SQLite database using `sqflite_sqlcipher` with the temporary password `myWorkHoursTracker_local_key_v1`.
- Database file: `work_hours_tracker.db`
- Schema version: 3 (with migration support for future updates)

### Tables

#### temp_work_sessions (Draft Storage)
- **Purpose**: Stores in-progress work session drafts
- **Primary key**: `id`
- **Unique constraint**: One draft per `job_profile_id` (UNIQUE constraint prevents multiple drafts)
- **Foreign key**: `job_profile_id` references `job_profiles(id)` with CASCADE delete
- **Columns**:
  - `job_profile_id` (INTEGER NOT NULL UNIQUE): Links draft to a specific job profile
  - `session_date` (TEXT NOT NULL): ISO 8601 formatted date of the work session
  - `clock_in_time` (TEXT): Time in HH:MM format
  - `clock_out_time` (TEXT): Time in HH:MM format
  - `break_count` (INTEGER): Number of breaks recorded (0–5)
  - `break1_start_time` to `break5_end_time` (TEXT): Break times in HH:MM format
  - `has_lunch` (INTEGER): Boolean flag (0 or 1) for lunch break
  - `lunch_start_time`, `lunch_end_time` (TEXT): Lunch times in HH:MM format
  - `note` (TEXT): Optional session note (max 200 characters)
  - `updated_at` (TEXT): Timestamp of last draft update
- **Data persistence**: 
  - When the user saves changes, the draft is inserted/updated via `saveOpenWorkSessionDraft()` using `ConflictAlgorithm.replace`
  - When the user exits without finalizing, the draft is preserved for the next session
  - When the user finalizes a session, the draft is deleted and the session is moved to `work_sessions`

#### work_sessions (Finalized Storage)
- **Purpose**: Stores completed work sessions
- **Primary key**: `id`
- **Foreign key**: `job_profile_id` references `job_profiles(id)` with CASCADE delete
- **Columns**: Same as `temp_work_sessions` except:
  - No UNIQUE constraint on `job_profile_id` (multiple finalized sessions per profile allowed)
  - `created_at` (TEXT): Timestamp of session completion
  - No `updated_at` field
- **Data persistence**: 
  - Sessions are inserted via `insertFinalizedWorkSession()` only when explicitly finished
  - Validation runs before insertion to ensure no time overlaps with existing sessions on the same date or across dates

## Create/Edit Current Work Session Form

### Form Access
- The form is accessed via `CreateEditCurrentWorkSessionPage`
- **Navigation**: User taps the "Create/Edit Current Work Session" button on the job profile details page
- The details page forwards the active `AppSettings` object into the button and form flow so date formatting and time-pick behavior match the user's saved preferences
- **Return behavior**: 
  - If the user saves changes and exits, the draft is persisted and the page pops
  - If the user finishes the session successfully, the page pops and returns `true`
  - If the user cancels without saving, the draft is preserved for next time

### Button Label Logic
- The button label on the profile details page is determined by whether an open draft exists:
  - "**Edit Current Work Session**" if `temp_work_sessions` has a row for the profile ID
  - "**Create Current Work Session**" if no draft exists
- The button state is refreshed via `didUpdateWidget()` whenever the profile ID changes, ensuring labels don't leak between profile switches
- After returning from the form page, the button future is reloaded to reflect any draft state changes

### Form Fields and Validation

#### 1) Date Field
- **Input type**: Date picker (tappable card)
- **Default value**: Current date (auto-filled)
- **Display format**: Configurable per app settings (MM/DD/YYYY, DD/MM/YYYY, or YYYY-MM-DD)
- **Undo button**: Shown if date was changed from the initial value
- **Validation**: 
  - Required: Must have a date (always satisfied due to auto-fill)
  - No future dates allowed (enforced by date picker)

#### 2) Clock-In Time
- **Input type**: Time picker (tappable card)
- **Display**: Formatted per app settings (12 hr or 24 hr)
- **Timestamp button**: Tappable clock icon to set time to now
- **Undo button**: Shown if time was changed from the initial value
- **Validation**:
  - Required: Must have a clock-in time to finalize
  - Must be before clock-out time
  - Must not overlap with any break or lunch time
  - Error message: "This time overlaps with [break/lunch]"

#### 3) Break Fields (0–5 Breaks)
- **Input type**: For each break, two time picker cards (start and end)
- **Display**: Formatted per app settings
- **Timestamp buttons**: Clock icons for each time to set to now
- **Undo buttons**: Shown if times were changed
- **Add/Remove buttons**: 
  - "Add break" button appears if fewer than 5 breaks are recorded
  - "Remove break" button appears if at least 1 break exists (removes the highest-numbered break)
- **Validation**:
  - Break times must be within clock-in to clock-out range
  - Breaks must not overlap with each other
  - Breaks must not overlap with lunch time
  - Break times must not be equal (start != end)
  - Error messages: "This time overlaps with [break/lunch/clock-out]"

#### 4) Lunch Break (Optional)
- **Input type**: Toggle button ("Add lunch" / "Remove lunch")
- **When enabled**: Two time picker cards appear for lunch start and end times
- **Display**: Formatted per app settings
- **Timestamp buttons**: Clock icons to set to now
- **Undo buttons**: Shown if times were changed
- **Validation** (when enabled):
  - Lunch must be within clock-in to clock-out range
  - Lunch must not overlap with breaks
  - Lunch start must not equal lunch end
  - Error messages: "This time overlaps with [break/clock-in/clock-out]"

#### 5) Clock-Out Time
- **Input type**: Time picker (tappable card)
- **Display**: Formatted per app settings
- **Timestamp button**: Clock icon to set to now
- **Undo button**: Shown if time was changed from the initial value
- **Validation**:
  - Required: Must have a clock-out time to finalize
  - Must be after clock-in time
  - Must not overlap with any break or lunch time

#### 6) Session Note (Optional)
- **Input type**: Multi-line text field (3 lines visible)
- **Max length**: 200 characters
- **Character counter**: Displayed below field
- **Validation**: 
  - Optional (can be empty)
  - Max 200 characters enforced by input limit
  - Trimmed of whitespace during validation

### Validation Logic

#### Required Field Validation
- **Fields required to finalize**: clock-in time, clock-out time
- **Errors returned as map**: `{'fieldName': 'error message', ...}`
- **Validation function**: `WorkSessionValidation.validateRequiredFields()`

#### Internal Overlap Validation (within session)
- Checks that all times are ordered correctly and don't overlap:
  - Clock-in < all break starts
  - All break ends < clock-out
  - All break starts < break ends (for each break)
  - Breaks don't overlap each other
  - If lunch exists: clock-in < lunch start < lunch end < clock-out
- **Validation function**: `WorkSessionValidation.validateTimeOverlapsWithinSession()`

#### Existing Session Overlap Validation
- Fetches all finalized sessions for the profile
- Checks if the new session's clock-in/clock-out times overlap with any existing session on the same or adjacent dates (across midnight)
- **Errors**: Marks clock-in and/or clock-out fields with overlap errors
- **Validation function**: `WorkSessionValidation.validateNoOverlapWithExistingSessions()`
- **Database query**: `getFinalizedWorkSessionsForProfile(jobProfileId)`

### Form Buttons

#### Save Changes Button (Outlined)
- **Action**: Calls `vm.saveChanges()`
- **Behavior**:
  - If no input has been entered, deletes any existing draft
  - If input exists, saves the current session as a draft to `temp_work_sessions`
  - Shows snackbar: "Changes saved."
- **Enabled state**: Always enabled unless form is busy

#### Finish Session Button (Filled)
- **Action**: Calls `vm.finishSession()`
- **Behavior**:
  - Runs all three validation checks (required fields, internal overlaps, existing overlaps)
  - If any validation fails, shows snackbar: "Please fix the highlighted inputs."
  - If all validations pass, saves session to `work_sessions`, deletes the draft, and pops the page returning `true`
  - Shows snackbar: "Work session finished."
- **Enabled state**: Disabled if form is busy

## State Management

### WorkSessionViewModel (MVVM Architecture)

**Purpose**: Manages form state, validation, and persistence logic

**Properties**:
- `jobProfileId`: The job profile the session is for
- `session`: Current `WorkSession` object being edited
- `hasOpenDraft`: Boolean indicating if a draft exists (used for button label)
- `isBusy`: Boolean indicating if an async operation is in progress

**Public Methods**:
- `static Future<WorkSessionViewModel> create({required int jobProfileId})`: Factory to create and initialize a ViewModel
  - Loads existing draft if present, otherwise creates blank session with auto-filled date and previous break/lunch preferences
- `void setSessionDate(DateTime date)`: Updates session date
- `void setFieldToNow(String key)`: Sets a time field to current time
- `void setTimeField(String key, TimeOfDay time)`: Sets a time field to a specific time
- `void setNote(String value)`: Updates session note
- `void addBreakField()`: Increments break count (max 5)
- `void removeBreakField()`: Decrements break count (removes highest break)
- `void setLunchEnabled(bool enabled)`: Enables/disables lunch break
- `void undoField(String key)`: Reverts a field to its initial value
- `void undoDate()`: Reverts date to initial value
- `Future<void> saveChanges()`: Saves session to draft or deletes draft if empty
- `Future<bool> finishSession()`: Validates and finalizes session; returns success/failure
- `Future<void> saveOnExit()`: Alias for `saveChanges()` used by PopScope on back button

**Getters**:
- `String get topButtonLabel`: Returns "Edit Current Work Session" or "Create Current Work Session" based on `hasOpenDraft`
- `String? errorFor(String key)`: Returns validation error for a field, or null if no error
- `bool fieldChanged(String key)`: Checks if a field differs from initial value
- `bool dateChanged()`: Checks if date differs from initial value

**Listeners**: 
- ViewModel extends `ChangeNotifier`, so UI rebuilds on state changes

### WorkSession (Model)

**Purpose**: Data model for a work session

**Fields**:
- `jobProfileId`: Links session to a job profile
- `sessionDate`: Date in ISO 8601 format
- `clockInTime`, `clockOutTime`: Times in HH:MM format
- `breakCount`: Number of breaks (0–5)
- `break1StartTime` to `break5EndTime`: Individual break times
- `hasLunch`: Boolean flag
- `lunchStartTime`, `lunchEndTime`: Lunch times
- `note`: Optional session note
- `id`: Database row ID (null for unsaved drafts)

**Methods**:
- `bool get hasAnyInput`: Returns true if any field is populated
- `WorkSession copyWith({...})`: Creates modified copy with specified fields changed
- `Map<String, Object?> toMap()`: Converts to database map
- `static WorkSession fromMap(Map<String, Object?> map)`: Creates from database map

## Form Page Lifecycle

### CreateEditCurrentWorkSessionPage (StatefulWidget)

**Lifecycle**:
1. `initState()`: Asynchronously creates ViewModel via `WorkSessionViewModel.create()`
2. Form rendered with ViewModel attached via `AnimatedBuilder` for reactive updates
3. On back button press: `PopScope.onPopInvokedWithResult` calls `_saveAndExit()` which saves changes and pops
4. When "Finish Session" succeeds: Manually pops with `Navigator.of(context).pop(true)`
5. `dispose()`: Unsubscribes from ViewModel and disposes ViewModel

**PopScope behavior**: 
- Prevents back navigation if `vm.isBusy` is true
- On pop attempt, calls `_saveAndExit()` to auto-save draft before leaving

## Button Label State Tracking (Fixed in This Version)

### Previous Bug
- The button state was cached in `_hasDraftFuture` once during `initState()` of the button's state object
- When the user navigated between job profiles, the widget was reused but the future wasn't refreshed
- Result: Button labels showed the previous profile's draft state until the page was manually refreshed

### Fix Applied
- Added `didUpdateWidget()` lifecycle hook to `_CurrentWorkSessionButtonState`
- When `profileId` changes (detected by comparing old and new widget), the future is reloaded
- Ensures button label is always accurate for the current profile

### Testing
- Regression widget test added: `test/job_profile_details_page_test.dart`
- Test switches between two profiles and verifies button label updates correctly for each
- The same regression test also covers the `appSettings` handoff on the details page so the session flow keeps using the correct display settings
- Test passes, confirming label behavior is now profile-scoped

## Files Changed

- `lib/work_session.dart`: Work session data model
- `lib/work_session_view_model.dart`: MVVM ViewModel for form logic
- `lib/work_session_validation.dart`: Validation utilities for time overlaps and required fields
- `lib/create_edit_current_work_session_page.dart`: Form page UI
- `lib/job_profile_details_page.dart`: Profile details page with button and optional draft-state loader
- `pubspec.yaml`: Added dependencies (if any)
- `test/job_profile_details_page_test.dart`: Regression test for button label state across profile switches
- `docs/create-edit-current-work-session-feature.md`: This implementation summary

## Notes

- Work sessions are always linked to a job profile; deleting a profile cascades delete to all its sessions and drafts
- Drafts are automatically saved as the user types (on every form interaction)
- The app respects app settings for date and time format display
- Validation errors are shown inline below their respective fields
- The feature preserves previous break count and lunch preference from the most recent finalized session for the profile
- No overlapping sessions are allowed within the same profile, even across date boundaries (e.g., 11 PM to 1 AM)
