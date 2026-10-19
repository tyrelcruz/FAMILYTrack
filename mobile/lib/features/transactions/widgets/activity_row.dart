import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/features/categories/models/category.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Transaction row on the page background: bordered icon tile, title,
/// "Category • time" and a red/green amount. In a family of two or more,
/// the tile carries the avatar of whoever made it.
class ActivityRow extends StatelessWidget {
  const ActivityRow({
    super.key,
    required this.item,
    required this.onTap,
    this.format = formatAmount,
    this.subtitle,
  });

  final TransactionItem item;
  final VoidCallback onTap;

  /// Formats (or hides) the amount.
  final String Function(double) format;

  /// Replaces "Category • time" under the title.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cat = Category.byId(item.categoryId);
    final family = context.watch<FamilyProvider>();
    final who = family.members.length > 1
        ? family.memberFor(item.memberId)
        : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Icon(cat.icon, color: cat.color, size: 28),
                ),
                if (who != null)
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Tooltip(
                      message: who.name,
                      // Solid so it reads at a glance at this size.
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: who.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          who.initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subtitle ?? cat.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: const BoxDecoration(
                          color: AppColors.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        // Plan expenses span days, so they show the date.
                        subtitle == null
                            ? formatTime(item.date)
                            : formatShortDay(item.date),
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${item.isExpense ? '-' : '+'}${format(item.amount)}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: item.isExpense ? AppColors.expenseRed : AppColors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
