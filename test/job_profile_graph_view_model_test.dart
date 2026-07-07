import 'package:flutter_test/flutter_test.dart';

import 'package:myworkhourstracker/job_profile.dart';
import 'package:myworkhourstracker/job_profile_graph_view_model.dart';
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
  test('graph view model reuses totals calculations across all views', () async {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Store',
      payRate: 10.0,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: true,
      overtimeMode: OvertimeMode.daily,
      overtimeThresholdHours: 8,
      overtimeMultiplier: 1.5,
    );

    final List<WorkSession> sessions = <WorkSession>[
      _session(date: DateTime(2026, 5, 2), clockIn: '09:00', clockOut: '19:00'),
      _session(date: DateTime(2026, 5, 9), clockIn: '08:00', clockOut: '20:00'),
    ];

    final JobProfileGraphViewModel vm = await JobProfileGraphViewModel.create(
      profile: profile,
      now: DateTime(2026, 5, 10),
      sessionsLoader: (_) async => sessions,
    );

    expect(vm.viewMode, JobProfileGraphViewMode.payPeriod);
    expect(vm.showOvertimeLine, isTrue);
    expect(vm.points, hasLength(7));
    expect(vm.points.first.summary.totalHours, 12);
    expect(vm.points.first.summary.overtimeHours, 4);
    expect(vm.points.first.summary.totalPay, 140);
    expect(formatGraphPointLabel(vm.viewMode, vm.points.first), 'Sat 9');
    expect(vm.points.last.summary.totalHours, 0);
    expect(vm.points.last.summary.overtimeHours, 0);
    expect(vm.points.last.summary.totalPay, 0);

    vm.setViewMode(JobProfileGraphViewMode.monthly);
    expect(vm.points, hasLength(12));
    expect(vm.points[4].summary.totalHours, 22);
    expect(vm.points[4].summary.overtimeHours, 6);
    expect(vm.points[4].summary.totalPay, 250);

    vm.setViewMode(JobProfileGraphViewMode.yearly);
    expect(vm.points, hasLength(1));
    expect(vm.points.single.summary.totalHours, 22);
    expect(vm.points.single.summary.overtimeHours, 6);
    expect(vm.points.single.summary.totalPay, 250);
  });
}