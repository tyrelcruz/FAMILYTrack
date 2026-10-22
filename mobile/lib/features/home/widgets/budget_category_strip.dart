import 'dart:math' as math;

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/features/categories/models/category.dart';
import 'package:finance_tracker/features/family/models/budget.dart';
import 'package:flutter/material.dart';

class BudgetProgress {
  const BudgetProgress(this.budget, this.spent);

  final Budget budget;
  final double spent;
}

/// Horizontally scrolling budget cards that run off the right edge.
class BudgetCategoryStrip extends StatelessWidget {
  const BudgetCategoryStrip({
    super.key,
    required this.budgets,
    required this.format,
    required this.onTap,
    required this.onAdd,
  });

  final List<BudgetProgress> budgets;

  /// Formats (or hides) an amount.
  final String Function(double) format;
  final ValueChanged<Budget> onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 184,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        itemCount: budgets.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, i) => i == budgets.length
            ? _AddCard(onTap: onAdd)
            : _BudgetCard(
                progress: budgets[i],
                format: format,
                onTap: () => onTap(budgets[i].budget),
              ),
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(padding: const EdgeInsets.all(18), child: child),
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.progress,
    required this.format,
    required this.onTap,
  });

  final BudgetProgress progress;
  final String Function(double) format;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = progress.budget;
    final cat = Category.byId(b.categoryId);
    final overall = b.isOverall;
    final over = progress.spent > b.limit;
    return _Shell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: overall ? AppColors.blueTint : cat.tint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              overall ? Icons.groups_outlined : cat.icon,
              color: overall ? AppColors.blue : cat.color,
              size: 21,
            ),
          ),
          const Spacer(),
          Text(
            overall ? 'Whole Family' : cat.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: b.limit == 0 ? 1 : math.min(progress.spent / b.limit, 1),
              minHeight: 5,
              backgroundColor: AppColors.progressTrack,
              color: over ? AppColors.expenseRed : AppColors.accentBlue,
            ),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: format(progress.spent),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: '  / ${format(b.limit)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  const _AddCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Shell(
      onTap: onTap,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.neutralTint,
                borderRadius: BorderRadius.all(Radius.circular(11)),
              ),
              child: Icon(
                Icons.add_rounded,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
          ),
          Spacer(),
          Text(
            'New Budget',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Set a monthly limit for a category.',
            style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
