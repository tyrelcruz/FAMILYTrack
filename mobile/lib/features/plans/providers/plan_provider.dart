import 'package:flutter/foundation.dart';

import 'package:finance_tracker/features/plans/data/plan_repository.dart';
import 'package:finance_tracker/features/plans/models/plan.dart';

class PlanProvider extends ChangeNotifier {
  PlanProvider(this._repo) {
    load();
  }

  final PlanRepository _repo;

  /// Called after every local write so the change can be uploaded.
  VoidCallback? onLocalChange;

  List<Plan> _plans = [];
  bool loading = true;

  List<Plan> get plans => _plans;

  Plan? byId(String? id) {
    for (final p in _plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() async {
    _plans = await _repo.all();
    loading = false;
    notifyListeners();
  }

  Future<void> save(Plan p) async {
    p.id == null ? await _repo.insert(p) : await _repo.update(p);
    await load();
    onLocalChange?.call();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    await load();
    onLocalChange?.call();
  }
}
