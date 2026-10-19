import 'package:flutter_test/flutter_test.dart';

import 'package:finance_tracker/features/categories/models/category.dart';
import 'package:finance_tracker/features/categories/models/category_guesser.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';

void main() {
  final everyday = Category.forType(TransactionType.expense);
  final trip = Category.forTrip();
  String? guess(String s, [List<Category>? from]) =>
      CategoryGuesser.guess(s, from ?? everyday);

  test('groceries from Filipino and English items', () {
    expect(guess('2 eggs, 2 kilos of manok'), 'groceries');
    expect(guess('Bigas 5kg at sibuyas'), 'groceries');
  });

  test('trip categories only when offered', () {
    expect(guess('Airbnb 2 nights', trip), 'lodging');
    expect(guess('Grab to airport', trip), 'transport');
    expect(guess('Island hopping tour', trip), 'activities');
    expect(guess('Strawberry jam pasalubong', trip), 'souvenirs');
    expect(guess('Petron gas', trip), 'fuel');
    // Accommodation isn't an everyday category.
    expect(guess('Airbnb 2 nights'), isNull);
  });

  test('whole words only, nothing for unknown text', () {
    expect(guess('gastos'), isNull);
    expect(guess(''), isNull);
    expect(guess('Jollibee lunch'), 'food');
  });

  test('income categories', () {
    expect(
      CategoryGuesser.guess(
        'Sweldo for October',
        Category.forType(TransactionType.income),
      ),
      'salary',
    );
  });
}
