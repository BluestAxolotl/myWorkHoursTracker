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
                  now: DateTime(2026, 5, 10),
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

  testWidgets('totals pay period updates when the profile pay period changes', (
    WidgetTester tester,
  ) async {
    final JobProfile weeklyProfile = JobProfile(
      id: 1,
      name: 'Profile A',
      payRate: 18.00,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: false,
    );
    final JobProfile biweeklyProfile = weeklyProfile.copyWith(
      payPeriod: PayPeriod.biweekly,
    );

    final ValueNotifier<JobProfile> activeProfile = ValueNotifier<JobProfile>(weeklyProfile);

    Future<List<WorkSession>> loadSessions(int profileId) async {
      return <WorkSession>[
        WorkSession(
          jobProfileId: profileId,
          sessionDate: DateTime(2026, 5, 9),
          clockInTime: '08:00',
          clockOutTime: '10:00',
        ),
      ];
    }

    const AppSettings testSettings = AppSettings(
      dateFormat: 'MM/DD/YYYY',
      timeFormat: '12 hr',
      currencySymbol: r'$',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<JobProfile>(
          valueListenable: activeProfile,
          builder: (BuildContext context, JobProfile profile, Widget? _) {
            return Scaffold(
              body: SingleChildScrollView(
                child: JobProfileLongForm(
                  profile: profile,
                  totalsSessionsLoader: loadSessions,
                  now: DateTime(2026, 5, 10),
                  appSettings: testSettings,
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    final Finder totalsCard = find.widgetWithText(Card, 'Totals');
    expect(
      find.descendant(
        of: totalsCard,
        matching: find.text('Pay period: 05/09/2026 - 05/15/2026'),
      ),
      findsOneWidget,
    );

    activeProfile.value = biweeklyProfile;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: totalsCard,
        matching: find.text('Pay period: 05/02/2026 - 05/15/2026'),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: totalsCard, matching: find.text('Search by date')),
    );
    await tester.pumpAndSettle();

    expect(find.text('05/02/2026 - 05/15/2026 (Current)'), findsWidgets);
    expect(find.text('05/09/2026 - 05/15/2026 (Current)'), findsNothing);

    await tester.tap(find.text('05/02/2026 - 05/15/2026 (Current)').first);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: totalsCard,
        matching: find.text('Pay period: 05/02/2026 - 05/15/2026'),
      ),
      findsOneWidget,
    );
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

  testWidgets('graph card defaults to pay period and switches modes', (
    WidgetTester tester,
  ) async {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Profile A',
      payRate: 10.00,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: true,
      overtimeMode: OvertimeMode.daily,
      overtimeThresholdHours: 8,
      overtimeMultiplier: 1.5,
    );

    Future<List<WorkSession>> loadSessions(int profileId) async {
      return <WorkSession>[
        WorkSession(
          jobProfileId: profileId,
          sessionDate: DateTime(2026, 5, 2),
          clockInTime: '09:00',
          clockOutTime: '19:00',
        ),
        WorkSession(
          jobProfileId: profileId,
          sessionDate: DateTime(2026, 5, 9),
          clockInTime: '08:00',
          clockOutTime: '20:00',
        ),
      ];
    }

    const AppSettings testSettings = AppSettings(
      dateFormat: 'MM/DD/YYYY',
      timeFormat: '12 hr',
      currencySymbol: r'$',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: JobProfileLongForm(
              profile: profile,
              totalsSessionsLoader: loadSessions,
              now: DateTime(2026, 5, 10),
              appSettings: testSettings,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final Finder graphCard = find.widgetWithText(Card, 'Hours & earnings graph');
    expect(graphCard, findsOneWidget);
    await tester.ensureVisible(graphCard);
    expect(
      find.descendant(of: graphCard, matching: find.text('Pay period trend')),
      findsOneWidget,
    );

    await tester.tap(find.descendant(of: graphCard, matching: find.text('Monthly')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: graphCard, matching: find.textContaining('Monthly trend')),
      findsOneWidget,
    );

    await tester.tap(find.descendant(of: graphCard, matching: find.text('Yearly')));
    await tester.pumpAndSettle();

    expect(find.descendant(of: graphCard, matching: find.text('Yearly trend')), findsOneWidget);
  });

  testWidgets('graph point tap shows a detail box', (
    WidgetTester tester,
  ) async {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Profile A',
      payRate: 10.00,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: true,
      overtimeMode: OvertimeMode.daily,
      overtimeThresholdHours: 8,
      overtimeMultiplier: 1.5,
    );

    Future<List<WorkSession>> loadSessions(int profileId) async {
      return <WorkSession>[
        WorkSession(
          jobProfileId: profileId,
          sessionDate: DateTime(2026, 5, 2),
          clockInTime: '09:00',
          clockOutTime: '19:00',
        ),
        WorkSession(
          jobProfileId: profileId,
          sessionDate: DateTime(2026, 5, 9),
          clockInTime: '08:00',
          clockOutTime: '20:00',
        ),
      ];
    }

    const AppSettings testSettings = AppSettings(
      dateFormat: 'MM/DD/YYYY',
      timeFormat: '12 hr',
      currencySymbol: r'$',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: JobProfileLongForm(
              profile: profile,
              totalsSessionsLoader: loadSessions,
              now: DateTime(2026, 5, 10),
              appSettings: testSettings,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final Finder graphCard = find.widgetWithText(Card, 'Hours & earnings graph');
    expect(graphCard, findsOneWidget);
    await tester.ensureVisible(graphCard);

    final Finder chart = find.byKey(const ValueKey('job-profile-graph-chart'));
    expect(chart, findsOneWidget);

    final Rect chartRect = tester.getRect(chart);
    await tester.tapAt(Offset(chartRect.left + 20, chartRect.top + 72));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('job-profile-graph-detail-box')), findsOneWidget);
    expect(find.textContaining('Regular hours: 8.00h'), findsOneWidget);
    expect(find.textContaining('Overtime hours: 4.00h'), findsOneWidget);
    expect(find.textContaining('Total pay: \$140.00'), findsOneWidget);
  });

}