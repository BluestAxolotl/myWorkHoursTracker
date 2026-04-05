# App Settings Initialization Feature

## Platform scope

- This repository currently targets Android only.
- Non-Android Flutter platform scaffolding has been removed.

## What was implemented

This feature adds an app settings flow that is required on first use and reused throughout job profile management.

### 1) First-use settings screen
- On app launch, settings are loaded from SharedPreferences.
- If any required setting is missing, the app shows the App Settings screen immediately.
- If SharedPreferences cannot be retrieved, fallback settings are used:
  - Date format: MM/DD/YYYY
  - Time format: 12 hr
  - Currency symbol: $
- On the first-use app settings screen, tapping the device's Back button minimizes the app

### 2) App settings options and validation
The App Settings screen includes:
- Date format drop-down
- Time format drop-down (12 hr or 24 hr)
- Combined currency search-and-selection field
- Typing filters currency symbols in the same control used to pick the final value

Validation behavior:
- The worker must select every required input.
- If any required input is missing, an inline error message appears next to that input.
- Saving is blocked until all required selections are present.

### 3) Save behavior
- The Save Settings button writes all settings to SharedPreferences.
- Existing saved values are overwritten with the latest selection.
- If the write fails, a snack bar error message is shown.
- Successful saving of settings takes user to job profile page, where changes to app settings can be seen

### 4) Sidebar gear access behavior
- The sidebar (drawer) contains a settings gear icon in the top-right area.
- The gear icon is always shown, regardless of the number of job profiles.
- Tapping the gear opens the App Settings screen.

### 5) Last profile deletion behavior
- Job profiles are tracked in a local list and persisted in SharedPreferences (for now)
- If the worker deletes the final remaining job profile, the user stays on the main app screen, which informs the user that there is no job profile
and prompts the user to create one in the sidebar

## Files changed
- lib/main.dart
  - Replaced template counter app with:
    - App settings model and fallback defaults
    - SharedPreferences load/save logic for settings and job profiles
    - First-run settings gate
    - Sidebar with gear icon access to settings
    - Add/delete job profile flow without forced settings redirect
    - Settings form with validation and filtered currency dropdown
- pubspec.yaml
  - Added shared_preferences dependency
- docs/app-settings-feature.md
  - Added this implementation summary

## Notes
- Settings are intended to apply globally across job profiles.
- Currency selection now uses a single autocomplete field instead of a separate search box and drop-down.
- If SharedPreferences retrieval fails, the app uses fallback defaults and continues with a safe first-run flow.
