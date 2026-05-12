import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myworkhourstracker/job_profile.dart';
import 'package:myworkhourstracker/job_profile_calendar_section.dart';
import 'package:myworkhourstracker/main.dart';
import 'package:myworkhourstracker/work_session.dart';

void main() {
  testWidgets('calendar section shows pay period and resets to current period on view change', (
    WidgetTester tester,
  ) async {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Profile A',
      payRate: 18.00,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: false,
    );

    final DateTime now = DateTime(2026, 5, 10);

    Future<List<WorkSession>> loadSessions(int profileId) async {
      return <WorkSession>[
        WorkSession(
          jobProfileId: profileId,
          sessionDate: DateTime(2026, 5, 9),
          clockInTime: '20:00',
          clockOutTime: '06:00',
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
            child: JobProfileCalendarSection(
              profile: profile,
              appSettings: testSettings,
              sessionsLoader: loadSessions,
              now: now,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Pay period: 05/09/2026 - 05/15/2026'), findsOneWidget);

    await tester.tap(find.text('Monthly').last);
    await tester.pumpAndSettle();
    expect(find.text('Month: May 2026'), findsOneWidget);

    await tester.tap(find.text('Yearly').last);
    await tester.pumpAndSettle();
    expect(find.text('Year: 2026'), findsOneWidget);

    await tester.tap(find.text('Daily').last);
    await tester.pumpAndSettle();
    expect(find.text('Day: 05/10/2026'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('Day: 05/11/2026'), findsOneWidget);

    await tester.tap(find.text('Daily').last);
    await tester.pumpAndSettle();
    expect(find.text('Day: 05/10/2026'), findsOneWidget);
  });

  testWidgets('calendar section shows a loading indicator before sessions load', (
    WidgetTester tester,
  ) async {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Profile A',
      payRate: 18.00,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: false,
    );

    final Completer<List<WorkSession>> completer = Completer<List<WorkSession>>();

    Future<List<WorkSession>> loadSessions(int profileId) {
      return completer.future;
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
            child: JobProfileCalendarSection(
              profile: profile,
              appSettings: testSettings,
              sessionsLoader: loadSessions,
              now: DateTime(2026, 5, 10),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(<WorkSession>[]);
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsOneWidget);
  });

  testWidgets('calendar section shows a loading indicator when switching to yearly mode', (
    WidgetTester tester,
  ) async {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Profile A',
      payRate: 18.00,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: false,
    );

    Future<List<WorkSession>> loadSessions(int profileId) async {
      return <WorkSession>[];
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
            child: JobProfileCalendarSection(
              profile: profile,
              appSettings: testSettings,
              sessionsLoader: loadSessions,
              now: DateTime(2026, 5, 10),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Yearly').last);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Year: 2026'), findsOneWidget);
  });

  testWidgets('calendar day detail uses the app time format setting', (
    WidgetTester tester,
  ) async {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Profile A',
      payRate: 18.00,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: false,
    );

    Future<List<WorkSession>> loadSessions(int profileId) async {
      return <WorkSession>[
        WorkSession(
          jobProfileId: profileId,
          sessionDate: DateTime(2026, 5, 9),
          clockInTime: '20:00',
          clockOutTime: '06:00',
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
            child: JobProfileCalendarSection(
              profile: profile,
              appSettings: testSettings,
              sessionsLoader: loadSessions,
              now: DateTime(2026, 5, 10),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('9').last);
    await tester.pumpAndSettle();

    expect(find.text('8:00 PM - 6:00 AM'), findsOneWidget);
    expect(find.text('20:00 - 06:00'), findsNothing);
  });

  testWidgets('multi-day sessions are colored on all affected days', (
    WidgetTester tester,
  ) async {
    const JobProfile profile = JobProfile(
      id: 1,
      name: 'Profile A',
      payRate: 18.00,
      payPeriod: PayPeriod.weekly,
      payPeriodEndDayOfWeek: Weekday.fri,
      overtimePaid: false,
    );

    Future<List<WorkSession>> loadSessions(int profileId) async {
      return <WorkSession>[
        WorkSession(
          jobProfileId: profileId,
          sessionDate: DateTime(2026, 5, 9),
          clockInTime: '20:00',
          clockOutTime: '06:00',
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
            child: JobProfileCalendarSection(
              profile: profile,
              appSettings: testSettings,
              sessionsLoader: loadSessions,
              now: DateTime(2026, 5, 10),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Monthly').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('9').first);
    await tester.pumpAndSettle();
    expect(find.text('8:00 PM - 6:00 AM'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.tap(find.text('10').first);
    await tester.pumpAndSettle();
    expect(find.text('8:00 PM - 6:00 AM'), findsOneWidget);
  });
}
