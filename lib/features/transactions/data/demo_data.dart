import 'package:finance_tracker/features/transactions/models/transaction.dart';

/// Sample records inserted on first launch so the home screen isn't empty.
/// Balances out to ₱8,182.80, up 12.5% on last month.
List<TransactionItem> demoTransactions(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = now.day > 1
      ? today.subtract(const Duration(days: 1))
      : today;
  final lastMonth = DateTime(now.year, now.month - 1, 25, 9);

  TransactionItem expense(
    String title,
    double amount,
    String cat,
    DateTime d,
  ) => TransactionItem(
    title: title,
    amount: amount,
    type: TransactionType.expense,
    categoryId: cat,
    date: d,
  );

  return [
    TransactionItem(
      title: 'Monthly Salary',
      amount: 7273.60,
      type: TransactionType.income,
      categoryId: 'salary',
      date: lastMonth,
    ),
    TransactionItem(
      title: 'Freelance Project',
      amount: 1694.20,
      type: TransactionType.income,
      categoryId: 'business',
      date: today.copyWithTime(8),
    ),
    expense('House Rent', 300, 'housing', today.copyWithTime(10)),
    expense('Internet Bill', 85, 'internet', today.copyWithTime(12)),
    expense('Groceries', 120, 'groceries', yesterday.copyWithTime(17, 45)),
    expense('Food & Dining', 280, 'food', yesterday.copyWithTime(19, 20)),
  ];
}

extension on DateTime {
  DateTime copyWithTime(int hour, [int minute = 0]) =>
      DateTime(year, month, day, hour, minute);
}
