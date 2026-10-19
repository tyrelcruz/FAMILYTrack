import 'package:finance_tracker/features/transactions/models/payment_method.dart';

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
    this.memberId,
    this.planId,
    this.paymentMethod,
  });

  /// UUID; null until saved.
  final String? id;
  final String title;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final DateTime date;
  final String note;

  /// Family member who made it; null means the group owner.
  final String? memberId;

  /// Trip or monthly plan this belongs to, if any.
  final String? planId;

  /// Cash, e-wallet, card or bank; null when not recorded.
  final PaymentMethod? paymentMethod;

  bool get isExpense => type == TransactionType.expense;

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'type': type.name,
    'category': categoryId,
    'date': date.millisecondsSinceEpoch,
    'note': note,
    'member_id': memberId,
    'plan_id': planId,
    'payment_method': paymentMethod?.name,
  };

  factory TransactionItem.fromMap(Map<String, Object?> m) => TransactionItem(
    id: m['id'] as String?,
    title: m['title'] as String,
    amount: (m['amount'] as num).toDouble(),
    type: TransactionType.values.byName(m['type'] as String),
    categoryId: m['category'] as String,
    date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
    note: (m['note'] as String?) ?? '',
    memberId: m['member_id'] as String?,
    planId: m['plan_id'] as String?,
    paymentMethod: PaymentMethod.tryParse(m['payment_method']),
  );

  /// Shape the sync API sends and accepts.
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'type': type.name,
    'categoryId': categoryId,
    'date': date.millisecondsSinceEpoch,
    'note': note,
    'memberId': memberId,
    'planId': planId,
    'paymentMethod': paymentMethod?.name,
  };

  factory TransactionItem.fromJson(Map<String, dynamic> j) => TransactionItem(
    id: j['id'] as String,
    title: j['title'] as String,
    amount: (j['amount'] as num).toDouble(),
    type: TransactionType.values.byName(j['type'] as String),
    categoryId: j['categoryId'] as String,
    date: DateTime.fromMillisecondsSinceEpoch(j['date'] as int),
    note: (j['note'] as String?) ?? '',
    memberId: j['memberId'] as String?,
    planId: j['planId'] as String?,
    paymentMethod: PaymentMethod.tryParse(j['paymentMethod']),
  );
}
