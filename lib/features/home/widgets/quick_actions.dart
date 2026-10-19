import 'dart:math' as math;

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({
    super.key,
    required this.onSend,
    required this.onRequest,
    required this.onTopUp,
    required this.onMore,
  });

  final VoidCallback onSend;
  final VoidCallback onRequest;
  final VoidCallback onTopUp;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    Widget divider() =>
        Container(width: 1, height: 72, color: AppColors.divider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          _Action(
            label: 'Send',
            color: AppColors.green,
            tint: AppColors.greenTint,
            onTap: onSend,
            icon: Transform.rotate(
              angle: -math.pi / 4,
              child: const Icon(
                Icons.send_outlined,
                color: AppColors.green,
                size: 24,
              ),
            ),
          ),
          divider(),
          _Action(
            label: 'Request',
            color: AppColors.blue,
            tint: AppColors.blueTint,
            onTap: onRequest,
            icon: const Icon(
              Icons.south_west_rounded,
              color: AppColors.blue,
              size: 26,
            ),
          ),
          divider(),
          _Action(
            label: 'Top Up',
            color: AppColors.purple,
            tint: AppColors.purpleTint,
            onTap: onTopUp,
            icon: const Icon(
              Icons.credit_card_outlined,
              color: AppColors.purple,
              size: 26,
            ),
          ),
          divider(),
          _Action(
            label: 'More',
            color: AppColors.textPrimary,
            tint: AppColors.neutralTint,
            onTap: onMore,
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: AppColors.textPrimary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.color,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final Color color;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: tint,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
