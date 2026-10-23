import 'dart:math' as math;

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/features/plans/models/plan.dart';
import 'package:finance_tracker/features/plans/models/plan_template.dart';
import 'package:finance_tracker/features/plans/widgets/plan_scene.dart';
import 'package:flutter/material.dart';

/// Icon and colors for each kind of plan.
extension PlanKindStyle on PlanKind {
  IconData get icon => switch (this) {
    PlanKind.trip => Icons.flight_takeoff_rounded,
    PlanKind.event => Icons.celebration_outlined,
    PlanKind.monthly => Icons.calendar_month_rounded,
    PlanKind.custom => Icons.tune_rounded,
  };
  Color get color => switch (this) {
    PlanKind.trip => AppColors.blue,
    PlanKind.event => const Color(0xFFDB2777),
    PlanKind.monthly => AppColors.purple,
    PlanKind.custom => const Color(0xFF0D9488),
  };
  Color get tint => switch (this) {
    PlanKind.trip => AppColors.blueTint,
    PlanKind.event => const Color(0xFFFCE7F3),
    PlanKind.monthly => AppColors.purpleTint,
    PlanKind.custom => const Color(0xFFDDF4F1),
  };
  String get label => switch (this) {
    PlanKind.trip => 'Trip',
    PlanKind.event => 'Event',
    PlanKind.monthly => 'Monthly',
    PlanKind.custom => 'Custom',
  };
}

/// "5 days left", "Starts in 3 days" or "Ended".
String planStatus(Plan p, DateTime now) {
  if (p.isPast(now)) return 'Ended';
  if (p.isUpcoming(now)) {
    final days = DateTime(
      p.start.year,
      p.start.month,
      p.start.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    return days == 1 ? 'Starts tomorrow' : 'Starts in $days days';
  }
  final left = p.daysLeft(now);
  return left == 1 ? 'Last day' : '$left days left';
}

/// Compact card for a plan that's on or coming up: painted scene, name,
/// dates and status, with spent / total and a bar along the bottom. Sized
/// to sit in a sideways strip so several plans fit without scrolling down.
class PlanStripCard extends StatelessWidget {
  const PlanStripCard({
    super.key,
    required this.plan,
    required this.spent,
    required this.memberCount,
    required this.onTap,
  });

  final Plan plan;
  final double spent;
  final int memberCount;
  final VoidCallback onTap;

  static const height = 150.0;

  @override
  Widget build(BuildContext context) {
    final total = plan.total;
    final over = spent > total;
    const shadow = [Shadow(color: Color(0x66000000), blurRadius: 8)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PlanScene(plan: plan),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33102040),
                  Color(0x00102040),
                  Color(0xB3102040),
                ],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppTheme.displayFont,
                                  fontFamilyFallback: AppTheme.displayFallback,
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                  shadows: shadow,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${formatDateRange(plan.start, plan.end)}'
                                '${memberCount > 1 ? ' · $memberCount people' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  shadows: shadow,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            planStatus(plan, DateTime.now()),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.tealDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatAmount(spent),
                          style: TextStyle(
                            fontFamily: AppTheme.displayFont,
                            fontFamilyFallback: AppTheme.displayFallback,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: over
                                ? const Color(0xFFFCA5A5)
                                : Colors.white,
                            shadows: shadow,
                          ),
                        ),
                        Text(
                          ' / ${formatAmount(total)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            shadows: shadow,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _percent(spent, total),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            shadows: shadow,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        height: 5,
                        color: Colors.white.withValues(alpha: 0.35),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _ratio(spent, total),
                          child: Container(
                            color: over
                                ? const Color(0xFFFCA5A5)
                                : AppColors.lime,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One slim line for any other plan: thumbnail, name and status, spent over
/// total with a hairline bar. Rows sit in one block split by dividers.
class PlanRow extends StatelessWidget {
  const PlanRow({
    super.key,
    required this.plan,
    required this.spent,
    required this.onTap,
  });

  final Plan plan;
  final double spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = plan.total;
    final over = spent > total;
    final now = DateTime.now();
    final ended = plan.isPast(now);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Opacity(
                    opacity: ended ? 0.55 : 1,
                    child: PlanScene(plan: plan),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDateRange(plan.start, plan.end)} · '
                      '${planStatus(plan, now)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _Bar(value: _ratio(spent, total), over: over, height: 3),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatAmount(spent),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: over
                          ? AppColors.expenseRed
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'of ${formatAmount(total)}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _ratio(double spent, double total) =>
    total <= 0 ? 0 : math.min(spent / total, 1);

String _percent(double spent, double total) =>
    total <= 0 ? '0%' : '${(spent / total * 100).round()}%';

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.over, required this.height});

  final double value;
  final bool over;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: Container(
      height: height,
      color: AppColors.progressTrack,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value,
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height),
            gradient: LinearGradient(
              colors: over
                  ? const [Color(0xFFF87171), AppColors.expenseRed]
                  : const [AppColors.lime, AppColors.lime],
            ),
          ),
        ),
      ),
    ),
  );
}

/// One template in the "Plan Templates" grid.
class PlanTemplateTile extends StatelessWidget {
  const PlanTemplateTile({
    super.key,
    required this.template,
    required this.onTap,
  });

  final PlanTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.divider),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.blueTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(template.icon, color: AppColors.blue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      template.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
