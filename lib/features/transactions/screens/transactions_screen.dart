import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';
import 'package:finance_tracker/features/transactions/widgets/month_selector.dart';
import 'package:finance_tracker/features/transactions/widgets/transaction_tile.dart';
import 'package:finance_tracker/features/transactions/screens/add_transaction_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FinanceProvider>();
    final items = p.monthItems;
    return Column(
      children: [
        const MonthSelector(),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No transactions this month'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final t = items[i];
                    return Dismissible(
                      key: ValueKey(t.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        context.read<FinanceProvider>().remove(t.id!);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Deleted "${t.title}"'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () =>
                                  context.read<FinanceProvider>().add(t),
                            ),
                          ),
                        );
                      },
                      child: TransactionTile(
                        item: t,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddTransactionScreen(existing: t),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
