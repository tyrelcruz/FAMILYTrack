enum TransactionType { income, expense }

class TransactionItem {
  const TransactionItem({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.date,
    this.note = '',
  });

  final int? id;
  final String title;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final DateTime date;
  final String note;

  bool get isExpense => type == TransactionType.expense;

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'type': type.name,
    'category': categoryId,
    'date': date.millisecondsSinceEpoch,
    'note': note,
  };

  factory TransactionItem.fromMap(Map<String, Object?> m) => TransactionItem(
    id: m['id'] as int?,
    title: m['title'] as String,
    amount: (m['amount'] as num).toDouble(),
    type: TransactionType.values.byName(m['type'] as String),
    categoryId: m['category'] as String,
    date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
    note: (m['note'] as String?) ?? '',
  );
}
