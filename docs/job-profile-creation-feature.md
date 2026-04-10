# Create Job Profile Feature

## Feature Overview

This feature enables users to create and manage job profiles, where each profile represents a unique work configuration with specific pay periods, overtime rules, and compensation details. Job profiles are persisted in an encrypted local SQLite database and form the foundation for tracking work hours and calculating pay.

## Database Persistence

### Encrypted SQLite Storage
- Job profiles are stored in an encrypted SQLite database using `sqflite_sqlcipher` with the password `myWorkHoursTracker_local_key_v1`.
- Database file: `work_hours_tracker.db`
- Schema version: 2 (with migration support for future updates)

### Tables
- **job_profiles**: Stores job profile data including pay rates, overtime rules, and pay schedule information.
- **work_sessions**: Stores individual work session records linked to job profiles via foreign key with CASCADE delete enabled.

### Data Persistence
- When a job profile is created, it is saved to the database via `JobProfileDatabase.instance.createJobProfile()`.
- When a job profile is deleted, all associated work sessions are automatically deleted via foreign key cascade.

## Create Job Profile Form

### Form Access
- The Create Job Profile page is accessed via `CreateJobProfilePage`.
- Returns a `JobProfile` object on successful creation via `Navigator.pop()`.

### Form Fields and Validation

#### 1) Job Profile Name
- **Input type**: Text field
- **Validation**:
  - Required: name must be 1–30 characters
  - Trimmed of whitespace before validation
  - Error message: "Name should be between 1 and 30 characters."
- **Error display timing**: Shown on blur or after submit attempt

#### 2) Pay Rate
- **Input type**: Decimal number field
- **Validation**:
  - Must be a positive non-zero value
  - Must have exactly two decimal places (e.g., 15.00)
  - Error messages:
    - "Enter a positive non-zero pay rate."
    - "Enter pay rate with two decimal places; use 0 as the last decimal if needed."
- **Error display timing**: Shown only after submit attempt

#### 3) Pay Period
- **Input type**: Dropdown selection
- **Options**: Daily, Weekly, Biweekly, Monthly
- **Behavior**:
  - Selecting Daily automatically sets overtime mode to Daily and clears supplementary pay-day fields.
  - Selecting Daily also clears any overtime threshold and multiplier inputs.
  - Changing pay period clears overtime fields to force reconfiguration.
- **Validation**: Required; error shown after submit attempt

#### 4) Pay Day (Weekday or Calendar Date)
- **For Weekly/Biweekly**:
  - **Input type**: Dropdown showing days of the week (Monday–Sunday)
  - **Field name**: "Pay day of the week"
  - **Validation**: Required when pay period is weekly or biweekly
- **For Monthly**:
  - **Input type**: Text field accepting integers 1–31
  - **Field name**: "Pay day of the month (1-31)"
  - **Validation**: Must be an integer between 1 and 31
  - **Error message**: "Enter a day between 1 and 31."
- **For Daily**: No pay-day field is shown
- **Validation timing**: Errors shown after submit attempt

#### 5) Overtime Paid
- **Input type**: Dropdown (Paid / Unpaid)
- **Behavior**:
  - Selecting "Unpaid" hides all overtime configuration fields.
  - Selecting "Paid" reveals overtime mode, threshold, and multiplier fields.
  - Changing this selection clears overtime threshold and multiplier inputs.
- **Validation**: Required; error shown after submit attempt

#### 6) Overtime Mode (Applies)
- **Visibility**: Only shown when "Overtime Paid" is set to "Paid"
- **For Daily pay period**: Shown as read-only text "Daily"
- **For other pay periods**: Dropdown with options Daily or Period (Weekly/Biweekly/Monthly)
- **Behavior**:
  - When pay period is null, the dropdown is disabled with a light background
  - Selecting a mode clears threshold and multiplier inputs to force fresh entry
- **Validation**: Required when creating overtime rules (error: "Please choose a pay period above")
- **Error display timing**: Shown after submit attempt

#### 7) Overtime Threshold
- **Input type**: Number field
- **Field label**: "Hours before overtime (range depends on mode)"
- **Visibility**: Only shown when overtime is paid and overtime mode is set, with no overtime mode errors
- **Validation**:
  - For Daily overtime: integer from 1 to 23
  - For Period-based overtime: integer from 23 to max hours in period
  - Error message: "Invalid input. Enter an integer from X to Y."
- **Max hours calculation**: `payPeriodDays() * 24` (rounded to at least 23)
- **Error display timing**: Shown after submit attempt and during threshold input changes

#### 8) Overtime Multiplier
- **Input type**: Decimal number field
- **Field label**: "Overtime multiplier (> 1.00 - 10.00)"
- **Visibility**: Only shown when overtime threshold field is visible and valid overtime mode is selected
- **Validation**:
  - Must have exactly two decimal places
  - Must be strictly greater than 1.00 (exclusive lower bound)
  - Must be up to 10.00 (inclusive upper bound)
  - Error messages:
    - "Enter multiplier with exactly two decimal places."
    - "Enter a value greater than 1.00 and up to 10.00."
- **Error display timing**: Shown after submit attempt (independently of threshold errors)

## Form Submission

### Validation Summary
Before submission, the form validates:
- All text fields (name, pay rate) are free of errors
- All required selections have been made (pay period, overtime paid/unpaid)
- If overtime is enabled, overtime mode and threshold are present with no errors
- Overtime multiplier is present and valid

### Error Handling
- If validation fails, an error snack bar is shown with context-appropriate text
- Submit button is disabled during submission (shows "Creating..." text)
- Network/database errors display a snack bar: "Could not save profile. Please try again."

### Successful Creation
- Profile is saved to encrypted SQLite database via `JobProfileDatabase.instance.createJobProfile()`
- The returned `JobProfile` object (with newly assigned ID) is passed back to the calling page via `Navigator.pop()`

## Related Files

- **lib/create_job_profile_page.dart**: Main form UI and validation logic
- **lib/job_profile.dart**: `JobProfile` data model with serialization/deserialization
- **lib/job_profile_database.dart**: Encrypted database setup, schema creation, migrations, and CRUD operations
- **lib/main.dart**: App navigation and home page that displays job profiles

## Pay Period Helpers

The form uses helper functions to calculate and label pay periods:
- `payPeriodDays(PayPeriod period)`: Returns the number of days in a pay period
- `payPeriodLabel(PayPeriod period)`: Returns user-friendly label (e.g., "Weekly", "Biweekly")
- `weekdayLabel(Weekday day)`: Returns day name
- `overtimeModeLabel(OvertimeMode mode)`: Returns overtime mode label
