import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TransactionItem map round trip', () {
    final t = TransactionItem(
      id: 1,
      title: 'Lunch',
      amount: 120.5,
      type: TransactionType.expense,
      categoryId: 'food',
      date: DateTime(2026, 1, 2),
    );
    final back = TransactionItem.fromMap(t.toMap());
    expect(back.title, 'Lunch');
    expect(back.amount, 120.5);
    expect(back.type, TransactionType.expense);
    expect(back.date, DateTime(2026, 1, 2));
  });
}
