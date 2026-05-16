import 'package:flutter/material.dart';

import 'job_profile.dart';
import 'job_profile_calendar_model.dart';
import 'job_profile_database.dart';
import 'job_profile_totals_view_model.dart';
import 'work_session.dart';

class JobProfileCalendarViewModel extends ChangeNotifier {
  JobProfileCalendarViewModel._({
    required this.profile,
    required DateTime now,
    required List<WorkSession> sessions,
    JobProfileDatabase? database,
    Future<List<WorkSession>> Function(int profileId)? sessionsLoader,
  })  : _today = dateOnly(now),
        _referenceDate = dateOnly(now),
        _selectedDateByMode = <JobProfileCalendarViewMode, DateTime>{
          JobProfileCalendarViewMode.payPeriod: dateOnly(now),
          JobProfileCalendarViewMode.daily: dateOnly(now),
          JobProfileCalendarViewMode.monthly: DateTime(now.year, now.month, 1),
          JobProfileCalendarViewMode.yearly: DateTime(now.year, 1, 1),
        },
        _sessions = sessions,
        _database = database,
        _sessionsLoader = sessionsLoader;

  final JobProfile profile;
  DateTime _today;
  DateTime _referenceDate;
  final Map<JobProfileCalendarViewMode, DateTime> _selectedDateByMode;
  final List<WorkSession> _sessions;
  final JobProfileDatabase? _database;
  final Future<List<WorkSession>> Function(int profileId)? _sessionsLoader;

  JobProfileCalendarViewMode _viewMode = JobProfileCalendarViewMode.payPeriod;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  JobProfileCalendarViewMode get viewMode => _viewMode;

  DateTime get currentDay => _today;

  DateTime get referenceDate => _referenceDate;

  List<WorkSession> get sessions => _sessions;

  PeriodWindow get payPeriodWindow => JobProfileTotalsCalculator.currentPayPeriodWindow(
        profile,
        _referenceDate,
      );

  DateTime get visibleRangeStart {
    switch (_viewMode) {
      case JobProfileCalendarViewMode.payPeriod:
        return payPeriodWindow.start;
      case JobProfileCalendarViewMode.daily:
        return _referenceDate;
      case JobProfileCalendarViewMode.monthly:
        return DateTime(_referenceDate.year, _referenceDate.month, 1);
      case JobProfileCalendarViewMode.yearly:
        return DateTime(_referenceDate.year, 1, 1);
    }
  }

  DateTime get visibleRangeEnd {
    switch (_viewMode) {
      case JobProfileCalendarViewMode.payPeriod:
        return payPeriodWindow.end;
      case JobProfileCalendarViewMode.daily:
        return _referenceDate;
      case JobProfileCalendarViewMode.monthly:
        return DateTime(_referenceDate.year, _referenceDate.month + 1, 0);
      case JobProfileCalendarViewMode.yearly:
        return DateTime(_referenceDate.year, 12, 31);
    }
  }

  DateTime get gridStart => startOfWeek(visibleRangeStart);

  DateTime get gridEnd => endOfWeek(visibleRangeEnd);

  bool get isYearlyView => _viewMode == JobProfileCalendarViewMode.yearly;

  bool get isDailyView => _viewMode == JobProfileCalendarViewMode.daily;

  Map<String, List<JobProfileCalendarSlice>> get slicesByDay => buildCalendarSlicesByDay(profile, _sessions);

  List<DateTime> get gridDays => daysInRange(gridStart, gridEnd);

  static Future<JobProfileCalendarViewModel> create({
    required JobProfile profile,
    DateTime? now,
    JobProfileDatabase? database,
    Future<List<WorkSession>> Function(int profileId)? sessionsLoader,
  }) async {
    final DateTime resolvedNow = dateOnly(now ?? DateTime.now());
    final int? profileId = profile.id;
    final List<WorkSession> sessions;

    if (profileId == null) {
      sessions = <WorkSession>[];
    } else if (sessionsLoader != null) {
      sessions = await sessionsLoader(profileId);
    } else {
      final JobProfileDatabase db = database ?? JobProfileDatabase.instance;
      sessions = await db.getFinalizedWorkSessionsForProfile(profileId);
    }

    return JobProfileCalendarViewModel._(
      profile: profile,
      now: resolvedNow,
      sessions: sessions,
      database: database,
      sessionsLoader: sessionsLoader,
    );
  }

  void setViewMode(JobProfileCalendarViewMode value) {
    if (_viewMode == value) {
      return;
    }
    _viewMode = value;
    final DateTime normalized = _normalizeForView(value, _today);
    _selectedDateByMode[value] = normalized;
    _referenceDate = normalized;
    notifyListeners();
  }

  void resetCurrentViewToToday() {
    final DateTime normalized = _normalizeForView(_viewMode, _today);
    _selectedDateByMode[_viewMode] = normalized;
    if (_sameDay(_referenceDate, normalized)) {
      return;
    }
    _referenceDate = normalized;
    notifyListeners();
  }

  void selectDateForCurrentView(DateTime date) {
    final DateTime normalized = _normalizeForView(_viewMode, dateOnly(date));
    if (_sameDay(_referenceDate, normalized)) {
      return;
    }

    _selectedDateByMode[_viewMode] = normalized;
    _referenceDate = normalized;
    notifyListeners();
  }

  void moveToPreviousPeriod() {
    _movePeriod(-1);
  }

  void moveToNextPeriod() {
    _movePeriod(1);
  }

  Future<void> refreshCalendar() async {
    final int? profileId = profile.id;
    if (profileId == null) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final List<WorkSession> newSessions;
      if (_sessionsLoader != null) {
        newSessions = await _sessionsLoader(profileId);
      } else {
        final JobProfileDatabase db = _database ?? JobProfileDatabase.instance;
        newSessions = await db.getFinalizedWorkSessionsForProfile(profileId);
      }

      _sessions
        ..clear()
        ..addAll(newSessions);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateNow(DateTime? now) {
    final DateTime resolvedNow = dateOnly(now ?? DateTime.now());
    if (_today == resolvedNow) {
      return;
    }
    final DateTime previousToday = _today;
    _today = resolvedNow;

    for (final JobProfileCalendarViewMode mode in JobProfileCalendarViewMode.values) {
      final DateTime? selected = _selectedDateByMode[mode];
      if (selected != null && _sameDay(selected, _normalizeForView(mode, previousToday))) {
        _selectedDateByMode[mode] = _normalizeForView(mode, resolvedNow);
      }
    }

    final DateTime fallback = _normalizeForView(_viewMode, resolvedNow);
    _referenceDate = _selectedDateByMode[_viewMode] ?? fallback;
    notifyListeners();
  }

  DateTime _normalizeForView(JobProfileCalendarViewMode mode, DateTime date) {
    switch (mode) {
      case JobProfileCalendarViewMode.payPeriod:
      case JobProfileCalendarViewMode.daily:
        return dateOnly(date);
      case JobProfileCalendarViewMode.monthly:
        return DateTime(date.year, date.month, 1);
      case JobProfileCalendarViewMode.yearly:
        return DateTime(date.year, 1, 1);
    }
  }

  void _movePeriod(int direction) {
    if (direction != -1 && direction != 1) {
      return;
    }

    final DateTime nextDate;
    switch (_viewMode) {
      case JobProfileCalendarViewMode.payPeriod:
        final PeriodWindow window = JobProfileTotalsCalculator.currentPayPeriodWindow(profile, _referenceDate);
        final PeriodWindow movedWindow = direction < 0
            ? JobProfileTotalsCalculator.previousPayPeriodWindow(profile, window)
            : JobProfileTotalsCalculator.nextPayPeriodWindow(profile, window);
        nextDate = movedWindow.end;
      case JobProfileCalendarViewMode.daily:
        nextDate = _referenceDate.add(Duration(days: direction));
      case JobProfileCalendarViewMode.monthly:
        nextDate = DateTime(_referenceDate.year, _referenceDate.month + direction, 1);
      case JobProfileCalendarViewMode.yearly:
        nextDate = DateTime(_referenceDate.year + direction, 1, 1);
    }

    final DateTime normalized = _normalizeForView(_viewMode, dateOnly(nextDate));
    _selectedDateByMode[_viewMode] = normalized;
    _referenceDate = normalized;
    notifyListeners();
  }
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}