import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'job_profile.dart';
import 'job_profile_calendar_model.dart';
import 'job_profile_calendar_view_model.dart';
import 'main.dart';
import 'work_session.dart';

class JobProfileCalendarSection extends StatefulWidget {
  const JobProfileCalendarSection({
    super.key,
    required this.profile,
    required this.appSettings,
    this.sessionsLoader,
    this.sessionRefreshToken = 0,
    this.now,
  });

  final JobProfile profile;
  final AppSettings appSettings;
  final Future<List<WorkSession>> Function(int profileId)? sessionsLoader;
  final int sessionRefreshToken;
  final DateTime? now;

  @override
  State<JobProfileCalendarSection> createState() => _JobProfileCalendarSectionState();
}

class _JobProfileCalendarSectionState extends State<JobProfileCalendarSection> {
  JobProfileCalendarViewModel? _viewModel;
  bool _isLoading = true;
  bool _isTransitionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadViewModel();
  }

  @override
  void didUpdateWidget(covariant JobProfileCalendarSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id) {
      _viewModel?.removeListener(_onViewModelChanged);
      _viewModel?.dispose();
      _viewModel = null;
      _isLoading = true;
      _loadViewModel();
      return;
    }

    if (oldWidget.sessionRefreshToken != widget.sessionRefreshToken) {
      _viewModel?.refreshCalendar();
      return;
    }

    if (oldWidget.now != widget.now) {
      _viewModel?.updateNow(widget.now);
    }
  }

  Future<void> _loadViewModel() async {
    final JobProfileCalendarViewModel viewModel = await JobProfileCalendarViewModel.create(
      profile: widget.profile,
      now: widget.now,
      sessionsLoader: widget.sessionsLoader,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _viewModel = viewModel;
      _isLoading = false;
    });
    viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _selectCalendarMode(
    JobProfileCalendarViewModel viewModel,
    JobProfileCalendarViewMode selectedMode,
  ) async {
    final bool showTransitionLoading = selectedMode == JobProfileCalendarViewMode.yearly;

    if (showTransitionLoading && mounted) {
      setState(() {
        _isTransitionLoading = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    if (!mounted) {
      return;
    }

    if (viewModel.viewMode == selectedMode) {
      viewModel.resetCurrentViewToToday();
    } else {
      viewModel.setViewMode(selectedMode);
    }

    if (showTransitionLoading && mounted) {
      setState(() {
        _isTransitionLoading = false;
      });
    }
  }

  Future<void> _selectPeriod(JobProfileCalendarViewModel viewModel) async {
    final DateTime initialDate = viewModel.referenceDate;
    final DateTime firstDate = DateTime(2000, 1, 1);
    final DateTime lastDate = DateTime(2100, 12, 31);

    switch (viewModel.viewMode) {
      case JobProfileCalendarViewMode.payPeriod:
        final DateTime? selected = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          helpText: 'Choose a date in the pay period',
        );
        if (selected != null) {
          viewModel.selectDateForCurrentView(selected);
        }
        break;
      case JobProfileCalendarViewMode.daily:
        final DateTime? selected = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          helpText: 'Choose a day',
        );
        if (selected != null) {
          viewModel.selectDateForCurrentView(selected);
        }
        break;
      case JobProfileCalendarViewMode.monthly:
        final DateTime? selected = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          helpText: 'Choose a date in the month',
        );
        if (selected != null) {
          viewModel.selectDateForCurrentView(selected);
        }
        break;
      case JobProfileCalendarViewMode.yearly:
        final DateTime? selected = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          helpText: 'Choose a date in the year',
        );
        if (selected != null) {
          viewModel.selectDateForCurrentView(selected);
        }
        break;
    }
  }

  String _periodLabel(JobProfileCalendarViewModel viewModel) {
    switch (viewModel.viewMode) {
      case JobProfileCalendarViewMode.payPeriod:
        return 'Choose pay period';
      case JobProfileCalendarViewMode.daily:
        return 'Choose day';
      case JobProfileCalendarViewMode.monthly:
        return 'Choose month';
      case JobProfileCalendarViewMode.yearly:
        return 'Choose year';
    }
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_onViewModelChanged);
    _viewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: double.infinity,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final JobProfileCalendarViewModel viewModel = _viewModel!;
    final bool showLoadingOverlay = viewModel.isLoading || _isTransitionLoading;

    return Stack(
      children: <Widget>[
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Calendar',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ToggleButtons(
                    isSelected: <bool>[
                      viewModel.viewMode == JobProfileCalendarViewMode.payPeriod,
                      viewModel.viewMode == JobProfileCalendarViewMode.daily,
                      viewModel.viewMode == JobProfileCalendarViewMode.monthly,
                      viewModel.viewMode == JobProfileCalendarViewMode.yearly,
                    ],
                    onPressed: (int index) async {
                      final JobProfileCalendarViewMode selectedMode;
                      switch (index) {
                        case 0:
                          selectedMode = JobProfileCalendarViewMode.payPeriod;
                          break;
                        case 1:
                          selectedMode = JobProfileCalendarViewMode.daily;
                          break;
                        case 2:
                          selectedMode = JobProfileCalendarViewMode.monthly;
                          break;
                        case 3:
                          selectedMode = JobProfileCalendarViewMode.yearly;
                          break;
                        default:
                          return;
                      }

                      await _selectCalendarMode(viewModel, selectedMode);
                    },
                    children: const <Widget>[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Pay period'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Daily'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Monthly'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Yearly'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  viewModel.viewMode == JobProfileCalendarViewMode.payPeriod
                      ? 'Pay period: ${formatDateRangeWithSetting(viewModel.payPeriodWindow.start, viewModel.payPeriodWindow.end, widget.appSettings.dateFormat)}'
                      : viewModel.viewMode == JobProfileCalendarViewMode.daily
                          ? 'Day: ${formatDateWithSetting(viewModel.referenceDate, widget.appSettings.dateFormat)}'
                          : viewModel.viewMode == JobProfileCalendarViewMode.monthly
                              ? 'Month: ${DateFormat('MMMM yyyy').format(viewModel.referenceDate)}'
                              : 'Year: ${viewModel.referenceDate.year}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton.outlined(
                        onPressed: viewModel.moveToPreviousPeriod,
                        icon: const Icon(Icons.chevron_left),
                        tooltip: 'Previous period',
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _selectPeriod(viewModel),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_periodLabel(viewModel)),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        onPressed: viewModel.moveToNextPeriod,
                        icon: const Icon(Icons.chevron_right),
                        tooltip: 'Next period',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (viewModel.viewMode == JobProfileCalendarViewMode.yearly)
                  _YearOverview(
                    profile: widget.profile,
                    sessions: viewModel.sessions,
                    timeFormat: widget.appSettings.timeFormat,
                    currentDay: viewModel.currentDay,
                    referenceDate: viewModel.referenceDate,
                  )
                else
                  _DayRangeCalendar(
                    profile: widget.profile,
                    sessions: viewModel.sessions,
                    timeFormat: widget.appSettings.timeFormat,
                    currentDay: viewModel.currentDay,
                    rangeStart: viewModel.visibleRangeStart,
                    rangeEnd: viewModel.visibleRangeEnd,
                    dense: viewModel.isDailyView,
                    singleDay: viewModel.isDailyView,
                  ),
              ],
            ),
          ),
        ),
        if (showLoadingOverlay)
          Positioned.fill(
            child: Container(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }

}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayRangeCalendar extends StatelessWidget {
  const _DayRangeCalendar({
    required this.profile,
    required this.sessions,
    required this.timeFormat,
    required this.currentDay,
    required this.rangeStart,
    required this.rangeEnd,
    required this.dense,
    this.singleDay = false,
  });

  final JobProfile profile;
  final List<WorkSession> sessions;
  final String timeFormat;
  final DateTime currentDay;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool dense;
  final bool singleDay;

  @override
  Widget build(BuildContext context) {
    final DateTime gridStart = singleDay ? rangeStart : startOfWeek(rangeStart);
    final DateTime gridEnd = singleDay ? rangeEnd : endOfWeek(rangeEnd);
    final List<DateTime> days = singleDay ? <DateTime>[rangeStart] : daysInRange(gridStart, gridEnd);
    final Map<String, List<JobProfileCalendarSlice>> slicesByDay = buildCalendarSlicesByDay(profile, sessions);
    final List<String> weekdayLabels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!singleDay)
          Row(
            children: weekdayLabels
                .map(
                  (String label) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: singleDay ? 1 : 7,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            mainAxisExtent: singleDay ? 132 : 96,
          ),
          itemBuilder: (BuildContext context, int index) {
            final DateTime day = days[index];
            final bool inVisibleRange = !day.isBefore(rangeStart) && !day.isAfter(rangeEnd);
            final bool isToday = _sameDay(day, currentDay);
            final List<JobProfileCalendarSlice> slices = slicesByDay[dateKey(day)] ?? <JobProfileCalendarSlice>[];
            final bool hasSession = slices.isNotEmpty;

            return GestureDetector(
              onTap: hasSession
                  ? () => _showDayDetail(context, day, slices, timeFormat)
                  : null,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isToday ? colorScheme.primary : colorScheme.outlineVariant,
                    width: isToday ? 2 : 1,
                  ),
                  color: isToday
                      ? colorScheme.primaryContainer.withValues(alpha: 0.45)
                      : inVisibleRange
                          ? (hasSession
                              ? colorScheme.primaryContainer.withValues(alpha: 0.50)
                              : colorScheme.surface)
                          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                ),
                padding: EdgeInsets.all(dense ? 6 : 8),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: inVisibleRange ? null : colorScheme.outline,
                        ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _YearOverview extends StatelessWidget {
  const _YearOverview({
    required this.profile,
    required this.sessions,
    required this.timeFormat,
    required this.currentDay,
    required this.referenceDate,
  });

  final JobProfile profile;
  final List<WorkSession> sessions;
  final String timeFormat;
  final DateTime currentDay;
  final DateTime referenceDate;

  @override
  Widget build(BuildContext context) {
    final List<Widget> monthCards = <Widget>[];
    for (int month = 1; month <= 12; month++) {
      final DateTime monthStart = DateTime(referenceDate.year, month, 1);
      final DateTime monthEnd = DateTime(referenceDate.year, month + 1, 0);
      monthCards.add(
        _MonthCard(
          profile: profile,
          sessions: sessions,
          timeFormat: timeFormat,
          currentDay: currentDay,
          monthStart: monthStart,
          monthEnd: monthEnd,
        ),
      );
    }

    return Column(
      children: monthCards
          .map(
            (Widget card) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: card,
            ),
          )
          .toList(),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.profile,
    required this.sessions,
    required this.timeFormat,
    required this.currentDay,
    required this.monthStart,
    required this.monthEnd,
  });

  final JobProfile profile;
  final List<WorkSession> sessions;
  final String timeFormat;
  final DateTime currentDay;
  final DateTime monthStart;
  final DateTime monthEnd;

  @override
  Widget build(BuildContext context) {
    final String monthLabel = DateFormat('MMMM yyyy').format(monthStart);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.65),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              monthLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _DayRangeCalendar(
              profile: profile,
              sessions: sessions,
              timeFormat: timeFormat,
              currentDay: currentDay,
              rangeStart: monthStart,
              rangeEnd: monthEnd,
              dense: false,
              singleDay: false,
            ),
          ],
        ),
      ),
    );
  }
}

void _showDayDetail(
  BuildContext context,
  DateTime day,
  List<JobProfileCalendarSlice> slices,
  String timeFormat,
) {
  final ColorScheme colorScheme = Theme.of(context).colorScheme;
  final String dayLabel = DateFormat('EEEE, MMM d, yyyy').format(day);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (BuildContext context, ScrollController scrollController) {
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      dayLabel,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${slices.length} work session${slices.length != 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: slices.length,
                  itemBuilder: (BuildContext context, int index) {
                    final JobProfileCalendarSlice slice = slices[index];
                    final WorkSession session = slice.session;
                    final Color background = slice.isOvertime ? colorScheme.errorContainer : colorScheme.primaryContainer;
                    final Color foreground = slice.isOvertime ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  '${displayTimeWithSetting(session.clockInTime, timeFormat)} - ${displayTimeWithSetting(session.clockOutTime, timeFormat)}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: foreground,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                Text(
                                  '${slice.totalHours.toStringAsFixed(2)}h',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: foreground,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                            if (slice.isOvertime)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Overtime',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: foreground,
                                      ),
                                ),
                              ),
                            if (session.note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Note: ${session.note}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: foreground,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}


