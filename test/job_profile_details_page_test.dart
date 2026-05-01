import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myworkhourstracker/job_profile.dart';
import 'package:myworkhourstracker/job_profile_details_page.dart';
import 'package:myworkhourstracker/main.dart';

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
              body: JobProfileLongForm(
                profile: showingDraftProfile
                    ? profileWithDraft
                    : profileWithoutDraft,
                hasOpenDraftLoader: loadDraftState,
                appSettings: testSettings,
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
}