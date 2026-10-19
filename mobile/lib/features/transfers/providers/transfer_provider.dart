import 'package:flutter/foundation.dart';

import 'package:finance_tracker/features/transfers/data/transfer_repository.dart';
import 'package:finance_tracker/features/transfers/models/transfer.dart';

class TransferProvider extends ChangeNotifier {
  TransferProvider(this._repo) {
    load();
  }

  final TransferRepository _repo;

  /// Called after every local write so the change can be uploaded.
  VoidCallback? onLocalChange;

  List<Transfer> _items = [];
  bool loading = true;

  List<Transfer> get all => _items;

  List<Transfer> forPlan(String? planId) =>
      _items.where((t) => t.planId == planId).toList();

  Future<void> load() async {
    _items = await _repo.all();
    loading = false;
    notifyListeners();
  }

  Future<void> add(Transfer t) async {
    await _repo.insert(t);
    await load();
    onLocalChange?.call();
  }

  Future<void> edit(Transfer t) async {
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
