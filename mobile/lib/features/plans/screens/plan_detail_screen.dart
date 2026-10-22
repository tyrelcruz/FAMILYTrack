import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/core/widgets/empty_state.dart';
import 'package:finance_tracker/core/widgets/form_sheet.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/categories/models/category.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/family/widgets/add_people_sheet.dart';
import 'package:finance_tracker/features/family/widgets/avatar_stack.dart';
import 'package:finance_tracker/features/family/widgets/member_avatar.dart';
import 'package:finance_tracker/features/plans/models/plan.dart';
import 'package:finance_tracker/features/plans/models/plan_stats.dart';
import 'package:finance_tracker/features/plans/providers/plan_provider.dart';
import 'package:finance_tracker/features/plans/screens/plan_form_screen.dart';
import 'package:finance_tracker/features/plans/widgets/plan_card.dart';
import 'package:finance_tracker/features/plans/widgets/plan_scene.dart';
import 'package:finance_tracker/features/transactions/models/payment_method.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';
import 'package:finance_tracker/features/transactions/screens/add_activity_sheet.dart';
import 'package:finance_tracker/features/transactions/screens/add_transaction_screen.dart';
import 'package:finance_tracker/features/transfers/models/transfer.dart';
import 'package:finance_tracker/features/transfers/providers/transfer_provider.dart';
import 'package:finance_tracker/features/transfers/screens/transfer_sheet.dart';
import 'package:finance_tracker/features/transfers/widgets/transfer_row.dart';

enum _Tab { transactions, members, details }

const _navy = AppColors.textPrimary;
const _sheetTop = Color(0xFFE9E8FF);
const _sheetBottom = AppColors.background;
const _paleBlue = Color(0xFFE3E2FF);
const _iconBlue = AppColors.forest;

/// Trip or monthly plan overview: scene header, budget, quick actions, then
/// transactions, members and details in tabs.
class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  _Tab _tab = _Tab.transactions;
  bool _showAll = false;

  static const _scene = 300.0;
  static const _overlap = 58.0;

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> _confirmDelete(Plan plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: Text(
          'Delete ${plan.name}?',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Its expenses stay in your transactions; they just won’t be grouped '
          'under this plan any more.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
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
    final plans = context.read<PlanProvider>();
    final finance = context.read<FinanceProvider>();
    Navigator.of(context).pop();
    await plans.remove(plan.id!);
    await finance.load();
  }

  /// Adds friends or family and puts them straight into this plan; an
  /// equal split is recalculated, a custom one gives them ₱0 to set later.
  Future<void> _invite(Plan plan) async {
    final ids = await showAddPeopleSheet(
      context,
      title: 'Invite to ${plan.name}',
    );
    final fresh = ids.where((id) => !plan.shares.containsKey(id)).toList();
    if (fresh.isEmpty || !mounted) return;
    final everyone = [...plan.shares.keys, ...fresh];
    await context.read<PlanProvider>().save(
      plan.copyWith(
        shares: plan.split == SplitMode.equal
            ? Plan.equalShares(plan.total, everyone)
            : {...plan.shares, for (final id in fresh) id: 0},
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${fresh.length} added to ${plan.name}'
            '${plan.split == SplitMode.custom ? ' — set their share in Edit plan' : ''}',
          ),
        ),
      );
  }

  void _more(Plan plan, {required bool canGive}) {
    Widget option(
      BuildContext sheet,
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color color = AppColors.textPrimary,
    }) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color == AppColors.textPrimary
              ? AppColors.blueTint
              : AppColors.redTint,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color == AppColors.textPrimary ? AppColors.blue : color,
          size: 21,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      onTap: () {
        Navigator.of(sheet).pop();
        onTap();
      },
    );

    showFormSheet(
      context,
      title: plan.name,
      subtitle: 'More for this plan',
      child: Builder(
        builder: (sheet) => Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              option(
                sheet,
                Icons.swap_horiz_rounded,
                'Move money between wallets',
                () => showTransferSheet(context, planId: plan.id),
              ),
              if (canGive)
                option(
                  sheet,
                  Icons.people_alt_outlined,
                  'Give money to someone',
                  () => showTransferSheet(
                    context,
                    planId: plan.id,
                    kind: TransferKind.people,
                  ),
                ),
              option(
                sheet,
                Icons.edit_outlined,
                'Edit plan',
                () => _push(PlanFormScreen(existing: plan)),
              ),
              option(
                sheet,
                Icons.delete_outline_rounded,
                'Delete plan',
                () => _confirmDelete(plan),
                color: AppColors.expenseRed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanProvider>().byId(widget.planId);
    final finance = context.watch<FinanceProvider>();
    final family = context.watch<FamilyProvider>();
    final myUserId = context.watch<SessionProvider>().session?.userId;
    // Deleted (here or on another phone) while open.
    if (plan == null) return const Scaffold();

    final stats = PlanStats.of(
      plan,
      finance.all,
      family,
      transfers: context.watch<TransferProvider>().all,
    );
    final now = DateTime.now();
    final daysLeft = plan.daysLeft(now);
    final left = plan.total - stats.spent;

    // Everyone with a share, plus anyone who spent without one.
    final people = <FamilyMember>[
      for (final m in family.members)
        if (stats.hasShare(plan, m.id!) || stats.byMember.containsKey(m.id)) m,
    ];
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    final Widget tabBody = switch (_tab) {
      _Tab.transactions => _transactionsTab(plan, stats, family, myUserId),
      _Tab.members => _membersTab(plan, stats, people),
      _Tab.details => _detailsTab(plan, stats, daysLeft, left, now),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _sheetBottom,
        body: ListView(
          padding: EdgeInsets.only(bottom: bottom + 24),
          children: [
            Stack(
              children: [
                SizedBox(
                  height: _scene + top,
                  child: _SceneHeader(
                    plan: plan,
                    members: people,
                    topInset: top,
                    overlap: _overlap,
                    onBack: () => Navigator.of(context).pop(),
                    onMore: () => _more(plan, canGive: people.length > 1),
                  ),
                ),
                _Sheet(
                  top: _scene + top - _overlap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BudgetCard(plan: plan, spent: stats.spent),
                      const SizedBox(height: 20),
                      Row(
                        // Keeps the circles level when a label wraps.
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ActionButton(
                            icon: Icons.add_rounded,
                            label: 'Add\nExpense',
                            onTap: () =>
                                showAddActivitySheet(context, planId: plan.id),
                          ),
                          _ActionButton(
                            icon: Icons.person_add_alt_1_outlined,
                            label: 'Invite',
                            onTap: () => _invite(plan),
                          ),
                          _ActionButton(
                            icon: Icons.savings_outlined,
                            label: 'Set\nBudget',
                            onTap: () => _push(PlanFormScreen(existing: plan)),
                          ),
                          _ActionButton(
                            icon: Icons.expand_more_rounded,
                            label: 'More',
                            onTap: () =>
                                _more(plan, canGive: people.length > 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _Tabs(
                        value: _tab,
                        onChanged: (t) => setState(() => _tab = t),
                      ),
                      tabBody,
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _transactionsTab(
    Plan plan,
    PlanStats stats,
    FamilyProvider family,
    String? myUserId,
  ) {
    // Expenses and transfers together, newest first.
    final entries = <(DateTime, Object)>[
      for (final t in stats.expenses) (t.date, t),
      for (final t in stats.transfers) (t.date, t),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    final shown = _showAll ? entries : entries.take(5).toList();
    String who(String? memberId) {
      final m = family.memberFor(memberId);
      return m.userId != null && m.userId == myUserId ? 'You' : m.name;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          'Latest Expenses',
          action: entries.length > 5
              ? (_showAll ? 'Show less' : 'See all')
              : null,
          onAction: () => setState(() => _showAll = !_showAll),
        ),
        if (entries.isEmpty)
          const EmptyState('No expenses yet — tap Add Expense'),
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, indent: 70, color: Color(0xFFDCDCEA)),
          switch (shown[i].$2) {
            final TransactionItem e => _ExpenseLine(
              item: e,
              subtitle: '${formatShortDay(e.date)}  •  ${who(e.memberId)}',
              onTap: () => _push(AddTransactionScreen(existing: e)),
            ),
            final Transfer t => TransferRow(
              transfer: t,
              onTap: () => showTransferSheet(context, existing: t),
            ),
            _ => const SizedBox.shrink(),
          },
        ],
      ],
    );
  }

  Widget _membersTab(Plan plan, PlanStats stats, List<FamilyMember> people) {
    var assigned = 0.0;
    for (final m in people) {
      assigned += stats.shareOf(plan, m.id!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          plan.split == SplitMode.equal ? 'Split equally' : 'Custom split',
          trailing:
              '${people.length} '
              '${people.length == 1 ? 'person' : 'people'}',
          action: people.length > 1 ? 'Give money' : null,
          onAction: () => showTransferSheet(
            context,
            planId: plan.id,
            kind: TransferKind.people,
          ),
        ),
        _WhiteCard(
          children: [
            if (people.isEmpty) const EmptyState('No one in this plan'),
            for (var i = 0; i < people.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, indent: 48, color: AppColors.divider),
              _PersonRow(
                member: people[i],
                share: stats.shareOf(plan, people[i].id!),
                spent: stats.byMember[people[i].id] ?? 0,
              ),
            ],
            if (plan.total - assigned >= 0.01) ...[
              const Divider(height: 1, color: AppColors.divider),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  '${formatAmount(plan.total - assigned)} of the budget '
                  'isn’t assigned to anyone.',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _detailsTab(
    Plan plan,
    PlanStats stats,
    int daysLeft,
    double left,
    DateTime now,
  ) {
    final methods = [
      for (final m in PaymentMethod.values)
        if (stats.fundsIn(plan, m) != 0 || (stats.byMethod[m] ?? 0) > 0) m,
    ];
    Widget info(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          'Where the money is',
          action: 'Move money',
          onAction: () => showTransferSheet(context, planId: plan.id),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth - 14) / 2;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final m in methods)
                  SizedBox(
                    width: w,
                    child: _WalletTile(
                      method: m,
                      allocated: stats.fundsIn(plan, m),
                      spent: stats.byMethod[m] ?? 0,
                    ),
                  ),
              ],
            );
          },
        ),
        const _SectionTitle('About this plan'),
        _WhiteCard(
          children: [
            if (plan.destination.isNotEmpty)
              info(Icons.place_outlined, 'Where', plan.destination),
            info(
              Icons.event_outlined,
              'Dates',
              formatDateRange(plan.start, plan.end),
            ),
            info(Icons.timelapse_rounded, 'Status', planStatus(plan, now)),
            info(
              Icons.today_outlined,
              'Per day left',
              daysLeft == 0
                  ? '—'
                  : formatAmount(
                      (math.max(left, 0) / daysLeft).floorToDouble(),
                    ),
            ),
            info(
              Icons.account_balance_wallet_outlined,
              'Total budget',
              formatAmount(plan.total),
            ),
            info(
              Icons.pie_chart_outline_rounded,
              'Split',
              plan.split == SplitMode.equal ? 'Equally' : 'Custom amounts',
            ),
          ],
        ),
        if (plan.description.isNotEmpty) ...[
          const _SectionTitle('Notes'),
          _WhiteCard(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  plan.description,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        SheetPrimaryButton(
          label: 'Edit Plan',
          onPressed: () => _push(PlanFormScreen(existing: plan)),
        ),
      ],
    );
  }
}

/// Full-width painted scene with the top bar, name, dates and members.
class _SceneHeader extends StatelessWidget {
  const _SceneHeader({
    required this.plan,
    required this.members,
    required this.topInset,
    required this.overlap,
    required this.onBack,
    required this.onMore,
  });

  final Plan plan;
  final List<FamilyMember> members;
  final double topInset;
  final double overlap;
  final VoidCallback onBack;
  final VoidCallback onMore;

  static const _shadow = [Shadow(color: Color(0x66000000), blurRadius: 10)];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PlanScene(plan: plan),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0x00000000), Color(0x80000000)],
              stops: [0, 0.35, 1],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, topInset + 6, 16, overlap + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _GlassButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: onBack,
                  ),
                  Expanded(
                    child: Text(
                      plan.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        shadows: _shadow,
                      ),
                    ),
                  ),
                  _GlassButton(icon: Icons.more_horiz_rounded, onTap: onMore),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontFamilyFallback: AppTheme.displayFallback,
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        shadows: _shadow,
                      ),
                    ),
                    if (plan.destination.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.place_rounded,
                              color: Colors.white,
                              size: 16,
                              shadows: _shadow,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                plan.destination,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  shadows: _shadow,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDateRange(plan.start, plan.end)}  •  '
                      '${members.length} '
                      '${members.length == 1 ? 'member' : 'members'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                        shadows: _shadow,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        AvatarStack(members: members, size: 32),
                        const SizedBox(width: 10),
                        Text(
                          '${members.length} '
                          '${members.length == 1 ? 'member' : 'members'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            shadows: _shadow,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.25),
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    ),
  );
}

/// White card over the scene: spent of total, bar and percent used.
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.plan, required this.spent});

  final Plan plan;
  final double spent;

  @override
  Widget build(BuildContext context) {
    final total = plan.total;
    final over = spent > total;
    final ratio = total <= 0 ? 0.0 : spent / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: _iconBlue.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            switch (plan.kind) {
              PlanKind.trip => 'Trip Budget',
              PlanKind.event => 'Event Budget',
              PlanKind.monthly => 'Monthly Budget',
              PlanKind.custom => 'Budget',
            },
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatAmount(spent),
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontFamilyFallback: AppTheme.displayFallback,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: over ? AppColors.expenseRed : _navy,
                ),
              ),
              Text(
                ' / ${formatAmount(total)}',
                style: const TextStyle(
                  fontSize: 17,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    height: 10,
                    color: const Color(0xFFE6E6F2),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: math.min(ratio, 1),
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          gradient: LinearGradient(
                            colors: over
                                ? const [
                                    Color(0xFFF87171),
                                    AppColors.expenseRed,
                                  ]
                                : const [AppColors.lime, AppColors.lime],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(ratio * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: _paleBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.blue, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: _navy,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Transactions / Members / Details, with a blue selected pill.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.value, required this.onChanged});

  final _Tab value;
  final ValueChanged<_Tab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, _Tab t) {
      final selected = value == t;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: selected ? AppColors.lime : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.forest : _navy,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE3E2F6),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          tab('Transactions', _Tab.transactions),
          tab('Members', _Tab.members),
          tab('Details', _Tab.details),
        ],
      ),
    );
  }
}

/// Expense row as in the reference: tinted category circle, title,
/// "Mar 15 • You", red amount.
class _ExpenseLine extends StatelessWidget {
  const _ExpenseLine({
    required this.item,
    required this.subtitle,
    required this.onTap,
  });

  final TransactionItem item;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cat = Category.byId(item.categoryId);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: _paleBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(cat.icon, color: _iconBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: _navy,
                          ),
                        ),
                      ),
                      if (item.hasAnyPhoto) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.photo_camera_outlined,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '- ${formatAmount(item.amount)}',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: AppColors.expenseRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing, this.action, this.onAction});

  final String title;
  final String? trailing;

  /// Optional link on the right, e.g. "Move money".
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 28, 2, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: AppTheme.displayFont,
              fontFamilyFallback: AppTheme.displayFallback,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        if (action != null) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.blue,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(26),
      boxShadow: AppColors.softShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// One place the money is kept: what's left there out of what was put in.
class _WalletTile extends StatelessWidget {
  const _WalletTile({
    required this.method,
    required this.allocated,
    required this.spent,
  });

  final PaymentMethod method;
  final double allocated;
  final double spent;

  @override
  Widget build(BuildContext context) {
    final left = allocated - spent;
    final over = left < 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: method.tint,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(method.icon, color: method.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  method.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              over ? '-${formatAmount(-left)}' : formatAmount(left),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: over ? AppColors.expenseRed : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            allocated == 0
                ? 'not budgeted · ${formatAmount(spent)} spent'
                : 'of ${formatAmount(allocated)} · ${formatAmount(spent)} spent',
            maxLines: 2,
            style: TextStyle(
              fontSize: 12.5,
              color: allocated == 0
                  ? AppColors.expenseRed
                  : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: allocated == 0 ? 1 : math.min(spent / allocated, 1),
              minHeight: 5,
              backgroundColor: AppColors.progressTrack,
              color: over ? AppColors.expenseRed : method.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A member's share of the plan, what they've spent and what's left —
/// kept to two short lines so a big group still fits on screen.
class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.member,
    required this.share,
    required this.spent,
  });

  final FamilyMember member;
  final double share;
  final double spent;

  @override
  Widget build(BuildContext context) {
    final left = share - spent;
    final over = left < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          MemberAvatar(member, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: formatAmount(left.abs()),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: over
                                  ? AppColors.expenseRed
                                  : AppColors.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: over ? ' over' : ' left',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: over
                                  ? AppColors.expenseRed
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: share == 0
                              ? (spent > 0 ? 1 : 0)
                              : math.min(spent / share, 1),
                          minHeight: 5,
                          backgroundColor: AppColors.progressTrack,
                          color: over ? AppColors.expenseRed : member.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Fixed width so every bar in the list is the same length.
                    SizedBox(
                      width: 116,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${formatAmount(spent)} / ${formatAmount(share)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted pale-blue panel that rises over the scene and holds everything
/// below it.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.top, required this.child});

  /// Where the sheet starts, from the top of the page.
  final double top;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top),
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_sheetTop, _sheetBottom],
          stops: [0, 0.4],
        ),
      ),
      child: child,
    ),
  );
}
