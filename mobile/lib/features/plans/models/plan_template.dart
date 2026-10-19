import 'package:flutter/material.dart';

import 'package:finance_tracker/features/plans/models/plan.dart';

/// A starting point for a new plan: kind, length and how it's split.
class PlanTemplate {
  const PlanTemplate({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.kind,
    required this.suggestedName,
    this.days = 1,
    this.split = SplitMode.equal,
    this.startOnWeekend = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final PlanKind kind;
  final String suggestedName;

  /// Length of a trip, both ends included.
  final int days;
  final SplitMode split;

  /// Starts on the coming Friday instead of today.
  final bool startOnWeekend;

  DateTimeRange range(DateTime today) {
    final start = startOnWeekend
        ? today.add(Duration(days: (DateTime.friday - today.weekday) % 7))
        : today;
    return DateTimeRange(
      start: start,
      end: start.add(Duration(days: days - 1)),
    );
  }

  static const all = [
    PlanTemplate(
      title: 'Weekend Getaway',
      subtitle: '3–7 days',
      icon: Icons.explore_outlined,
      kind: PlanKind.trip,
      suggestedName: 'Weekend getaway',
      days: 3,
      startOnWeekend: true,
    ),
    PlanTemplate(
      title: 'International Trip',
      subtitle: '7+ days',
      icon: Icons.public_rounded,
      kind: PlanKind.trip,
      suggestedName: 'International trip',
      days: 7,
    ),
    PlanTemplate(
      title: 'Group Vacation',
      subtitle: 'Custom',
      icon: Icons.groups_2_outlined,
      kind: PlanKind.trip,
      suggestedName: 'Group vacation',
      days: 5,
      split: SplitMode.custom,
    ),
    PlanTemplate(
      title: 'Event & Celebration',
      subtitle: 'Birthdays, Events, etc.',
      icon: Icons.celebration_outlined,
      kind: PlanKind.event,
      suggestedName: 'Birthday party',
    ),
    PlanTemplate(
      title: 'Monthly Budget',
      subtitle: 'A whole month',
      icon: Icons.calendar_month_rounded,
      kind: PlanKind.monthly,
      suggestedName: 'Monthly budget',
    ),
    PlanTemplate(
      title: 'Holiday Season',
      subtitle: 'Christmas & New Year',
      icon: Icons.card_giftcard_rounded,
      kind: PlanKind.trip,
      suggestedName: 'Holiday season',
      days: 14,
    ),
  ];
}
