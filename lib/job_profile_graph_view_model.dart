import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'job_profile.dart';
import 'job_profile_database.dart';
import 'job_profile_totals_view_model.dart';
import 'work_session.dart';

enum JobProfileGraphViewMode { payPeriod, monthly, yearly }

class JobProfileGraphPoint {
  const JobProfileGraphPoint({
    required this.window,
    required this.summary,
  });

  final PeriodWindow window;
  final JobProfileTotalsSummary summary;
}

class JobProfileGraphViewModel extends ChangeNotifier {
  JobProfileGraphViewModel._({
    required this.profile,
    required DateTime now,
    required List<WorkSession> sessions,
    JobProfileDatabase? database,
    Future<List<WorkSession>> Function(int profileId)? sessionsLoader,
  })  : _today = _dateOnly(now),
        _sessions = sessions,
        _database = database,
        _sessionsLoader = sessionsLoader {
    _recompute();
  }

  final JobProfile profile;
  DateTime _today;
  final List<WorkSession> _sessions;
  final JobProfileDatabase? _database;
  final Future<List<WorkSession>> Function(int profileId)? _sessionsLoader;

  JobProfileGraphViewMode _viewMode = JobProfileGraphViewMode.payPeriod;
  List<JobProfileGraphPoint> _points = <JobProfileGraphPoint>[];

  JobProfileGraphViewMode get viewMode => _viewMode;

  List<JobProfileGraphPoint> get points => _points;

  bool get showOvertimeLine {
    return profile.overtimePaid &&
        profile.overtimeMode != null &&
        profile.overtimeThresholdHours != null &&
        profile.overtimeMultiplier != null;
  }

  static Future<JobProfileGraphViewModel> create({
    required JobProfile profile,
    DateTime? now,
    JobProfileDatabase? database,
    Future<List<WorkSession>> Function(int profileId)? sessionsLoader,
  }) async {
    final DateTime resolvedNow = _dateOnly(now ?? DateTime.now());
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

    return JobProfileGraphViewModel._(
      profile: profile,
      now: resolvedNow,
      sessions: sessions,
      database: database,
      sessionsLoader: sessionsLoader,
    );
  }

  void setViewMode(JobProfileGraphViewMode value) {
    if (_viewMode == value) {
      return;
    }
    _viewMode = value;
    _recompute();
    notifyListeners();
  }

  void updateNow(DateTime? now) {
    final DateTime resolvedNow = _dateOnly(now ?? DateTime.now());
    if (_today == resolvedNow) {
      return;
    }
    _today = resolvedNow;
    _recompute();
    notifyListeners();
  }

  Future<void> refreshSessions() async {
    final int? profileId = profile.id;
    if (profileId == null) {
      return;
    }

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
      _recompute();
      notifyListeners();
    } catch (e) {
      // Keep graph state stable if refresh fails.
    }
  }

  void _recompute() {
    switch (_viewMode) {
      case JobProfileGraphViewMode.payPeriod:
        _points = _buildPayPeriodPoints();
        break;
      case JobProfileGraphViewMode.monthly:
        _points = _buildMonthlyPoints();
        break;
      case JobProfileGraphViewMode.yearly:
        _points = _buildYearlyPoints();
        break;
    }
  }

  List<JobProfileGraphPoint> _buildPayPeriodPoints() {
    final PeriodWindow currentPayPeriod = JobProfileTotalsCalculator.currentPayPeriodWindow(
      profile,
      _today,
    );

    final List<PeriodWindow> days = List<PeriodWindow>.generate(
      currentPayPeriod.end.difference(currentPayPeriod.start).inDays + 1,
      (int index) {
        final DateTime day = currentPayPeriod.start.add(Duration(days: index));
        return PeriodWindow(start: day, end: day);
      },
    );

    return days
        .map(
          (PeriodWindow day) => JobProfileGraphPoint(
            window: day,
            summary: JobProfileTotalsCalculator.calculateForWindow(
              profile: profile,
              sessions: _sessions,
              window: day,
            ),
          ),
        )
        .toList();
  }

  List<JobProfileGraphPoint> _buildMonthlyPoints() {
    final DateTime monthStart = DateTime(_today.year, _today.month, 1);
    final int daysInMonth = DateTime(_today.year, _today.month + 1, 0).day;

    return List<JobProfileGraphPoint>.generate(daysInMonth, (int index) {
      final DateTime day = monthStart.add(Duration(days: index));
      final PeriodWindow window = PeriodWindow(start: day, end: day);
      return JobProfileGraphPoint(
        window: window,
        summary: JobProfileTotalsCalculator.calculateForWindow(
          profile: profile,
          sessions: _sessions,
          window: window,
        ),
      );
    });
  }

  List<JobProfileGraphPoint> _buildYearlyPoints() {
    return List<JobProfileGraphPoint>.generate(12, (int index) {
      final int month = index + 1;
      final DateTime start = DateTime(_today.year, month, 1);
      final DateTime end = DateTime(_today.year, month + 1, 0);
      final PeriodWindow window = PeriodWindow(start: start, end: end);
      return JobProfileGraphPoint(
        window: window,
        summary: JobProfileTotalsCalculator.calculateForWindow(
          profile: profile,
          sessions: _sessions,
          window: window,
        ),
      );
    });
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

String formatGraphPointLabel(
  JobProfileGraphViewMode viewMode,
  JobProfileGraphPoint point,
) {
  switch (viewMode) {
    case JobProfileGraphViewMode.payPeriod:
      return DateFormat('EEE d').format(point.window.start);
    case JobProfileGraphViewMode.monthly:
      return DateFormat('d').format(point.window.start);
    case JobProfileGraphViewMode.yearly:
      return DateFormat('MMM').format(point.window.start);
  }
}