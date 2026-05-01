import 'package:flutter/material.dart';

import 'create_edit_current_work_session_page.dart';
import 'job_profile.dart';
import 'job_profile_database.dart';
import 'main.dart';

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

class JobProfileLongForm extends StatelessWidget {
  const JobProfileLongForm({
    super.key,
    required this.profile,
    this.hasOpenDraftLoader,
    required this.appSettings,
  });

  final JobProfile profile;
  final Future<bool> Function(int profileId)? hasOpenDraftLoader;
  final AppSettings appSettings;

  @override
  Widget build(BuildContext context) {
    final int? profileId = profile.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (profileId != null)
          _CurrentWorkSessionButton(
            profileId: profileId,
            profileName: profile.name,
            hasOpenDraftLoader: hasOpenDraftLoader,
            appSettings: appSettings,
          ),
        if (profileId != null) const SizedBox(height: 16),
        Text(
          'Job Profile Summary',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        _DetailRow(label: 'Profile ID', value: '${profile.id ?? '-'}'),
        _DetailRow(label: 'Name', value: profile.name),
        _DetailRow(label: 'Pay Rate', value: profile.formattedPayRate),
        _DetailRow(
          label: 'Pay Period',
          value: payPeriodLabel(profile.payPeriod),
        ),
        _DetailRow(
          label: 'Pay Day',
          value: profile.payPeriod == PayPeriod.daily
              ? 'N/A'
              : profile.payPeriod == PayPeriod.monthly
                  ? (profile.payDayOfMonth?.toString() ?? 'N/A')
                  : (profile.payDayOfWeek == null
                      ? 'N/A'
                      : weekdayLabel(profile.payDayOfWeek!)),
        ),
        const Divider(height: 32),
        _DetailRow(
          label: 'Overtime',
          value: profile.overtimePaid ? 'Paid' : 'Unpaid',
        ),
        _DetailRow(
          label: 'Overtime Mode',
          value: profile.overtimeMode == null
              ? 'N/A'
              : overtimeModeLabel(profile.overtimeMode!),
        ),
        _DetailRow(
          label: 'Hours Before Overtime',
          value: profile.overtimeThresholdHours?.toString() ?? 'N/A',
        ),
        _DetailRow(
          label: 'Overtime Multiplier',
          value: profile.formattedOvertimeMultiplier ?? 'N/A',
        ),
        const SizedBox(height: 24),
        const Text(
          'Work sessions for this profile can be added next on this long-scroll page.',
        ),
      ],
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
  });

  final int profileId;
  final String profileName;
  final Future<bool> Function(int profileId)? hasOpenDraftLoader;
  final AppSettings appSettings;

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
