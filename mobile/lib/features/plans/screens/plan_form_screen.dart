import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/widgets/breakdown_layout.dart';
import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/core/widgets/form_sheet.dart';
import 'package:finance_tracker/core/widgets/segmented_pill.dart';
import 'package:finance_tracker/core/widgets/sheet_parts.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/family/widgets/member_avatar.dart';
import 'package:finance_tracker/features/family/widgets/add_people_sheet.dart';
import 'package:finance_tracker/features/family/widgets/member_chip.dart';
import 'package:finance_tracker/features/plans/models/destination.dart';
import 'package:finance_tracker/features/plans/models/plan.dart';
import 'package:finance_tracker/features/plans/models/plan_template.dart';
import 'package:finance_tracker/features/plans/providers/plan_provider.dart';
import 'package:finance_tracker/features/plans/widgets/plan_scene.dart';
import 'package:finance_tracker/features/transactions/models/payment_method.dart';

const _navy = AppColors.textPrimary;
const _blue = AppColors.blue;
const _border = AppColors.divider;

/// The three tabs; Custom covers a whole month or any other dates.
enum _Mode { trip, event, custom }

/// Create or edit a plan: where, when, how much and who's in.
class PlanFormScreen extends StatefulWidget {
  const PlanFormScreen({super.key, this.existing, this.template});

  final Plan? existing;

  /// Pre-fills a new plan, e.g. "Weekend Getaway".
  final PlanTemplate? template;

  @override
  State<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends State<PlanFormScreen> {
  final _name = TextEditingController();
  final _search = TextEditingController();
  final _description = TextEditingController();
  final _budget = TextEditingController();
  final _funds = {
    for (final m in PaymentMethod.values) m: TextEditingController(),
  };
  final _customShares = <String, TextEditingController>{};
  final _searchFocus = FocusNode();

  late _Mode _mode;

  /// Custom plans: true for one calendar month, false for any dates.
  bool _wholeMonth = false;
  late DateTimeRange _range;
  late DateTime _month;
  late SplitMode _split;

  /// The chosen place, e.g. "Tokyo, Japan"; empty for none.
  String _place = '';

  /// Once the user types a name we stop suggesting one from the place.
  bool _nameTouched = false;

  /// Where a single budget is kept, unless split across wallets.
  PaymentMethod _wallet = PaymentMethod.cash;
  bool _splitWallets = false;

  /// Member ids sharing the plan, in family order.
  final _selected = <String>{};
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final t = widget.template;
    final today = DateUtils.dateOnly(DateTime.now());
    final kind = e?.kind ?? t?.kind ?? PlanKind.trip;
    _mode = switch (kind) {
      PlanKind.trip => _Mode.trip,
      PlanKind.event => _Mode.event,
      PlanKind.monthly || PlanKind.custom => _Mode.custom,
    };
    _wholeMonth = kind == PlanKind.monthly;
    _name.text = e?.name ?? t?.suggestedName ?? '';
    _nameTouched = _name.text.isNotEmpty;
    _place = e?.destination ?? '';
    _description.text = e?.description ?? '';
    _range = e != null
        ? DateTimeRange(start: e.start, end: e.end)
        : t?.range(today) ??
              DateTimeRange(
                start: today,
                end: today.add(const Duration(days: 3)),
              );
    _month = DateTime((e?.start ?? today).year, (e?.start ?? today).month);
    _split = e?.split ?? t?.split ?? SplitMode.equal;

    // One wallet with money → simple budget; several → split view.
    final funded = [
      for (final m in PaymentMethod.values)
        if ((e?.funds[m] ?? 0) > 0) m,
    ];
    if (funded.length > 1) {
      _splitWallets = true;
      for (final m in funded) {
        _funds[m]!.text = _plain(e!.funds[m]!);
      }
    } else if (funded.length == 1) {
      _wallet = funded.single;
      _budget.text = _plain(e!.funds[_wallet]!);
    }

    final members = context.read<FamilyProvider>().members;
    if (e == null) {
      _selected.addAll(members.map((m) => m.id!));
    } else {
      _selected.addAll(
        e.shares.keys.where((id) => members.any((m) => m.id == id)),
      );
      for (final id in _selected) {
        _shareController(id).text = _plain(e.shares[id]!);
      }
    }
    for (final c in [_budget, _search, ..._funds.values]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    for (final c in [
      _name,
      _search,
      _description,
      _budget,
      ..._funds.values,
      ..._customShares.values,
    ]) {
      c.dispose();
    }
    _searchFocus.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) => double.tryParse(c.text) ?? 0;

  double get _total => _splitWallets
      ? _funds.values.fold(0.0, (s, c) => s + _parse(c))
      : _parse(_budget);

  List<String> _orderedSelection(List<FamilyMember> members) => [
    for (final m in members)
      if (_selected.contains(m.id)) m.id!,
  ];

  TextEditingController _shareController(String id) =>
      _customShares.putIfAbsent(id, () {
        final c = TextEditingController();
        c.addListener(_refresh);
        return c;
      });

  /// Picks a place and, unless a name was typed, names the plan after it.
  void _choosePlace(String label) {
    setState(() {
      _place = label;
      if (!_nameTouched) {
        final short = label.split(',').first.trim();
        _name.text = _mode == _Mode.trip ? '$short trip' : short;
      }
    });
    _search.clear();
    _searchFocus.unfocus();
  }

  /// New people are added to the family and ticked for this plan.
  Future<void> _addPeople() async {
    final ids = await showAddPeopleSheet(
      context,
      title: _mode == _Mode.trip ? 'Who’s going?' : 'Who’s in?',
    );
    if (ids.isNotEmpty && mounted) setState(() => _selected.addAll(ids));
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _range = picked);
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    final members = context.read<FamilyProvider>().members;
    final ids = _orderedSelection(members);
    final total = _total;
    final name = _name.text.trim().isNotEmpty
        ? _name.text.trim()
        : _place.split(',').first.trim();
    if (name.isEmpty) return _toast('Give the plan a name');
    if (ids.isEmpty) return _toast('Pick at least one person');

    final Map<String, double> shares;
    if (_split == SplitMode.equal) {
      shares = Plan.equalShares(total, ids);
    } else {
      shares = {for (final id in ids) id: _parse(_shareController(id))};
      final assigned = shares.values.fold(0.0, (s, v) => s + v);
      if (assigned > total + 0.005) {
        return _toast(
          'Shares add up to ${formatAmount(assigned)}, more than the '
          '${formatAmount(total)} budget',
        );
      }
    }

    final monthly = _mode == _Mode.custom && _wholeMonth;
    final kind = switch (_mode) {
      _Mode.trip => PlanKind.trip,
      _Mode.event => PlanKind.event,
      _Mode.custom => monthly ? PlanKind.monthly : PlanKind.custom,
    };
    setState(() => _saving = true);
    await context.read<PlanProvider>().save(
      Plan(
        id: widget.existing?.id,
        name: name,
        kind: kind,
        start: monthly ? _month : _range.start,
        end: monthly ? DateTime(_month.year, _month.month + 1, 0) : _range.end,
        funds: _splitWallets
            ? {
                for (final e in _funds.entries)
                  if (_parse(e.value) > 0) e.key: _parse(e.value),
              }
            : {if (total > 0) _wallet: total},
        shares: shares,
        split: _split,
        createdBy:
            widget.existing?.createdBy ??
            context.read<SessionProvider>().session?.userId,
        destination: _mode == _Mode.custom ? '' : _place,
        description: _description.text.trim(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final members = context.watch<FamilyProvider>().members;
    final ids = _orderedSelection(members);
    final total = _total;
    final equal = Plan.equalShares(total, ids);
    final assigned = ids.fold(0.0, (s, id) => s + _parse(_shareController(id)));
    final query = _search.text.trim();
    final results = Destination.search(query);
    final exact = results.any(
      (d) => d.label.toLowerCase() == query.toLowerCase(),
    );
    final hasPlace = _mode != _Mode.custom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: GradientActionButton(
              label: _editing ? 'Save Changes' : 'Create Plan',
              colors: const [AppColors.lime, AppColors.lime],
              enabled: true,
              busy: _saving,
              onTap: _save,
            ),
          ),
        ),
        body: PatchBackdrop.behind(
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(foregroundColor: _blue),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _editing ? 'EDIT PLAN' : 'CREATE PLAN',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: AppTheme.displayFont,
                            fontFamilyFallback: AppTheme.displayFallback,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: _navy,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving ? null : _save,
                        style: TextButton.styleFrom(foregroundColor: _blue),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    children: [
                      _ModeTabs(
                        value: _mode,
                        onChanged: (m) => setState(() => _mode = m),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        switch (_mode) {
                          _Mode.trip => 'Where to?',
                          _Mode.event => 'What’s the occasion?',
                          _Mode.custom => 'What’s it for?',
                        },
                        style: const TextStyle(
                          fontFamily: AppTheme.displayFont,
                          fontFamilyFallback: AppTheme.displayFallback,
                          fontSize: 26.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: _navy,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (hasPlace) ...[
                        _Box(
                          child: TextField(
                            controller: _search,
                            focusNode: _searchFocus,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (v) {
                              if (v.trim().isNotEmpty) {
                                _choosePlace(
                                  results.isNotEmpty
                                      ? results.first.label
                                      : v.trim(),
                                );
                              }
                            },
                            style: _fieldText,
                            decoration: _input(
                              hint: _mode == _Mode.trip
                                  ? 'Search destination...'
                                  : 'Search venue or city...',
                              icon: Icons.search_rounded,
                            ),
                          ),
                        ),
                        if (query.isNotEmpty)
                          _SearchResults(
                            results: results,
                            query: exact ? null : query,
                            onPick: _choosePlace,
                          ),
                        if (_place.isNotEmpty) ...[
                          _Label(_mode == _Mode.trip ? 'Destination' : 'Venue'),
                          _PlaceCard(
                            place: _place,
                            onChange: () {
                              setState(() => _place = '');
                              _searchFocus.requestFocus();
                            },
                          ),
                        ],
                      ],
                      const _Label('Name'),
                      _Box(
                        child: TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => _nameTouched = true,
                          style: _fieldText,
                          decoration: _input(
                            hint: switch (_mode) {
                              _Mode.trip => 'e.g. Tokyo trip',
                              _Mode.event => 'e.g. Lola’s 80th birthday',
                              _Mode.custom => 'e.g. November budget',
                            },
                            icon: Icons.edit_outlined,
                          ),
                        ),
                      ),
                      if (_mode == _Mode.custom) ...[
                        const SizedBox(height: 12),
                        _Box(
                          child: SwitchListTile.adaptive(
                            value: _wholeMonth,
                            onChanged: (v) => setState(() => _wholeMonth = v),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            title: const Text(
                              'A whole month',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _navy,
                              ),
                            ),
                            subtitle: const Text(
                              'e.g. the family’s November budget',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                      _Label(
                        _mode == _Mode.custom && _wholeMonth
                            ? 'Month'
                            : 'Dates',
                      ),
                      if (_mode == _Mode.custom && _wholeMonth)
                        _MonthPicker(
                          month: _month,
                          onChanged: (m) => setState(() => _month = m),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _DatePill(
                                date: _range.start,
                                onTap: _pickRange,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: _blue,
                                size: 15.5,
                              ),
                            ),
                            Expanded(
                              child: _DatePill(
                                date: _range.end,
                                onTap: _pickRange,
                              ),
                            ),
                          ],
                        ),
                      const _Label('Budget', optional: true),
                      if (!_splitWallets)
                        _Box(
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _budget,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,2}'),
                                    ),
                                  ],
                                  style: _fieldText,
                                  decoration: _input(
                                    hint: '₱0',
                                    icon: Icons.account_balance_wallet_outlined,
                                  ).copyWith(prefixText: '₱ '),
                                ),
                              ),
                              _WalletMenu(
                                value: _wallet,
                                onChanged: (m) => setState(() => _wallet = m),
                              ),
                            ],
                          ),
                        )
                      else
                        _Box(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                          child: Column(
                            children: [
                              for (final m in PaymentMethod.values) ...[
                                _FundRow(method: m, controller: _funds[m]!),
                                const SizedBox(height: 8),
                              ],
                              const Divider(color: AppColors.divider),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      'Total budget',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      formatAmount(total),
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                        color: _navy,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() {
                            // Carry the amount over when switching views.
                            if (!_splitWallets) {
                              _funds[_wallet]!.text = _budget.text;
                            } else {
                              _budget.text = total > 0 ? _plain(total) : '';
                            }
                            _splitWallets = !_splitWallets;
                          }),
                          style: TextButton.styleFrom(foregroundColor: _blue),
                          icon: Icon(
                            _splitWallets
                                ? Icons.unfold_less_rounded
                                : Icons.call_split_rounded,
                            size: 15.5,
                          ),
                          label: Text(
                            _splitWallets
                                ? 'Keep it in one wallet'
                                : 'Split across wallets',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      _Label(_mode == _Mode.trip ? 'Who’s going' : 'Who’s in'),
                      _Box(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final m in members)
                                  MemberChip(
                                    member: m,
                                    selected: _selected.contains(m.id),
                                    onTap: () => setState(
                                      () => _selected.contains(m.id)
                                          ? _selected.remove(m.id)
                                          : _selected.add(m.id!),
                                    ),
                                  ),
                                _AddPeopleChip(onTap: _addPeople),
                              ],
                            ),
                            if (members.length < 2) ...[
                              const SizedBox(height: 10),
                              const Text(
                                'Just you so far — add the friends or family '
                                'coming along.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            SegmentedPill<SplitMode>(
                              value: _split,
                              onChanged: (s) => setState(() => _split = s),
                              options: const [
                                SegmentOption(SplitMode.equal, 'Split equally'),
                                SegmentOption(SplitMode.custom, 'Custom'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            for (final m in members)
                              if (_selected.contains(m.id))
                                _ShareRow(
                                  member: m,
                                  equalAmount: _split == SplitMode.equal
                                      ? equal[m.id] ?? 0
                                      : null,
                                  controller: _split == SplitMode.custom
                                      ? _shareController(m.id!)
                                      : null,
                                ),
                            if (_split == SplitMode.custom &&
                                ids.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _AssignedStatus(total: total, assigned: assigned),
                            ],
                          ],
                        ),
                      ),
                      const _Label('Description', optional: true),
                      _Box(
                        child: TextField(
                          controller: _description,
                          minLines: 3,
                          maxLines: 6,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                            hintText:
                                'e.g. Let’s explore Tokyo! Food, culture and '
                                'adventures.',
                            hintStyle: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _fieldText = TextStyle(
  fontSize: 13.5,
  fontWeight: FontWeight.w600,
  color: AppColors.textPrimary,
);

InputDecoration _input({required String hint, required IconData icon}) =>
    InputDecoration(
      border: InputBorder.none,
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 16, right: 10),
        child: Icon(icon, color: _blue, size: 19),
      ),
      prefixIconConstraints: const BoxConstraints(),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
    );

/// White rounded box with a pale blue edge, like the reference fields.
class _Box extends StatelessWidget {
  const _Box({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.optional = false});

  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          if (optional)
            const TextSpan(
              text: ' (optional)',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: _navy,
      ),
    ),
  );
}

/// Trip / Event / Custom with a blue selected pill.
class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.value, required this.onChanged});

  final _Mode value;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, _Mode m) {
      final selected = value == m;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: selected ? AppColors.mint : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.tealDark : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          tab('Trip', _Mode.trip),
          tab('Event', _Mode.event),
          tab('Custom', _Mode.custom),
        ],
      ),
    );
  }
}

/// Matching places under the search box, plus "use what I typed".
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.query,
    required this.onPick,
  });

  final List<Destination> results;

  /// Offered as-is when it isn't one of the results.
  final String? query;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: _Box(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final d in results)
            ListTile(
              onTap: () => onPick(d.label),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: SceneArt(style: d.style),
                ),
              ),
              title: Text(
                d.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _navy,
                ),
              ),
              subtitle: Text(
                d.blurb,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          if (query != null)
            ListTile(
              onTap: () => onPick(query!),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.blueTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.place_outlined, color: _blue),
              ),
              title: Text(
                'Use “$query”',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _navy,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// The chosen place: scene thumbnail, name and a short description.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onChange});

  final String place;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final d = Destination.find(place);
    final style =
        d?.style ?? SceneStyle.values[place.length % SceneStyle.values.length];
    return _Box(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: onChange,
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 76,
                height: 76,
                child: SceneArt(style: style),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d?.blurb ?? 'Tap to change the place.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_double_arrow_right_rounded,
              color: _blue,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Box(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, color: _blue, size: 16.5),
            const SizedBox(width: 10),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatDayShortYear(date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.month, required this.onChanged});

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData icon, int delta) => IconButton(
      onPressed: () => onChanged(DateTime(month.year, month.month + delta)),
      icon: Icon(icon, color: _blue),
    );
    return _Box(
      child: Row(
        children: [
          arrow(Icons.chevron_left_rounded, -1),
          Expanded(
            child: Text(
              formatMonth(month),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _navy,
              ),
            ),
          ),
          arrow(Icons.chevron_right_rounded, 1),
        ],
      ),
    );
  }
}

/// "in Cash ▾" next to the budget: which wallet holds it.
class _WalletMenu extends StatelessWidget {
  const _WalletMenu({required this.value, required this.onChanged});

  final PaymentMethod value;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) => PopupMenuButton<PaymentMethod>(
    initialValue: value,
    onSelected: onChanged,
    position: PopupMenuPosition.under,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    itemBuilder: (_) => [
      for (final m in PaymentMethod.values)
        PopupMenuItem(
          value: m,
          child: Row(
            children: [
              Icon(m.icon, color: m.color, size: 17),
              const SizedBox(width: 10),
              Text(m.label),
            ],
          ),
        ),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(value.icon, color: value.color, size: 15.5),
          const SizedBox(width: 6),
          Text(
            value.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, color: _navy),
        ],
      ),
    ),
  );
}

/// Small grey ₱ amount field used for funds and custom shares.
class _MoneyField extends StatelessWidget {
  const _MoneyField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 140,
    child: TextField(
      controller: controller,
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: sheetInputDecoration(hint: '0').copyWith(
        prefixText: '₱ ',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
    ),
  );
}

class _FundRow extends StatelessWidget {
  const _FundRow({required this.method, required this.controller});

  final PaymentMethod method;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: method.tint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(method.icon, color: method.color, size: 19),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Text(
          method.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      _MoneyField(controller: controller),
    ],
  );
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.member, this.equalAmount, this.controller});

  final FamilyMember member;

  /// Shown read-only when splitting equally.
  final double? equalAmount;

  /// Editable when splitting by custom amounts.
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        MemberAvatar(member, size: 34.5),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (controller != null)
          _MoneyField(controller: controller!)
        else
          Text(
            formatAmount(equalAmount ?? 0),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
      ],
    ),
  );
}

class _AssignedStatus extends StatelessWidget {
  const _AssignedStatus({required this.total, required this.assigned});

  final double total;
  final double assigned;

  @override
  Widget build(BuildContext context) {
    final diff = total - assigned;
    final (text, color, tint, icon) = diff.abs() < 0.005
        ? (
            'Every peso is assigned',
            AppColors.green,
            AppColors.greenTint,
            Icons.check_circle_outline_rounded,
          )
        : diff > 0
        ? (
            '${formatAmount(diff)} not assigned to anyone',
            AppColors.orange,
            AppColors.orangeTint,
            Icons.info_outline_rounded,
          )
        : (
            'Over the budget by ${formatAmount(-diff)}',
            AppColors.expenseRed,
            AppColors.redTint,
            Icons.error_outline_rounded,
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "+ Add people" at the end of the member chips.
class _AddPeopleChip extends StatelessWidget {
  const _AddPeopleChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.blueTint,
    shape: const StadiumBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: const Padding(
        padding: EdgeInsets.fromLTRB(10, 9, 14, 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_alt_1_rounded, size: 15.5, color: _blue),
            SizedBox(width: 6),
            Text(
              'Add people',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _blue,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
