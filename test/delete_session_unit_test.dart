import 'package:flutter_test/flutter_test.dart';

import 'package:myworkhourstracker/job_profile.dart';
import 'package:myworkhourstracker/job_profile_calendar_model.dart';
import 'package:myworkhourstracker/job_profile_calendar_section.dart';
import 'package:myworkhourstracker/job_profile_calendar_view_model.dart';
import 'package:myworkhourstracker/work_session.dart';
import 'package:myworkhourstracker/main.dart';

// Note: use real view model via `JobProfileCalendarViewModel.create`

void main() {
  test('performDeleteFinalizedWorkSession uses injected DB and refreshes slices', () async {
    // Arrange: fake DB that records calls
    int? deletedId;
    deleteFinalizedWorkSessionFn = (int id) async {
      deletedId = id;
      return 1;
    };

    final JobProfile profile = JobProfile(id: 1, name: 'test', payRate: 0.0, payPeriod: PayPeriod.daily, overtimePaid: false);
    final JobProfileCalendarSection fakeSection = JobProfileCalendarSection(profile: profile, appSettings: AppSettings.fallback);

    final DateTime day = DateTime(2024, 1, 1);

    // Create a real view model that loads our single session
    final WorkSession session = WorkSession(id: 42, jobProfileId: 1, sessionDate: day);
    final JobProfileCalendarViewModel viewModel = await JobProfileCalendarViewModel.create(
      profile: profile,
      sessionsLoader: (int profileId) async => <WorkSession>[session],
    );

    // Act
    final List<JobProfileCalendarSlice> updated = await performDeleteFinalizedWorkSession(42, fakeSection, viewModel, day);

    // Assert
    expect(deletedId, 42);
    expect(updated, isA<List<JobProfileCalendarSlice>>());
  });
}
