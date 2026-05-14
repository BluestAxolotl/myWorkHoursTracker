import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myworkhourstracker/job_profile.dart';
import 'package:myworkhourstracker/job_profile_calendar_section.dart';
import 'package:myworkhourstracker/job_profile_details_page.dart';
import 'package:myworkhourstracker/main.dart';
import 'package:myworkhourstracker/work_session.dart';

void main() {
  testWidgets('current work session label updates for the active profile only', (
    WidgetTester tester,
  ) async {
    final JobProfile profileWithDraft = JobProfile(
      id: 1,
      name: 'Profile A',
      payRate: 18.00,
      payPeriod: PayPeriod.weekly,
      overtimePaid: false,
    );
    final JobProfile profileWithoutDraft = JobProfile(
      id: 2,
      name: 'Profile B',
      payRate: 20.00,
      payPeriod: PayPeriod.weekly,
      overtimePaid: false,
    );

    final ValueNotifier<bool> showDraftProfile = ValueNotifier<bool>(true);

    Future<bool> loadDraftState(int profileId) async {
      return profileId == profileWithDraft.id;
    }

    const AppSettings testSettings = AppSettings(
      dateFormat: 'MM/DD/YYYY',
      timeFormat: '12 hr',
      currencySymbol: r'$',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: showDraftProfile,
          builder: (BuildContext context, bool showingDraftProfile, Widget? _) {
            return Scaffold(
              body: SingleChildScrollView(
                child: JobProfileLongForm(
                  profile: showingDraftProfile
                      ? profileWithDraft
                      : profileWithoutDraft,
                  hasOpenDraftLoader: loadDraftState,
                  totalsSessionsLoader: (_) async => <WorkSession>[],
                  appSettings: testSettings,
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Edit Current Work Session'), findsOneWidget);

    showDraftProfile.value = false;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Create Current Work Session'), findsOneWidget);
    expect(find.text('Edit Current Work Session'), findsNothing);
  });

  testWidgets('calendar refreshes when the refresh token changes', (
    WidgetTester tester,
  ) async {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Profile A',
      payRate: 18.00,
      payPeriod: PayPeriod.weekly,
      overtimePaid: false,
    );

    final DateTime now = DateTime(2026, 5, 10);
    bool includeSession = false;
    int loadCount = 0;
    int refreshToken = 0;

    Future<List<WorkSession>> loadSessions(int profileId) async {
      loadCount++;
      if (!includeSession) {
        return <WorkSession>[];
      }

      return <WorkSession>[
        WorkSession(
          jobProfileId: profileId,
          sessionDate: DateTime(2026, 5, 15),
          clockInTime: '08:00',
          clockOutTime: '09:00',
        ),
      ];
    }

    const AppSettings testSettings = AppSettings(
      dateFormat: 'MM/DD/YYYY',
      timeFormat: '12 hr',
      currencySymbol: r'$',
    );

    Widget buildCalendar() {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: JobProfileCalendarSection(
              profile: profile,
              appSettings: testSettings,
              sessionsLoader: loadSessions,
              sessionRefreshToken: refreshToken,
              now: now,
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildCalendar());
    await tester.pumpAndSettle();
    final int initialLoadCount = loadCount;

    includeSession = true;
    refreshToken++;
    await tester.pumpWidget(buildCalendar());
    await tester.pumpAndSettle();

    expect(loadCount, greaterThan(initialLoadCount));

    await tester.tap(find.text('Monthly').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('15').first);
    await tester.pumpAndSettle();

    expect(find.text('8:00 AM - 9:00 AM'), findsOneWidget);
  });

}