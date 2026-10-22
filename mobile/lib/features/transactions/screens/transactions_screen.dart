import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/core/widgets/circle_button.dart';
import 'package:finance_tracker/core/widgets/empty_state.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';
import 'package:finance_tracker/features/transactions/screens/add_activity_sheet.dart';
import 'package:finance_tracker/features/transactions/screens/add_transaction_screen.dart';
import 'package:finance_tracker/features/transactions/widgets/activity_row.dart';
import 'package:finance_tracker/features/transactions/widgets/month_selector.dart';
import 'package:finance_tracker/features/transfers/models/transfer.dart';
import 'package:finance_tracker/features/transfers/providers/transfer_provider.dart';
import 'package:finance_tracker/features/transfers/screens/transfer_sheet.dart';
import 'package:finance_tracker/features/transfers/widgets/transfer_row.dart';

/// Full list of the selected month's transactions, grouped by day.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  /// null shows both income and expenses.
  TransactionType? _filter;

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  void _delete(TransactionItem t) {
    final provider = context.read<FinanceProvider>();
    provider.remove(t.id!);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted “${t.title}”'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => provider.add(t),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    final items = p.monthItems
        .where((t) => _filter == null || t.type == _filter)
        .toList();

    // Transfers only show under "All"; they aren't income or expense.
    final transfers = _filter != null
        ? const <Transfer>[]
        : context
              .watch<TransferProvider>()
              .all
              .where(
                (t) =>
                    t.date.year == p.month.year &&
                    t.date.month == p.month.month,
              )
              .toList();

    // Group into days, newest first.
    DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
    final days = <DateTime, List<TransactionItem>>{};
    for (final t in items) {
      days.putIfAbsent(dayOf(t.date), () => []).add(t);
    }
    final transfersByDay = <DateTime, List<Transfer>>{};
    for (final t in transfers) {
      transfersByDay.putIfAbsent(dayOf(t.date), () => []).add(t);
      days.putIfAbsent(dayOf(t.date), () => []);
    }
    final dayKeys = days.keys.toList()..sort((a, b) => b.compareTo(a));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              Row(
                children: [
                  CircleButton(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Transactions',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontFamilyFallback: AppTheme.displayFallback,
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  CircleButton(
                    onTap: () => showAddActivitySheet(context),
                    child: const Icon(
                      Icons.add_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const MonthSelector(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TotalCard(
                      label: 'Income',
                      amount: p.monthIncome,
                      icon: Icons.south_west_rounded,
                      color: AppColors.green,
                      tint: AppColors.greenTint,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _TotalCard(
                      label: 'Expenses',
                      amount: p.monthExpense,
                      icon: Icons.north_east_rounded,
                      color: AppColors.expenseRed,
                      tint: AppColors.redTint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _FilterToggle(
                value: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty && transfers.isEmpty)
                const EmptyState('No transactions this month'),
              for (final day in dayKeys) ...[
                _DayHeader(day: day, items: days[day]!),
                for (final t in transfersByDay[day] ?? const <Transfer>[])
                  TransferRow(
                    transfer: t,
                    onTap: () => showTransferSheet(context, existing: t),
                  ),
                for (final t in days[day]!)
                  Dismissible(
                    key: ValueKey(t.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 22),
                      decoration: BoxDecoration(
                        color: AppColors.redTint,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.red,
                      ),
                    ),
                    onDismissed: (_) => _delete(t),
                    child: ActivityRow(
                      item: t,
                      onTap: () => _push(AddTransactionScreen(existing: t)),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.tint,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatAmount(amount),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterToggle extends StatelessWidget {
  const _FilterToggle({required this.value, required this.onChanged});

  final TransactionType? value;
  final ValueChanged<TransactionType?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, TransactionType? v) {
      final selected = value == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: selected ? AppColors.softShadow : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.neutralTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          tab('All', null),
          tab('Expenses', TransactionType.expense),
          tab('Income', TransactionType.income),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.items});

  final DateTime day;
  final List<TransactionItem> items;

  @override
  Widget build(BuildContext context) {
    final net = items.fold(
      0.0,
      (s, t) => s + (t.isExpense ? -t.amount : t.amount),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              formatDayHeader(day),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '${net < 0 ? '-' : '+'}${formatAmount(net.abs())}',
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
