import 'package:flutter/material.dart';

import 'job_profile_database.dart';
import 'work_session.dart';
import 'work_session_validation.dart';

const int maxBreakCount = 5;
const int maxNoteLength = 200;

class WorkSessionViewModel extends ChangeNotifier {
  WorkSessionViewModel._({
    required this.jobProfileId,
    required JobProfileDatabase database,
    required WorkSession session,
    required bool hasOpenDraft,
  })  : _session = session,
        _initialSession = session,
        _database = database,
        _hasOpenDraft = hasOpenDraft;

  final int jobProfileId;
  final JobProfileDatabase _database;

  WorkSession _session;
  WorkSession _initialSession;
  bool _hasOpenDraft;
  bool _isBusy = false;

  final Map<String, String?> _errors = <String, String?>{};

  static Future<WorkSessionViewModel> create({
    required int jobProfileId,
    JobProfileDatabase? database,
  }) async {
    final JobProfileDatabase db = database ?? JobProfileDatabase.instance;
    final WorkSession? draft = await db.getOpenWorkSessionDraft(jobProfileId);

    if (draft != null) {
      return WorkSessionViewModel._(
        jobProfileId: jobProfileId,
        database: db,
        session: draft,
        hasOpenDraft: true,
      );
    }

    final WorkSession? mostRecent =
        await db.getMostRecentFinalizedWorkSession(jobProfileId);

    final DateTime now = DateTime.now();
    WorkSession base = WorkSession(
      jobProfileId: jobProfileId,
      sessionDate: DateTime(now.year, now.month, now.day),
      breakCount: mostRecent?.breakCount ?? 0,
      hasLunch: mostRecent?.hasLunch ?? false,
    );

    if (base.breakCount < 0 || base.breakCount > maxBreakCount) {
      base = base.copyWith(breakCount: 0);
    }

    return WorkSessionViewModel._(
      jobProfileId: jobProfileId,
      database: db,
      session: base,
      hasOpenDraft: false,
    );
  }

  WorkSession get session => _session;

  bool get hasOpenDraft => _hasOpenDraft;

  bool get isBusy => _isBusy;

  String get topButtonLabel =>
      _hasOpenDraft ? 'Edit Current Work Session' : 'Create Current Work Session';

  String? errorFor(String key) => _errors[key];

  void clearError(String key) {
    if (_errors.containsKey(key)) {
      _errors.remove(key);
      notifyListeners();
    }
  }

  bool fieldChanged(String key) {
    final String? current = _valueByKey(_session, key);
    final String? initial = _valueByKey(_initialSession, key);
    return current != initial;
  }

  bool dateChanged() {
    return formatDateOnly(_session.sessionDate) !=
        formatDateOnly(_initialSession.sessionDate);
  }

  void undoField(String key) {
    final String? value = _valueByKey(_initialSession, key);
    _setFieldValue(key, value);
    clearError(key);
  }

  void undoDate() {
    _session = _session.copyWith(sessionDate: _initialSession.sessionDate);
    clearError('sessionDate');
    notifyListeners();
  }

  void setSessionDate(DateTime date) {
    _session = _session.copyWith(sessionDate: DateTime(date.year, date.month, date.day));
    clearError('sessionDate');
    notifyListeners();
  }

  void setFieldToNow(String key) {
    final TimeOfDay now = TimeOfDay.now();
    final String formatted = formatTimeOfDay(now);
    _setFieldValue(key, formatted);
    clearError(key);
  }

  void setTimeField(String key, TimeOfDay time) {
    _setFieldValue(key, formatTimeOfDay(time));
    clearError(key);
  }

  void setNote(String value) {
    _session = _session.copyWith(note: value);
    clearError('note');
    notifyListeners();
  }

  void addBreakField() {
    if (_session.breakCount >= maxBreakCount) {
      return;
    }
    _session = _session.copyWith(breakCount: _session.breakCount + 1);
    notifyListeners();
  }

  void removeBreakField() {
    if (_session.breakCount <= 0) {
      return;
    }
    final int currentCount = _session.breakCount;
    switch (currentCount) {
      case 1:
        _session = _session.copyWith(
          breakCount: 0,
          clearBreak1StartTime: true,
          clearBreak1EndTime: true,
        );
        break;
      case 2:
        _session = _session.copyWith(
          breakCount: 1,
          clearBreak2StartTime: true,
          clearBreak2EndTime: true,
        );
        break;
      case 3:
        _session = _session.copyWith(
          breakCount: 2,
          clearBreak3StartTime: true,
          clearBreak3EndTime: true,
        );
        break;
      case 4:
        _session = _session.copyWith(
          breakCount: 3,
          clearBreak4StartTime: true,
          clearBreak4EndTime: true,
        );
        break;
      case 5:
        _session = _session.copyWith(
          breakCount: 4,
          clearBreak5StartTime: true,
          clearBreak5EndTime: true,
        );
        break;
      default:
        break;
    }
    _clearBreakErrorsAbove(_session.breakCount);
    notifyListeners();
  }

  void setLunchEnabled(bool enabled) {
    if (!enabled) {
      _session = _session.copyWith(
        hasLunch: false,
        clearLunchStartTime: true,
        clearLunchEndTime: true,
      );
      clearError('lunchStartTime');
      clearError('lunchEndTime');
    } else {
      _session = _session.copyWith(hasLunch: true);
    }
    notifyListeners();
  }

  Future<void> saveChanges() async {
    _isBusy = true;
    notifyListeners();

    try {
      if (!_session.hasAnyInput) {
        await _database.deleteOpenWorkSessionDraft(jobProfileId);
        _hasOpenDraft = false;
        _initialSession = _session;
      } else {
        await _database.saveOpenWorkSessionDraft(_session);
        _hasOpenDraft = true;
        _initialSession = _session;
      }
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> finishSession() async {
    _errors.clear();

    if (!_validateRequiredFields()) {
      notifyListeners();
      return false;
    }

    if (!_validateTimeOverlapsWithinSession()) {
      notifyListeners();
      return false;
    }

    if (!await _validateNoOverlapWithExistingSessions()) {
      notifyListeners();
      return false;
    }

    _isBusy = true;
    notifyListeners();

    try {
      await _database.insertFinalizedWorkSession(_session);
      await _database.deleteOpenWorkSessionDraft(jobProfileId);
      _hasOpenDraft = false;
      _initialSession = _session;
      return true;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> saveOnExit() async {
    await saveChanges();
  }

  String? _valueByKey(WorkSession session, String key) {
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

  void _setFieldValue(String key, String? value) {
    switch (key) {
      case 'clockInTime':
        _session = _session.copyWith(
          clockInTime: value,
          clearClockInTime: value == null,
        );
        break;
      case 'clockOutTime':
        _session = _session.copyWith(
          clockOutTime: value,
          clearClockOutTime: value == null,
        );
        break;
      case 'break1StartTime':
        _session = _session.copyWith(
          break1StartTime: value,
          clearBreak1StartTime: value == null,
        );
        break;
      case 'break1EndTime':
        _session = _session.copyWith(
          break1EndTime: value,
          clearBreak1EndTime: value == null,
        );
        break;
      case 'break2StartTime':
        _session = _session.copyWith(
          break2StartTime: value,
          clearBreak2StartTime: value == null,
        );
        break;
      case 'break2EndTime':
        _session = _session.copyWith(
          break2EndTime: value,
          clearBreak2EndTime: value == null,
        );
        break;
      case 'break3StartTime':
        _session = _session.copyWith(
          break3StartTime: value,
          clearBreak3StartTime: value == null,
        );
        break;
      case 'break3EndTime':
        _session = _session.copyWith(
          break3EndTime: value,
          clearBreak3EndTime: value == null,
        );
        break;
      case 'break4StartTime':
        _session = _session.copyWith(
          break4StartTime: value,
          clearBreak4StartTime: value == null,
        );
        break;
      case 'break4EndTime':
        _session = _session.copyWith(
          break4EndTime: value,
          clearBreak4EndTime: value == null,
        );
        break;
      case 'break5StartTime':
        _session = _session.copyWith(
          break5StartTime: value,
          clearBreak5StartTime: value == null,
        );
        break;
      case 'break5EndTime':
        _session = _session.copyWith(
          break5EndTime: value,
          clearBreak5EndTime: value == null,
        );
        break;
      case 'lunchStartTime':
        _session = _session.copyWith(
          lunchStartTime: value,
          clearLunchStartTime: value == null,
        );
        break;
      case 'lunchEndTime':
        _session = _session.copyWith(
          lunchEndTime: value,
          clearLunchEndTime: value == null,
        );
        break;
      default:
        return;
    }

    notifyListeners();
  }

  void _clearBreakErrorsAbove(int breakCount) {
    for (int i = breakCount + 1; i <= maxBreakCount; i++) {
      _errors.remove('break${i}StartTime');
      _errors.remove('break${i}EndTime');
    }
  }

  bool _validateRequiredFields() {
    final Map<String, String> errors = WorkSessionValidation.validateRequiredFields(_session);
    _errors.addAll(errors);
    return errors.isEmpty;
  }

  bool _validateTimeOverlapsWithinSession() {
    final Map<String, String> errors = WorkSessionValidation.validateInternalOverlaps(_session);
    _errors.addAll(errors);
    return errors.isEmpty;
  }

  Future<bool> _validateNoOverlapWithExistingSessions() async {
    final List<WorkSession> finalized =
        await _database.getFinalizedWorkSessionsForProfile(jobProfileId);
    final Map<String, String> errors = WorkSessionValidation.validateAgainstExistingSessions(
      _session,
      finalized,
    );
    _errors.addAll(errors);
    return errors.isEmpty;
  }
}
