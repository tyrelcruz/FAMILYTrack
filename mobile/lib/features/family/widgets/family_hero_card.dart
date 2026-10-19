import 'dart:math' as math;

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/widgets/avatar_stack.dart';
import 'package:flutter/material.dart';

/// Gradient card, matching the home balance card: what the whole family
/// spent in a month, against the monthly budget if there is one.
class FamilyHeroCard extends StatelessWidget {
  const FamilyHeroCard({
    super.key,
    required this.month,
    required this.spent,
    required this.budget,
    required this.members,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onEditBudget,
  });

  final DateTime month;
  final double spent;
  final double? budget;
  final List<FamilyMember> members;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onEditBudget;

  static const _white70 = Color(0xD9FFFFFF);

  @override
  Widget build(BuildContext context) {
    final limit = budget;
    final over = limit != null && spent > limit;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: AppColors.cardGradient,
          stops: [0, 0.45, 0.78, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardGradient[1].withValues(alpha: 0.30),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MonthArrow(Icons.chevron_left_rounded, onPrevMonth),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  formatMonth(month),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _MonthArrow(Icons.chevron_right_rounded, onNextMonth),
              const Spacer(),
              AvatarStack(members: members, size: 32),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Family spent',
            style: TextStyle(
              color: _white70,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatAmount(spent),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (limit != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: limit == 0 ? 1 : math.min(spent / limit, 1),
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                color: over ? AppColors.trendDown : Colors.white,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  limit == null
                      ? 'No monthly budget yet'
                      : over
                      ? '${formatAmount(spent - limit)} over the '
                            '${formatAmount(limit)} budget'
                      : '${formatAmount(limit - spent)} left of '
                            '${formatAmount(limit)}',
                  style: TextStyle(
                    color: over ? AppColors.trendDown : _white70,
                    fontSize: 14.5,
                    fontWeight: over ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              Material(
                color: Colors.white,
                shape: const StadiumBorder(),
                child: InkWell(
                  onTap: onEditBudget,
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Text(
                      limit == null ? 'Set budget' : 'Edit budget',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow(this.icon, this.onTap);

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.2),
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 30,
        height: 30,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    ),
  );
}
