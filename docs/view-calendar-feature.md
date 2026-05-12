# View Calendar Feature

## Platform scope

- This repository currently targets Android only.
- The calendar feature is part of the job profile detail experience.

## What was implemented

This feature provides a calendar view for each job profile so the worker can see when work sessions happened, switch between time ranges, and inspect session details.

### 1) Calendar modes
The calendar supports four modes:
- Daily
- Pay period
- Monthly
- Yearly

The mode buttons behave as follows:
- Switching to a different mode resets that mode to the period containing today.
- Tapping the active mode button again also snaps the calendar back to the current period.
- The selected period can still be changed independently with the date/period picker.

### 2) Calendar loading behavior
- The calendar shows an initial loading indicator while sessions are being prepared.
- Switching to yearly mode shows a loading overlay so the user has feedback during the slower transition.
- The loading state is separate from the calendar content so the view stays responsive once data is ready.

### 3) Day coloring
- Session rectangles and hour badges were removed from the main calendar grid.
- Instead, a day with at least one work session is filled with a distinct background color.
- Days without work sessions keep the neutral surface color.
- Days that represent today still keep a stronger border treatment so the current day remains visible.

### 4) Zoom-in day detail view
- Tapping a day opens a bottom-sheet detail view for that day.
- The detail view lists the work sessions that fall on the tapped day.
- Session times in the detail view follow the app time-format setting, so 12 hr and 24 hr display are both respected.

### 5) Multi-day session handling
- Overnight sessions are treated as spanning into the next day.
- The calendar slices a session across every day it covers, so each affected day is colored.
- This means a session that runs from one day into the next appears when zooming in on either day.

## Files changed
- lib/job_profile_calendar_section.dart
  - Calendar UI, loading overlays, mode selection, and zoom-in detail sheet
- lib/job_profile_calendar_view_model.dart
  - Calendar mode state, current-period reset logic, and date selection
- lib/job_profile_calendar_model.dart
  - Session slicing by day for multi-day coverage
- lib/work_session.dart
  - Time formatting helpers used by the detail view
- test/job_profile_calendar_section_test.dart
  - Widget coverage for loading, mode reset, time format display, and multi-day sessions
- docs/view-calendar-feature.md
  - This implementation summary

## Notes
- The calendar grid is designed to provide a quick overview first, then let the worker drill into details only when needed.
- Multi-day sessions are handled in the data model, not with a special-case UI path, which keeps the behavior consistent across views.