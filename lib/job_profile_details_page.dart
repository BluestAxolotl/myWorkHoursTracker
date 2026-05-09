import 'package:flutter/material.dart';

import 'create_edit_current_work_session_page.dart';
import 'job_profile.dart';
import 'job_profile_database.dart';
import 'job_profile_totals_view_model.dart';
import 'main.dart';
import 'work_session.dart';

class JobProfileDetailsPage extends StatelessWidget {
  const JobProfileDetailsPage({
    super.key,
    required this.profile,
    required this.appSettings,
  });

  final JobProfile profile;
  final AppSettings appSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(profile.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: JobProfileLongForm(
          profile: profile,
          appSettings: appSettings,
        ),
      ),
    );
  }
}

class JobProfileLongForm extends StatefulWidget {
  const JobProfileLongForm({
    super.key,
    required this.profile,
    this.hasOpenDraftLoader,
    this.totalsSessionsLoader,
    required this.appSettings,
  });

  final JobProfile profile;
  final Future<bool> Function(int profileId)? hasOpenDraftLoader;
  final Future<List<WorkSession>> Function(int profileId)? totalsSessionsLoader;
  final AppSettings appSettings;

  @override
  State<JobProfileLongForm> createState() => _JobProfileLongFormState();
}

class _JobProfileLongFormState extends State<JobProfileLongForm> {
  late final GlobalKey<_JobProfileTotalsSectionState> _totalsSectionKey =
      GlobalKey<_JobProfileTotalsSectionState>();

  Future<void> _onSessionSaved() async {
    await _totalsSectionKey.currentState?.refreshTotals();
  }

  @override
  Widget build(BuildContext context) {
    final int? profileId = widget.profile.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (profileId != null)
          _CurrentWorkSessionButton(
            profileId: profileId,
            profileName: widget.profile.name,
            hasOpenDraftLoader: widget.hasOpenDraftLoader,
            appSettings: widget.appSettings,
            onSessionSaved: _onSessionSaved,
          ),
        if (profileId != null) const SizedBox(height: 16),
        if (profileId != null)
          _JobProfileTotalsSection(
            key: _totalsSectionKey,
            profile: widget.profile,
            appSettings: widget.appSettings,
            totalsSessionsLoader: widget.totalsSessionsLoader,
          ),
        if (profileId != null) const SizedBox(height: 16),
        Text(
          'Job Profile Summary',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        _DetailRow(label: 'Profile ID', value: '${widget.profile.id ?? '-'}'),
        _DetailRow(label: 'Name', value: widget.profile.name),
        _DetailRow(label: 'Pay Rate', value: widget.profile.formattedPayRate),
        _DetailRow(
          label: 'Pay Period',
          value: payPeriodLabel(widget.profile.payPeriod),
        ),
        _DetailRow(
          label: 'Pay Period End',
          value: widget.profile.payPeriod == PayPeriod.daily
              ? 'N/A'
              : widget.profile.payPeriod == PayPeriod.monthly
                  ? (widget.profile.payPeriodEndDayOfMonth?.toString() ?? 'N/A')
                  : (widget.profile.payPeriodEndDayOfWeek == null
                      ? 'N/A'
                      : weekdayLabel(widget.profile.payPeriodEndDayOfWeek!)),
        ),
        const Divider(height: 32),
        _DetailRow(
          label: 'Overtime',
          value: widget.profile.overtimePaid ? 'Paid' : 'Unpaid',
        ),
        _DetailRow(
          label: 'Overtime Mode',
          value: widget.profile.overtimeMode == null
              ? 'N/A'
              : overtimeModeLabel(widget.profile.overtimeMode!),
        ),
        _DetailRow(
          label: 'Hours Before Overtime',
          value: widget.profile.overtimeThresholdHours?.toString() ?? 'N/A',
        ),
        _DetailRow(
          label: 'Overtime Multiplier',
          value: widget.profile.formattedOvertimeMultiplier ?? 'N/A',
        ),
        const SizedBox(height: 24),
        const Text(
          'Work sessions for this profile can be added next on this long-scroll page.',
        ),
      ],
    );
  }
}

class _JobProfileTotalsSection extends StatefulWidget {
  const _JobProfileTotalsSection({
    super.key,
    required this.profile,
    required this.appSettings,
    this.totalsSessionsLoader,
  });

  final JobProfile profile;
  final AppSettings appSettings;
  final Future<List<WorkSession>> Function(int profileId)? totalsSessionsLoader;

  @override
  State<_JobProfileTotalsSection> createState() => _JobProfileTotalsSectionState();
}

class _JobProfileTotalsSectionState extends State<_JobProfileTotalsSection> {
  JobProfileTotalsViewModel? _viewModel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadViewModel();
  }

  Future<void> _loadViewModel() async {
    final JobProfileTotalsViewModel vm = await JobProfileTotalsViewModel.create(
      profile: widget.profile,
      sessionsLoader: widget.totalsSessionsLoader,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _viewModel = vm;
      _isLoading = false;
    });

    vm.addListener(_onVmChanged);
  }

  void _onVmChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _selectPayPeriod() async {
    final JobProfileTotalsViewModel vm = _viewModel!;
    final List<PeriodWindow> availablePeriods = JobProfileTotalsCalculator.buildSelectablePayPeriods(
      vm.profile,
      vm.sessions,
    );

    if (availablePeriods.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No work sessions available')),
        );
      }
      return;
    }

    final PeriodWindow? selected = await showDialog<PeriodWindow>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Select pay period'),
          children: <Widget>[
            SizedBox(
              width: 400,
              height: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final PeriodWindow period in availablePeriods)
                      SimpleDialogOption(
                        onPressed: () =>
                            Navigator.of(context).pop(period),
                        child: Text(
                          JobProfileTotalsCalculator.formatSelectablePayPeriodLabel(
                            vm.profile,
                            period,
                            widget.appSettings.dateFormat,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    if (selected != null) {
      vm.setPayPeriodReferenceDate(selected.start);
    }
  }

  Future<void> _selectYear() async {
    final JobProfileTotalsViewModel vm = _viewModel!;
    final List<int> availableYears = JobProfileTotalsCalculator.buildSelectableYears(vm.sessions);

    if (availableYears.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No work sessions available')),
        );
      }
      return;
    }

    final int? selectedYear = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Select year'),
          children: <Widget>[
            SizedBox(
              width: 300,
              height: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final int year in availableYears)
                      SimpleDialogOption(
                        onPressed: () =>
                            Navigator.of(context).pop(year),
                        child: Text(
                          JobProfileTotalsCalculator.formatSelectableYearLabel(year),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    if (selectedYear != null) {
      vm.setSelectedYear(selectedYear);
    }
  }

  @override
  void didUpdateWidget(covariant _JobProfileTotalsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      _viewModel?.removeListener(_onVmChanged);
      _viewModel?.dispose();
      _viewModel = null;
      setState(() {
        _isLoading = true;
      });
      _loadViewModel();
    }
  }

  Future<void> refreshTotals() async {
    await _viewModel?.refreshSessions();
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_onVmChanged);
    _viewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _viewModel == null) {
      return const SizedBox(
        width: double.infinity,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final JobProfileTotalsViewModel vm = _viewModel!;
    final JobProfileTotalsSummary summary = vm.summary;
    final String currency = widget.appSettings.currencySymbol;
    final bool showOvertimeBreakdown =
      widget.profile.overtimePaid && widget.profile.overtimeMode != null;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Totals',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ToggleButtons(
              isSelected: <bool>[
                vm.viewMode == TotalsViewMode.payPeriod,
                vm.viewMode == TotalsViewMode.yearly,
              ],
              onPressed: (int index) {
                if (index == 0) {
                  vm.setCurrentPayPeriod();
                } else {
                  vm.setCurrentYear();
                }
              },
              children: const <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Pay period'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Yearly'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              vm.viewMode == TotalsViewMode.payPeriod
                  ? 'Pay period: ${JobProfileTotalsCalculator.formatPayPeriodLabel(vm.profile, vm.referenceDate, widget.appSettings.dateFormat)}'
                  : 'Year: ${JobProfileTotalsCalculator.formatYearLabel(vm.selectedYear)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: vm.viewMode == TotalsViewMode.payPeriod
                  ? _selectPayPeriod
                  : _selectYear,
              icon: const Icon(Icons.search),
              label: Text(
                vm.viewMode == TotalsViewMode.payPeriod
                    ? 'Search by date'
                    : 'Search by year',
              ),
            ),
            const SizedBox(height: 16),
            _DetailRow(
              label: 'Total hours worked',
              value: summary.totalHours.toStringAsFixed(2),
            ),
            _DetailRow(
              label: 'Total pre-tax pay',
              value: '$currency${summary.totalPay.toStringAsFixed(2)}',
            ),
            if (showOvertimeBreakdown) ...<Widget>[
              const Divider(height: 24),
              _DetailRow(
                label: 'Regular hours',
                value: summary.regularHours.toStringAsFixed(2),
              ),
              _DetailRow(
                label: 'Regular pay',
                value: '$currency${summary.regularPay.toStringAsFixed(2)}',
              ),
              _DetailRow(
                label: 'Overtime hours',
                value: summary.overtimeHours.toStringAsFixed(2),
              ),
              _DetailRow(
                label: 'Overtime pay',
                value: '$currency${summary.overtimePay.toStringAsFixed(2)}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _CurrentWorkSessionButton extends StatefulWidget {
  const _CurrentWorkSessionButton({
    required this.profileId,
    required this.profileName,
    this.hasOpenDraftLoader,
    required this.appSettings,
    this.onSessionSaved,
  });

  final int profileId;
  final String profileName;
  final Future<bool> Function(int profileId)? hasOpenDraftLoader;
  final AppSettings appSettings;
  final Future<void> Function()? onSessionSaved;

  @override
  State<_CurrentWorkSessionButton> createState() =>
      _CurrentWorkSessionButtonState();
}

class _CurrentWorkSessionButtonState extends State<_CurrentWorkSessionButton> {
  late Future<bool> _hasDraftFuture;

  @override
  void initState() {
    super.initState();
    _hasDraftFuture = _loadHasDraft();
  }

  @override
  void didUpdateWidget(covariant _CurrentWorkSessionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      _hasDraftFuture = _loadHasDraft();
    }
  }

  Future<bool> _loadHasDraft() {
    final Future<bool> Function(int profileId)? loader = widget.hasOpenDraftLoader;
    if (loader != null) {
      return loader(widget.profileId);
    }
    return JobProfileDatabase.instance.hasOpenWorkSessionDraft(widget.profileId);
  }

  Future<void> _openCreateEditPage() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => CreateEditCurrentWorkSessionPage(
          jobProfileId: widget.profileId,
          jobProfileName: widget.profileName,
          appSettings: widget.appSettings,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _hasDraftFuture = _loadHasDraft();
    });

    // Notify parent to refresh totals
    await widget.onSessionSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasDraftFuture,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        final bool hasDraft = snapshot.data ?? false;
        final String label = hasDraft
            ? 'Edit Current Work Session'
            : 'Create Current Work Session';

        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: snapshot.connectionState == ConnectionState.waiting
                ? null
                : _openCreateEditPage,
            icon: const Icon(Icons.edit_calendar),
            label: Text(label),
          ),
        );
      },
    );
  }
}
