import 'dart:math';

import 'package:flutter/material.dart';

import 'job_profile.dart';
import 'job_profile_database.dart';

class CreateJobProfilePage extends StatefulWidget {
  const CreateJobProfilePage({super.key});

  @override
  State<CreateJobProfilePage> createState() => _CreateJobProfilePageState();
}

class _CreateJobProfilePageState extends State<CreateJobProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _payRateController = TextEditingController();
  final TextEditingController _overtimeThresholdController =
      TextEditingController();
  final TextEditingController _overtimeMultiplierController =
      TextEditingController();
  final TextEditingController _payDayOfMonthController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();

  bool _nameTouched = false;
  bool _submitAttempted = false;
  bool _isSubmitting = false;

  PayPeriod? _payPeriod;
  Weekday? _payDayOfWeek;
  int? _payDayOfMonth;

  bool? _breaksPaid;
  int? _unpaidBreakCount;

  bool? _lunchPaid;

  bool? _overtimePaid;
  OvertimeMode? _overtimeMode;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(_handleNameBlurValidation);
    _overtimeThresholdController.addListener(_handleOvertimeThresholdChanged);
  }

  @override
  void dispose() {
    _overtimeThresholdController.removeListener(_handleOvertimeThresholdChanged);
    _nameController.dispose();
    _payRateController.dispose();
    _overtimeThresholdController.dispose();
    _overtimeMultiplierController.dispose();
    _payDayOfMonthController.dispose();
    _nameFocusNode.removeListener(_handleNameBlurValidation);
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _handleNameBlurValidation() {
    if (!_nameFocusNode.hasFocus) {
      setState(() {
        _nameTouched = true;
      });
    }
  }

  void _handleOvertimeThresholdChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  bool get _isPayPeriodDaily => _payPeriod == PayPeriod.daily;

  int _maxOvertimeThresholdByPayPeriod() {
    if (_payPeriod == null) {
      return 24;
    }
    return max(23, payPeriodDays(_payPeriod!) * 24);
  }

  List<String> _nameErrors() {
    final String trimmed = _nameController.text.trim();
    if (trimmed.isEmpty || trimmed.length > 30) {
      return <String>['Name should be between 1 and 30 characters.'];
    }
    return <String>[];
  }

  List<String> _payRateErrors() {
    final String raw = _payRateController.text.trim();
    final List<String> errors = <String>[];

    final RegExp twoDecimalsPattern = RegExp(r'^\d+\.\d{2}$');
    final double? parsed = double.tryParse(raw);

    if (parsed == null || parsed <= 0) {
      errors.add('Enter a positive non-zero pay rate.');
    }

    if (!twoDecimalsPattern.hasMatch(raw)) {
      errors.add(
        'Enter pay rate with two decimal places; use 0 as the last decimal if needed.',
      );
    }

    return errors;
  }

  List<String> _payDayOfWeekErrors() {
    if (_payPeriod == null || _payPeriod == PayPeriod.daily || _payPeriod == PayPeriod.monthly) {
      return <String>[];
    }
    if (_payDayOfWeek == null) {
      return <String>['Please choose a pay day of the week.'];
    }
    return <String>[];
  }

  List<String> _payDayOfMonthErrors() {
    if (_payPeriod != PayPeriod.monthly) {
      return <String>[];
    }
    final int? day = int.tryParse(_payDayOfMonthController.text.trim());
    if (day == null || day < 1 || day > 31) {
      return <String>['Enter a day between 1 and 31.'];
    }
    return <String>[];
  }

  List<String> _overtimeModeErrors() {
    if (_overtimePaid != true) {
      return <String>[];
    }
    if (_payPeriod == null) {
      return <String>['Please choose a pay period above'];
    }
    return <String>[];
  }

  List<String> _overtimeThresholdErrors() {
    if (_overtimePaid != true || _overtimeMode == null) {
      return <String>[];
    }

    final int? threshold = int.tryParse(_overtimeThresholdController.text.trim());

    if (_overtimeMode == OvertimeMode.daily) {
      if (threshold == null || threshold < 1 || threshold > 23) {
        return <String>['Invalid input. Enter an integer from 1 to 23.'];
      }
      return <String>[];
    }

    final int maxHours = _maxOvertimeThresholdByPayPeriod();
    if (threshold == null || threshold < 23 || threshold > maxHours) {
      return <String>[
        'Invalid input. Enter an integer from 23 to $maxHours.',
      ];
    }
    return <String>[];
  }

  List<String> _overtimeMultiplierErrors() {
    if (_overtimePaid != true ||
        _overtimeMode == null ||
        _overtimeThresholdErrors().isNotEmpty) {
      return <String>[];
    }

    final String raw = _overtimeMultiplierController.text.trim();
    final RegExp twoDecimalsPattern = RegExp(r'^\d+\.\d{2}$');
    final double? value = double.tryParse(raw);

    if (!twoDecimalsPattern.hasMatch(raw)) {
      return <String>['Enter multiplier with exactly two decimal places.'];
    }

    if (value == null || value <= 1.00 || value > 10.00) {
      return <String>['Enter a value greater than 1.00 and up to 10.00.'];
    }

    return <String>[];
  }

  bool _validateRequiredSelections() {
    final bool hasPayPeriod = _payPeriod != null;
    
    bool hasValidPayDay;
    if (_payPeriod == PayPeriod.daily) {
      hasValidPayDay = true;
    } else if (_payPeriod == PayPeriod.monthly) {
      hasValidPayDay = _payDayOfMonth != null && _payDayOfMonth! >= 1 && _payDayOfMonth! <= 31;
    } else {
      hasValidPayDay = _payDayOfWeek != null;
    }

    final bool hasBreaks = _breaksPaid != null;
    final bool hasUnpaidCount = _breaksPaid != false || _unpaidBreakCount != null;
    final bool hasLunch = _lunchPaid != null;
    final bool hasOvertimeChoice = _overtimePaid != null;

    final bool overtimeSelectionValid =
        _overtimePaid != true ||
      (_isPayPeriodDaily || _overtimeMode != null);

    return hasPayPeriod &&
        hasValidPayDay &&
        hasBreaks &&
        hasUnpaidCount &&
        hasLunch &&
        hasOvertimeChoice &&
        overtimeSelectionValid;
  }

  Future<void> _handleCreate() async {
    setState(() {
      _submitAttempted = true;
      _nameTouched = true;
    });

    final bool hasNoTextErrors = _nameErrors().isEmpty && _payRateErrors().isEmpty;
    final bool hasNoOvertimeErrors =
        _overtimeModeErrors().isEmpty &&
        _overtimeThresholdErrors().isEmpty &&
        _overtimeMultiplierErrors().isEmpty;

    final bool hasAllSelections = _validateRequiredSelections();

    if (!hasNoTextErrors || !hasAllSelections || !hasNoOvertimeErrors) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in required fields and correct errors.'),
        ),
      );
      return;
    }

    final double payRate = double.parse(_payRateController.text.trim());

    final bool overtimePaid = _overtimePaid ?? false;
    final OvertimeMode? overtimeMode = overtimePaid
        ? (_isPayPeriodDaily ? OvertimeMode.daily : _overtimeMode)
        : null;

    final int? overtimeThreshold = overtimePaid
        ? int.tryParse(_overtimeThresholdController.text.trim())
        : null;

    final double? overtimeMultiplier = overtimePaid
        ? double.tryParse(_overtimeMultiplierController.text.trim())
        : null;

    final JobProfile profile = JobProfile(
      name: _nameController.text.trim(),
      payRate: payRate,
      payPeriod: _payPeriod!,
      payDayOfWeek: _payDayOfWeek,
      payDayOfMonth: _payDayOfMonth,
      breaksPaid: _breaksPaid ?? true,
      unpaidBreakCount: _breaksPaid == false ? _unpaidBreakCount : null,
      lunchPaid: _lunchPaid ?? true,
      overtimePaid: overtimePaid,
      overtimeMode: overtimeMode,
      overtimeThresholdHours: overtimeThreshold,
      overtimeMultiplier: overtimeMultiplier,
    );

    setState(() {
      _isSubmitting = true;
    });

    try {
      final int newId = await JobProfileDatabase.instance.createJobProfile(profile);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop<JobProfile>(profile.copyWith(id: newId));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save profile. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildErrorList(List<String> errors) {
    if (errors.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: errors
            .map(
              (String message) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> nameErrors = (_nameTouched || _submitAttempted)
        ? _nameErrors()
        : <String>[];
    final List<String> payRateErrors = _submitAttempted ? _payRateErrors() : <String>[];
    final List<String> overtimeModeErrors =
        _submitAttempted ? _overtimeModeErrors() : <String>[];
    final List<String> overtimeThresholdErrors =
        _submitAttempted ? _overtimeThresholdErrors() : <String>[];
    final List<String> overtimeMultiplierErrors =
        _submitAttempted ? _overtimeMultiplierErrors() : <String>[];

    final bool showOvertimeThresholdInput = _overtimePaid == true &&
      (_isPayPeriodDaily || _overtimeMode != null) &&
        overtimeModeErrors.isEmpty;

    final bool showOvertimeMultiplierInput = showOvertimeThresholdInput;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Job Profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'Job profile name',
                    border: OutlineInputBorder(),
                  ),
                ),
                _buildErrorList(nameErrors),
                const SizedBox(height: 16),
                TextField(
                  controller: _payRateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Pay rate (e.g. 15.00)',
                    border: OutlineInputBorder(),
                  ),
                ),
                _buildErrorList(payRateErrors),
                const SizedBox(height: 16),
                DropdownButtonFormField<PayPeriod>(
                  initialValue: _payPeriod,
                  decoration: const InputDecoration(
                    labelText: 'Pay period',
                    border: OutlineInputBorder(),
                  ),
                  items: PayPeriod.values
                      .map(
                        (PayPeriod value) => DropdownMenuItem<PayPeriod>(
                          value: value,
                          child: Text(payPeriodLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (PayPeriod? value) {
                    setState(() {
                      _payPeriod = value;
                      if (_payPeriod == PayPeriod.daily) {
                        _payDayOfWeek = null;
                        _payDayOfMonth = null;
                        if (_overtimePaid == true) {
                          _overtimeMode = OvertimeMode.daily;
                        }
                      }
                      if (_overtimePaid != true) {
                        _overtimeMode = null;
                      }
                      _overtimeThresholdController.clear();
                      _overtimeMultiplierController.clear();
                    });
                  },
                ),
                if (_submitAttempted && _payPeriod == null)
                  _buildErrorList(<String>['Please choose a pay period.']),
                if (_payPeriod == PayPeriod.weekly || _payPeriod == PayPeriod.biweekly) ...<Widget>[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Weekday>(
                    initialValue: _payDayOfWeek,
                    decoration: const InputDecoration(
                      labelText: 'Pay day of the week',
                      border: OutlineInputBorder(),
                    ),
                    items: Weekday.values
                        .map(
                          (Weekday value) => DropdownMenuItem<Weekday>(
                            value: value,
                            child: Text(weekdayLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (Weekday? value) {
                      setState(() {
                        _payDayOfWeek = value;
                      });
                    },
                  ),
                  _buildErrorList(_submitAttempted ? _payDayOfWeekErrors() : <String>[]),
                ] else if (_payPeriod == PayPeriod.monthly) ...<Widget>[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _payDayOfMonthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Pay day of the month (1-31)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (String value) {
                      setState(() {
                        _payDayOfMonth = int.tryParse(value.trim());
                      });
                    },
                  ),
                  _buildErrorList(_submitAttempted ? _payDayOfMonthErrors() : <String>[]),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<bool>(
                  initialValue: _breaksPaid,
                  decoration: const InputDecoration(
                    labelText: 'Breaks paid?',
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<bool>>[
                    DropdownMenuItem<bool>(value: true, child: Text('Paid')),
                    DropdownMenuItem<bool>(value: false, child: Text('Unpaid')),
                  ],
                  onChanged: (bool? value) {
                    setState(() {
                      _breaksPaid = value;
                      if (value != false) {
                        _unpaidBreakCount = null;
                      }
                    });
                  },
                ),
                if (_submitAttempted && _breaksPaid == null)
                  _buildErrorList(<String>['Please choose paid or unpaid breaks.']),
                if (_breaksPaid == false) ...<Widget>[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _unpaidBreakCount,
                    decoration: const InputDecoration(
                      labelText: 'Number of unpaid breaks',
                      border: OutlineInputBorder(),
                    ),
                    items: const <int>[1, 2, 3, 4, 5]
                        .map(
                          (int value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text(value.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (int? value) {
                      setState(() {
                        _unpaidBreakCount = value;
                      });
                    },
                  ),
                  if (_submitAttempted && _unpaidBreakCount == null)
                    _buildErrorList(<String>['Please choose the unpaid break count.']),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<bool>(
                  initialValue: _lunchPaid,
                  decoration: const InputDecoration(
                    labelText: 'Lunch paid?',
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<bool>>[
                    DropdownMenuItem<bool>(value: true, child: Text('Paid')),
                    DropdownMenuItem<bool>(value: false, child: Text('Unpaid')),
                  ],
                  onChanged: (bool? value) {
                    setState(() {
                      _lunchPaid = value;
                    });
                  },
                ),
                if (_submitAttempted && _lunchPaid == null)
                  _buildErrorList(<String>['Please choose paid or unpaid lunch.']),
                const SizedBox(height: 16),
                DropdownButtonFormField<bool>(
                  initialValue: _overtimePaid,
                  decoration: const InputDecoration(
                    labelText: 'Overtime paid?',
                    border: OutlineInputBorder(),
                  ),
                  items: const <DropdownMenuItem<bool>>[
                    DropdownMenuItem<bool>(value: true, child: Text('Paid')),
                    DropdownMenuItem<bool>(value: false, child: Text('Unpaid')),
                  ],
                  onChanged: (bool? value) {
                    setState(() {
                      _overtimePaid = value;
                      if (_overtimePaid == true && _isPayPeriodDaily) {
                        _overtimeMode = OvertimeMode.daily;
                      }
                      if (_overtimePaid != true) {
                        _overtimeMode = null;
                        _overtimeThresholdController.clear();
                        _overtimeMultiplierController.clear();
                      }
                    });
                  },
                ),
                if (_submitAttempted && _overtimePaid == null)
                  _buildErrorList(<String>['Please choose paid or unpaid overtime.']),
                if (_overtimePaid == true) ...<Widget>[
                  const SizedBox(height: 16),
                  if (_isPayPeriodDaily)
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Overtime applies',
                        border: OutlineInputBorder(),
                      ),
                      child: const Text('Daily'),
                    )
                  else
                    DropdownButtonFormField<OvertimeMode>(
                      initialValue: _overtimeMode,
                      decoration: InputDecoration(
                        labelText: 'Overtime applies',
                        border: const OutlineInputBorder(),
                        fillColor: _payPeriod == null
                            ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                            : null,
                        filled: _payPeriod == null,
                      ),
                      items: OvertimeMode.values
                          .map(
                            (OvertimeMode mode) => DropdownMenuItem<OvertimeMode>(
                              value: mode,
                              child: Text(overtimeModeLabel(mode)),
                            ),
                          )
                          .toList(),
                      onChanged: _payPeriod == null
                          ? null
                          : (OvertimeMode? value) {
                              setState(() {
                                _overtimeMode = value;
                                _overtimeThresholdController.clear();
                                _overtimeMultiplierController.clear();
                              });
                            },
                    ),
                  _buildErrorList(overtimeModeErrors),
                ],
                if (showOvertimeThresholdInput) ...<Widget>[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _overtimeThresholdController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _isPayPeriodDaily || _overtimeMode == OvertimeMode.daily
                          ? 'Hours before overtime (1-23)'
                          : 'Hours before overtime (23-${_maxOvertimeThresholdByPayPeriod()})',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  _buildErrorList(overtimeThresholdErrors),
                ],
                if (showOvertimeMultiplierInput) ...<Widget>[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _overtimeMultiplierController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Overtime multiplier (> 1.00 - 10.00)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  _buildErrorList(overtimeMultiplierErrors),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSubmitting ? null : _handleCreate,
                  child: Text(_isSubmitting ? 'Creating...' : 'Create'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
