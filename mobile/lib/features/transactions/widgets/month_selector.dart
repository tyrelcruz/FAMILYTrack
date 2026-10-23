import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';

class MonthSelector extends StatelessWidget {
  const MonthSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Arrow(Icons.chevron_left_rounded, () => p.changeMonth(-1)),
          SizedBox(
            width: 170,
            child: Text(
              formatMonth(p.month),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _Arrow(Icons.chevron_right_rounded, () => p.changeMonth(1)),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow(this.icon, this.onTap);

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.textPrimary, size: 20.5),
        ),
      ),
    );
  }
}
