import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/core/widgets/circle_button.dart';
import 'package:finance_tracker/core/widgets/empty_state.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/categories/models/category.dart';
import 'package:finance_tracker/features/family/models/budget.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/family/screens/budget_form.dart';
import 'package:finance_tracker/features/notifications/models/activity.dart';
import 'package:finance_tracker/features/notifications/providers/activity_provider.dart';
import 'package:finance_tracker/features/plans/models/plan_stats.dart';
import 'package:finance_tracker/features/plans/providers/plan_provider.dart';
import 'package:finance_tracker/features/plans/screens/plan_detail_screen.dart';
import 'package:finance_tracker/features/transactions/models/payment_method.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';
import 'package:finance_tracker/features/transactions/screens/add_transaction_screen.dart';

/// Bell screen: budget and plan warnings, then what the family has been
/// doing (from the server's activity feed).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the bell counts as seeing everything in it.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<ActivityProvider>().markSeen(),
    );
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityProvider>();
    final session = context.watch<SessionProvider>();
    final warnings = _warnings(context);
    final myUserId = session.session?.userId;

    // Group the feed by day.
    final days = <String, List<Activity>>{};
    for (final a in activity.items) {
      days.putIfAbsent(formatDayHeader(a.createdAt), () => []).add(a);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: session.sync,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
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
                    const Expanded(
                      child: Text(
                        'Notifications',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 54),
                  ],
                ),
                if (warnings.isNotEmpty) ...[
                  const _SectionTitle('Heads up'),
                  for (final w in warnings) ...[
                    _WarningCard(warning: w),
                    const SizedBox(height: 10),
                  ],
                ],
                if (activity.items.isEmpty) ...[
                  const SizedBox(height: 40),
                  const EmptyState(
                    'Nothing yet. When someone in the family adds an expense, '
                    'joins, or makes a plan, it shows up here.',
                  ),
                ],
                for (final day in days.entries) ...[
                  _SectionTitle(day.key),
                  _FeedCard(
                    items: day.value,
                    myUserId: myUserId,
                    onOpen: _openTarget,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Opens what an entry is about, if it's still here.
  void _openTarget(Activity a) {
    final finance = context.read<FinanceProvider>();
    final plans = context.read<PlanProvider>();
    final txId = a.data['transactionId'];
    if (txId != null) {
      for (final t in finance.all) {
        if (t.id == txId) return _push(AddTransactionScreen(existing: t));
      }
    }
    final planId = a.data['planId'];
    if (planId is String && plans.byId(planId) != null) {
      _push(PlanDetailScreen(planId: planId));
    }
  }
}

class _Warning {
  const _Warning(
    this.icon,
    this.color,
    this.tint,
    this.title,
    this.body,
    this.onTap,
  );

  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String body;
  final VoidCallback onTap;
}

/// Budgets and active plans that are over, or nearly out.
List<_Warning> _warnings(BuildContext context) {
  final finance = context.watch<FinanceProvider>();
  final family = context.watch<FamilyProvider>();
  final plans = context.watch<PlanProvider>();
  final now = DateTime.now();
  final thisMonth = finance.all
      .where((t) => t.date.year == now.year && t.date.month == now.month)
      .toList();
  final out = <_Warning>[];

  void budgetCheck(Budget b, String name) {
    final spent = family.spentFor(b, thisMonth);
    if (b.limit <= 0 || spent < b.limit * 0.9) return;
    final over = spent > b.limit;
    out.add(
      _Warning(
        over ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
        over ? AppColors.expenseRed : AppColors.orange,
        over ? AppColors.redTint : AppColors.orangeTint,
        over ? '$name is over budget' : '$name is almost used up',
        over
            ? '${formatAmount(spent - b.limit)} over the ${formatAmount(b.limit)} limit this month.'
            : 'Only ${formatAmount(b.limit - spent)} left of ${formatAmount(b.limit)} this month.',
        () => showBudgetForm(context, existing: b),
      ),
    );
  }

  final overall = family.overallBudget;
  if (overall != null) budgetCheck(overall, 'The family budget');
  for (final b in family.categoryBudgets) {
    budgetCheck(b, Category.byId(b.categoryId).name);
  }
  for (final p in plans.plans.where((p) => p.isActive(now))) {
    final spent = PlanStats.of(p, finance.all, family).spent;
    if (p.total <= 0 || spent < p.total * 0.9) continue;
    final over = spent > p.total;
    out.add(
      _Warning(
        over ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
        over ? AppColors.expenseRed : AppColors.orange,
        over ? AppColors.redTint : AppColors.orangeTint,
        over ? '${p.name} is over budget' : '${p.name} is almost used up',
        over
            ? '${formatAmount(spent - p.total)} over the ${formatAmount(p.total)} plan.'
            : 'Only ${formatAmount(p.total - spent)} left of ${formatAmount(p.total)}.',
        () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlanDetailScreen(planId: p.id!)),
        ),
      ),
    );
  }
  return out;
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.warning});

  final _Warning warning;

  @override
  Widget build(BuildContext context) => Material(
    color: warning.tint,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: warning.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(warning.icon, color: warning.color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warning.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    warning.body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    ),
  );
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.items,
    required this.myUserId,
    required this.onOpen,
  });

  final List<Activity> items;
  final String? myUserId;
  final ValueChanged<Activity> onOpen;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      boxShadow: AppColors.softShadow,
    ),
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, indent: 52, color: AppColors.divider),
          _FeedRow(
            activity: items[i],
            mine: items[i].actorUserId == myUserId,
            onTap: () => onOpen(items[i]),
          ),
        ],
      ],
    ),
  );
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({
    required this.activity,
    required this.mine,
    required this.onTap,
  });

  final Activity activity;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilyProvider>();
    final a = activity;
    final d = a.data;
    final who = mine ? 'You' : a.actorName;
    // The actor's current member, for their avatar color.
    FamilyMember? actor = family.memberForUser(a.actorUserId);
    String memberName(Object? id) =>
        id is String ? family.memberFor(id).name : 'someone';
    String money(Object? v) => formatAmount((v as num? ?? 0).toDouble());

    final String text;
    String? detail;
    String? amount;
    var amountColor = AppColors.textPrimary;
    switch (a.kind) {
      case 'transaction_added':
        final income = d['type'] == 'income';
        text = '$who added ${d['title']}';
        detail = Category.byId('${d['categoryId']}').name;
        amount = '${income ? '+' : '-'}${money(d['amount'])}';
        amountColor = income ? AppColors.green : AppColors.expenseRed;
      case 'member_joined':
        text = '${mine ? 'You' : d['name']} joined the family';
      case 'member_added':
        text = '$who added ${d['name']} to the family';
      case 'plan_created':
        text = '$who created the plan ${d['name']}';
        detail =
            '${d['kind'] == 'trip' ? 'Trip' : 'Monthly'} · ${money(d['total'])}';
      case 'budget_set':
        final cat = d['categoryId'] == Budget.overall
            ? 'family'
            : Category.byId('${d['categoryId']}').name;
        text = '$who set the $cat budget to ${money(d['limit'])}';
      case 'transfer_added':
        if (d['kind'] == 'people') {
          text =
              '${memberName(d['fromMemberId'])} gave '
              '${memberName(d['toMemberId'])} ${money(d['amount'])}';
        } else {
          final from = PaymentMethod.tryParse(d['fromMethod'])?.label ?? '?';
          final to = PaymentMethod.tryParse(d['toMethod'])?.label ?? '?';
          text = '$who moved ${money(d['amount'])} from $from to $to';
        }
      default:
        text = '$who updated the family';
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: actor?.color ?? AppColors.textMuted,
                shape: BoxShape.circle,
              ),
              child: Text(
                (actor?.name ?? a.actorName).isEmpty
                    ? '?'
                    : (actor?.name ?? a.actorName)[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [?detail, formatTime(a.createdAt)].join(' · '),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (amount != null) ...[
              const SizedBox(width: 8),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: amountColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 24, 2, 10),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),
  );
}
