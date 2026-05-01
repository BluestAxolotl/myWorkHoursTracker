import 'package:flutter/material.dart';

import 'main.dart';
import 'work_session.dart';
import 'work_session_view_model.dart';

class CreateEditCurrentWorkSessionPage extends StatefulWidget {
  const CreateEditCurrentWorkSessionPage({
    super.key,
    required this.jobProfileId,
    required this.jobProfileName,
    required this.appSettings,
  });

  final int jobProfileId;
  final String jobProfileName;
  final AppSettings appSettings;

  @override
  State<CreateEditCurrentWorkSessionPage> createState() =>
      _CreateEditCurrentWorkSessionPageState();
}

class _CreateEditCurrentWorkSessionPageState
    extends State<CreateEditCurrentWorkSessionPage> {
  WorkSessionViewModel? _viewModel;
  bool _isLoading = true;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadViewModel();
  }

  Future<void> _loadViewModel() async {
    final WorkSessionViewModel vm = await WorkSessionViewModel.create(
      jobProfileId: widget.jobProfileId,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _viewModel = vm;
      _noteController.text = vm.session.note;
      _isLoading = false;
    });

    vm.addListener(_syncNoteIfNeeded);
  }

  void _syncNoteIfNeeded() {
    final WorkSessionViewModel? vm = _viewModel;
    if (vm == null) {
      return;
    }
    final String incoming = vm.session.note;
    if (_noteController.text != incoming) {
      _noteController.value = TextEditingValue(
        text: incoming,
        selection: TextSelection.collapsed(offset: incoming.length),
      );
    }
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_syncNoteIfNeeded);
    _viewModel?.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(WorkSessionViewModel vm) async {
    final DateTime initial = vm.session.sessionDate;
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      initialDatePickerMode: DatePickerMode.day,
    );

    if (picked != null) {
      vm.setSessionDate(picked);
    }
  }

  Future<void> _pickTime(WorkSessionViewModel vm, String key) async {
    final TimeOfDay? initial = parseTimeOfDay(_valueByKey(vm.session, key));
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
      useRootNavigator: false,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: widget.appSettings.timeFormat == '24 hr',
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      vm.setTimeField(key, picked);
    }
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

  Future<void> _saveAndExit(WorkSessionViewModel vm) async {
    await vm.saveOnExit();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _viewModel == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final WorkSessionViewModel vm = _viewModel!;

    return PopScope(
      canPop: !vm.isBusy,
      onPopInvokedWithResult: (bool didPop, Object? _) async {
        if (didPop || vm.isBusy) {
          return;
        }
        await _saveAndExit(vm);
      },
      child: AnimatedBuilder(
        animation: vm,
        builder: (BuildContext context, Widget? _) {
          return Scaffold(
            appBar: AppBar(
              title: Text(vm.hasOpenDraft ? 'Edit Current Work Session' : 'Create Current Work Session'),
              leading: BackButton(
                onPressed: vm.isBusy ? null : () => _saveAndExit(vm),
              ),
            ),
            body: AbsorbPointer(
              absorbing: vm.isBusy,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _DateFieldCard(
                      label: 'Date',
                      value: formatDateWithSetting(
                        vm.session.sessionDate,
                        widget.appSettings.dateFormat,
                      ),
                      errorText: vm.errorFor('sessionDate'),
                      onTap: () => _pickDate(vm),
                      onUndo: vm.dateChanged() ? vm.undoDate : null,
                    ),
                    const SizedBox(height: 12),
                    _TimeFieldCard(
                      label: 'Clock-in',
                      value: displayTimeWithSetting(
                        vm.session.clockInTime,
                        widget.appSettings.timeFormat,
                      ),
                      errorText: vm.errorFor('clockInTime'),
                      onPick: () => _pickTime(vm, 'clockInTime'),
                      onTimestamp: () => vm.setFieldToNow('clockInTime'),
                      onUndo: vm.fieldChanged('clockInTime')
                          ? () => vm.undoField('clockInTime')
                          : null,
                    ),
                    _buildBreakFields(vm),
                    if (vm.session.hasLunch) ...<Widget>[
                      _TimeFieldCard(
                        label: 'Lunch start',
                        value: displayTimeWithSetting(
                          vm.session.lunchStartTime,
                          widget.appSettings.timeFormat,
                        ),
                        errorText: vm.errorFor('lunchStartTime'),
                        onPick: () => _pickTime(vm, 'lunchStartTime'),
                        onTimestamp: () => vm.setFieldToNow('lunchStartTime'),
                        onUndo: vm.fieldChanged('lunchStartTime')
                            ? () => vm.undoField('lunchStartTime')
                            : null,
                      ),
                      _TimeFieldCard(
                        label: 'Lunch end',
                        value: displayTimeWithSetting(
                          vm.session.lunchEndTime,
                          widget.appSettings.timeFormat,
                        ),
                        errorText: vm.errorFor('lunchEndTime'),
                        onPick: () => _pickTime(vm, 'lunchEndTime'),
                        onTimestamp: () => vm.setFieldToNow('lunchEndTime'),
                        onUndo: vm.fieldChanged('lunchEndTime')
                            ? () => vm.undoField('lunchEndTime')
                            : null,
                      ),
                    ],
                    _TimeFieldCard(
                      label: 'Clock-out',
                      value: displayTimeWithSetting(
                        vm.session.clockOutTime,
                        widget.appSettings.timeFormat,
                      ),
                      errorText: vm.errorFor('clockOutTime'),
                      onPick: () => _pickTime(vm, 'clockOutTime'),
                      onTimestamp: () => vm.setFieldToNow('clockOutTime'),
                      onUndo: vm.fieldChanged('clockOutTime')
                          ? () => vm.undoField('clockOutTime')
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: vm.session.breakCount < maxBreakCount
                              ? vm.addBreakField
                              : null,
                          icon: const Icon(Icons.add),
                          label: const Text('Add break'),
                        ),
                        OutlinedButton.icon(
                          onPressed: vm.session.breakCount > 0
                              ? vm.removeBreakField
                              : null,
                          icon: const Icon(Icons.remove),
                          label: const Text('Remove break'),
                        ),
                        OutlinedButton.icon(
                          onPressed: vm.session.hasLunch
                              ? () => vm.setLunchEnabled(false)
                              : () => vm.setLunchEnabled(true),
                          icon: Icon(vm.session.hasLunch ? Icons.remove_circle_outline : Icons.add_circle_outline),
                          label: Text(vm.session.hasLunch ? 'Remove lunch' : 'Add lunch'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _noteController,
                      maxLength: maxNoteLength,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Session note (optional)',
                        hintText: 'Up to 200 characters',
                        border: const OutlineInputBorder(),
                        errorText: vm.errorFor('note'),
                      ),
                      onChanged: vm.setNote,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: vm.isBusy
                                ? null
                                : () async {
                                    final ScaffoldMessengerState messenger =
                                        ScaffoldMessenger.of(context);
                                    await vm.saveChanges();
                                    if (!mounted) {
                                      return;
                                    }
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Changes saved.')),
                                    );
                                  },
                            child: const Text('Save changes'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: vm.isBusy
                                ? null
                                : () async {
                                    final ScaffoldMessengerState messenger =
                                        ScaffoldMessenger.of(context);
                                    final NavigatorState navigator =
                                        Navigator.of(context);
                                    final bool done = await vm.finishSession();
                                    if (!mounted) {
                                      return;
                                    }
                                    if (done) {
                                      messenger.showSnackBar(
                                        const SnackBar(content: Text('Work session finished.')),
                                      );
                                      navigator.pop(true);
                                    } else {
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Please fix the highlighted inputs.'),
                                        ),
                                      );
                                    }
                                  },
                            child: const Text('Finish session'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBreakFields(WorkSessionViewModel vm) {
    final List<Widget> widgets = <Widget>[];
    for (int i = 1; i <= vm.session.breakCount; i++) {
      widgets.add(
        _TimeFieldCard(
          label: 'Break $i start',
          value: displayTimeWithSetting(
            _valueByKey(vm.session, 'break${i}StartTime'),
            widget.appSettings.timeFormat,
          ),
          errorText: vm.errorFor('break${i}StartTime'),
          onPick: () => _pickTime(vm, 'break${i}StartTime'),
          onTimestamp: () => vm.setFieldToNow('break${i}StartTime'),
          onUndo: vm.fieldChanged('break${i}StartTime')
              ? () => vm.undoField('break${i}StartTime')
              : null,
        ),
      );
      widgets.add(
        _TimeFieldCard(
          label: 'Break $i end',
          value: displayTimeWithSetting(
            _valueByKey(vm.session, 'break${i}EndTime'),
            widget.appSettings.timeFormat,
          ),
          errorText: vm.errorFor('break${i}EndTime'),
          onPick: () => _pickTime(vm, 'break${i}EndTime'),
          onTimestamp: () => vm.setFieldToNow('break${i}EndTime'),
          onUndo: vm.fieldChanged('break${i}EndTime')
              ? () => vm.undoField('break${i}EndTime')
              : null,
        ),
      );
    }
    return Column(children: widgets);
  }
}

class _TimeFieldCard extends StatelessWidget {
  const _TimeFieldCard({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onTimestamp,
    this.onUndo,
    this.errorText,
  });

  final String label;
  final String value;
  final VoidCallback onPick;
  final VoidCallback onTimestamp;
  final VoidCallback? onUndo;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: errorText,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: InkWell(
                onTap: onPick,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(value.isEmpty ? 'Select time' : value),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Use current time',
              onPressed: onTimestamp,
              icon: const Icon(Icons.more_time),
            ),
            if (onUndo != null)
              IconButton(
                tooltip: 'Undo change',
                onPressed: onUndo,
                icon: const Icon(Icons.undo),
              ),
          ],
        ),
      ),
    );
  }
}

class _DateFieldCard extends StatelessWidget {
  const _DateFieldCard({
    required this.label,
    required this.value,
    required this.onTap,
    this.onUndo,
    this.errorText,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onUndo;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(value),
              ),
            ),
          ),
          if (onUndo != null)
            IconButton(
              tooltip: 'Undo date change',
              onPressed: onUndo,
              icon: const Icon(Icons.undo),
            ),
        ],
      ),
    );
  }
}
