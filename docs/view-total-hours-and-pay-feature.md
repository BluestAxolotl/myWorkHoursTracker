# View: Total Hours and Pay — Feature Doc

## Purpose
Provide a concise totals summary for a `JobProfile` showing total hours worked and computed pay. The summary supports two modes — pay-period (default) and yearly — and applies `JobProfile` overtime rules (daily or by-pay-period) when computing overtime pay.

## Placement
- Displayed on the `JobProfile` details page beneath the Create/Edit Current Work Session control and above the job profile settings.

## UI Behavior
- Card shows:
  - Toggle to switch between **Pay-period** and **Yearly** modes.
  - For Pay-period: a vertical list of recent pay-period windows with per-window totals.
  - For Yearly: the calendar year aggregates (Jan–Dec) with yearly totals.
  - Each period row shows: period label (date range), regular hours, overtime hours, regular pay, overtime pay, total pay.
- Compact summary (single-line) shown on small screens; full list collapses behind an expander.

Note: the user-facing label previously shown as "Pay Day" has been renamed to "Pay Period End" throughout the UI and model. See Implementation Notes below for the API/database changes.

## Modes
- Pay-period (default): Groups `WorkSession` records into contiguous windows determined by the `JobProfile.payPeriod` setting (e.g., 7 days). Windows are anchored using the session dates and aligned to chronological series; recent N windows are shown (implementation currently shows the last 6 windows).
- Yearly: Groups sessions by calendar year (January 1 — December 31).

Selection & Search behavior updates:
- The selectable pay-period list always includes the current pay period even if there are no sessions in it.
- The selectable lists are deduplicated using `PeriodWindow` equality and include any payroll window that overlaps session end dates (fixes cases where recent windows were omitted).
- The pay-period and year selection dialogs were simplified to `SimpleDialog` for stability and layout consistency.

## Overtime Rules
- Uses fields on `JobProfile`:
  - `overtimePaid` (bool)
  - `overtimeMode` (`daily` | `byPayPeriod`)
  - `overtimeThresholdHours` (hours, e.g., 8)
  - `overtimeMultiplier` (e.g., 1.5)
- Calculation approach (high level):
  1. For each window (pay-period or year), collect sessions whose end date falls inside the window (see note about 24-hour/overnight sessions below).
  2. Sum worked hours.
  3. If `overtimePaid` is false, overtime hours/pay = 0.
  4. If `overtimeMode == daily`: compute overtime per-session by comparing `session.workHours` to `overtimeThresholdHours` and treat excess as overtime.
  5. If `overtimeMode == byPayPeriod`: compute overtime on the window total: any hours beyond `overtimeThresholdHours` are overtime (see configuration for threshold meaning in the profile).
  6. Pay calculation:
     - Regular pay = `regularHours * payRate`
     - Overtime pay = `overtimeHours * payRate * overtimeMultiplier`
     - Total pay = regular pay + overtime pay

## Example
- JobProfile: payRate = 20.00, payPeriod = 7 days, overtimePaid = true, overtimeMode = daily, overtimeThresholdHours = 8, overtimeMultiplier = 1.5.
- Session A (2026-04-21): 9 hours -> regular 8h, overtime 1h.
- Session B (2026-04-22): 7 hours -> regular 7h, overtime 0h.
- Window total: regular 15h, overtime 1h; regular pay = 15 * 20 = 300; overtime pay = 1 * 20 * 1.5 = 30; total = 330.

## Implementation Notes
- Business logic is in `JobProfileTotalsViewModel` and `JobProfileTotalsCalculator` (`lib/job_profile_totals_view_model.dart`).
- The UI card is added to `JobProfile` details page in `lib/job_profile_details_page.dart` and is supplied a `totalsSessionsLoader` in tests to avoid DB coupling.
- Formatting (dates, times, currency) uses `AppSettings` for locale/format settings; pass the `AppSettings` instance into the details page and totals view to keep currency/date formats consistent.

Recent implementation details / changes
- Field renames: `payDayOfWeek` → `payPeriodEndDayOfWeek`, `payDayOfMonth` → `payPeriodEndDayOfMonth` in `lib/job_profile.dart` and associated `toMap()`/`fromMap()` keys updated (`pay_period_end_day_of_week`, `pay_period_end_day_of_month`).
- Database migration: `lib/job_profile_database.dart` now migrates existing `pay_day_of_week` / `pay_day_of_month` columns to the new names during an upgrade; database version was bumped to `4` to trigger the migration path for existing installations.
- Selectable-period builder: `JobProfileTotalsCalculator.buildSelectablePayPeriods()` always includes the current window and deduplicates windows; `buildAllPayPeriods()` loop condition was fixed to include windows whose start is on or before the latest session end date (prevents missing recent windows).
- Dialogs and labels: selection dialogs simplified to `SimpleDialog`; form labels updated to "Pay period end day of the week" and "Pay period end day of the month (1-31)" in `lib/create_job_profile_page.dart`.
- Auto-select helpers: `setCurrentPayPeriod()` and `setCurrentYear()` exist on the ViewModel and are wired to the UI toggle so the current period/year is auto-selected when toggling views.
- Robustness: `PeriodWindow` implements value equality (start/end) so selectable lists dedupe correctly.
- Overnight / 24-hour sessions: `_sessionEndDate()` treats equal clock-in and clock-out times as spanning to the next day (24-hour session), and period/window aggregation handles these correctly.

## Tests
- Unit tests: `test/job_profile_totals_view_model_test.dart` — covers pay-period and yearly aggregation and overtime math.
- Widget tests: `test/job_profile_details_page_test.dart` — updated to account for the totals card in layout.

Added focused tests for regression coverage:
- `test/repro_selectable_periods_test.dart` — reproduction test for selectable-period behavior (keeps current and previous windows with sessions).
- `test/edge_case_24hr_session_test.dart` — verifies 24-hour sessions and boundary behavior.
- `test/repro_selectable_periods_test_debug.dart` — debugging helper (committed but disabled by default). Run with `--dart-define=RUN_DEBUG_TESTS=true` to enable.

## Files Touched
- `lib/job_profile_totals_view_model.dart` — period building, window inclusion fixes, and formatting helpers.
- `lib/job_profile.dart` — field renames and serialization updates.
- `lib/job_profile_database.dart` — schema update, migration logic, and database version bump to 4.
- `lib/job_profile_details_page.dart`, `lib/create_job_profile_page.dart` — UI labels, dialogs, and wiring to auto-select helpers.
- Tests: `test/job_profile_totals_view_model_test.dart`, `test/job_profile_details_page_test.dart`, `test/repro_selectable_periods_test.dart`, `test/edge_case_24hr_session_test.dart`, `test/repro_selectable_periods_test_debug.dart`.

## Future Work / TODOs
- Add per-company or per-profile custom pay-period anchors (e.g., anchored to payroll start dates).
- Add caching for expensive aggregates and background refresh for large datasets.
- UI: Add date-range picker to customize which windows are shown.
- Consider documenting the `RUN_DEBUG_TESTS` test flag in the repo README.

## Review Checklist
- Validate that payPeriod grouping matches payroll expectations.
- Ensure `AppSettings` currency/locale are respected in formatted output.
- Confirm Overtime rules behave for boundary cases (midnight-crossing sessions, DST shifts).

---
Created for: `JobProfile` totals view feature.
