import 'package:finance_tracker/features/transactions/models/payment_method.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';

/// A past entry worth repeating: what it was, how much, and where it went.
class QuickPick {
  const QuickPick({
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.paymentMethod,
    required this.count,
  });

  final String title;

  /// From the most recent time it was entered.
  final double amount;
  final String categoryId;
  final PaymentMethod? paymentMethod;

  /// How many times it's been entered.
  final int count;
}

/// The entries someone most likely wants to repeat: frequent ones first,
/// boosted when recent or when they belong to [planId].
List<QuickPick> quickPicks(
  List<TransactionItem> all, {
  required TransactionType type,
  Set<String>? categoryIds,
  String? planId,
  DateTime? now,
  int limit = 8,
}) {
  final today = now ?? DateTime.now();
  final groups = <String, List<TransactionItem>>{};
  for (final t in all) {
    if (t.type != type) continue;
    if (categoryIds != null && !categoryIds.contains(t.categoryId)) continue;
    final key = '${t.title.trim().toLowerCase()}|${t.categoryId}';
    groups.putIfAbsent(key, () => []).add(t);
  }

  double score(List<TransactionItem> items, TransactionItem latest) {
    final days = today.difference(latest.date).inDays;
    return items.length * 2 +
        (days <= 7 ? 3 : (days <= 30 ? 1 : 0)) +
        (planId != null && items.any((t) => t.planId == planId) ? 6 : 0);
  }

  final ranked =
      [
        for (final items in groups.values)
          (
            items: items,
            latest: items.reduce((a, b) => a.date.isAfter(b.date) ? a : b),
          ),
      ]..sort((a, b) {
        final byScore = score(
          b.items,
          b.latest,
        ).compareTo(score(a.items, a.latest));
        return byScore != 0 ? byScore : b.latest.date.compareTo(a.latest.date);
      });

  return [
    for (final g in ranked.take(limit))
      QuickPick(
        title: g.latest.title.trim(),
        amount: g.latest.amount,
        categoryId: g.latest.categoryId,
        paymentMethod: g.latest.paymentMethod,
        count: g.items.length,
      ),
  ];
}
