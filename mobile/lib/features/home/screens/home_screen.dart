import 'dart:math' as math;

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/core/widgets/circle_button.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/family/models/budget.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/family/screens/budget_form.dart';
import 'package:finance_tracker/features/home/widgets/budget_category_strip.dart';
import 'package:finance_tracker/features/home/widgets/coin_breakdown.dart';
import 'package:finance_tracker/features/home/widgets/recent_activity.dart';
import 'package:finance_tracker/features/notifications/providers/activity_provider.dart';
import 'package:finance_tracker/features/notifications/screens/notifications_screen.dart';
import 'package:finance_tracker/features/stats/screens/stats_screen.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';
import 'package:finance_tracker/features/transactions/screens/add_transaction_screen.dart';
import 'package:finance_tracker/features/transactions/screens/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Home: "October's breakdown" — money in vs out as coin stacks, what's
/// left before the limit and per day, a tip, then recent activity.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onProfileTap});

  final VoidCallback onProfileTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Months whose tip card was closed.
  final _dismissedTips = <DateTime>{};

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  void _openAllTransactions() => _push(const TransactionsScreen());

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final family = context.watch<FamilyProvider>();
    final session = context.watch<SessionProvider>();
    if (finance.loading || family.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final month = finance.month;
    final items = finance.monthItems;
    double sum(bool Function(TransactionItem t) test) =>
        items.where(test).fold(0.0, (s, t) => s + t.amount);
    final income = sum((t) => !t.isExpense);
    final planSpent = sum((t) => t.isExpense && t.planId != null);
    final everyday = sum((t) => t.isExpense && t.planId == null);
    final out = planSpent + everyday;
    final overall = family.overallBudget;

    // Where today falls in the shown month.
    final now = DateTime.now();
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final isCurrent = month.year == now.year && month.month == now.month;
    final isPast =
        DateTime(
          month.year,
          month.month + 1,
        ).isBefore(DateTime(now.year, now.month, now.day + 1)) &&
        !isCurrent;
    final daysLeft = isCurrent ? days - now.day + 1 : (isPast ? 0 : days);
    final progress = isCurrent ? (now.day - 1) / days : (isPast ? 1.0 : 0.0);
    final left = overall == null ? null : overall.limit - out;
    final perDay = left == null || daysLeft == 0
        ? null
        : math.max(left, 0) / daysLeft;

    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final unread = context.watch<ActivityProvider>().unreadFor(
      session.session?.userId,
    );
    final monthName = DateFormat('MMMM').format(month);
    final tip = _dismissedTips.contains(month)
        ? null
        : _tipFor(
            hasLimit: overall != null,
            left: left ?? 0,
            count: items.where((t) => t.isExpense).length,
            dayOfMonth: isCurrent ? now.day : days,
          );

    return ColoredBox(
      color: _tealGreen,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Indigo breakdown ─────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(12, top + 6, 12, 0),
            child: Row(
              children: [
                _TopIcon(
                  icon: Icons.notifications_none_rounded,
                  dot: unread > 0,
                  onTap: () => _push(const NotificationsScreen()),
                ),
                Expanded(
                  child: Text(
                    "${monthName.toUpperCase()}'S BREAKDOWN",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontFamilyFallback: AppTheme.displayFallback,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: Colors.white,
                    ),
                  ),
                ),
                _TopIcon(
                  icon: Icons.settings_outlined,
                  onTap: widget.onProfileTap,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$monthName 1 - $monthName $days',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _softWhite),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 128,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCurrent
                ? '$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left'
                : (isPast ? 'Month ended' : 'Hasn’t started'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.lime,
            ),
          ),
          const SizedBox(height: 18),
          Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CoinBreakdown(
                  income: income,
                  spent: everyday,
                  plans: planSpent,
                  limit: overall?.limit,
                ),
              ),
              Positioned(
                left: 0,
                bottom: 50,
                child: _SideArrow(
                  left: true,
                  onTap: () => finance.changeMonth(-1),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 50,
                child: _SideArrow(
                  left: false,
                  onTap: () => finance.changeMonth(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Centered under each coin stack (same 36% / 64% as the stacks).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LayoutBuilder(
              builder: (context, c) => SizedBox(
                height: 48,
                child: Stack(
                  children: [
                    for (final (x, label, amount) in [
                      (0.36, 'In', income),
                      (0.64, 'Out', out),
                    ])
                      Positioned(
                        left: c.maxWidth * x,
                        top: 0,
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, 0),
                          child: _InOut(label: label, amount: amount),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 34),
          // ── White sheet ──────────────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.sizeOf(context).height * 0.6,
                ),
                padding: EdgeInsets.fromLTRB(0, 34, 0, bottom + 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(36),
                  ),
                  // Thin grey edge and a soft shadow so the sheet stands out
                  // on the white page.
                  border: Border.all(color: AppColors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.07),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: _Figure(
                              amount: left == null
                                  ? out
                                  : math.max(left, 0).toDouble(),
                              caption: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    left == null
                                        ? 'spent · '
                                        : (left < 0 ? 'over ' : 'until '),
                                    style: _captionStyle,
                                  ),
                                  GestureDetector(
                                    onTap: () => showBudgetForm(
                                      context,
                                      existing: overall,
                                      categoryId: Budget.overall,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          overall == null
                                              ? 'set a limit'
                                              : formatAmount(overall.limit),
                                          style: _captionStyle.copyWith(
                                            color: AppColors.blue,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                          color: AppColors.forest,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: AppColors.divider,
                          ),
                          Expanded(
                            child: _Figure(
                              amount: perDay,
                              caption: const Text(
                                'per day',
                                style: _captionStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (tip != null) ...[
                      const SizedBox(height: 28),
                      _TipCard(
                        text: tip,
                        onClose: () =>
                            setState(() => _dismissedTips.add(month)),
                      ),
                    ],
                    _SectionTitle(
                      'Recent Activity',
                      onTap: _openAllTransactions,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: RecentActivity(
                        items: items.take(6).toList(),
                        format: formatAmount,
                        onTap: (t) => _push(AddTransactionScreen(existing: t)),
                      ),
                    ),
                    _SectionTitle(
                      'Budgets',
                      onTap: () => _push(const _InsightsPage()),
                    ),
                    BudgetCategoryStrip(
                      budgets: [
                        if (overall != null) BudgetProgress(overall, out),
                        for (final b in family.categoryBudgets)
                          BudgetProgress(b, family.spentFor(b, items)),
                      ],
                      format: formatAmount,
                      onTap: (b) => showBudgetForm(context, existing: b),
                      onAdd: () => showBudgetForm(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A short nudge for the month, like the reference's mint card.
  String _tipFor({
    required bool hasLimit,
    required double left,
    required int count,
    required int dayOfMonth,
  }) {
    if (!hasLimit) {
      return 'Set a monthly limit to see what you can spend each day.';
    }
    if (left < 0) return 'Over the limit this month. Time to slow down?';
    if (dayOfMonth >= 14) {
      return 'Been ${dayOfMonth ~/ 7} weeks of budgeting. Keep it up!';
    }
    if (count == 0) return 'Nothing spent yet this month. Nice start!';
    return '$count ${count == 1 ? 'expense' : 'expenses'} logged so far. '
        'Nice tracking!';
  }
}

/// Deep green behind the breakdown, and slightly dimmed white text on it.
const _tealGreen = Color(0xFF008577);
const _darkBlue = Color(0xFF243B53);
const _softWhite = Color(0xD9FFFFFF);

const _captionStyle = TextStyle(fontSize: 13, color: AppColors.textSecondary);

/// "$1,274.87" with small cents over a caption, like the reference.
class _Figure extends StatelessWidget {
  const _Figure({required this.amount, required this.caption});

  /// Null shows a dash.
  final double? amount;
  final Widget caption;

  @override
  Widget build(BuildContext context) {
    final text = amount == null ? '—' : formatMoney(amount!);
    final dot = text.lastIndexOf('.');
    final whole = dot < 0 ? text : text.substring(0, dot);
    final cents = dot < 0 ? '' : text.substring(dot);
    const big = TextStyle(
      fontFamily: AppTheme.displayFont,
      fontFamilyFallback: AppTheme.displayFallback,
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
      height: 1.1,
    );
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: whole),
                TextSpan(text: cents, style: big.copyWith(fontSize: 15)),
              ],
            ),
            style: big,
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(fit: BoxFit.scaleDown, child: caption),
      ],
    );
  }
}

class _InOut extends StatelessWidget {
  const _InOut({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 14, color: _softWhite)),
      const SizedBox(height: 2),
      Text(
        formatAmount(amount.roundToDouble()),
        style: const TextStyle(
          fontFamily: AppTheme.displayFont,
          fontFamilyFallback: AppTheme.displayFallback,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    ],
  );
}

/// Half-circle buttons on the screen edges for the previous / next month.
class _SideArrow extends StatelessWidget {
  const _SideArrow({required this.left, required this.onTap});

  final bool left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(
        left: left ? Radius.zero : const Radius.circular(40),
        right: left ? const Radius.circular(40) : Radius.zero,
      ),
    ),
    child: InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 42,
        height: 80,
        child: Icon(
          left ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    ),
  );
}

class _TopIcon extends StatelessWidget {
  const _TopIcon({required this.icon, required this.onTap, this.dot = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool dot;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    icon: Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: Colors.white, size: 26),
        if (dot)
          Positioned(
            right: 1,
            top: 1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.lime,
                shape: BoxShape.circle,
                border: Border.all(color: _tealGreen, width: 1.5),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Mint card with an icon, a short message and a close button.
class _TipCard extends StatelessWidget {
  const _TipCard({required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 8, 16),
      decoration: BoxDecoration(
        color: AppColors.greenTint,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.blueTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_emotions_rounded,
              color: AppColors.blue,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.3,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: InkWell(
              onTap: onClose,
              customBorder: const CircleBorder(),
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// "BILLS DUE →" style heading: uppercase, condensed, arrow on the right.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontFamily: AppTheme.displayFont,
                fontFamilyFallback: AppTheme.displayFallback,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 24,
            color: AppColors.textPrimary,
          ),
        ],
      ),
    ),
  );
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
                      fontFamily: AppTheme.displayFont,
                      fontFamilyFallback: AppTheme.displayFallback,
                      fontSize: 20,
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
