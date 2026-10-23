import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/widgets/empty_state.dart';
import 'package:finance_tracker/features/categories/models/category.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';

/// Latest transactions, grouped by day into soft rounded blocks of compact
/// rows, with a "see all" footer.
class RecentActivity extends StatelessWidget {
  const RecentActivity({
    super.key,
    required this.items,
    required this.format,
    required this.onTap,
    this.total,
    this.onSeeAll,
  });

  /// Newest first.
  final List<TransactionItem> items;
  final String Function(double) format;
  final ValueChanged<TransactionItem> onTap;

  /// How many there are in all, for the footer; defaults to [items].
  final int? total;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const EmptyState('No activity yet');
    final days = <DateTime, List<TransactionItem>>{};
    for (final t in items) {
      days
          .putIfAbsent(
            DateTime(t.date.year, t.date.month, t.date.day),
            () => [],
          )
          .add(t);
    }
    final all = total ?? items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final MapEntry(key: day, value: list) in days.entries) ...[
          _DayLabel(day: day, items: list, format: format),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 70,
                      color: AppColors.divider,
                    ),
                  _Row(
                    item: list[i],
                    format: format,
                    onTap: () => onTap(list[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (onSeeAll != null)
          Center(
            child: InkWell(
              onTap: onSeeAll,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all $all ${all == 1 ? 'transaction' : 'transactions'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tealDark,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: AppColors.tealDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Today" with the day's net on the right, both quiet.
class _DayLabel extends StatelessWidget {
  const _DayLabel({
    required this.day,
    required this.items,
    required this.format,
  });

  final DateTime day;
  final List<TransactionItem> items;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final net = items.fold(
      0.0,
      (s, t) => s + (t.isExpense ? -t.amount : t.amount),
    );
    final today = DateUtils.dateOnly(DateTime.now());
    final label = day == today
        ? 'Today'
        : day == today.subtract(const Duration(days: 1))
        ? 'Yesterday'
        : DateFormat('EEEE, MMM d').format(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            '${net < 0 ? '−' : '+'}${format(net.abs())}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.format, required this.onTap});

  final TransactionItem item;
  final String Function(double) format;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cat = Category.byId(item.categoryId);
    final family = context.watch<FamilyProvider>();
    final who = family.members.length > 1
        ? family.memberFor(item.memberId)
        : null;
    final meta = [cat.name, ?who?.name].join('  ·  ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        child: Row(
          children: [
            // Neutral circle; only the icon carries the category color.
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(cat.icon, color: cat.color, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (item.hasAnyPhoto) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.photo_camera_outlined,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.isExpense ? '−' : '+'}${format(item.amount)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: item.isExpense
                        ? AppColors.textPrimary
                        : AppColors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('h:mm a').format(item.date),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
