import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/widgets/breakdown_layout.dart';
import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/core/widgets/circle_button.dart';
import 'package:finance_tracker/core/widgets/form_sheet.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/categories/models/category.dart';
import 'package:finance_tracker/features/categories/widgets/category_chip.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/family/widgets/member_chip.dart';
import 'package:finance_tracker/features/plans/models/plan.dart';
import 'package:finance_tracker/features/plans/providers/plan_provider.dart';
import 'package:finance_tracker/features/transactions/models/payment_method.dart';
import 'package:finance_tracker/features/transactions/widgets/receipt_photo.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.existing,
    this.initialType = TransactionType.expense,
    this.initialMemberId,
  });

  final TransactionItem? existing;
  final TransactionType initialType;
  final String? initialMemberId;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late TransactionType _type;
  late String _categoryId;
  late DateTime _date;
  String? _memberId;
  PaymentMethod? _method;

  /// A photo picked on this screen; [_photoChanged] also covers removing.
  File? _newPhoto;
  bool _photoChanged = false;

  bool get _editing => widget.existing != null;

  /// Set when editing an expense that belongs to a trip.
  bool _trip = false;

  List<Category> get _categories => _type == TransactionType.expense && _trip
      ? Category.forTrip()
      : Category.forType(_type);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title);
    _amount = TextEditingController(text: e?.amount.toStringAsFixed(2));
    _note = TextEditingController(text: e?.note);
    _type = e?.type ?? widget.initialType;
    final plan = context.read<PlanProvider>().byId(e?.planId);
    _trip =
        plan?.kind == PlanKind.trip ||
        (e != null && Category.byId(e.categoryId).tripOnly);
    _categoryId = e?.categoryId ?? _categories.first.id;
    _date = e?.date ?? DateTime.now();
    // New entries default to whoever is signed in on this phone.
    final me = context.read<FamilyProvider>().memberForUser(
      context.read<SessionProvider>().session?.userId,
    );
    _memberId = e?.memberId ?? widget.initialMemberId ?? me?.id;
    _method = e?.paymentMethod;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    // Keep the time of day so the home screen shows when it happened.
    setState(
      () => _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      ),
    );
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: const Text(
          'Delete transaction?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          '“${widget.existing!.title}” will be removed for everyone in the '
          'family.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: const StadiumBorder(),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final provider = context.read<FinanceProvider>();
    final nav = Navigator.of(context);
    await provider.remove(widget.existing!.id!);
    nav.pop();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<FinanceProvider>();
    final item = TransactionItem(
      id: widget.existing?.id,
      title: _title.text.trim(),
      amount: double.parse(_amount.text),
      type: _type,
      categoryId: _categoryId,
      date: _date,
      note: _note.text.trim(),
      memberId: _memberId,
      // Keeps the expense in its trip or monthly plan.
      planId: widget.existing?.planId,
      paymentMethod: _method,
    );
    if (_editing) {
      await provider.edit(item);
      if (_photoChanged) await provider.setPhoto(item.id!, _newPhoto);
    } else {
      await provider.add(item, photo: _newPhoto);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final members = context.watch<FamilyProvider>().members;
    const fieldStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
    final expense = _type == TransactionType.expense;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: SheetPrimaryButton(
              label: _editing ? 'Save Changes' : 'Add Transaction',
              onPressed: _save,
            ),
          ),
        ),
        body: PatchBackdrop.behind(
          SafeArea(
            bottom: false,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Row(
                    children: [
                      CircleButton(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _editing ? 'EDIT TRANSACTION' : 'NEW TRANSACTION',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: AppTheme.displayFont,
                            fontFamilyFallback: AppTheme.displayFallback,
                            fontSize: 21.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (_editing)
                        CircleButton(
                          onTap: _delete,
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.red,
                          ),
                        )
                      else
                        const SizedBox(width: 54),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _TypeToggle(
                    value: _type,
                    onChanged: (t) => setState(() {
                      _type = t;
                      _categoryId = _categories.first.id;
                    }),
                  ),
                  const SizedBox(height: 18),
                  _Section(
                    child: Column(
                      children: [
                        Text(
                          expense
                              ? 'How much did you spend?'
                              : 'How much came in?',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: IntrinsicWidth(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 160),
                              child: TextFormField(
                                controller: _amount,
                                autofocus: !_editing,
                                textAlign: TextAlign.start,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                ],
                                style: TextStyle(
                                  fontFamily: AppTheme.displayFont,
                                  fontFamilyFallback: AppTheme.displayFallback,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                  color: expense
                                      ? AppColors.textPrimary
                                      : AppColors.green,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '₱0.00',
                                  hintStyle: TextStyle(
                                    color: AppColors.textMuted,
                                  ),
                                  prefixText: '₱',
                                  prefixStyle: TextStyle(
                                    fontFamily: AppTheme.displayFont,
                                    fontFamilyFallback:
                                        AppTheme.displayFallback,
                                    fontSize: 42,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                validator: (v) {
                                  final n = double.tryParse(v ?? '');
                                  return (n == null || n <= 0)
                                      ? 'Enter an amount greater than 0'
                                      : null;
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Section(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SheetLabel('Title'),
                        TextFormField(
                          controller: _title,
                          textCapitalization: TextCapitalization.sentences,
                          style: fieldStyle,
                          decoration: sheetInputDecoration(
                            hint: expense ? 'e.g. Groceries' : 'e.g. Salary',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter a title'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        const SheetLabel('Category'),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final c in _categories)
                              CategoryChip.of(
                                c,
                                selected: c.id == _categoryId,
                                onTap: () => setState(() => _categoryId = c.id),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Section(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Only worth asking once the family has more than one person.
                        if (members.length > 1) ...[
                          SheetLabel(expense ? 'Paid by' : 'Received by'),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final m in members)
                                MemberChip(
                                  member: m,
                                  selected:
                                      m.id ==
                                      context
                                          .read<FamilyProvider>()
                                          .memberFor(_memberId)
                                          .id,
                                  onTap: () => setState(() => _memberId = m.id),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                        SheetLabel(expense ? 'Paid with' : 'Received in'),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final m in PaymentMethod.values)
                              CategoryChip(
                                label: m.label,
                                icon: m.icon,
                                color: m.color,
                                tint: m.tint,
                                selected: m == _method,
                                // Tapping the selected one clears it.
                                onTap: () => setState(
                                  () => _method = m == _method ? null : m,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const SheetLabel('Date'),
                        Material(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 17,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      formatDay(_date),
                                      style: fieldStyle,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 17,
                                    color: AppColors.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SheetLabel('Photo'),
                        ReceiptField(
                          path: _photoChanged
                              ? _newPhoto?.path
                              : widget.existing?.photoPath,
                          onChanged: (f) => setState(() {
                            _newPhoto = f;
                            _photoChanged = true;
                          }),
                        ),
                        const SizedBox(height: 20),
                        const SheetLabel('Note'),
                        TextFormField(
                          controller: _note,
                          maxLines: 2,
                          style: fieldStyle,
                          decoration: sheetInputDecoration(hint: 'Optional'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White rounded section card.
class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(26),
      boxShadow: AppColors.softShadow,
    ),
    child: child,
  );
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.value, required this.onChanged});

  final TransactionType value;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, IconData icon, TransactionType t, Color color) {
      final selected = value == t;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: selected ? AppColors.softShadow : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15.5,
                  color: selected ? color : AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.neutralTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          tab(
            'Expense',
            Icons.north_east_rounded,
            TransactionType.expense,
            AppColors.expenseRed,
          ),
          tab(
            'Income',
            Icons.south_west_rounded,
            TransactionType.income,
            AppColors.green,
          ),
        ],
      ),
    );
  }
}
