import 'package:flutter/material.dart';

class WorkSession {
  const WorkSession({
    this.id,
    required this.jobProfileId,
    required this.sessionDate,
    this.clockInTime,
    this.clockOutTime,
    this.break1StartTime,
    this.break1EndTime,
    this.break2StartTime,
    this.break2EndTime,
    this.break3StartTime,
    this.break3EndTime,
    this.break4StartTime,
    this.break4EndTime,
    this.break5StartTime,
    this.break5EndTime,
    this.hasLunch = false,
    this.lunchStartTime,
    this.lunchEndTime,
    this.breakCount = 0,
    this.note = '',
  });

  final int? id;
  final int jobProfileId;
  final DateTime sessionDate;
  final String? clockInTime;
  final String? clockOutTime;
  final String? break1StartTime;
  final String? break1EndTime;
  final String? break2StartTime;
  final String? break2EndTime;
  final String? break3StartTime;
  final String? break3EndTime;
  final String? break4StartTime;
  final String? break4EndTime;
  final String? break5StartTime;
  final String? break5EndTime;
  final bool hasLunch;
  final String? lunchStartTime;
  final String? lunchEndTime;
  final int breakCount;
  final String note;

  static WorkSession emptyForJobProfile(int jobProfileId) {
    final DateTime now = DateTime.now();
    return WorkSession(
      jobProfileId: jobProfileId,
      sessionDate: DateTime(now.year, now.month, now.day),
    );
  }

  WorkSession copyWith({
    int? id,
    int? jobProfileId,
    DateTime? sessionDate,
    String? clockInTime,
    String? clockOutTime,
    String? break1StartTime,
    String? break1EndTime,
    String? break2StartTime,
    String? break2EndTime,
    String? break3StartTime,
    String? break3EndTime,
    String? break4StartTime,
    String? break4EndTime,
    String? break5StartTime,
    String? break5EndTime,
    bool? hasLunch,
    String? lunchStartTime,
    String? lunchEndTime,
    int? breakCount,
    String? note,
    bool clearClockInTime = false,
    bool clearClockOutTime = false,
    bool clearBreak1StartTime = false,
    bool clearBreak1EndTime = false,
    bool clearBreak2StartTime = false,
    bool clearBreak2EndTime = false,
    bool clearBreak3StartTime = false,
    bool clearBreak3EndTime = false,
    bool clearBreak4StartTime = false,
    bool clearBreak4EndTime = false,
    bool clearBreak5StartTime = false,
    bool clearBreak5EndTime = false,
    bool clearLunchStartTime = false,
    bool clearLunchEndTime = false,
  }) {
    return WorkSession(
      id: id ?? this.id,
      jobProfileId: jobProfileId ?? this.jobProfileId,
      sessionDate: sessionDate ?? this.sessionDate,
      clockInTime: clearClockInTime ? null : (clockInTime ?? this.clockInTime),
      clockOutTime: clearClockOutTime ? null : (clockOutTime ?? this.clockOutTime),
      break1StartTime: clearBreak1StartTime
          ? null
          : (break1StartTime ?? this.break1StartTime),
      break1EndTime:
          clearBreak1EndTime ? null : (break1EndTime ?? this.break1EndTime),
      break2StartTime: clearBreak2StartTime
          ? null
          : (break2StartTime ?? this.break2StartTime),
      break2EndTime:
          clearBreak2EndTime ? null : (break2EndTime ?? this.break2EndTime),
      break3StartTime: clearBreak3StartTime
          ? null
          : (break3StartTime ?? this.break3StartTime),
      break3EndTime:
          clearBreak3EndTime ? null : (break3EndTime ?? this.break3EndTime),
      break4StartTime: clearBreak4StartTime
          ? null
          : (break4StartTime ?? this.break4StartTime),
      break4EndTime:
          clearBreak4EndTime ? null : (break4EndTime ?? this.break4EndTime),
      break5StartTime: clearBreak5StartTime
          ? null
          : (break5StartTime ?? this.break5StartTime),
      break5EndTime:
          clearBreak5EndTime ? null : (break5EndTime ?? this.break5EndTime),
      hasLunch: hasLunch ?? this.hasLunch,
      lunchStartTime:
          clearLunchStartTime ? null : (lunchStartTime ?? this.lunchStartTime),
      lunchEndTime:
          clearLunchEndTime ? null : (lunchEndTime ?? this.lunchEndTime),
      breakCount: breakCount ?? this.breakCount,
      note: note ?? this.note,
    );
  }

  bool get hasAnyInput {
    return clockInTime != null ||
        clockOutTime != null ||
        break1StartTime != null ||
        break1EndTime != null ||
        break2StartTime != null ||
        break2EndTime != null ||
        break3StartTime != null ||
        break3EndTime != null ||
        break4StartTime != null ||
        break4EndTime != null ||
        break5StartTime != null ||
        break5EndTime != null ||
        lunchStartTime != null ||
        lunchEndTime != null ||
        note.trim().isNotEmpty;
  }

  double? get totalWorkHours {
    final int? clockInMinutes = parseMinutes(clockInTime);
    final int? clockOutMinutes = parseMinutes(clockOutTime);
    if (clockInMinutes == null || clockOutMinutes == null) {
      return null;
    }
    int adjustedClockOutMinutes = clockOutMinutes;
    if (adjustedClockOutMinutes <= clockInMinutes) {
      adjustedClockOutMinutes += minutesInDay;
    }
    int totalDuration = adjustedClockOutMinutes - clockInMinutes;
    for (final TimeRangePair pair in breakPairs) {
      final int? start = parseMinutes(pair.start);
      final int? end = parseMinutes(pair.end);
      if (start == null || end == null) {
        continue;
      }
      int adjustedStart = start;
      int adjustedEnd = end;
      if (adjustedStart < clockInMinutes) {
        adjustedStart += minutesInDay;
      }
      if (adjustedEnd < clockInMinutes) {
        adjustedEnd += minutesInDay;
      }
      if (adjustedEnd <= adjustedStart) {
        adjustedEnd += minutesInDay;
      }
      totalDuration -= (adjustedEnd - adjustedStart);
    }

    if (hasLunch) {
      final int? lunchStart = parseMinutes(lunchStartTime);
      final int? lunchEnd = parseMinutes(lunchEndTime);
      if (lunchStart != null && lunchEnd != null) {
        int adjustedLunchStart = lunchStart;
        int adjustedLunchEnd = lunchEnd;
        if (adjustedLunchStart < clockInMinutes) {
          adjustedLunchStart += minutesInDay;
        }
        if (adjustedLunchEnd < clockInMinutes) {
          adjustedLunchEnd += minutesInDay;
        }
        if (adjustedLunchEnd <= adjustedLunchStart) {
          adjustedLunchEnd += minutesInDay;
        }
        totalDuration -= (adjustedLunchEnd - adjustedLunchStart);
      }
    }

    return totalDuration / 60.0;
  }

  List<TimeRangePair> get breakPairs {
    return <TimeRangePair>[
      TimeRangePair(start: break1StartTime, end: break1EndTime),
      TimeRangePair(start: break2StartTime, end: break2EndTime),
      TimeRangePair(start: break3StartTime, end: break3EndTime),
      TimeRangePair(start: break4StartTime, end: break4EndTime),
      TimeRangePair(start: break5StartTime, end: break5EndTime),
    ].sublist(0, breakCount.clamp(0, 5));
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'job_profile_id': jobProfileId,
      'session_date': formatDateOnly(sessionDate),
      'clock_in_time': clockInTime,
      'clock_out_time': clockOutTime,
      'break_count': breakCount,
      'break1_start_time': break1StartTime,
      'break1_end_time': break1EndTime,
      'break2_start_time': break2StartTime,
      'break2_end_time': break2EndTime,
      'break3_start_time': break3StartTime,
      'break3_end_time': break3EndTime,
      'break4_start_time': break4StartTime,
      'break4_end_time': break4EndTime,
      'break5_start_time': break5StartTime,
      'break5_end_time': break5EndTime,
      'has_lunch': hasLunch ? 1 : 0,
      'lunch_start_time': lunchStartTime,
      'lunch_end_time': lunchEndTime,
      'note': note,
    };
  }

  static WorkSession fromMap(Map<String, Object?> map) {
    return WorkSession(
      id: map['id'] as int?,
      jobProfileId: map['job_profile_id'] as int,
      sessionDate: parseDateOnly((map['session_date'] ?? '').toString()),
      clockInTime: map['clock_in_time'] as String?,
      clockOutTime: map['clock_out_time'] as String?,
      breakCount: (map['break_count'] as int? ?? 0).clamp(0, 5),
      break1StartTime: map['break1_start_time'] as String?,
      break1EndTime: map['break1_end_time'] as String?,
      break2StartTime: map['break2_start_time'] as String?,
      break2EndTime: map['break2_end_time'] as String?,
      break3StartTime: map['break3_start_time'] as String?,
      break3EndTime: map['break3_end_time'] as String?,
      break4StartTime: map['break4_start_time'] as String?,
      break4EndTime: map['break4_end_time'] as String?,
      break5StartTime: map['break5_start_time'] as String?,
      break5EndTime: map['break5_end_time'] as String?,
      hasLunch: (map['has_lunch'] as int? ?? 0) == 1,
      lunchStartTime: map['lunch_start_time'] as String?,
      lunchEndTime: map['lunch_end_time'] as String?,
      note: (map['note'] as String?) ?? '',
    );
  }
}

class TimeRangePair {
  const TimeRangePair({required this.start, required this.end});

  final String? start;
  final String? end;
}

const int minutesInDay = 1440;

String formatDateOnly(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String formatDateWithSetting(DateTime date, String dateFormat) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  final String year = date.year.toString();
  final String yearFull = date.year.toString().padLeft(4, '0');

  switch (dateFormat) {
    case 'MM/DD/YYYY':
      return '$month/$day/$year';
    case 'DD/MM/YYYY':
      return '$day/$month/$year';
    case 'YYYY-MM-DD':
      return '$yearFull-$month-$day';
    default:
      return '$month/$day/$year';
  }
}

DateTime parseDateOnly(String raw) {
  if (raw.isEmpty) {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
  final DateTime parsed = DateTime.tryParse(raw) ?? DateTime.now();
  return DateTime(parsed.year, parsed.month, parsed.day);
}

int? parseMinutes(String? hhmm) {
  if (hhmm == null || hhmm.trim().isEmpty) {
    return null;
  }
  final List<String> parts = hhmm.split(':');
  if (parts.length != 2) {
    return null;
  }
  final int? hour = int.tryParse(parts[0]);
  final int? minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return (hour * 60) + minute;
}

String formatTimeOfDay(TimeOfDay time) {
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

TimeOfDay? parseTimeOfDay(String? value) {
  final int? minutes = parseMinutes(value);
  if (minutes == null) {
    return null;
  }
  final int hour = minutes ~/ 60;
  final int minute = minutes % 60;
  return TimeOfDay(hour: hour, minute: minute);
}

String displayTime(BuildContext context, String? value) {
  final TimeOfDay? parsed = parseTimeOfDay(value);
  if (parsed == null) {
    return '';
  }
  return parsed.format(context);
}

String displayTimeWithSetting(String? value, String timeFormat) {
  final TimeOfDay? parsed = parseTimeOfDay(value);
  if (parsed == null) {
    return '';
  }
  if (timeFormat == '24 hr') {
    final String hour = parsed.hour.toString().padLeft(2, '0');
    final String minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  } else {
    final int hour12 = parsed.hourOfPeriod == 0 ? 12 : parsed.hourOfPeriod;
    final String minute = parsed.minute.toString().padLeft(2, '0');
    final String period = parsed.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }
}