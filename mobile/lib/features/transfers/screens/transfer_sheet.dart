import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/widgets/segmented_pill.dart';
import 'package:finance_tracker/core/widgets/sheet_parts.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/family/widgets/member_avatar.dart';
import 'package:finance_tracker/features/plans/providers/plan_provider.dart';
import 'package:finance_tracker/features/transactions/models/payment_method.dart';
import 'package:finance_tracker/features/transfers/models/transfer.dart';
import 'package:finance_tracker/features/transfers/providers/transfer_provider.dart';

/// Move money without spending it: between wallets or between people.
/// Pass [planId] to keep it inside a trip or monthly plan.
Future<void> showTransferSheet(
  BuildContext context, {
  String? planId,
  TransferKind kind = TransferKind.wallet,
  Transfer? existing,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.surface,
  barrierColor: AppColors.textPrimary.withValues(alpha: 0.25),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
  ),
  builder: (_) =>
      _TransferSheet(planId: planId, kind: kind, existing: existing),
);

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({this.planId, required this.kind, this.existing});

  final String? planId;
  final TransferKind kind;
  final Transfer? existing;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late TransferKind _kind;
  PaymentMethod _fromMethod = PaymentMethod.ewallet;
  PaymentMethod _toMethod = PaymentMethod.cash;
  String? _fromMember;
  String? _toMember;

  /// '' means not part of a plan (menus need a non-null value).
  late String _planId;
  bool _saving = false;

  double get _value => double.tryParse(_amount.text) ?? 0;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final family = context.read<FamilyProvider>();
    final me = family.memberForUser(
      context.read<SessionProvider>().session?.userId,
    );
    _kind = e?.kind ?? widget.kind;
    _planId = e?.planId ?? widget.planId ?? '';
    _fromMethod = e?.fromMethod ?? _fromMethod;
    _toMethod = e?.toMethod ?? _toMethod;
    _fromMember = e?.fromMemberId ?? me?.id ?? family.owner.id;
    _toMember =
        e?.toMemberId ??
        family.members
            .firstWhere((m) => m.id != _fromMember, orElse: () => family.owner)
            .id;
    if (e != null) {
      _amount.text = e.amount == e.amount.roundToDouble()
          ? e.amount.toStringAsFixed(0)
          : e.amount.toStringAsFixed(2);
      _note.text = e.note;
    }
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// What's wrong with the current choices, if anything.
  String? get _problem {
    if (_kind == TransferKind.wallet && _fromMethod == _toMethod) {
      return 'Pick two different wallets';
    }
    if (_kind == TransferKind.people && _fromMember == _toMember) {
      return 'Pick two different people';
    }
    return null;
  }

  void _swap() => setState(() {
    if (_kind == TransferKind.people) {
      final from = _fromMember;
      _fromMember = _toMember;
      _toMember = from;
    } else {
      final from = _fromMethod;
      _fromMethod = _toMethod;
      _toMethod = from;
    }
  });

  Future<void> _save() async {
    if (_value <= 0 || _problem != null || _saving) return;
    setState(() => _saving = true);
    final people = _kind == TransferKind.people;
    final t = Transfer(
      id: widget.existing?.id,
      kind: _kind,
      amount: _value,
      fromMethod: _fromMethod,
      toMethod: people ? null : _toMethod,
      fromMemberId: people ? _fromMember : null,
      toMemberId: people ? _toMember : null,
      planId: _planId.isEmpty ? null : _planId,
      note: _note.text.trim(),
      date: widget.existing?.date ?? DateTime.now(),
    );
    final provider = context.read<TransferProvider>();
    widget.existing == null ? await provider.add(t) : await provider.edit(t);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await context.read<TransferProvider>().remove(widget.existing!.id!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilyProvider>();
    final plans = context.watch<PlanProvider>();
    final now = DateTime.now();
    final planOptions = [
      '',
      for (final p in plans.plans)
        if (!p.isPast(now) || p.id == _planId) p.id!,
    ];
    final canGive = family.members.length > 1;
    final people = _kind == TransferKind.people;

    Widget methodLabel(PaymentMethod m) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(m.icon, size: 17, color: m.color),
        const SizedBox(width: 6),
        Flexible(child: Text(m.label, overflow: TextOverflow.ellipsis)),
      ],
    );
    Widget memberLabel(String id) {
      final m = family.memberFor(id);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MemberAvatar(m, size: 20),
          const SizedBox(width: 6),
          Flexible(child: Text(m.name, overflow: TextOverflow.ellipsis)),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.existing == null ? 'Add Transfer' : 'Edit Transfer',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Moves money around — it isn’t counted as spending.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                SegmentedPill<TransferKind>(
                  value: _kind,
                  onChanged: (k) => setState(() => _kind = k),
                  options: const [
                    SegmentOption(
                      TransferKind.wallet,
                      'Between wallets',
                      icon: Icons.swap_horiz_rounded,
                    ),
                    SegmentOption(
                      TransferKind.people,
                      'Between people',
                      icon: Icons.people_alt_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (people && !canGive)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: sheetBoxDecoration,
                    child: const Text(
                      'Add someone to the family first (Family tab) to move '
                      'money between people.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: people
                            ? SheetSelect<String>(
                                label: 'From',
                                value: _fromMember!,
                                display: memberLabel,
                                options: [
                                  for (final m in family.members) m.id!,
                                ],
                                onChanged: (v) =>
                                    setState(() => _fromMember = v),
                              )
                            : SheetSelect<PaymentMethod>(
                                label: 'From',
                                value: _fromMethod,
                                display: methodLabel,
                                options: PaymentMethod.values,
                                onChanged: (v) =>
                                    setState(() => _fromMethod = v),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: IconButton(
                          tooltip: 'Swap',
                          onPressed: _swap,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                      Expanded(
                        child: people
                            ? SheetSelect<String>(
                                label: 'To',
                                value: _toMember!,
                                display: memberLabel,
                                options: [
                                  for (final m in family.members) m.id!,
                                ],
                                onChanged: (v) => setState(() => _toMember = v),
                              )
                            : SheetSelect<PaymentMethod>(
                                label: 'To',
                                value: _toMethod,
                                display: methodLabel,
                                options: PaymentMethod.values,
                                onChanged: (v) => setState(() => _toMethod = v),
                              ),
                      ),
                    ],
                  ),
                if (people && canGive) ...[
                  const SizedBox(height: 10),
                  SheetSelect<PaymentMethod>(
                    label: 'Given as',
                    value: _fromMethod,
                    display: methodLabel,
                    options: PaymentMethod.values,
                    onChanged: (v) => setState(() => _fromMethod = v),
                  ),
                ],
                const SizedBox(height: 14),
                SheetBigAmount(controller: _amount),
                Text(
                  _problem ?? 'Amount',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: _problem == null
                        ? AppColors.textMuted
                        : AppColors.expenseRed,
                  ),
                ),
                const SizedBox(height: 14),
                SheetNoteField(
                  controller: _note,
                  hint: people
                      ? 'What for? e.g. Share for the hotel'
                      : 'What for? e.g. Withdrew cash at the ATM',
                ),
                if (planOptions.length > 1) ...[
                  const SizedBox(height: 10),
                  SheetSelect<String>(
                    label: 'Plan',
                    value: _planId,
                    display: (id) => Text(
                      id.isEmpty ? 'Not in a plan' : plans.byId(id)!.name,
                    ),
                    options: planOptions,
                    onChanged: (v) => setState(() => _planId = v),
                  ),
                ],
                if (widget.existing != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.expenseRed,
                    ),
                    child: const Text('Delete transfer'),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: GradientActionButton(
                label: widget.existing == null ? 'Save Transfer' : 'Save',
                enabled: _value > 0 && _problem == null && (!people || canGive),
                busy: _saving,
                onTap: _save,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
