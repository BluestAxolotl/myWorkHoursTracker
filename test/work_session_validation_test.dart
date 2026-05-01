import 'package:flutter_test/flutter_test.dart';
import 'package:myworkhourstracker/work_session.dart';
import 'package:myworkhourstracker/work_session_validation.dart';

WorkSession _session({
  required DateTime date,
  required String clockIn,
  required String clockOut,
  int breakCount = 0,
  bool hasLunch = false,
  String? break1Start,
  String? break1End,
  String? lunchStart,
  String? lunchEnd,
  String note = '',
}) {
  return WorkSession(
    jobProfileId: 1,
    sessionDate: date,
    clockInTime: clockIn,
    clockOutTime: clockOut,
    breakCount: breakCount,
    hasLunch: hasLunch,
    break1StartTime: break1Start,
    break1EndTime: break1End,
    lunchStartTime: lunchStart,
    lunchEndTime: lunchEnd,
    note: note,
  );
}

void main() {
  test('required fields validation ignores optional lunch and breaks', () {
    final WorkSession session = _session(
      date: DateTime(2026, 4, 25),
      clockIn: '09:00',
      clockOut: '17:00',
    );

    final Map<String, String> errors = WorkSessionValidation.validateRequiredFields(session);

    expect(errors, isEmpty);
  });

  test('internal overlap validation detects break inside clock range and break collision', () {
    final WorkSession session = _session(
      date: DateTime(2026, 4, 25),
      clockIn: '08:00',
      clockOut: '16:00',
      breakCount: 2,
      break1Start: '10:00',
      break1End: '10:15',
    ).copyWith(
      break2StartTime: '10:10',
      break2EndTime: '10:20',
    );

    final Map<String, String> errors = WorkSessionValidation.validateInternalOverlaps(session);

    expect(errors['break1StartTime'], 'This time overlaps with break 2');
  });

  test('internal overlap validation detects lunch outside the session range', () {
    final WorkSession session = _session(
      date: DateTime(2026, 4, 25),
      clockIn: '08:00',
      clockOut: '12:00',
      hasLunch: true,
      lunchStart: '12:10',
      lunchEnd: '12:30',
    );

    final Map<String, String> errors = WorkSessionValidation.validateInternalOverlaps(session);

    expect(errors['lunchStartTime'], 'This time overlaps with clock-in/clock-out');
  });

  test('existing session validation detects overlap across dates', () {
    final WorkSession current = _session(
      date: DateTime(2026, 4, 25),
      clockIn: '22:30',
      clockOut: '01:30',
    );
    final WorkSession existing = _session(
      date: DateTime(2026, 4, 26),
      clockIn: '00:15',
      clockOut: '03:00',
    );

    final Map<String, String> errors = WorkSessionValidation.validateAgainstExistingSessions(
      current,
      <WorkSession>[existing],
    );

    expect(errors['clockInTime'], 'This time overlaps with existing work session');
    expect(errors['clockOutTime'], 'This time overlaps with existing work session');
  });
}