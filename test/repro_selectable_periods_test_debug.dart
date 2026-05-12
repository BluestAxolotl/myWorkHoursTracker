// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures

import 'package:flutter_test/flutter_test.dart';
import 'package:myworkhourstracker/job_profile.dart';
import 'package:myworkhourstracker/job_profile_totals_view_model.dart';
import 'package:myworkhourstracker/work_session.dart';

void main() {
  const bool runDebugTests = bool.fromEnvironment('RUN_DEBUG_TESTS', defaultValue: false);

  test(
    'debug selectable periods output',
    () {
      const JobProfile profile = JobProfile(
        id: 1,
        name: 'Store',
        payRate: 10.0,
        payPeriod: PayPeriod.weekly,
        payPeriodEndDayOfWeek: Weekday.fri,
        overtimePaid: false,
      );

      final DateTime now = DateTime(2026, 5, 6);

      final List<WorkSession> sessions = <WorkSession>[
        WorkSession(jobProfileId: 1, sessionDate: DateTime(2026, 4, 26), clockInTime: '09:00', clockOutTime: '17:00'),
        WorkSession(jobProfileId: 1, sessionDate: DateTime(2026, 4, 20), clockInTime: '09:00', clockOutTime: '17:00'),
      ];

      final List<PeriodWindow> selectable = JobProfileTotalsCalculator.buildSelectablePayPeriods(profile, sessions, now: now);

      final List<String> labels = selectable
          .map(
            (PeriodWindow period) => JobProfileTotalsCalculator.formatSelectablePayPeriodLabel(
              profile,
              period,
              'MM/DD/YYYY',
              now: now,
            ),
          )
          .toList();

      print('SELECTABLE COUNT: ${selectable.length}');
      for (final String label in labels) {
        print('LABEL: $label');
      }
    },
    skip: !runDebugTests,
  );
}
