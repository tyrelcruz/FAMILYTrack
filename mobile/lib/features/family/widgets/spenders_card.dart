import 'dart:math' as math;

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/widgets/member_avatar.dart';
import 'package:flutter/material.dart';

class Spender {
  const Spender({
    required this.member,
    required this.spent,
    required this.count,
    required this.tags,
  });

  final FamilyMember member;
  final double spent;

  /// Number of expenses this month.
  final int count;

  /// e.g. ["You", "Owner"] or ["No account"].
  final List<String> tags;
}

/// "Who's spending": members ranked by what they spent, with each
/// person's share of the family total.
class SpendersCard extends StatelessWidget {
  const SpendersCard({
    super.key,
    required this.spenders,
    required this.total,
    required this.onTap,
  });

  final List<Spender> spenders;
  final double total;
  final ValueChanged<FamilyMember> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          for (var i = 0; i < spenders.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 60, color: AppColors.divider),
            _SpenderRow(
              spender: spenders[i],
              share: total == 0 ? 0 : spenders[i].spent / total,
              onTap: () => onTap(spenders[i].member),
            ),
          ],
        ],
      ),
    );
  }
}

class _SpenderRow extends StatelessWidget {
  const _SpenderRow({
    required this.spender,
    required this.share,
    required this.onTap,
  });

  final Spender spender;
  final double share;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = spender.member;
    final count = spender.count;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            MemberAvatar(m, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Name and tags take the free space so the amount
                      // lines up on the right.
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                m.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            for (final t in spender.tags) ...[
                              const SizedBox(width: 6),
                              _Tag(t),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatAmount(spender.spent),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    count == 0
                        ? 'No spending yet'
                        : '$count ${count == 1 ? 'expense' : 'expenses'} · '
                              '${(share * 100).round()}% of the family',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: math.min(share, 1),
                      minHeight: 5,
                      backgroundColor: AppColors.progressTrack,
                      color: m.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final you = label == 'You';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: you ? AppColors.blueTint : AppColors.neutralTint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: you ? AppColors.blue : AppColors.textSecondary,
        ),
      ),
    );
  }
}
