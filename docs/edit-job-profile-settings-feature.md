# Edit Job Profile Settings Feature

## Overview

This feature lets users edit the settings for an existing job profile from the sidebar. The edit flow reuses the same job profile form used for creation, so users can change the profile name, pay rate, pay period, pay-day fields, and overtime configuration without switching to a separate settings screen.

## User Experience

- Each job profile in the sidebar exposes an Edit action.
- Tapping Edit opens the shared job profile form populated with the current profile values.
- Saving changes updates the existing profile rather than creating a new one.
- The sidebar entry, totals section, and calendar section refresh after save so the new settings take effect immediately.

## Implementation Details

### Reused Form
- File: `lib/create_job_profile_page.dart`
- The form now accepts an optional initial `JobProfile`.
- In edit mode, the title and submit button switch to edit/save wording.
- The same validation rules are used for both create and edit flows.

### Database Update
- File: `lib/job_profile_database.dart`
- Added `updateJobProfile(JobProfile profile)` to persist edited settings back to the `job_profiles` table.

### Sidebar Wiring
- File: `lib/main.dart`
- The sidebar Edit button now opens the shared job profile form with the selected profile.
- After the edit returns, the profile list is reloaded and the selected profile stays active.

### Calendar and Totals Refresh
- File: `lib/job_profile_details_page.dart`
- File: `lib/job_profile_calendar_section.dart`
- File: `lib/job_profile_details_page.dart` now compares full profile settings, not just the profile id, so totals and calendar state refresh when pay rules change.
- The calendar and totals view models are recreated when relevant profile settings change.
 - The totals section is keyed to the `JobProfile` settings so the UI and view model are rebuilt when pay-period or overtime configuration changes, preventing stale in-place totals after edits.

## Testing

- Run `flutter analyze`.
- Run `flutter test`.
- A pure-Dart unit test covers the profile-settings comparison helper used to detect changes.
