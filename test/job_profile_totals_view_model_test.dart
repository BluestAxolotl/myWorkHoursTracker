import 'package:flutter_test/flutter_test.dart';

import 'package:myworkhourstracker/job_profile.dart';
import 'package:myworkhourstracker/job_profile_totals_view_model.dart';
import 'package:myworkhourstracker/work_session.dart';

WorkSession _session({
  required DateTime date,
  required String clockIn,
  required String clockOut,
}) {
  return WorkSession(
    jobProfileId: 1,
    sessionDate: date,
    clockInTime: clockIn,
    clockOutTime: clockOut,
  );
}

void main() {
  test('formats pay period and year labels using the selected settings', () {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Store',
      payRate: 10.0,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: false,
    );

    expect(
      JobProfileTotalsCalculator.formatPayPeriodLabel(
        profile,
        DateTime(2026, 5, 6),
        'MM/DD/YYYY',
      ),
      '05/02/2026 - 05/08/2026',
    );
    expect(JobProfileTotalsCalculator.formatYearLabel(2026), '2026');
    expect(
      parseDateWithSetting('05/06/2026', 'MM/DD/YYYY'),
      DateTime(2026, 5, 6),
    );
  });

  test('selectable pay periods and years include the current values', () {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Store',
      payRate: 10.0,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: false,
    );

    final DateTime now = DateTime(2026, 5, 6);
    final List<PeriodWindow> selectablePeriods = JobProfileTotalsCalculator.buildSelectablePayPeriods(
      profile,
      <WorkSession>[],
      now: now,
    );
    final List<int> selectableYears = JobProfileTotalsCalculator.buildSelectableYears(
      <WorkSession>[],
      now: now,
    );

    expect(selectablePeriods, hasLength(1));
    expect(
      JobProfileTotalsCalculator.formatSelectablePayPeriodLabel(
        profile,
        selectablePeriods.first,
        'MM/DD/YYYY',
        now: now,
      ),
      contains('(Current)'),
    );
    expect(selectableYears, contains(2026));
    expect(
      JobProfileTotalsCalculator.formatSelectableYearLabel(2026, now: now),
      '2026 (Current)',
    );
  });

  test('pay period view applies daily overtime per session count', () {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Store',
      payRate: 10.0,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: true,
      overtimeMode: OvertimeMode.byPayPeriod,
      overtimeThresholdHours: 40,
      overtimeMultiplier: 1.5,
    );

    final List<WorkSession> sessions = <WorkSession>[
      _session(date: DateTime(2026, 5, 2), clockIn: '09:00', clockOut: '19:00'),
      _session(date: DateTime(2026, 5, 3), clockIn: '09:00', clockOut: '19:00'),
      _session(date: DateTime(2026, 5, 4), clockIn: '09:00', clockOut: '19:00'),
      _session(date: DateTime(2026, 5, 5), clockIn: '09:00', clockOut: '19:00'),
      _session(date: DateTime(2026, 5, 6), clockIn: '09:00', clockOut: '14:00'),
      _session(date: DateTime(2026, 4, 25), clockIn: '09:00', clockOut: '19:00'),
    ];

    final JobProfileTotalsSummary summary = JobProfileTotalsCalculator.calculate(
      profile: profile,
      sessions: sessions,
      viewMode: TotalsViewMode.payPeriod,
      referenceDate: DateTime(2026, 5, 6),
    );

    expect(summary.totalHours, 45);
    expect(summary.regularHours, 40);
    expect(summary.overtimeHours, 5);
    expect(summary.totalPay, 475);
  });

  test('yearly view sums multiple pay periods in the current year', () {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Store',
      payRate: 10.0,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: true,
      overtimeMode: OvertimeMode.byPayPeriod,
      overtimeThresholdHours: 40,
      overtimeMultiplier: 1.5,
    );

    final List<WorkSession> sessions = <WorkSession>[
      _session(date: DateTime(2026, 4, 25), clockIn: '09:00', clockOut: '19:00'),
      _session(date: DateTime(2026, 4, 27), clockIn: '09:00', clockOut: '19:00'),
      _session(date: DateTime(2026, 4, 28), clockIn: '09:00', clockOut: '18:00'),
      _session(date: DateTime(2026, 5, 1), clockIn: '09:00', clockOut: '18:00'),
      _session(date: DateTime(2026, 5, 2), clockIn: '09:00', clockOut: '19:00'),
      _session(date: DateTime(2026, 5, 3), clockIn: '09:00', clockOut: '19:00'),
      _session(date: DateTime(2026, 5, 4), clockIn: '09:00', clockOut: '19:00'),
      _session(date: DateTime(2026, 5, 5), clockIn: '09:00', clockOut: '19:00'),
      _session(date: DateTime(2026, 5, 6), clockIn: '09:00', clockOut: '14:00'),
      _session(date: DateTime(2027, 1, 2), clockIn: '09:00', clockOut: '19:00'),
    ];

    final JobProfileTotalsSummary summary = JobProfileTotalsCalculator.calculate(
      profile: profile,
      sessions: sessions,
      viewMode: TotalsViewMode.yearly,
      referenceDate: DateTime(2026, 5, 6),
    );

    expect(summary.totalHours, 83);
    expect(summary.regularHours, 78);
    expect(summary.overtimeHours, 5);
    expect(summary.totalPay, 855);
    expect(summary.periodCount, 2);
  });
}
