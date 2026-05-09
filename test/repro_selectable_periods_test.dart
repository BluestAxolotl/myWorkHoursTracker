import 'package:flutter_test/flutter_test.dart';
import 'package:myworkhourstracker/job_profile.dart';
import 'package:myworkhourstracker/job_profile_totals_view_model.dart';
import 'package:myworkhourstracker/work_session.dart';

void main() {
  test('repro selectable periods for weekly with two prior periods', () {
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

    // Create sessions in two prior periods:
    // P-1: 04/25 - 05/01 -> choose 2026-04-26
    // P-2: 04/18 - 04/24 -> choose 2026-04-20
    final List<WorkSession> sessions = <WorkSession>[
      WorkSession(jobProfileId: 1, sessionDate: DateTime(2026,4,26), clockInTime: '09:00', clockOutTime: '17:00'),
      WorkSession(jobProfileId: 1, sessionDate: DateTime(2026,4,20), clockInTime: '09:00', clockOutTime: '17:00'),
    ];

    final List<PeriodWindow> selectable = JobProfileTotalsCalculator.buildSelectablePayPeriods(profile, sessions, now: now);

    // Print to help debugging in CI/logs
    // Expect selectable contains current, P-1, P-2 -> length 3
    expect(selectable.length, 3);

    final labels = selectable.map((p) => JobProfileTotalsCalculator.formatSelectablePayPeriodLabel(profile, p, 'MM/DD/YYYY', now: now)).toList();
    expect(labels.any((l) => l.contains('04/25/2026 - 05/01/2026')), true);
    expect(labels.any((l) => l.contains('04/18/2026 - 04/24/2026')), true);
  });
}
