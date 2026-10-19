import 'dart:math' as math;

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/widgets/avatar_stack.dart';
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

/// Big card for the current plan: painted scene with name, dates and who's
/// in it, then spent / total with a progress bar.
class FeaturedPlanCard extends StatelessWidget {
  const FeaturedPlanCard({
    super.key,
    required this.plan,
    required this.spent,
    required this.members,
    required this.onTap,
  });

  final Plan plan;
  final double spent;
  final List<FamilyMember> members;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = plan.total;
    final over = spent > total;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppColors.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 170,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PlanScene(plan: plan),
                      // Darkens the left so the white text reads.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0x99102040), Color(0x00102040)],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                                shadows: [
                                  Shadow(
                                    color: Color(0x55000000),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDateRange(plan.start, plan.end),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(
                                    color: Color(0x55000000),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                AvatarStack(members: members, size: 32),
                                const SizedBox(width: 10),
                                Text(
                                  '${members.length} '
                                  '${members.length == 1 ? 'member' : 'members'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formatAmount(spent),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                              color: over
                                  ? AppColors.expenseRed
                                  : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            ' / ${formatAmount(total)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _percent(spent, total),
                            style: const TextStyle(
                              fontSize: 14.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Bar(value: _ratio(spent, total), over: over, height: 8),
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
}

/// Row card for the rest of the plans: scene thumbnail, name, dates,
/// spent / total and percent.
class PlanListCard extends StatelessWidget {
  const PlanListCard({
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
    final ended = plan.isPast(DateTime.now());
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 74,
                    height: 74,
                    child: Opacity(
                      opacity: ended ? 0.55 : 1,
                      child: PlanScene(plan: plan),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        ended
                            ? '${formatDateRange(plan.start, plan.end)} · Ended'
                            : formatDateRange(plan.start, plan.end),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: formatAmount(spent),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: over
                                    ? AppColors.expenseRed
                                    : AppColors.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${formatAmount(total)}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _Bar(
                              value: _ratio(spent, total),
                              over: over,
                              height: 6,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _percent(spent, total),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
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
                  : const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
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
      boxShadow: AppColors.softShadow,
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
                child: Icon(template.icon, color: AppColors.blue, size: 21),
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
                        fontSize: 13.5,
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
                        fontSize: 12,
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
