import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/transfers/models/transfer.dart';

/// A transfer in a list, styled like the expense rows but neutral:
/// "Cash → E-wallet" or "Ana → Sam", amount without a sign.
class TransferRow extends StatelessWidget {
  const TransferRow({super.key, required this.transfer, required this.onTap});

  final Transfer transfer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilyProvider>();
    final t = transfer;
    final people = t.kind == TransferKind.people;
    final title = people
        ? '${family.memberFor(t.fromMemberId).name} → '
              '${family.memberFor(t.toMemberId).name}'
        : '${t.fromMethod?.label ?? '?'} → ${t.toMethod?.label ?? '?'}';
    final detail = [
      if (t.note.isNotEmpty) t.note else (people ? 'Gave money' : 'Transfer'),
      formatTime(t.date),
    ].join(' • ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.neutralTint,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                people ? Icons.people_alt_outlined : Icons.swap_horiz_rounded,
                color: AppColors.textSecondary,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatAmount(t.amount),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
