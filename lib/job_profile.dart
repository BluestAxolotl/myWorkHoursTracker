import 'dart:math';

enum PayPeriod { daily, weekly, biweekly, monthly }

enum Weekday { mon, tues, wed, thurs, fri, sat, sun }

enum OvertimeMode { daily, byPayPeriod }

String payPeriodLabel(PayPeriod value) {
  switch (value) {
    case PayPeriod.daily:
      return 'Daily';
    case PayPeriod.weekly:
      return 'Weekly';
    case PayPeriod.biweekly:
      return 'Biweekly';
    case PayPeriod.monthly:
      return 'Monthly';
  }
}

String weekdayLabel(Weekday value) {
  switch (value) {
    case Weekday.mon:
      return 'Mon';
    case Weekday.tues:
      return 'Tues';
    case Weekday.wed:
      return 'Wed';
    case Weekday.thurs:
      return 'Thurs';
    case Weekday.fri:
      return 'Fri';
    case Weekday.sat:
      return 'Sat';
    case Weekday.sun:
      return 'Sun';
  }
}

String overtimeModeLabel(OvertimeMode value) {
  switch (value) {
    case OvertimeMode.daily:
      return 'Daily';
    case OvertimeMode.byPayPeriod:
      return 'By pay period';
  }
}

int payPeriodDays(PayPeriod period) {
  switch (period) {
    case PayPeriod.daily:
      return 1;
    case PayPeriod.weekly:
      return 7;
    case PayPeriod.biweekly:
      return 14;
    case PayPeriod.monthly:
      return 30;
  }
}

class JobProfile {
  const JobProfile({
    this.id,
    required this.name,
    required this.payRate,
    required this.payPeriod,
    this.payDayOfWeek,
    this.payDayOfMonth,
    required this.breaksPaid,
    this.unpaidBreakCount,
    required this.lunchPaid,
    required this.overtimePaid,
    this.overtimeMode,
    this.overtimeThresholdHours,
    this.overtimeMultiplier,
  });

  final int? id;
  final String name;
  final double payRate;
  final PayPeriod payPeriod;
  final Weekday? payDayOfWeek;
  final int? payDayOfMonth;
  final bool breaksPaid;
  final int? unpaidBreakCount;
  final bool lunchPaid;
  final bool overtimePaid;
  final OvertimeMode? overtimeMode;
  final int? overtimeThresholdHours;
  final double? overtimeMultiplier;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'pay_rate': payRate.toStringAsFixed(2),
      'pay_period': payPeriod.name,
      'pay_day_of_week': payDayOfWeek?.name,
      'pay_day_of_month': payDayOfMonth,
      'breaks_paid': breaksPaid ? 1 : 0,
      'unpaid_break_count': unpaidBreakCount,
      'lunch_paid': lunchPaid ? 1 : 0,
      'overtime_paid': overtimePaid ? 1 : 0,
      'overtime_mode': overtimeMode?.name,
      'overtime_threshold_hours': overtimeThresholdHours,
      'overtime_multiplier': overtimeMultiplier?.toStringAsFixed(2),
    };
  }

  JobProfile copyWith({
    int? id,
    String? name,
    double? payRate,
    PayPeriod? payPeriod,
    Weekday? payDayOfWeek,
    int? payDayOfMonth,
    bool? breaksPaid,
    int? unpaidBreakCount,
    bool? lunchPaid,
    bool? overtimePaid,
    OvertimeMode? overtimeMode,
    int? overtimeThresholdHours,
    double? overtimeMultiplier,
  }) {
    return JobProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      payRate: payRate ?? this.payRate,
      payPeriod: payPeriod ?? this.payPeriod,
      payDayOfWeek: payDayOfWeek ?? this.payDayOfWeek,
      payDayOfMonth: payDayOfMonth ?? this.payDayOfMonth,
      breaksPaid: breaksPaid ?? this.breaksPaid,
      unpaidBreakCount: unpaidBreakCount ?? this.unpaidBreakCount,
      lunchPaid: lunchPaid ?? this.lunchPaid,
      overtimePaid: overtimePaid ?? this.overtimePaid,
      overtimeMode: overtimeMode ?? this.overtimeMode,
      overtimeThresholdHours:
          overtimeThresholdHours ?? this.overtimeThresholdHours,
      overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
    );
  }

  static JobProfile fromMap(Map<String, Object?> map) {
    return JobProfile(
      id: map['id'] as int?,
      name: map['name'] as String,
      payRate: double.tryParse((map['pay_rate'] ?? '0').toString()) ?? 0,
      payPeriod: PayPeriod.values.firstWhere(
        (PayPeriod period) => period.name == map['pay_period'],
        orElse: () => PayPeriod.weekly,
      ),
      payDayOfWeek: map['pay_day_of_week'] == null
          ? null
          : Weekday.values.firstWhere(
              (Weekday day) => day.name == map['pay_day_of_week'],
              orElse: () => Weekday.mon,
            ),
      payDayOfMonth: map['pay_day_of_month'] as int?,
      breaksPaid: (map['breaks_paid'] as int? ?? 0) == 1,
      unpaidBreakCount: map['unpaid_break_count'] as int?,
      lunchPaid: (map['lunch_paid'] as int? ?? 0) == 1,
      overtimePaid: (map['overtime_paid'] as int? ?? 0) == 1,
      overtimeMode: map['overtime_mode'] == null
          ? null
          : OvertimeMode.values.firstWhere(
              (OvertimeMode mode) => mode.name == map['overtime_mode'],
              orElse: () => OvertimeMode.daily,
            ),
      overtimeThresholdHours: map['overtime_threshold_hours'] as int?,
      overtimeMultiplier: map['overtime_multiplier'] == null
          ? null
          : double.tryParse(map['overtime_multiplier'].toString()),
    );
  }

  String get formattedPayRate => payRate.toStringAsFixed(2);

  String? get formattedOvertimeMultiplier => overtimeMultiplier?.toStringAsFixed(2);

  int maxThresholdForPayPeriod() {
    return max(23, payPeriodDays(payPeriod) * 24);
  }
}
