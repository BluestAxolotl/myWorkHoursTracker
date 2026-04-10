// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:myworkhourstracker/job_profile.dart';

void main() {
  test('Pay period day conversion works', () {
    expect(payPeriodDays(PayPeriod.daily), 1);
    expect(payPeriodDays(PayPeriod.weekly), 7);
    expect(payPeriodDays(PayPeriod.biweekly), 14);
    expect(payPeriodDays(PayPeriod.monthly), 30);
  });

  test('JobProfile map serialization round trip works', () {
    const JobProfile profile = JobProfile(
      id: 5,
      name: 'store clerk',
      payRate: 19.50,
      payPeriod: PayPeriod.weekly,
      payDayOfWeek: Weekday.fri,
      overtimePaid: true,
      overtimeMode: OvertimeMode.byPayPeriod,
      overtimeThresholdHours: 40,
      overtimeMultiplier: 1.50,
    );

    final Map<String, Object?> map = profile.toMap();
    final JobProfile parsed = JobProfile.fromMap(map);

    expect(parsed.id, 5);
    expect(parsed.name, 'store clerk');
    expect(parsed.payRate, 19.50);
    expect(parsed.payPeriod, PayPeriod.weekly);
    expect(parsed.payDayOfWeek, Weekday.fri);
    expect(parsed.overtimePaid, true);
    expect(parsed.overtimeMode, OvertimeMode.byPayPeriod);
    expect(parsed.overtimeThresholdHours, 40);
    expect(parsed.overtimeMultiplier, 1.50);
  });

  test('JobProfile monthly pay period serialization works', () {
    const JobProfile profile = JobProfile(
      id: 7,
      name: 'accountant',
      payRate: 3500.00,
      payPeriod: PayPeriod.monthly,
      payDayOfMonth: 15,
      overtimePaid: false,
    );

    final Map<String, Object?> map = profile.toMap();
    final JobProfile parsed = JobProfile.fromMap(map);

    expect(parsed.id, 7);
    expect(parsed.name, 'accountant');
    expect(parsed.payRate, 3500.00);
    expect(parsed.payPeriod, PayPeriod.monthly);
    expect(parsed.payDayOfMonth, 15);
    expect(parsed.payDayOfWeek, isNull);
    expect(parsed.overtimePaid, false);
  });
}
