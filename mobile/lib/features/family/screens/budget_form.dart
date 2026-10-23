import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/features/categories/models/category.dart';
import 'package:finance_tracker/features/categories/widgets/category_chip.dart';
import 'package:finance_tracker/features/family/models/budget.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/core/widgets/form_sheet.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';

/// Add a budget, or edit [existing]. Pass [categoryId] to preselect one,
/// e.g. [Budget.overall] from the summary card.
Future<void> showBudgetForm(
  BuildContext context, {
  Budget? existing,
  String? categoryId,
}) => showFormSheet(
  context,
  title: existing == null ? 'New budget' : 'Edit budget',
  subtitle: 'A monthly spending limit for the whole family.',
  child: _BudgetForm(existing: existing, categoryId: categoryId),
);

class _BudgetForm extends StatefulWidget {
  const _BudgetForm({this.existing, this.categoryId});

  final Budget? existing;
  final String? categoryId;

  @override
  State<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<_BudgetForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final List<String> _options;
  late String _categoryId;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(text: e?.limit.toStringAsFixed(2));
    final taken = context.read<FamilyProvider>().budgetedCategories;
    _options = e != null
        ? [e.categoryId]
        : [
            Budget.overall,
            for (final c in Category.forType(TransactionType.expense)) c.id,
          ].where((id) => !taken.contains(id)).toList();
    final preset = widget.categoryId;
    _categoryId =
        e?.categoryId ??
        (preset != null && _options.contains(preset) ? preset : null) ??
        (_options.isEmpty ? Budget.overall : _options.first);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<FamilyProvider>().saveBudget(
      Budget(categoryId: _categoryId, limit: double.parse(_amount.text)),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await context.read<FamilyProvider>().removeBudget(_categoryId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_options.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text(
          'Every category already has a budget. Tap one to edit it.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetLabel('Monthly limit'),
          SheetAmountField(controller: _amount),
          const SizedBox(height: 22),
          SheetLabel(_editing ? 'Category' : 'Choose a category'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final id in _options)
                id == Budget.overall
                    ? CategoryChip(
                        label: 'Whole family',
                        icon: Icons.groups_rounded,
                        color: AppColors.blue,
                        tint: AppColors.blueTint,
                        selected: id == _categoryId,
                        onTap: () => setState(() => _categoryId = id),
                      )
                    : CategoryChip.of(
                        Category.byId(id),
                        selected: id == _categoryId,
                        onTap: () => setState(() => _categoryId = id),
                      ),
            ],
          ),
          const SizedBox(height: 28),
          SheetPrimaryButton(
            label: _editing ? 'Save Changes' : 'Create Budget',
            onPressed: _save,
          ),
          if (_editing) ...[
            const SizedBox(height: 10),
            SheetDangerButton(label: 'Remove Budget', onPressed: _delete),
          ],
        ],
      ),
    );
  }
}
