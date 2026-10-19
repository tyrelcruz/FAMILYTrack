import 'package:finance_tracker/features/transactions/models/payment_method.dart';

/// Moving between wallets (cash → e-wallet) or between people.
enum TransferKind { wallet, people }

/// Money moved without being spent. Never counts as income or expense.
class Transfer {
  const Transfer({
    this.id,
    required this.kind,
    required this.amount,
    this.fromMethod,
    this.toMethod,
    this.fromMemberId,
    this.toMemberId,
    this.planId,
    this.note = '',
    required this.date,
  });

  /// UUID; null until saved.
  final String? id;
  final TransferKind kind;
  final double amount;
  final PaymentMethod? fromMethod;
  final PaymentMethod? toMethod;

  /// Giver and receiver, for transfers between people.
  final String? fromMemberId;
  final String? toMemberId;

  /// Trip or monthly plan whose wallets or shares this moves money in.
  final String? planId;
  final String note;
  final DateTime date;

  Map<String, Object?> toMap() => {
    'id': id,
    'kind': kind.name,
    'amount': amount,
    'from_method': fromMethod?.name,
    'to_method': toMethod?.name,
    'from_member_id': fromMemberId,
    'to_member_id': toMemberId,
    'plan_id': planId,
    'note': note,
    'date': date.millisecondsSinceEpoch,
  };

  factory Transfer.fromMap(Map<String, Object?> m) => Transfer(
    id: m['id'] as String?,
    kind: TransferKind.values.byName(m['kind'] as String),
    amount: (m['amount'] as num).toDouble(),
    fromMethod: PaymentMethod.tryParse(m['from_method']),
    toMethod: PaymentMethod.tryParse(m['to_method']),
    fromMemberId: m['from_member_id'] as String?,
    toMemberId: m['to_member_id'] as String?,
    planId: m['plan_id'] as String?,
    note: (m['note'] as String?) ?? '',
    date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
  );

  /// Shape the sync API sends and accepts.
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'amount': amount,
    'fromMethod': fromMethod?.name,
    'toMethod': toMethod?.name,
    'fromMemberId': fromMemberId,
    'toMemberId': toMemberId,
    'planId': planId,
    'note': note,
    'date': date.millisecondsSinceEpoch,
  };
}
