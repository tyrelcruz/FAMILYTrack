import 'package:flutter/foundation.dart';

import 'package:finance_tracker/features/transactions/data/transaction_repository.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';

class FinanceProvider extends ChangeNotifier {
  FinanceProvider(this._repo) {
    load();
  }

  final TransactionRepository _repo;

  /// Called after every local write so the change can be uploaded.
  VoidCallback? onLocalChange;

  List<TransactionItem> _items = [];
  bool loading = true;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime get month => _month;
  List<TransactionItem> get all => _items;

  List<TransactionItem> get monthItems => _items
      .where((t) => t.date.year == _month.year && t.date.month == _month.month)
      .toList();

  double get monthIncome => _sum(monthItems, TransactionType.income);
  double get monthExpense => _sum(monthItems, TransactionType.expense);
  double get totalBalance =>
      _sum(_items, TransactionType.income) -
      _sum(_items, TransactionType.expense);

  List<TransactionItem> recentExpenses([int count = 4]) =>
      _items.where((t) => t.isExpense).take(count).toList();

  /// Percent change of the total balance against the balance at the end of
  /// last month; null when there's no prior balance to compare with.
  double? get balanceChangePercent {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month);
    final before = _items.where((t) => t.date.isBefore(startOfMonth));
    final previous =
        _sum(before, TransactionType.income) -
        _sum(before, TransactionType.expense);
    if (previous == 0) return null;
    return (totalBalance - previous) / previous.abs() * 100;
  }

  /// Expense totals per category id for the selected month.
  Map<String, double> get expenseByCategory {
    final result = <String, double>{};
    for (final t in monthItems.where((t) => t.isExpense)) {
      result[t.categoryId] = (result[t.categoryId] ?? 0) + t.amount;
    }
    return result;
  }

  double _sum(Iterable<TransactionItem> items, TransactionType type) =>
      items.where((t) => t.type == type).fold(0.0, (s, t) => s + t.amount);

  Future<void> load() async {
    _items = await _repo.all();
    loading = false;
    notifyListeners();
  }

  void changeMonth(int delta) {
    _month = DateTime(_month.year, _month.month + delta);
    notifyListeners();
  }

  Future<void> add(TransactionItem t) async {
    await _repo.insert(t);
    await load();
    onLocalChange?.call();
  }

  Future<void> edit(TransactionItem t) async {
    await _repo.update(t);
    await load();
    onLocalChange?.call();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    await load();
    onLocalChange?.call();
  }
}
