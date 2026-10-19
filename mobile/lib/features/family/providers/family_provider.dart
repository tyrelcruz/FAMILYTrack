import 'package:flutter/foundation.dart';

import 'package:finance_tracker/core/constants/user_profile.dart';
import 'package:finance_tracker/features/family/data/family_repository.dart';
import 'package:finance_tracker/features/family/models/budget.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';

class FamilyProvider extends ChangeNotifier {
  FamilyProvider(this._repo) {
    load();
  }

  final FamilyRepository _repo;

  /// Called after every local write so the change can be uploaded.
  VoidCallback? onLocalChange;

  List<FamilyMember> _members = [];
  List<Budget> _budgets = [];
  bool loading = true;

  List<FamilyMember> get members => _members;

  FamilyMember get owner => _members.firstWhere(
    (m) => m.isOwner,
    orElse: () => FamilyMember(
      id: '',
      name: UserProfile.firstName,
      color: FamilyMember.palette.first,
      isOwner: true,
    ),
  );

  /// Transactions without a member (or with a removed one) belong to the owner.
  FamilyMember memberFor(String? id) =>
      _members.firstWhere((m) => m.id == id, orElse: () => owner);

  /// The member linked to an account, e.g. the signed-in user.
  FamilyMember? memberForUser(String? userId) {
    if (userId == null) return null;
    for (final m in _members) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  Budget? get overallBudget {
    for (final b in _budgets) {
      if (b.isOverall) return b;
    }
    return null;
  }

  List<Budget> get categoryBudgets =>
      _budgets.where((b) => !b.isOverall).toList();

  Set<String> get budgetedCategories =>
      _budgets.map((b) => b.categoryId).toSet();

  /// Expense totals per member id for [items].
  Map<String, double> spendByMember(Iterable<TransactionItem> items) {
    final result = <String, double>{};
    for (final t in items.where((t) => t.isExpense)) {
      final id = memberFor(t.memberId).id!;
      result[id] = (result[id] ?? 0) + t.amount;
    }
    return result;
  }

  double spentFor(Budget b, Iterable<TransactionItem> items) => items
      .where(
        (t) => t.isExpense && (b.isOverall || t.categoryId == b.categoryId),
      )
      .fold(0.0, (s, t) => s + t.amount);

  Future<void> load() async {
    _members = await _repo.members();
    _budgets = await _repo.budgets();
    loading = false;
    notifyListeners();
  }

  /// Adds someone to the family and returns their id.
  Future<String> addMember(FamilyMember m) async {
    final id = await _repo.insertMember(m);
    await load();
    onLocalChange?.call();
    return id;
  }

  Future<void> editMember(FamilyMember m) async {
    await _repo.updateMember(m);
    await load();
    onLocalChange?.call();
  }

  Future<void> removeMember(String id) async {
    await _repo.deleteMember(id);
    await load();
    onLocalChange?.call();
  }

  Future<void> saveBudget(Budget b) async {
    await _repo.saveBudget(b);
    await load();
    onLocalChange?.call();
  }

  Future<void> removeBudget(String categoryId) async {
    await _repo.deleteBudget(categoryId);
    await load();
    onLocalChange?.call();
  }
}
