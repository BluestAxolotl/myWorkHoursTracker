import 'dart:math';

import 'package:flutter/material.dart';

import 'job_profile.dart';
import 'job_profile_database.dart';
import 'work_session.dart';

enum TotalsViewMode { payPeriod, yearly }

class JobProfileTotalsSummary {
  const JobProfileTotalsSummary({
    required this.totalHours,
    required this.regularHours,
    required this.overtimeHours,
    required this.regularPay,
    required this.overtimePay,
    required this.totalPay,
    required this.sessionCount,
    required this.periodCount,
  });

  const JobProfileTotalsSummary.empty()
      : totalHours = 0,
        regularHours = 0,
        overtimeHours = 0,
        regularPay = 0,
        overtimePay = 0,
        totalPay = 0,
        sessionCount = 0,
        periodCount = 0;

  final double totalHours;
  final double regularHours;
  final double overtimeHours;
  final double regularPay;
  final double overtimePay;
  final double totalPay;
  final int sessionCount;
  final int periodCount;
}

class JobProfileTotalsViewModel extends ChangeNotifier {
  JobProfileTotalsViewModel._({
    required this.profile,
    required DateTime referenceDate,
    required int selectedYear,
    required List<WorkSession> sessions,
    JobProfileDatabase? database,
    Future<List<WorkSession>> Function(int profileId)? sessionsLoader,
  }) : _payPeriodReferenceDate = referenceDate,
       _selectedYear = selectedYear,
       _sessions = sessions,
       _database = database,
       _sessionsLoader = sessionsLoader {
    _recompute();
  }

  final JobProfile profile;
  DateTime _payPeriodReferenceDate;
  int _selectedYear;
  final List<WorkSession> _sessions;
  final JobProfileDatabase? _database;
  final Future<List<WorkSession>> Function(int profileId)? _sessionsLoader;

  TotalsViewMode _viewMode = TotalsViewMode.payPeriod;
  JobProfileTotalsSummary _summary = const JobProfileTotalsSummary.empty();

  TotalsViewMode get viewMode => _viewMode;

  JobProfileTotalsSummary get summary => _summary;

  bool get isPayPeriodView => _viewMode == TotalsViewMode.payPeriod;

  int get selectedYear => _selectedYear;

  DateTime get referenceDate => _payPeriodReferenceDate;

  List<WorkSession> get sessions => _sessions;

  static Future<JobProfileTotalsViewModel> create({
    required JobProfile profile,
    DateTime? referenceDate,
    JobProfileDatabase? database,
    Future<List<WorkSession>> Function(int profileId)? sessionsLoader,
  }) async {
    final DateTime resolvedReferenceDate = referenceDate ?? DateTime.now();
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

    return JobProfileTotalsViewModel._(
      profile: profile,
      referenceDate: resolvedReferenceDate,
      selectedYear: resolvedReferenceDate.year,
      sessions: sessions,
      database: database,
      sessionsLoader: sessionsLoader,
    );
  }

  void setViewMode(TotalsViewMode value) {
    if (_viewMode == value) {
      return;
    }
    _viewMode = value;
    _recompute();
    notifyListeners();
  }

  void setPayPeriodReferenceDate(DateTime value) {
    if (_viewMode != TotalsViewMode.payPeriod) {
      _viewMode = TotalsViewMode.payPeriod;
    }
    if (_sameDay(_payPeriodReferenceDate, value)) {
      return;
    }
    _payPeriodReferenceDate = value;
    _recompute();
    notifyListeners();
  }

  void setSelectedYear(int value) {
    if (_viewMode != TotalsViewMode.yearly) {
      _viewMode = TotalsViewMode.yearly;
    }
    if (_selectedYear == value) {
      return;
    }
    _selectedYear = value;
    _recompute();
    notifyListeners();
  }

  void setCurrentPayPeriod({DateTime? now}) {
    final DateTime currentNow = now ?? DateTime.now();
    final DateTime currentDate = DateTime(currentNow.year, currentNow.month, currentNow.day);
    final bool modeChanged = _viewMode != TotalsViewMode.payPeriod;
    _viewMode = TotalsViewMode.payPeriod;
    if (!modeChanged && _sameDay(_payPeriodReferenceDate, currentDate)) {
      return;
    }
    _payPeriodReferenceDate = currentDate;
    _recompute();
    notifyListeners();
  }

  void setCurrentYear({DateTime? now}) {
    final int currentYear = (now ?? DateTime.now()).year;
    final bool modeChanged = _viewMode != TotalsViewMode.yearly;
    _viewMode = TotalsViewMode.yearly;
    if (!modeChanged && _selectedYear == currentYear) {
      return;
    }
    _selectedYear = currentYear;
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

      _sessions.clear();
      _sessions.addAll(newSessions);
      _recompute();
      notifyListeners();
    } catch (e) {
      // Log error if needed; don't crash on refresh failure
    }
  }

  void _recompute() {
    _summary = JobProfileTotalsCalculator.calculate(
      profile: profile,
      sessions: _sessions,
      viewMode: _viewMode,
      referenceDate: _viewMode == TotalsViewMode.payPeriod
          ? _payPeriodReferenceDate
          : DateTime(_selectedYear, 7, 1),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class JobProfileTotalsCalculator {
  static List<PeriodWindow> buildSelectablePayPeriods(
    JobProfile profile,
    Iterable<WorkSession> sessions, {
    DateTime? now,
  }) {
    final DateTime currentDate = _dateOnly(now ?? DateTime.now());
    final List<PeriodWindow> selectablePeriods = <PeriodWindow>[
      _currentPayPeriodRange(profile, currentDate).window,
    ];

    for (final PeriodWindow period in buildAllPayPeriods(profile, sessions)) {
      if (!selectablePeriods.contains(period)) {
        selectablePeriods.add(period);
      }
    }

    return selectablePeriods;
  }

  static List<int> buildSelectableYears(
    Iterable<WorkSession> sessions, {
    DateTime? now,
  }) {
    final int currentYear = (now ?? DateTime.now()).year;
    final List<int> selectableYears = <int>[currentYear];

    for (final int year in buildAllYears(sessions)) {
      if (!selectableYears.contains(year)) {
        selectableYears.add(year);
      }
    }

    return selectableYears;
  }

  static List<PeriodWindow> buildAllPayPeriods(
    JobProfile profile,
    Iterable<WorkSession> sessions,
  ) {
    if (sessions.isEmpty) {
      return <PeriodWindow>[];
    }

    final DateTime earliest = sessions
        .map((WorkSession s) => _sessionEndDate(s))
        .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
    final DateTime latest = sessions
        .map((WorkSession s) => _sessionEndDate(s))
        .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b);

    final List<PeriodWindow> periods = <PeriodWindow>[];
    _DateRange current = _currentPayPeriodRange(profile, earliest);
    // Include any window that starts on or before the latest session end date.
    while (!current.window.start.isAfter(latest)) {
      periods.add(current.window);
      current = _DateRange(window: _nextWindow(profile, current.window));
    }

    return periods;
  }

  static List<int> buildAllYears(Iterable<WorkSession> sessions) {
    if (sessions.isEmpty) {
      return <int>[];
    }

    final Set<int> years = <int>{};
    for (final WorkSession session in sessions) {
      final DateTime endDate = _sessionEndDate(session);
      years.add(endDate.year);
    }

    return years.toList()..sort();
  }

  static PeriodWindow? findPeriodForDate(
    JobProfile profile,
    DateTime searchDate,
    Iterable<PeriodWindow> availablePeriods,
  ) {
    try {
      for (final PeriodWindow period in availablePeriods) {
        if (period.contains(searchDate)) {
          return period;
        }
      }
    } catch (_) {
      // Return null if search fails
    }
    return null;
  }

  static String formatPayPeriodLabel(
    JobProfile profile,
    DateTime referenceDate,
    String dateFormat,
  ) {
    final _DateRange range = _currentPayPeriodRange(profile, referenceDate);
    return formatDateRangeWithSetting(range.window.start, range.window.end, dateFormat);
  }

  static String formatYearLabel(int year) {
    return year.toString();
  }

  static String formatSelectablePayPeriodLabel(
    JobProfile profile,
    PeriodWindow period,
    String dateFormat, {
    DateTime? now,
  }) {
    final DateTime currentDate = _dateOnly(now ?? DateTime.now());
    final String label = formatDateRangeWithSetting(period.start, period.end, dateFormat);
    final PeriodWindow currentWindow = _currentPayPeriodRange(profile, currentDate).window;
    return period == currentWindow ? '$label (Current)' : label;
  }

  static String formatSelectableYearLabel(
    int year, {
    DateTime? now,
  }) {
    final int currentYear = (now ?? DateTime.now()).year;
    return year == currentYear ? '$year (Current)' : year.toString();
  }

  static JobProfileTotalsSummary calculate({
    required JobProfile profile,
    required Iterable<WorkSession> sessions,
    required TotalsViewMode viewMode,
    required DateTime referenceDate,
  }) {
    final _DateRange range = viewMode == TotalsViewMode.payPeriod
        ? _currentPayPeriodRange(profile, referenceDate)
        : _currentYearRange(referenceDate);
    final List<PeriodWindow> windows = viewMode == TotalsViewMode.payPeriod
        ? <PeriodWindow>[range.window]
        : _buildYearWindows(profile, referenceDate);

    final List<WorkSession> relevantSessions;
    if (viewMode == TotalsViewMode.payPeriod) {
      relevantSessions = sessions
          .where((WorkSession session) => windows.first.contains(_sessionEndDate(session)))
          .toList();
    } else {
      final DateTime yearStart = range.start!;
      final DateTime yearEndExclusive = range.endExclusive!;
      relevantSessions = sessions.where((WorkSession session) {
        final DateTime endDate = _sessionEndDate(session);
        if (endDate.isBefore(yearStart) || !endDate.isBefore(yearEndExclusive)) {
          return false;
        }
        return windows.any((PeriodWindow window) => window.contains(endDate));
      }).toList();
    }

    if (relevantSessions.isEmpty) {
      return const JobProfileTotalsSummary.empty();
    }

    final Map<PeriodWindow, _PeriodAggregate> aggregates = <PeriodWindow, _PeriodAggregate>{};
    for (final WorkSession session in relevantSessions) {
      final DateTime endDate = _sessionEndDate(session);
      final PeriodWindow window = windows.firstWhere(
        (PeriodWindow candidate) => candidate.contains(endDate),
        orElse: () => range.window,
      );
      aggregates.putIfAbsent(window, () => _PeriodAggregate()).add(session);
    }

    double totalHours = 0;
    double regularHours = 0;
    double overtimeHours = 0;
    double regularPay = 0;
    double overtimePay = 0;

    for (final _PeriodAggregate aggregate in aggregates.values) {
      final double periodHours = aggregate.totalHours;
      final _PayBreakdown breakdown = _breakdownForPeriod(
        profile: profile,
        periodHours: periodHours,
        sessionCount: aggregate.sessionCount,
      );

      totalHours += periodHours;
      regularHours += breakdown.regularHours;
      overtimeHours += breakdown.overtimeHours;
      regularPay += breakdown.regularPay;
      overtimePay += breakdown.overtimePay;
    }

    return JobProfileTotalsSummary(
      totalHours: totalHours,
      regularHours: regularHours,
      overtimeHours: overtimeHours,
      regularPay: regularPay,
      overtimePay: overtimePay,
      totalPay: regularPay + overtimePay,
      sessionCount: relevantSessions.length,
      periodCount: aggregates.length,
    );
  }

  static _PayBreakdown _breakdownForPeriod({
    required JobProfile profile,
    required double periodHours,
    required int sessionCount,
  }) {
    final double overtimeMultiplier = profile.overtimeMultiplier ?? 1;
    final bool hasCompleteOvertimeConfig =
        profile.overtimePaid &&
        profile.overtimeMode != null &&
        profile.overtimeThresholdHours != null &&
        profile.overtimeMultiplier != null;

    if (!hasCompleteOvertimeConfig) {
      return _PayBreakdown(
        regularHours: periodHours,
        overtimeHours: 0,
        regularPay: periodHours * profile.payRate,
        overtimePay: 0,
      );
    }

    final double thresholdHours = profile.overtimeMode == OvertimeMode.daily
        ? (profile.overtimeThresholdHours!.toDouble() * sessionCount)
        : profile.overtimeThresholdHours!.toDouble();
    final double regularHours = min(periodHours, thresholdHours);
    final double overtimeHours = max(0, periodHours - thresholdHours);

    return _PayBreakdown(
      regularHours: regularHours,
      overtimeHours: overtimeHours,
      regularPay: regularHours * profile.payRate,
      overtimePay: overtimeHours * profile.payRate * overtimeMultiplier,
    );
  }

  static _DateRange _currentPayPeriodRange(JobProfile profile, DateTime referenceDate) {
    switch (profile.payPeriod) {
      case PayPeriod.daily:
        final DateTime day = _dateOnly(referenceDate);
        return _DateRange(window: PeriodWindow(start: day, end: day));
      case PayPeriod.weekly:
        final DateTime end = _nextWeekdayOnOrAfter(referenceDate, profile.payPeriodEndDayOfWeek ?? Weekday.mon);
        return _DateRange(
          window: PeriodWindow(
            start: end.subtract(const Duration(days: 6)),
            end: end,
          ),
        );
      case PayPeriod.biweekly:
        final DateTime end = _nextWeekdayOnOrAfter(referenceDate, profile.payPeriodEndDayOfWeek ?? Weekday.mon);
        return _DateRange(
          window: PeriodWindow(
            start: end.subtract(const Duration(days: 13)),
            end: end,
          ),
        );
      case PayPeriod.monthly:
        final DateTime end = _nextMonthlyPayDayOnOrAfter(referenceDate, profile.payPeriodEndDayOfMonth ?? 1);
        return _DateRange(
          window: PeriodWindow(
            start: _monthlyWindowStart(end, profile.payPeriodEndDayOfMonth ?? 1),
            end: end,
          ),
        );
    }
  }

  static _DateRange _currentYearRange(DateTime referenceDate) {
    final DateTime start = DateTime(referenceDate.year, 1, 1);
    final DateTime endExclusive = DateTime(referenceDate.year + 1, 1, 1);
    return _DateRange(
      start: start,
      endExclusive: endExclusive,
      window: PeriodWindow(start: start, end: endExclusive.subtract(const Duration(days: 1))),
    );
  }

  static List<PeriodWindow> _buildYearWindows(JobProfile profile, DateTime referenceDate) {
    final _DateRange yearRange = _currentYearRange(referenceDate);
    final DateTime yearStart = yearRange.start!;
    final DateTime yearEnd = yearRange.endExclusive!.subtract(const Duration(days: 1));

    // Find a window that ends within the year by starting from mid-year.
    final DateTime mid = DateTime(referenceDate.year, 7, 1);
    _DateRange midRange = _currentPayPeriodRange(profile, mid);

    PeriodWindow current = midRange.window;

    // If the mid-year window ends after the year, go back until we find one that ends in the year.
    while (current.end.isAfter(yearEnd)) {
      current = _previousWindow(profile, current);
    }

    // If the mid-year window ends before the year starts, go forward until we find one that ends in the year.
    while (current.end.isBefore(yearStart)) {
      current = _nextWindow(profile, current);
    }

    // Now current ends within the year. Walk both directions to collect all windows with end dates in the year.
    final List<PeriodWindow> windows = <PeriodWindow>[];

    // Walk backwards.
    PeriodWindow back = current;
    while (!back.end.isBefore(yearStart)) {
      windows.insert(0, back);
      back = _previousWindow(profile, back);
    }

    // Walk forwards from the next window after current.
    PeriodWindow forward = _nextWindow(profile, current);
    while (!forward.end.isAfter(yearEnd)) {
      windows.add(forward);
      forward = _nextWindow(profile, forward);
    }

    return windows;
  }

  static PeriodWindow _previousWindow(JobProfile profile, PeriodWindow window) {
    switch (profile.payPeriod) {
      case PayPeriod.daily:
        final DateTime day = window.start.subtract(const Duration(days: 1));
        return PeriodWindow(start: day, end: day);
      case PayPeriod.weekly:
        final DateTime end = window.start.subtract(const Duration(days: 1));
        return PeriodWindow(start: end.subtract(const Duration(days: 6)), end: end);
      case PayPeriod.biweekly:
        final DateTime end = window.start.subtract(const Duration(days: 1));
        return PeriodWindow(start: end.subtract(const Duration(days: 13)), end: end);
      case PayPeriod.monthly:
        final int payDay = profile.payPeriodEndDayOfMonth ?? 1;
        final DateTime end = window.start.subtract(const Duration(days: 1));
        return PeriodWindow(start: _monthlyWindowStart(end, payDay), end: end);
    }
  }

  static PeriodWindow _nextWindow(JobProfile profile, PeriodWindow window) {
    switch (profile.payPeriod) {
      case PayPeriod.daily:
        final DateTime day = window.end.add(const Duration(days: 1));
        return PeriodWindow(start: day, end: day);
      case PayPeriod.weekly:
        final DateTime start = window.end.add(const Duration(days: 1));
        final DateTime end = start.add(const Duration(days: 6));
        return PeriodWindow(start: start, end: end);
      case PayPeriod.biweekly:
        final DateTime start = window.end.add(const Duration(days: 1));
        final DateTime end = start.add(const Duration(days: 13));
        return PeriodWindow(start: start, end: end);
      case PayPeriod.monthly:
        final int payDay = profile.payPeriodEndDayOfMonth ?? 1;
        final DateTime start = window.end.add(const Duration(days: 1));
        final DateTime end = _nextMonthlyPayDayOnOrAfter(start, payDay);
        return PeriodWindow(start: start, end: end);
    }
  }

  static DateTime _sessionEndDate(WorkSession session) {
    final DateTime start = _dateOnly(session.sessionDate);
    final int? clockInMinutes = parseMinutes(session.clockInTime);
    final int? clockOutMinutes = parseMinutes(session.clockOutTime);
    if (clockInMinutes == null || clockOutMinutes == null) {
      return start;
    }
    return clockOutMinutes <= clockInMinutes
        ? start.add(const Duration(days: 1))
        : start;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _nextWeekdayOnOrAfter(DateTime date, Weekday weekday) {
    final DateTime day = _dateOnly(date);
    final int desiredWeekday = _weekdayToDateTimeValue(weekday);
    final int delta = (desiredWeekday - day.weekday) % 7;
    return day.add(Duration(days: delta));
  }

  static int _weekdayToDateTimeValue(Weekday weekday) {
    switch (weekday) {
      case Weekday.mon:
        return DateTime.monday;
      case Weekday.tues:
        return DateTime.tuesday;
      case Weekday.wed:
        return DateTime.wednesday;
      case Weekday.thurs:
        return DateTime.thursday;
      case Weekday.fri:
        return DateTime.friday;
      case Weekday.sat:
        return DateTime.saturday;
      case Weekday.sun:
        return DateTime.sunday;
    }
  }

  static DateTime _nextMonthlyPayDayOnOrAfter(DateTime date, int payPeriodEndDayOfMonth) {
    final DateTime day = _dateOnly(date);
    final int currentMonthEnd = min(payPeriodEndDayOfMonth, _daysInMonth(day.year, day.month));
    if (day.day <= currentMonthEnd) {
      return DateTime(day.year, day.month, currentMonthEnd);
    }

    final DateTime nextMonth = DateTime(day.year, day.month + 1, 1);
    final int nextMonthEnd = min(payPeriodEndDayOfMonth, _daysInMonth(nextMonth.year, nextMonth.month));
    return DateTime(nextMonth.year, nextMonth.month, nextMonthEnd);
  }

  static DateTime _monthlyWindowStart(DateTime end, int payPeriodEndDayOfMonth) {
    final DateTime previousEnd = _previousMonthlyPayDay(end, payPeriodEndDayOfMonth);
    return previousEnd.add(const Duration(days: 1));
  }

  static DateTime _previousMonthlyPayDay(DateTime end, int payPeriodEndDayOfMonth) {
    final DateTime previousMonth = DateTime(end.year, end.month - 1, 1);
    final int previousMonthEnd = min(payPeriodEndDayOfMonth, _daysInMonth(previousMonth.year, previousMonth.month));
    return DateTime(previousMonth.year, previousMonth.month, previousMonthEnd);
  }

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }
}

class PeriodWindow {
  const PeriodWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) {
    return !date.isBefore(start) && !date.isAfter(end);
  }

  @override
  bool operator ==(Object other) {
    return other is PeriodWindow &&
        other.start.isAtSameMomentAs(start) &&
        other.end.isAtSameMomentAs(end);
  }

  @override
  int get hashCode => Object.hash(start, end);
}

class _DateRange {
  const _DateRange({
    this.start,
    this.endExclusive,
    required this.window,
  });

  final DateTime? start;
  final DateTime? endExclusive;
  final PeriodWindow window;
}

class _PeriodAggregate {
  final List<WorkSession> _sessions = <WorkSession>[];

  void add(WorkSession session) {
    _sessions.add(session);
  }

  double get totalHours {
    return _sessions.fold<double>(0, (double total, WorkSession session) {
      return total + (session.totalWorkHours ?? 0);
    });
  }

  int get sessionCount => _sessions.length;
}

class _PayBreakdown {
  const _PayBreakdown({
    required this.regularHours,
    required this.overtimeHours,
    required this.regularPay,
    required this.overtimePay,
  });

  final double regularHours;
  final double overtimeHours;
  final double regularPay;
  final double overtimePay;
}
