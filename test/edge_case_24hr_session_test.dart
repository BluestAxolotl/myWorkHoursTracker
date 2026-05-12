import 'package:flutter_test/flutter_test.dart';
import 'package:myworkhourstracker/job_profile.dart';
import 'package:myworkhourstracker/job_profile_totals_view_model.dart';
import 'package:myworkhourstracker/work_session.dart';

void main() {
  test('24-hour session (same clock-in and clock-out time) computes correctly', () {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Store',
      payRate: 10.0,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: false,
    );

    // Now = 2026-05-06 (Wed), current pay period is 05/02 - 05/08
    final DateTime now = DateTime(2026, 5, 6);

    // Create a 24-hour session: same clock-in and clock-out (8 AM to 8 AM)
    // session_date = 2026-05-05 (Tue), so session spans Tue 8AM to Wed 8AM
    final List<WorkSession> sessions = <WorkSession>[
      WorkSession(
        jobProfileId: 1,
        sessionDate: DateTime(2026, 5, 5),
        clockInTime: '08:00',
        clockOutTime: '08:00', // Same time - 24-hour session
      ),
    ];

    // Build selectable periods
    final List<PeriodWindow> selectable =
        JobProfileTotalsCalculator.buildSelectablePayPeriods(profile, sessions, now: now);

    // Check that the period is included (should be current period since session is in current period)
    final List<String> labels = selectable
        .map((p) => JobProfileTotalsCalculator.formatSelectablePayPeriodLabel(
              profile,
              p,
              'MM/DD/YYYY',
              now: now,
            ))
        .toList();

    // The session on May 5 should end on May 6 (next day due to 24-hour interpretation)
    // Current period is 05/02 - 05/08, so it should be included
    expect(labels.any((l) => l.contains('05/02/2026 - 05/08/2026')), true,
        reason: 'Current period should be selectable for 24-hour session in current period');
  });

  test('24-hour session at period boundary', () {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Store',
      payRate: 10.0,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: false,
    );

    // Now = 2026-05-06 (Wed), current pay period is 05/02 - 05/08
    final DateTime now = DateTime(2026, 5, 6);

    // Create a 24-hour session on the last day of a previous period
    // Period before current: 04/25 - 05/01
    // Session on 05/01 (Fri, end of period) clocking in/out at 8 AM
    // This would end on 05/02, which is in the current period
    final List<WorkSession> sessions = <WorkSession>[
      WorkSession(
        jobProfileId: 1,
        sessionDate: DateTime(2026, 5, 1),
        clockInTime: '08:00',
        clockOutTime: '08:00',
      ),
    ];

    final List<PeriodWindow> selectable =
        JobProfileTotalsCalculator.buildSelectablePayPeriods(profile, sessions, now: now);

    final List<String> labels = selectable
        .map((p) => JobProfileTotalsCalculator.formatSelectablePayPeriodLabel(
              profile,
              p,
              'MM/DD/YYYY',
              now: now,
            ))
        .toList();

    // Session ends on 05/02, so current period should be included
    expect(labels.any((l) => l.contains('05/02/2026 - 05/08/2026')), true,
        reason: 'Current period should be selectable for 24-hour session ending in current period');
  });

  test('calculate totals with 24-hour session', () {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Store',
      payRate: 10.0,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: false,
    );

    final DateTime now = DateTime(2026, 5, 6);

    // 24-hour session on 2026-05-05
    final List<WorkSession> sessions = <WorkSession>[
      WorkSession(
        jobProfileId: 1,
        sessionDate: DateTime(2026, 5, 5),
        clockInTime: '08:00',
        clockOutTime: '08:00',
      ),
    ];

    // Calculate for current period
    final JobProfileTotalsSummary summary = JobProfileTotalsCalculator.calculate(
      profile: profile,
      sessions: sessions,
      viewMode: TotalsViewMode.payPeriod,
      referenceDate: now,
    );

    // Should compute without error and include the session
    expect(summary.sessionCount, 1, reason: 'Should count the 24-hour session');
    // 24 hours of work
    expect(summary.totalHours, 24.0, reason: 'Should count 24 hours');
  });
}
