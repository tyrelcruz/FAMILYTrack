import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/core/widgets/circle_button.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/family/models/budget.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/family/screens/budget_form.dart';
import 'package:finance_tracker/features/home/widgets/balance_card.dart';
import 'package:finance_tracker/features/home/widgets/budget_category_strip.dart';
import 'package:finance_tracker/features/home/widgets/home_hero.dart';
import 'package:finance_tracker/features/home/widgets/recent_activity.dart';
import 'package:finance_tracker/features/notifications/providers/activity_provider.dart';
import 'package:finance_tracker/features/notifications/screens/notifications_screen.dart';
import 'package:finance_tracker/features/stats/screens/stats_screen.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';
import 'package:finance_tracker/features/transactions/screens/add_transaction_screen.dart';
import 'package:finance_tracker/features/transactions/screens/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onProfileTap});

  final VoidCallback onProfileTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Eye toggle next to "Safe to spend" masks every amount on the page.
  bool _hidden = false;

  String _money(double v) => _hidden ? '₱••••' : formatAmount(v);

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  void _openAllTransactions() => _push(const TransactionsScreen());

  void _explainSafeToSpend() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: const Text(
        'Safe to spend',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: const Text(
        'What’s left of the family’s monthly budget after this month’s '
        'expenses, split across the days remaining. Without a budget it’s '
        'this month’s income minus expenses.',
        style: TextStyle(color: AppColors.textSecondary, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final family = context.watch<FamilyProvider>();
    final session = context.watch<SessionProvider>();
    if (finance.loading || family.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final thisMonth = finance.all
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .toList();
    double sum(bool expense) => thisMonth
        .where((t) => t.isExpense == expense)
        .fold(0.0, (s, t) => s + t.amount);
    final spent = sum(true);
    final daysLeft =
        DateUtils.getDaysInMonth(now.year, now.month) - now.day + 1;
    final overall = family.overallBudget;

    final double safe;
    final String caption;
    if (overall != null) {
      final left = overall.limit - spent;
      safe = left < 0 ? 0 : left;
      caption = left < 0
          ? 'You’re ${_money(-left)} over this month’s budget.'
          : '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left this month, '
                'you can spend ${_money((left / daysLeft).floorToDouble())}\u2060/\u2060day.';
    } else {
      final left = sum(false) - spent;
      safe = left < 0 ? 0 : left;
      caption = 'Tap to set a monthly budget and get a daily allowance.';
    }

    final name = session.session?.name ?? family.owner.name;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ListView(
      padding: EdgeInsets.only(bottom: bottomInset + 16),
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(20, topInset + 8, 20, 30),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppColors.heroGradient,
              stops: [0, 0.4, 0.75, 1],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeHero(
                userInitial: name.isEmpty ? '?' : name[0].toUpperCase(),
                amount: _money(safe),
                caption: caption,
                hidden: _hidden,
                onToggleHidden: () => setState(() => _hidden = !_hidden),
                onAmountTap: () => overall == null
                    ? showBudgetForm(context, categoryId: Budget.overall)
                    : _explainSafeToSpend(),
                onNotificationsTap: () => _push(const NotificationsScreen()),
                unread: context.watch<ActivityProvider>().unreadFor(
                  session.session?.userId,
                ),
                onInfoTap: _explainSafeToSpend,
                onProfileTap: widget.onProfileTap,
              ),
              const SizedBox(height: 30),
              BalanceCard(
                amount: _money(finance.totalBalance),
                onTap: _openAllTransactions,
              ),
            ],
          ),
        ),
        _SectionTitle(
          'Budget Category',
          action: 'Insights',
          onAction: () => _push(const _InsightsPage()),
        ),
        BudgetCategoryStrip(
          budgets: [
            if (overall != null) BudgetProgress(overall, spent),
            for (final b in family.categoryBudgets)
              BudgetProgress(b, family.spentFor(b, thisMonth)),
          ],
          format: _money,
          onTap: (b) => showBudgetForm(context, existing: b),
          onAdd: () => showBudgetForm(context),
        ),
        _SectionTitle(
          'Recent Activity',
          action: 'See all',
          onAction: _openAllTransactions,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: RecentActivity(
            items: finance.all.take(6).toList(),
            format: _money,
            onTap: (t) => _push(AddTransactionScreen(existing: t)),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(action ?? 'See all'),
            ),
        ],
      ),
    );
  }
}

/// Spending-by-category charts, opened from the Budget Category heading.
class _InsightsPage extends StatelessWidget {
  const _InsightsPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
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
                    'Insights',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 54),
              ],
            ),
          ),
          const Expanded(child: StatsScreen()),
        ],
      ),
    ),
  );
}
