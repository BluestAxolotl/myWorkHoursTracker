import 'package:flutter/material.dart';

import 'job_profile.dart';

class JobProfileDetailsPage extends StatelessWidget {
  const JobProfileDetailsPage({super.key, required this.profile});

  final JobProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(profile.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: JobProfileLongForm(profile: profile),
      ),
    );
  }
}

class JobProfileLongForm extends StatelessWidget {
  const JobProfileLongForm({super.key, required this.profile});

  final JobProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
          label: 'Breaks',
          value: profile.breaksPaid ? 'Paid' : 'Unpaid',
        ),
        _DetailRow(
          label: 'Unpaid Break Count',
          value: profile.unpaidBreakCount?.toString() ?? 'N/A',
        ),
        _DetailRow(
          label: 'Lunch',
          value: profile.lunchPaid ? 'Paid' : 'Unpaid',
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
