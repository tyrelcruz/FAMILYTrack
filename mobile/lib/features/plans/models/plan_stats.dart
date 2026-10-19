import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/plans/models/plan.dart';
import 'package:finance_tracker/features/transactions/models/payment_method.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:finance_tracker/features/transfers/models/transfer.dart';

/// What's been spent on a plan, by person and by where the money came from,
/// with money moved between wallets or people applied.
class PlanStats {
  PlanStats._(
    this.expenses,
    this.transfers,
    this.spent,
    this.byMethod,
    this.byMember,
    this._fundMoves,
    this._shareMoves,
  );

  factory PlanStats.of(
    Plan plan,
    List<TransactionItem> all,
    FamilyProvider family, {
    List<Transfer> transfers = const [],
  }) {
    final expenses = all
        .where((t) => t.planId == plan.id && t.isExpense)
        .toList();
    final byMethod = <PaymentMethod, double>{};
    final byMember = <String, double>{};
    var spent = 0.0;
    for (final t in expenses) {
      spent += t.amount;
      // Older entries without a method count as cash.
      final m = t.paymentMethod ?? PaymentMethod.cash;
      byMethod[m] = (byMethod[m] ?? 0) + t.amount;
      final who = family.memberFor(t.memberId).id ?? '';
      byMember[who] = (byMember[who] ?? 0) + t.amount;
    }

    final mine = transfers.where((t) => t.planId == plan.id).toList();
    final fundMoves = <PaymentMethod, double>{};
    final shareMoves = <String, double>{};
    void add<K>(Map<K, double> m, K? k, double v) {
      if (k != null) m[k] = (m[k] ?? 0) + v;
    }

    for (final t in mine) {
      if (t.kind == TransferKind.wallet) {
        add(fundMoves, t.fromMethod, -t.amount);
        add(fundMoves, t.toMethod, t.amount);
      } else {
        add(shareMoves, family.memberFor(t.fromMemberId).id, -t.amount);
        add(shareMoves, family.memberFor(t.toMemberId).id, t.amount);
      }
    }
    return PlanStats._(
      expenses,
      mine,
      spent,
      byMethod,
      byMember,
      fundMoves,
      shareMoves,
    );
  }

  final List<TransactionItem> expenses;
  final List<Transfer> transfers;
  final double spent;
  final Map<PaymentMethod, double> byMethod;
  final Map<String, double> byMember;
  final Map<PaymentMethod, double> _fundMoves;
  final Map<String, double> _shareMoves;

  /// Money in [m] for the plan after wallet transfers.
  double fundsIn(Plan plan, PaymentMethod m) =>
      (plan.funds[m] ?? 0) + (_fundMoves[m] ?? 0);

  /// [memberId]'s share after people gave each other money.
  double shareOf(Plan plan, String memberId) =>
      (plan.shares[memberId] ?? 0) + (_shareMoves[memberId] ?? 0);

  bool hasShare(Plan plan, String memberId) =>
      plan.shares.containsKey(memberId) || _shareMoves.containsKey(memberId);
}
