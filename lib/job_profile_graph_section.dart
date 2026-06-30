import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'job_profile.dart';
import 'job_profile_graph_view_model.dart';
import 'main.dart';
import 'work_session.dart';

class JobProfileGraphSection extends StatefulWidget {
  const JobProfileGraphSection({
    super.key,
    required this.profile,
    required this.appSettings,
    this.totalsSessionsLoader,
    this.now,
  });

  final JobProfile profile;
  final AppSettings appSettings;
  final Future<List<WorkSession>> Function(int profileId)? totalsSessionsLoader;
  final DateTime? now;

  @override
  State<JobProfileGraphSection> createState() => JobProfileGraphSectionState();
}

class JobProfileGraphSectionState extends State<JobProfileGraphSection> {
  JobProfileGraphViewModel? _viewModel;
  bool _isLoading = true;
  int? _selectedPointIndex;

  @override
  void initState() {
    super.initState();
    _loadViewModel();
  }

  Future<void> _loadViewModel() async {
    final JobProfileGraphViewModel vm = await JobProfileGraphViewModel.create(
      profile: widget.profile,
      now: widget.now,
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

  void _selectPoint(int? index) {
    if (_selectedPointIndex == index) {
      return;
    }

    setState(() {
      _selectedPointIndex = index;
    });
  }

  Future<void> refreshGraph() async {
    await _viewModel?.refreshSessions();
  }

  @override
  void didUpdateWidget(covariant JobProfileGraphSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.now != widget.now) {
      _viewModel?.updateNow(widget.now);
    }
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

    final JobProfileGraphViewModel vm = _viewModel!;
    final ThemeData theme = Theme.of(context);
    final bool showAllXAxisLabels = true;
    final List<_GraphSeriesPoint> seriesPoints = vm.points
        .map(
          (JobProfileGraphPoint point) => _GraphSeriesPoint(
            label: formatGraphPointLabel(vm.viewMode, point),
            totalHours: point.summary.totalHours,
            regularHours: point.summary.regularHours,
            overtimeHours: point.summary.overtimeHours,
            regularPay: point.summary.regularPay,
            overtimePay: point.summary.overtimePay,
            totalPay: point.summary.totalPay,
          ),
        )
        .toList();
    final int? selectedPointIndex = _selectedPointIndex != null && _selectedPointIndex! < seriesPoints.length ? _selectedPointIndex : null;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Hours & earnings graph',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ToggleButtons(
              isSelected: <bool>[
                vm.viewMode == JobProfileGraphViewMode.payPeriod,
                vm.viewMode == JobProfileGraphViewMode.monthly,
                vm.viewMode == JobProfileGraphViewMode.yearly,
              ],
              onPressed: (int index) {
                _selectPoint(null);
                switch (index) {
                  case 0:
                    vm.setViewMode(JobProfileGraphViewMode.payPeriod);
                    break;
                  case 1:
                    vm.setViewMode(JobProfileGraphViewMode.monthly);
                    break;
                  case 2:
                    vm.setViewMode(JobProfileGraphViewMode.yearly);
                    break;
                }
              },
              children: const <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Pay period'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Month'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Year'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _subtitle(vm),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _LegendItem(
                  color: theme.colorScheme.primary,
                  label: 'Hours worked',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap a point for regular hours, overtime, and pay.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (seriesPoints.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No work sessions available for the graph.'),
              )
            else
              SizedBox(
                height: 280,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final _GraphChartLayout layout = _GraphChartLayout.build(
                      points: seriesPoints,
                      width: max(
                        constraints.maxWidth - _HoursAxis.axisWidth,
                        seriesPoints.length * _TrendGraphPainter.pointSpacing,
                      ),
                    );

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _HoursAxis(
                          width: _HoursAxis.axisWidth,
                          axisColor: theme.colorScheme.outline,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          labelStyle: theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11),
                          textDirection: Directionality.of(context),
                          hoursMax: layout.hoursMax,
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: GestureDetector(
                              key: const ValueKey('job-profile-graph-chart'),
                              behavior: HitTestBehavior.translucent,
                              onTapDown: (TapDownDetails details) {
                                final int? tappedIndex = layout.hitTest(details.localPosition);
                                if (tappedIndex != null) {
                                  _selectPoint(tappedIndex);
                                }
                              },
                              child: SizedBox(
                                width: layout.width,
                                height: 280,
                                child: Stack(
                                  children: <Widget>[
                                    CustomPaint(
                                      size: Size(layout.width, 280),
                                      painter: _TrendGraphPainter(
                                        points: seriesPoints,
                                        hoursColor: theme.colorScheme.primary,
                                        axisColor: theme.colorScheme.outline,
                                        gridColor: theme.colorScheme.outlineVariant,
                                        labelStyle: theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11),
                                        textDirection: Directionality.of(context),
                                        selectedPointIndex: selectedPointIndex,
                                        showAllLabels: showAllXAxisLabels,
                                      ),
                                    ),
                                    if (selectedPointIndex != null)
                                      _GraphDetailBox(
                                        point: seriesPoints[selectedPointIndex],
                                        width: layout.width,
                                        pointOffset: layout.pointOffsets[selectedPointIndex],
                                        currencySymbol: widget.appSettings.currencySymbol,
                                        onClose: () => _selectPoint(null),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle(JobProfileGraphViewModel vm) {
    switch (vm.viewMode) {
      case JobProfileGraphViewMode.payPeriod:
        return 'Pay period trend';
      case JobProfileGraphViewMode.monthly:
        final DateTime reference = vm.points.isNotEmpty ? vm.points.first.window.start : DateTime.now();
        return 'Month trend • ${DateFormat('MMMM yyyy').format(reference)}';
      case JobProfileGraphViewMode.yearly:
        final int year = vm.points.isNotEmpty ? vm.points.first.window.start.year : DateTime.now().year;
        return 'Year trend • $year';
    }
  }

}

class _HoursAxis extends StatelessWidget {
  const _HoursAxis({
    required this.width,
    required this.axisColor,
    required this.backgroundColor,
    required this.labelStyle,
    required this.textDirection,
    required this.hoursMax,
  });

  static const double axisWidth = 52;

  final double width;
  final Color axisColor;
  final Color backgroundColor;
  final TextStyle labelStyle;
  final TextDirection textDirection;
  final double hoursMax;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: double.infinity,
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double chartTop = _TrendGraphPainter.topPadding;
          final double chartBottom = constraints.maxHeight - _TrendGraphPainter.bottomPadding;
          final double chartHeight = chartBottom - chartTop;

          return Padding(
            padding: EdgeInsets.only(top: chartTop, bottom: _TrendGraphPainter.bottomPadding),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: axisColor)),
              ),
              child: Stack(
                children: <Widget>[
                  for (int index = 0; index <= 4; index++)
                    Positioned(
                      top: (chartHeight * (1 - (index / 4))).clamp(0.0, chartHeight - 16),
                      left: 0,
                      right: 8,
                      child: Text(
                        _formatHours(hoursMax * (index / 4)),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                        textDirection: textDirection,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatHours(double value) {
    return value.toStringAsFixed(value >= 10 ? 0 : 1);
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

class _GraphSeriesPoint {
  const _GraphSeriesPoint({
    required this.label,
    required this.totalHours,
    required this.regularHours,
    required this.overtimeHours,
    required this.regularPay,
    required this.overtimePay,
    required this.totalPay,
  });

  final String label;
  final double totalHours;
  final double regularHours;
  final double overtimeHours;
  final double regularPay;
  final double overtimePay;
  final double totalPay;
}

class _TrendGraphPainter extends CustomPainter {
  _TrendGraphPainter({
    required this.points,
    required this.hoursColor,
    required this.axisColor,
    required this.gridColor,
    required this.labelStyle,
    required this.textDirection,
    required this.selectedPointIndex,
    required this.showAllLabels,
  });

  final List<_GraphSeriesPoint> points;
  final Color hoursColor;
  final Color axisColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final TextDirection textDirection;
  final int? selectedPointIndex;
  final bool showAllLabels;

  static const double leftPadding = 16;
  static const double rightPadding = 16;
  static const double topPadding = 20;
  static const double bottomPadding = 64;
  static const double pointSpacing = 120;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    final double chartLeft = leftPadding;
    final double chartRight = size.width - rightPadding;
    final double chartTop = topPadding;
    final double chartBottom = size.height - bottomPadding;
    final double chartWidth = chartRight - chartLeft;
    final double chartHeight = chartBottom - chartTop;
    final double hoursMax = max<double>(1, points.fold<double>(0, (double currentMax, _GraphSeriesPoint point) => max(currentMax, point.totalHours))) * 1.1;

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Paint axisPaint = Paint()
      ..color = axisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final Paint hoursPaint = Paint()
      ..color = hoursColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint selectedPaint = Paint()
      ..color = hoursColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;
    final Paint pointPaint = Paint()..style = PaintingStyle.fill;

    canvas.drawLine(Offset(chartLeft, chartBottom), Offset(chartRight, chartBottom), axisPaint);

    const int ticks = 4;
    for (int index = 0; index <= ticks; index++) {
      final double fraction = index / ticks;
      final double y = chartBottom - (chartHeight * fraction);
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
    }

    final List<Offset> hoursPoints = <Offset>[];
    final double pointCount = max(1, points.length - 1).toDouble();

    for (int index = 0; index < points.length; index++) {
      final _GraphSeriesPoint point = points[index];
      final double x = points.length == 1
          ? chartLeft + (chartWidth / 2)
          : chartLeft + (chartWidth * (index / pointCount));
      final double hoursY = chartBottom - ((point.totalHours / hoursMax) * chartHeight);
      hoursPoints.add(Offset(x, hoursY));
    }

    _drawPath(canvas, hoursPoints, hoursPaint);

    for (final Offset point in hoursPoints) {
      pointPaint.color = hoursColor;
      canvas.drawCircle(point, 4, pointPaint);
    }

    if (selectedPointIndex != null) {
      final int index = selectedPointIndex!;
      if (index < 0 || index >= hoursPoints.length) {
        return;
      }
      final Offset selectedPoint = hoursPoints[index];
      canvas.drawCircle(selectedPoint, 7, selectedPaint);
      canvas.drawCircle(selectedPoint, 4, pointPaint);
    }

    for (int index = 0; index < points.length; index++) {
      final _GraphSeriesPoint point = points[index];
      final double x = hoursPoints[index].dx;
      if (!_shouldPaintLabel(index, points.length)) {
        continue;
      }

      final TextSpan labelSpan = TextSpan(text: point.label, style: labelStyle);
      final TextPainter labelPainter = TextPainter(
        text: labelSpan,
        textDirection: textDirection,
        textAlign: TextAlign.center,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: pointSpacing - 16);
      labelPainter.paint(
        canvas,
        Offset(x - labelPainter.width / 2, chartBottom + 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendGraphPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.hoursColor != hoursColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.gridColor != gridColor ||
      oldDelegate.selectedPointIndex != selectedPointIndex ||
      oldDelegate.showAllLabels != showAllLabels;
  }

  void _drawPath(Canvas canvas, List<Offset> offsets, Paint paint) {
    if (offsets.isEmpty) {
      return;
    }
    final Path path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (int index = 1; index < offsets.length; index++) {
      path.lineTo(offsets[index].dx, offsets[index].dy);
    }
    canvas.drawPath(path, paint);
  }

  bool _shouldPaintLabel(int index, int pointCount) {
    return true;
  }

}

class _GraphChartLayout {
  const _GraphChartLayout({
    required this.width,
    required this.hoursMax,
    required this.pointOffsets,
  });

  final double width;
  final double hoursMax;
  final List<Offset> pointOffsets;

  factory _GraphChartLayout.build({
    required List<_GraphSeriesPoint> points,
    required double width,
  }) {
    final double chartLeft = _TrendGraphPainter.leftPadding;
    final double chartRight = width - _TrendGraphPainter.rightPadding;
    final double chartTop = _TrendGraphPainter.topPadding;
    final double chartBottom = 280 - _TrendGraphPainter.bottomPadding;
    final double chartHeight = chartBottom - chartTop;
    final double hoursMax = max<double>(1, points.fold<double>(0, (double currentMax, _GraphSeriesPoint point) => max(currentMax, point.totalHours))) * 1.1;
    final double pointCount = max(1, points.length - 1).toDouble();
    final List<Offset> pointOffsets = <Offset>[];

    for (int index = 0; index < points.length; index++) {
      final _GraphSeriesPoint point = points[index];
      final double x = points.length == 1
          ? chartLeft + ((chartRight - chartLeft) / 2)
          : chartLeft + ((chartRight - chartLeft) * (index / pointCount));
      final double y = chartBottom - ((point.totalHours / hoursMax) * chartHeight);
      pointOffsets.add(Offset(x, y));
    }

    return _GraphChartLayout(
      width: width,
      hoursMax: hoursMax,
      pointOffsets: pointOffsets,
    );
  }

  int? hitTest(Offset localPosition) {
    if (pointOffsets.isEmpty) {
      return null;
    }

    int nearestIndex = 0;
    double nearestDistance = double.infinity;

    for (int index = 0; index < pointOffsets.length; index++) {
      final double distance = (pointOffsets[index] - localPosition).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }

    return nearestDistance <= 48 ? nearestIndex : null;
  }
}

class _GraphDetailBox extends StatelessWidget {
  const _GraphDetailBox({
    required this.point,
    required this.width,
    required this.pointOffset,
    required this.currencySymbol,
    required this.onClose,
  });

  final _GraphSeriesPoint point;
  final double width;
  final Offset pointOffset;
  final String currencySymbol;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const double boxWidth = 220;
    const double boxHeight = 124;
    final double left = (pointOffset.dx - (boxWidth / 2)).clamp(8.0, max(8.0, width - boxWidth - 8.0));
    final double top = pointOffset.dy >= boxHeight + 24 ? pointOffset.dy - boxHeight - 12 : pointOffset.dy + 16;

    return Positioned(
      left: left,
      top: top,
      child: Material(
        key: const ValueKey('job-profile-graph-detail-box'),
        color: theme.colorScheme.surface,
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: boxWidth,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      point.label,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Close details',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Regular hours: ${point.regularHours.toStringAsFixed(2)}h'),
              Text('Overtime hours: ${point.overtimeHours.toStringAsFixed(2)}h'),
              const SizedBox(height: 4),
              Text('Regular pay: ${_formatMoney(point.regularPay, currencySymbol)}'),
              if (point.overtimeHours > 0)
                Text('Overtime pay: ${_formatMoney(point.overtimePay, currencySymbol)}'),
              Text('Total pay: ${_formatMoney(point.totalPay, currencySymbol)}'),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMoney(double value, String currencySymbol) {
    return '$currencySymbol${value.toStringAsFixed(2)}';
  }
}