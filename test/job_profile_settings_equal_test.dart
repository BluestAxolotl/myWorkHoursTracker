import 'package:flutter_test/flutter_test.dart';

import 'package:myworkhourstracker/job_profile.dart';

void main() {
  test('jobProfileSettingsEqual returns true for identical settings', () {
    const JobProfile profileA = JobProfile(
      id: 1,
      name: 'Warehouse',
      payRate: 18.50,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: true,
      overtimeMode: OvertimeMode.byPayPeriod,
      overtimeThresholdHours: 40,
      overtimeMultiplier: 1.50,
    );

    const JobProfile profileB = JobProfile(
      id: 1,
      name: 'Warehouse',
      payRate: 18.50,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: true,
      overtimeMode: OvertimeMode.byPayPeriod,
      overtimeThresholdHours: 40,
      overtimeMultiplier: 1.50,
    );

    expect(jobProfileSettingsEqual(profileA, profileB), isTrue);
  });

  test('jobProfileSettingsEqual returns false when settings differ', () {
    const JobProfile profileA = JobProfile(
      id: 1,
      name: 'Warehouse',
      payRate: 18.50,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: true,
      overtimeMode: OvertimeMode.byPayPeriod,
      overtimeThresholdHours: 40,
      overtimeMultiplier: 1.50,
    );

    const JobProfile profileB = JobProfile(
      id: 1,
      name: 'Warehouse',
      payRate: 19.00,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: true,
      overtimeMode: OvertimeMode.byPayPeriod,
      overtimeThresholdHours: 40,
      overtimeMultiplier: 1.50,
    );

    expect(jobProfileSettingsEqual(profileA, profileB), isFalse);
  });
}