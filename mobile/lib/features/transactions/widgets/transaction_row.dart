import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/features/categories/models/category.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:flutter/material.dart';

/// Row used inside the white cards: tinted category icon, title, time and
/// amount. Income is shown in green with a plus sign.
class TransactionRow extends StatelessWidget {
  const TransactionRow({super.key, required this.item, required this.onTap});

  final TransactionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cat = Category.byId(item.categoryId);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: cat.tint,
                shape: BoxShape.circle,
              ),
              child: Icon(cat.icon, color: cat.color, size: 22.5),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Stays on one line like the design; shrinks on narrow screens.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formatTimeAndDate(item.date),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${item.isExpense ? '' : '+'}${formatMoney(item.amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: item.isExpense ? AppColors.textPrimary : AppColors.green,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
