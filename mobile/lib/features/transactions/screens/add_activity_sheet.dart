import 'dart:math' as math;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/core/widgets/form_sheet.dart';
import 'package:finance_tracker/core/widgets/sheet_parts.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/categories/models/category.dart';
import 'package:finance_tracker/features/categories/models/category_guesser.dart';
import 'package:finance_tracker/features/categories/widgets/category_chip.dart';
import 'package:finance_tracker/features/family/models/budget.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/family/screens/budget_form.dart';
import 'package:finance_tracker/features/family/widgets/member_avatar.dart';
import 'package:finance_tracker/features/plans/models/plan.dart';
import 'package:finance_tracker/features/plans/models/plan_stats.dart';
import 'package:finance_tracker/features/plans/providers/plan_provider.dart';
import 'package:finance_tracker/features/transfers/providers/transfer_provider.dart';
import 'package:finance_tracker/features/transactions/models/payment_method.dart';
import 'package:finance_tracker/features/transactions/widgets/receipt_photo.dart';
import 'package:finance_tracker/features/transactions/models/quick_picks.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';

/// Quick "Add Activity" sheet: category, type, amount and what it was for.
Future<void> showAddActivitySheet(
  BuildContext context, {
  String? memberId,
  TransactionType initialType = TransactionType.expense,
  String? initialCategoryId,
  String? noteHint,
  String? planId,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: sheetConstraints(context),
  backgroundColor: AppColors.surface,
  barrierColor: AppColors.textPrimary.withValues(alpha: 0.25),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
  ),
  // Hugs its content; scrolls if the keyboard leaves too little room.
  builder: (_) => _AddActivitySheet(
    memberId: memberId,
    initialType: initialType,
    initialCategoryId: initialCategoryId,
    noteHint: noteHint,
    planId: planId,
  ),
);

class _AddActivitySheet extends StatefulWidget {
  const _AddActivitySheet({
    this.memberId,
    this.initialType = TransactionType.expense,
    this.initialCategoryId,
    this.noteHint,
    this.planId,
  });

  final String? memberId;

  /// Trip or monthly plan the expense goes into.
  final String? planId;
  final TransactionType initialType;
  final String? initialCategoryId;
  final String? noteHint;

  @override
  State<_AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends State<_AddActivitySheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late TransactionType _type = widget.initialType;
  late String _categoryId =
      widget.initialCategoryId ?? Category.forType(_type).first.id;
  String? _memberId;

  /// Photo of the receipt or item, uploaded with the entry.
  File? _photo;
  PaymentMethod _method = PaymentMethod.cash;
  bool _saving = false;

  /// Plan this expense goes into, if any (read once when the sheet opens).
  Plan? _plan;

  /// The user picked a category themselves, so typing won't change it.
  bool _categoryChosen = false;

  /// The current category came from what was typed.
  bool _autoPicked = false;

  bool get _trip => _plan?.kind == PlanKind.trip;

  /// Trip expenses get trip categories (Accommodation, Pasalubong…).
  List<Category> get _categories =>
      _expense && _trip ? Category.forTrip() : Category.forType(_type);

  double get _value => double.tryParse(_amount.text) ?? 0;
  bool get _expense => _type == TransactionType.expense;

  @override
  void initState() {
    super.initState();
    // Defaults to whoever is signed in on this phone.
    _memberId =
        widget.memberId ??
        context
            .read<FamilyProvider>()
            .memberForUser(context.read<SessionProvider>().session?.userId)
            ?.id;
    // In a plan, start with the first place it has money.
    final plan = _plan = context.read<PlanProvider>().byId(widget.planId);
    if (_trip && widget.initialCategoryId == null) {
      _categoryId = _categories.first.id;
    }
    if (plan != null && plan.funds.isNotEmpty) {
      _method = PaymentMethod.values.firstWhere(
        (m) => (plan.funds[m] ?? 0) > 0,
        orElse: () => PaymentMethod.cash,
      );
    }
    _amount.addListener(() => setState(() {}));
    _note.addListener(_autoCategorize);
  }

  /// Follows what's typed ("2 kilos of manok" → Groceries) until the user
  /// picks a category themselves.
  void _autoCategorize() {
    if (_categoryChosen) return;
    final guess = CategoryGuesser.guess(_note.text, _categories);
    setState(() {
      _autoPicked = guess != null;
      if (guess != null) _categoryId = guess;
    });
  }

  void _chooseCategory(String id) => setState(() {
    _categoryId = id;
    _categoryChosen = true;
    _autoPicked = false;
  });

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Fills the sheet from a past entry; the user only needs to tap Add.
  void _applyPick(QuickPick p) {
    HapticFeedback.selectionClick();
    setState(() {
      _categoryId = p.categoryId;
      _categoryChosen = true;
      _autoPicked = false;
      _method = p.paymentMethod ?? _method;
    });
    _note.text = p.title;
    _amount.text = p.amount == p.amount.roundToDouble()
        ? p.amount.toStringAsFixed(0)
        : p.amount.toStringAsFixed(2);
  }

  void _setType(TransactionType t) {
    setState(() {
      _type = t;
      _categoryId = _categories.first.id;
      _categoryChosen = false;
    });
    _autoCategorize();
  }

  Future<void> _pickCategory() async {
    String? picked;
    await showFormSheet(
      context,
      title: _expense ? 'Spent on' : 'Received from',
      subtitle: 'Pick a category for this activity.',
      child: Builder(
        builder: (sheet) => Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in _categories)
              CategoryChip.of(
                c,
                selected: c.id == _categoryId,
                onTap: () {
                  picked = c.id;
                  Navigator.of(sheet).pop();
                },
              ),
          ],
        ),
      ),
    );
    if (picked != null) _chooseCategory(picked!);
  }

  Future<void> _save() async {
    if (_value <= 0 || _saving) return;
    setState(() => _saving = true);
    final note = _note.text.trim();
    await context.read<FinanceProvider>().add(
      TransactionItem(
        title: note.isEmpty ? Category.byId(_categoryId).name : note,
        amount: _value,
        type: _type,
        categoryId: _categoryId,
        date: DateTime.now(),
        memberId: _memberId,
        planId: widget.planId,
        paymentMethod: _method,
      ),
      photo: _photo,
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// Budget check against the plan instead of the monthly category budget.
  Widget _planCheck(Plan plan, PlanStats stats) {
    final leftAfter = plan.total - stats.spent - _value;
    final allocated = stats.fundsIn(plan, _method);
    final methodLeftAfter = allocated - (stats.byMethod[_method] ?? 0) - _value;
    return _CheckCard(
      title: 'Check this expense',
      message: leftAfter >= 0
          ? '${formatAmount(leftAfter)} of ${plan.name} left after this.'
          : 'This takes ${plan.name} ${formatAmount(-leftAfter)} over budget.',
      footer: allocated == 0
          ? '${_method.label} isn’t budgeted in this plan'
          : methodLeftAfter >= 0
          ? '${formatAmount(methodLeftAfter)} left in ${_method.label}'
          : '${_method.label} short by ${formatAmount(-methodLeftAfter)}',
      warning: leftAfter < 0 || methodLeftAfter < 0,
      onTap: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final family = context.watch<FamilyProvider>();
    final cat = Category.byId(_categoryId);

    final now = DateTime.now();
    final monthOfCategory = finance.all.where(
      (t) =>
          t.date.year == now.year &&
          t.date.month == now.month &&
          t.categoryId == _categoryId &&
          t.type == _type,
    );
    final categoryTotal = monthOfCategory.fold(0.0, (s, t) => s + t.amount);
    Budget? budget;
    for (final b in family.categoryBudgets) {
      if (b.categoryId == _categoryId) budget = b;
    }
    final budgetLeft = budget == null ? null : budget.limit - categoryTotal;
    final plan = context.watch<PlanProvider>().byId(widget.planId);
    final planStats = plan == null
        ? null
        : PlanStats.of(
            plan,
            finance.all,
            family,
            transfers: context.watch<TransferProvider>().all,
          );
    final picks = quickPicks(
      finance.all,
      type: _type,
      categoryIds: {for (final c in _categories) c.id},
      planId: widget.planId,
    );
    final daysLeft =
        DateUtils.getDaysInMonth(now.year, now.month) - now.day + 1;

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
                SheetTitleBar(
                  _trip && _expense ? 'Add Trip Expense' : 'Add Activity',
                ),
                const SizedBox(height: 14),
                if (plan != null && planStats != null)
                  _CategoryCard(
                    category: cat,
                    preposition: 'for',
                    label: plan.name,
                    amount: formatAmount(
                      math.max(plan.total - planStats.spent, 0),
                    ),
                    caption: 'left of ${formatAmount(plan.total)}',
                    onTap: null,
                  )
                else
                  _CategoryCard(
                    category: cat,
                    preposition: _expense ? 'from' : 'into',
                    label: cat.name,
                    amount: budgetLeft != null
                        ? formatAmount(math.max(budgetLeft, 0))
                        : formatAmount(categoryTotal),
                    caption: budgetLeft != null
                        ? 'left this month'
                        : (_expense ? 'spent this month' : 'this month'),
                    onTap: _pickCategory,
                  ),
                if (picks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _QuickPicks(picks: picks, onPick: _applyPick),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SheetSelect<TransactionType>(
                        label: 'Type',
                        value: _type,
                        display: (t) => t == TransactionType.expense
                            ? const Text('Expense')
                            : const Text('Income'),
                        options: const [
                          TransactionType.expense,
                          TransactionType.income,
                        ],
                        onChanged: _setType,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SheetSelect<PaymentMethod>(
                        label: _expense ? 'Paid with' : 'Received in',
                        value: _method,
                        display: (m) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(m.icon, size: 14.5, color: m.color),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                m.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        options: PaymentMethod.values,
                        onChanged: (m) => setState(() => _method = m),
                      ),
                    ),
                  ],
                ),
                if (family.members.length > 1) ...[
                  const SizedBox(height: 10),
                  SheetSelect<String>(
                    label: _expense ? 'Paid by' : 'Received by',
                    value: family.memberFor(_memberId).id!,
                    display: (id) {
                      final m = family.memberFor(id);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MemberAvatar(m, size: 17),
                          const SizedBox(width: 6),
                          Text(m.name),
                        ],
                      );
                    },
                    options: [for (final m in family.members) m.id!],
                    onChanged: (id) => setState(() => _memberId = id),
                  ),
                ],
                const SizedBox(height: 12),
                SheetBigAmount(controller: _amount),
                Text(
                  'Amount · balance ${formatAmount(finance.totalBalance)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                SheetNoteField(
                  controller: _note,
                  hint:
                      widget.noteHint ??
                      (!_expense
                          ? 'Where is it from? e.g. Sweldo'
                          : _trip
                          ? 'What was it? e.g. Grab to the hotel'
                          : 'What did you buy? e.g. 2 kilos of manok'),
                ),
                const SizedBox(height: 10),
                ReceiptField(
                  compact: true,
                  path: _photo?.path,
                  onChanged: (f) => setState(() => _photo = f),
                ),
                const SizedBox(height: 12),
                _CategoryStrip(
                  categories: _categories,
                  selected: _categoryId,
                  autoPicked: _autoPicked,
                  onSelect: _chooseCategory,
                  onMore: _pickCategory,
                ),
                const SizedBox(height: 14),
                if (plan != null && planStats != null && _expense)
                  _planCheck(plan, planStats)
                else
                  _CheckCard(
                    title: _expense ? 'Check this activity' : 'Nice one!',
                    message: !_expense
                        ? 'Your balance becomes '
                              '${formatAmount(finance.totalBalance + _value)}.'
                        : budgetLeft == null
                        ? 'No ${cat.name} budget yet. Set one?'
                        : budgetLeft - _value >= 0
                        ? '${formatAmount(budgetLeft - _value)} of ${cat.name} '
                              'left after this.'
                        : '${formatAmount(_value - budgetLeft)} over the '
                              '${cat.name} budget.',
                    footer: _expense && budget != null
                        ? '${((categoryTotal + _value) / budget.limit * 100).round()}% '
                              'of the budget used'
                        : '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left this month',
                    warning:
                        budgetLeft != null &&
                        _expense &&
                        budgetLeft - _value < 0,
                    onTap: _expense
                        ? () => showBudgetForm(
                            context,
                            existing: budget,
                            categoryId: _categoryId,
                          )
                        : null,
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: GradientActionButton(
                enabled: _value > 0,
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.preposition,
    required this.label,
    required this.amount,
    required this.caption,
    required this.onTap,
  });

  /// Drives the faded decoration icon.
  final Category category;
  final String preposition;

  /// Category or plan name after the preposition.
  final String label;
  final String amount;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 90,
          decoration: sheetBoxDecoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Oversized, faded category icon as decoration.
                Positioned(
                  right: -10,
                  top: -12,
                  child: Transform.rotate(
                    angle: 0.25,
                    child: Icon(
                      category.icon,
                      size: 74,
                      color: category.color.withValues(alpha: 0.22),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$preposition  ',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: label,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  amount,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.displayFont,
                                    fontFamilyFallback:
                                        AppTheme.displayFallback,
                                    fontSize: 21.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (onTap != null)
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textPrimary,
                          size: 22.5,
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

class _CheckCard extends StatelessWidget {
  const _CheckCard({
    required this.title,
    required this.message,
    required this.footer,
    required this.warning,
    required this.onTap,
  });

  final String title;
  final String message;
  final String footer;
  final bool warning;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: sheetBoxDecoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                const Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 110,
                  child: CustomPaint(painter: _SparklePainter()),
                ),
                if (onTap != null)
                  Positioned(
                    right: 18,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: AppColors.lime,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20.5,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 100, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: warning
                              ? AppColors.expenseRed
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        footer,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
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

/// Glossy blue four-point stars, like the reference illustration.
class _SparklePainter extends CustomPainter {
  const _SparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    void star(Offset c, double r, double angle) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = angle + i * math.pi / 2;
        final tip = c + Offset(math.cos(a), math.sin(a)) * r;
        final mid = a + math.pi / 4;
        final control = c + Offset(math.cos(mid), math.sin(mid)) * r * 0.16;
        if (i == 0) path.moveTo(tip.dx, tip.dy);
        final next = angle + (i + 1) * math.pi / 2;
        final nextTip = c + Offset(math.cos(next), math.sin(next)) * r;
        path.quadraticBezierTo(control.dx, control.dy, nextTip.dx, nextTip.dy);
      }
      path.close();
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFEE99), AppColors.gold, Color(0xFFF08C00)],
            stops: [0, 0.6, 1],
          ).createShader(rect),
      );
      // Soft highlight for a glossy look.
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            radius: 0.6,
            colors: [
              Colors.white.withValues(alpha: 0.7),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    final w = size.width;
    final h = size.height;
    star(Offset(w * 0.40, h * 0.60), h * 0.46, -math.pi / 2 + 0.12);
    star(Offset(w * 0.86, h * 0.30), h * 0.16, -math.pi / 2);
    star(Offset(w * 0.84, h * 0.88), h * 0.15, -math.pi / 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// "Category" heading and a sideways row of category chips; marks when the
/// pick came from what was typed and scrolls the selected chip into view.
class _CategoryStrip extends StatefulWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selected,
    required this.autoPicked,
    required this.onSelect,
    required this.onMore,
  });

  final List<Category> categories;
  final String selected;
  final bool autoPicked;
  final ValueChanged<String> onSelect;
  final VoidCallback onMore;

  @override
  State<_CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends State<_CategoryStrip> {
  final _keys = <String, GlobalKey>{};
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  @override
  void didUpdateWidget(covariant _CategoryStrip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      // Scrolls only this row; the sheet itself stays put while typing.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final chip = _keys[widget.selected]?.currentContext;
        final row = context.findRenderObject();
        if (chip == null ||
            !mounted ||
            !_scroll.hasClients ||
            row is! RenderBox) {
          return;
        }
        final box = chip.findRenderObject() as RenderBox;
        final dx = box.localToGlobal(Offset.zero, ancestor: row).dx;
        final target = (_scroll.offset + dx - 20).clamp(
          0.0,
          _scroll.position.maxScrollExtent,
        );
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Category',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 10),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.autoPicked ? 1 : 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
                decoration: BoxDecoration(
                  color: AppColors.blueTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 11,
                      color: AppColors.blue,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Auto-picked',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: widget.onMore,
              child: const Text(
                'See all',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final c in widget.categories) ...[
                CategoryChip.of(
                  c,
                  key: _keyFor(c.id),
                  selected: c.id == widget.selected,
                  onTap: () => widget.onSelect(c.id),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "Quick add" row of past entries; one tap fills the whole sheet.
class _QuickPicks extends StatelessWidget {
  const _QuickPicks({required this.picks, required this.onPick});

  final List<QuickPick> picks;
  final ValueChanged<QuickPick> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history_rounded, size: 14, color: AppColors.textMuted),
            SizedBox(width: 6),
            Text(
              'Quick add',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            Spacer(),
            Text(
              'Tap to fill',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final p in picks) ...[
                _QuickPickChip(pick: p, onTap: () => onPick(p)),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickPickChip extends StatelessWidget {
  const _QuickPickChip({required this.pick, required this.onTap});

  final QuickPick pick;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cat = Category.byId(pick.categoryId);
    return Material(
      color: AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(color: AppColors.divider, width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: cat.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(cat.icon, color: cat.color, size: 14),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  pick.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                formatAmount(pick.amount),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
