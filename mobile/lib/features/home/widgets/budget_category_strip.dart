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

// Quiet navy text and a faint stitch, a light nod to the travel patches.
const _ink = Color(0xFF1D5C99);
const _inkDark = Color(0xFF173F66);
const _stitch = Color(0xFFC9D8E6);

/// Horizontally scrolling white budget cards with a faint stitched edge.
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
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        itemCount: budgets.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
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
  Widget build(BuildContext context) => Container(
    width: 150,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.divider),
      boxShadow: [
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: CustomPaint(
          painter: const _StitchPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// Round tinted icon badge.
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color, required this.tint});

  final IconData icon;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
    child: Icon(icon, size: 18, color: color),
  );
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
    final value = b.limit == 0 ? 1.0 : math.min(progress.spent / b.limit, 1.0);
    return _Shell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Badge(
            icon: overall ? Icons.groups_rounded : cat.icon,
            color: overall ? _ink : cat.color,
            tint: overall ? AppColors.mint : cat.tint,
          ),
          const Spacer(),
          Text(
            overall ? 'Whole Family' : cat.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _inkDark,
            ),
          ),
          const SizedBox(height: 7),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.mintTrack,
              borderRadius: BorderRadius.circular(3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: value,
                  heightFactor: 1,
                  child: ColoredBox(
                    color: over ? AppColors.expenseRed : AppColors.lime,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: format(progress.spent),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: _inkDark,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${format(b.limit)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9DB0BF),
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
          _Badge(
            icon: Icons.add_rounded,
            color: _ink,
            tint: AppColors.background,
          ),
          Spacer(),
          Text(
            'New Budget',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _inkDark,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Set a monthly limit for a category.',
            style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// A faint dashed line just inside the card's edge, like stitching.
class _StitchPainter extends CustomPainter {
  const _StitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(6);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    final paint = Paint()
      ..color = _stitch
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      const dash = 4.0, gap = 4.0;
      final n = math.max((metric.length / (dash + gap)).floor(), 1);
      final step = metric.length / n;
      for (var d = 0.0; d < metric.length - 0.1; d += step) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_StitchPainter old) => false;
}
