import 'package:flutter_test/flutter_test.dart';

import 'package:finance_tracker/features/transactions/models/payment_method.dart';
import 'package:finance_tracker/features/transactions/models/quick_picks.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';

void main() {
  final now = DateTime(2026, 10, 19, 12);
  TransactionItem t(
    String title,
    double amount,
    String cat, {
    int daysAgo = 0,
    String? plan,
    PaymentMethod? method,
    TransactionType type = TransactionType.expense,
  }) => TransactionItem(
    title: title,
    amount: amount,
    type: type,
    categoryId: cat,
    date: now.subtract(Duration(days: daysAgo)),
    planId: plan,
    paymentMethod: method,
  );

  test('frequent first, latest amount and method win, case-insensitive', () {
    final picks = quickPicks(
      [
        t('Grab', 150, 'transport', daysAgo: 20),
        t('grab ', 180, 'transport', daysAgo: 2, method: PaymentMethod.ewallet),
        t('Grab', 160, 'transport', daysAgo: 10),
        t('Jollibee', 250, 'food', daysAgo: 1),
        t('Sweldo', 20000, 'salary', type: TransactionType.income),
      ],
      type: TransactionType.expense,
      now: now,
    );
    expect(picks.first.title, 'grab');
    expect(picks.first.count, 3);
    expect(picks.first.amount, 180);
    expect(picks.first.paymentMethod, PaymentMethod.ewallet);
    expect(picks.map((p) => p.categoryId), isNot(contains('salary')));
  });

  test('a trip favors its own expenses and allowed categories', () {
    final picks = quickPicks(
      [
        t('Groceries', 900, 'groceries', daysAgo: 1),
        t('Groceries', 950, 'groceries', daysAgo: 3),
        t('Strawberries', 300, 'food', daysAgo: 1, plan: 'trip'),
        t('Netflix', 549, 'entertainment', daysAgo: 1),
      ],
      type: TransactionType.expense,
      categoryIds: {'groceries', 'food'},
      planId: 'trip',
      now: now,
    );
    expect(picks.first.title, 'Strawberries');
    expect(picks.map((p) => p.title), isNot(contains('Netflix')));
  });
}
