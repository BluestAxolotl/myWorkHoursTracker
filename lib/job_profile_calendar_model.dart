import 'job_profile.dart';
import 'work_session.dart';

enum JobProfileCalendarViewMode { payPeriod, daily, monthly, yearly }

class JobProfileCalendarSlice {
  const JobProfileCalendarSlice({
    required this.session,
    required this.day,
    required this.isStartDay,
    required this.totalHours,
    required this.isOvertime,
  });

  final WorkSession session;
  final DateTime day;
  final bool isStartDay;
  final double totalHours;
  final bool isOvertime;
}

Map<String, List<JobProfileCalendarSlice>> buildCalendarSlicesByDay(
  JobProfile profile,
  Iterable<WorkSession> sessions,
) {
  final Map<String, List<JobProfileCalendarSlice>> slicesByDay = <String, List<JobProfileCalendarSlice>>{};
  final List<WorkSession> sortedSessions = List<WorkSession>.from(sessions)
    ..sort((WorkSession a, WorkSession b) {
      final int dateCompare = a.sessionDate.compareTo(b.sessionDate);
      if (dateCompare != 0) {
        return dateCompare;
      }
      final int? aStart = parseMinutes(a.clockInTime);
      final int? bStart = parseMinutes(b.clockInTime);
      if (aStart != null && bStart != null && aStart != bStart) {
        return aStart.compareTo(bStart);
      }
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });

  for (final WorkSession session in sortedSessions) {
    final DateTime start = dateOnly(session.sessionDate);
    final DateTime end = sessionEndDate(session);
    final double totalHours = session.totalWorkHours ?? 0;
    final bool isOvertime = isDailyOvertimeSession(profile, session);
    DateTime day = start;
    while (!day.isAfter(end)) {
      final JobProfileCalendarSlice slice = JobProfileCalendarSlice(
        session: session,
        day: day,
        isStartDay: _sameDay(day, start),
        totalHours: totalHours,
        isOvertime: isOvertime,
      );
      slicesByDay.putIfAbsent(dateKey(day), () => <JobProfileCalendarSlice>[]).add(slice);
      day = day.add(const Duration(days: 1));
    }
  }

  return slicesByDay;
}

bool isDailyOvertimeSession(JobProfile profile, WorkSession session) {
  if (!profile.overtimePaid || profile.overtimeMode != OvertimeMode.daily) {
    return false;
  }

  final int? thresholdHours = profile.overtimeThresholdHours;
  final double? totalHours = session.totalWorkHours;
  if (thresholdHours == null || totalHours == null) {
    return false;
  }

  return totalHours > thresholdHours;
}

DateTime sessionEndDate(WorkSession session) {
  final DateTime start = dateOnly(session.sessionDate);
  final int? clockInMinutes = parseMinutes(session.clockInTime);
  final int? clockOutMinutes = parseMinutes(session.clockOutTime);
  if (clockInMinutes == null || clockOutMinutes == null) {
    return start;
  }
  return clockOutMinutes <= clockInMinutes ? start.add(const Duration(days: 1)) : start;
}

DateTime startOfWeek(DateTime date) {
  final DateTime day = dateOnly(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime endOfWeek(DateTime date) {
  return startOfWeek(date).add(const Duration(days: 6));
}

List<DateTime> daysInRange(DateTime start, DateTime end) {
  final List<DateTime> days = <DateTime>[];
  DateTime current = dateOnly(start);
  final DateTime last = dateOnly(end);
  while (!current.isAfter(last)) {
    days.add(current);
    current = current.add(const Duration(days: 1));
  }
  return days;
}

String dateKey(DateTime date) {
  final DateTime day = dateOnly(date);
  return '${day.year}-${day.month}-${day.day}';
}

DateTime dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}