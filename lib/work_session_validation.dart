import 'work_session.dart';

const int _maxNoteLength = 200;

class WorkSessionValidation {
  static Map<String, String> validateRequiredFields(WorkSession session) {
    final Map<String, String> errors = <String, String>{};

    if (session.clockInTime == null) {
      errors['clockInTime'] = 'Required';
    }
    if (session.clockOutTime == null) {
      errors['clockOutTime'] = 'Required';
    }

    for (int i = 1; i <= session.breakCount; i++) {
      final String? breakStart = _valueByKey(session, 'break${i}StartTime');
      final String? breakEnd = _valueByKey(session, 'break${i}EndTime');
      if (breakStart == null) {
        errors['break${i}StartTime'] = 'Required';
      }
      if (breakEnd == null) {
        errors['break${i}EndTime'] = 'Required';
      }
    }

    if (session.hasLunch) {
      if (session.lunchStartTime == null) {
        errors['lunchStartTime'] = 'Required';
      }
      if (session.lunchEndTime == null) {
        errors['lunchEndTime'] = 'Required';
      }
    }

    if (session.note.length > _maxNoteLength) {
      errors['note'] = 'Note must be 200 characters or fewer';
    }

    return errors;
  }

  static Map<String, String> validateInternalOverlaps(WorkSession session) {
    final Map<String, String> errors = <String, String>{};
    final int? clockIn = parseMinutes(session.clockInTime);
    final int? clockOutRaw = parseMinutes(session.clockOutTime);
    if (clockIn == null || clockOutRaw == null) {
      return errors;
    }

    int clockOut = clockOutRaw;
    if (clockOut <= clockIn) {
      clockOut += minutesInDay;
    }

    final List<_ValidationInterval> intervals = <_ValidationInterval>[];

    for (int i = 1; i <= session.breakCount; i++) {
      final String startKey = 'break${i}StartTime';
      final String endKey = 'break${i}EndTime';
      final int? start = parseMinutes(_valueByKey(session, startKey));
      final int? end = parseMinutes(_valueByKey(session, endKey));
      if (start == null || end == null) {
        continue;
      }

      final _NormalizedInterval normalized = _normalizeInterval(
        start: start,
        end: end,
        clockIn: clockIn,
      );

      if (normalized.start < clockIn || normalized.end > clockOut) {
        errors[startKey] = 'This time overlaps with clock-in/clock-out';
        errors[endKey] = 'This time overlaps with clock-in/clock-out';
        return errors;
      }

      intervals.add(
        _ValidationInterval(
          start: normalized.start,
          end: normalized.end,
          startField: startKey,
          endField: endKey,
          name: 'break $i',
        ),
      );
    }

    if (session.hasLunch) {
      final int? lunchStart = parseMinutes(session.lunchStartTime);
      final int? lunchEnd = parseMinutes(session.lunchEndTime);
      if (lunchStart != null && lunchEnd != null) {
        final _NormalizedInterval normalized = _normalizeInterval(
          start: lunchStart,
          end: lunchEnd,
          clockIn: clockIn,
        );

        if (normalized.start < clockIn || normalized.end > clockOut) {
          errors['lunchStartTime'] = 'This time overlaps with clock-in/clock-out';
          errors['lunchEndTime'] = 'This time overlaps with clock-in/clock-out';
          return errors;
        }

        intervals.add(
          _ValidationInterval(
            start: normalized.start,
            end: normalized.end,
            startField: 'lunchStartTime',
            endField: 'lunchEndTime',
            name: 'lunch',
          ),
        );
      }
    }

    for (int i = 0; i < intervals.length; i++) {
      for (int j = i + 1; j < intervals.length; j++) {
        final _ValidationInterval first = intervals[i];
        final _ValidationInterval second = intervals[j];
        final bool overlaps = first.start < second.end && second.start < first.end;
        if (overlaps) {
          errors[first.startField] = 'This time overlaps with ${second.name}';
          errors[first.endField] = 'This time overlaps with ${second.name}';
          return errors;
        }
      }
    }

    return errors;
  }

  static Map<String, String> validateAgainstExistingSessions(
    WorkSession session,
    Iterable<WorkSession> existingSessions,
  ) {
    final Map<String, String> errors = <String, String>{};
    final int? currentStartRaw = parseMinutes(session.clockInTime);
    final int? currentEndRaw = parseMinutes(session.clockOutTime);

    if (currentStartRaw == null || currentEndRaw == null) {
      return errors;
    }

    final DateTime currentStartDateTime = _combineDateAndMinutes(
      session.sessionDate,
      currentStartRaw,
    );
    DateTime currentEndDateTime = _combineDateAndMinutes(
      session.sessionDate,
      currentEndRaw,
    );
    if (!currentEndDateTime.isAfter(currentStartDateTime)) {
      currentEndDateTime = currentEndDateTime.add(const Duration(days: 1));
    }

    for (final WorkSession existing in existingSessions) {
      final int? existingStartRaw = parseMinutes(existing.clockInTime);
      final int? existingEndRaw = parseMinutes(existing.clockOutTime);
      if (existingStartRaw == null || existingEndRaw == null) {
        continue;
      }

      final DateTime existingStart =
          _combineDateAndMinutes(existing.sessionDate, existingStartRaw);
      DateTime existingEnd =
          _combineDateAndMinutes(existing.sessionDate, existingEndRaw);
      if (!existingEnd.isAfter(existingStart)) {
        existingEnd = existingEnd.add(const Duration(days: 1));
      }

      final bool overlaps =
          currentStartDateTime.isBefore(existingEnd) &&
          existingStart.isBefore(currentEndDateTime);
      if (overlaps) {
        errors['clockInTime'] = 'This time overlaps with existing work session';
        errors['clockOutTime'] = 'This time overlaps with existing work session';
        return errors;
      }
    }

    return errors;
  }

  static String? _valueByKey(WorkSession session, String key) {
    switch (key) {
      case 'clockInTime':
        return session.clockInTime;
      case 'clockOutTime':
        return session.clockOutTime;
      case 'break1StartTime':
        return session.break1StartTime;
      case 'break1EndTime':
        return session.break1EndTime;
      case 'break2StartTime':
        return session.break2StartTime;
      case 'break2EndTime':
        return session.break2EndTime;
      case 'break3StartTime':
        return session.break3StartTime;
      case 'break3EndTime':
        return session.break3EndTime;
      case 'break4StartTime':
        return session.break4StartTime;
      case 'break4EndTime':
        return session.break4EndTime;
      case 'break5StartTime':
        return session.break5StartTime;
      case 'break5EndTime':
        return session.break5EndTime;
      case 'lunchStartTime':
        return session.lunchStartTime;
      case 'lunchEndTime':
        return session.lunchEndTime;
      default:
        return null;
    }
  }

  static _NormalizedInterval _normalizeInterval({
    required int start,
    required int end,
    required int clockIn,
  }) {
    int normalizedStart = start;
    int normalizedEnd = end;
    if (normalizedStart < clockIn) {
      normalizedStart += minutesInDay;
    }
    if (normalizedEnd < clockIn) {
      normalizedEnd += minutesInDay;
    }
    if (normalizedEnd <= normalizedStart) {
      normalizedEnd += minutesInDay;
    }
    return _NormalizedInterval(start: normalizedStart, end: normalizedEnd);
  }

  static DateTime _combineDateAndMinutes(DateTime date, int minutes) {
    final int hours = minutes ~/ 60;
    final int remainderMinutes = minutes % 60;
    return DateTime(
      date.year,
      date.month,
      date.day,
      hours,
      remainderMinutes,
    );
  }
}

class _ValidationInterval {
  const _ValidationInterval({
    required this.start,
    required this.end,
    required this.startField,
    required this.endField,
    required this.name,
  });

  final int start;
  final int end;
  final String startField;
  final String endField;
  final String name;
}

class _NormalizedInterval {
  const _NormalizedInterval({required this.start, required this.end});

  final int start;
  final int end;
}