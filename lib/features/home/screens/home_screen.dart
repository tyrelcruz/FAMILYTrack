import 'package:finance_tracker/core/widgets/coming_soon.dart';
import 'package:finance_tracker/features/home/widgets/balance_card.dart';
import 'package:finance_tracker/features/home/widgets/expenses_card.dart';
import 'package:finance_tracker/features/home/widgets/home_header.dart';
import 'package:finance_tracker/features/home/widgets/quick_actions.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';
import 'package:finance_tracker/features/transactions/screens/add_transaction_screen.dart';
import 'package:finance_tracker/features/transactions/screens/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onProfileTap});

  final VoidCallback onProfileTap;

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  void _openAllTransactions(BuildContext context) => _push(
    context,
    Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: const TransactionsScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    if (p.loading) return const Center(child: CircularProgressIndicator());
    // Includes the floating nav bar height, since the shell uses extendBody.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(24, 12, 24, bottomInset + 24),
        children: [
          HomeHeader(
            onMenuTap: () => showComingSoon(context, 'Menu'),
            onNotificationsTap: () => showComingSoon(context, 'Notifications'),
            onProfileTap: onProfileTap,
          ),
          const SizedBox(height: 28),
          BalanceCard(
            balance: p.totalBalance,
            changePercent: p.balanceChangePercent,
            onAddCard: () => showComingSoon(context, 'Cards'),
          ),
          const SizedBox(height: 22),
          QuickActions(
            onSend: () => _push(context, const AddTransactionScreen()),
            onRequest: () => _push(
              context,
              const AddTransactionScreen(initialType: TransactionType.income),
            ),
            onTopUp: () => _push(
              context,
              const AddTransactionScreen(initialType: TransactionType.income),
            ),
            onMore: () => _openAllTransactions(context),
          ),
          const SizedBox(height: 22),
          ExpensesCard(
            expenses: p.recentExpenses(),
            onViewAll: () => _openAllTransactions(context),
            onTapExpense: (t) =>
                _push(context, AddTransactionScreen(existing: t)),
          ),
        ],
      ),
    );
  }
}
