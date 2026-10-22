import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/widgets/circle_button.dart';
import 'package:finance_tracker/core/widgets/form_sheet.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/family/models/budget.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/family/screens/budget_form.dart';
import 'package:finance_tracker/features/family/screens/member_detail_screen.dart';
import 'package:finance_tracker/features/family/screens/member_form.dart';
import 'package:finance_tracker/features/family/widgets/add_people_card.dart';
import 'package:finance_tracker/features/family/widgets/family_hero_card.dart';
import 'package:finance_tracker/features/family/widgets/spenders_card.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';

/// Family tab: who's in the family and who spent what this month.
/// (Category budgets live on Home; trip and monthly budgets under Plans.)
class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key, required this.onConnect});

  /// Switches to the Profile tab to sign in or set up the family.
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final family = context.watch<FamilyProvider>();
    final session = context.watch<SessionProvider>();
    if (finance.loading || family.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Includes the floating nav bar height, since the shell uses extendBody.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final group = session.group;
    final myUserId = session.session?.userId;
    final overall = family.overallBudget;

    final expenses = finance.monthItems.where((t) => t.isExpense).toList();
    final spentBy = family.spendByMember(expenses);
    final countBy = <String, int>{};
    for (final t in expenses) {
      final id = family.memberFor(t.memberId).id!;
      countBy[id] = (countBy[id] ?? 0) + 1;
    }
    List<String> tagsFor(FamilyMember m) {
      // Before syncing, the owner is whoever holds this phone.
      final you = group == null ? m.isOwner : m.userId == myUserId;
      return [
        if (you) 'You',
        if (m.isOwner && !you) 'Owner',
        if (group != null && m.userId == null && !m.isOwner) 'No account',
      ];
    }

    final spenders = [
      for (final m in family.members)
        Spender(
          member: m,
          spent: spentBy[m.id] ?? 0,
          count: countBy[m.id] ?? 0,
          tags: tagsFor(m),
        ),
    ]..sort((a, b) => b.spent.compareTo(a.spent));

    Widget addPeople() => AddPeopleCard(
      inviteCode: group?.inviteCode,
      onSetUpSync: onConnect,
      onAddWithoutAccount: () => showMemberForm(context),
    );

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: session.sync,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FAMILY',
                        style: TextStyle(
                          fontFamily: AppTheme.displayFont,
                          fontFamilyFallback: AppTheme.displayFallback,
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _StatusLine(session: session),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CircleButton(
                  onTap: () => showFormSheet(
                    context,
                    title: 'Add someone',
                    subtitle: 'Choose how they’ll be part of the family.',
                    child: addPeople(),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_rounded,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            FamilyHeroCard(
              month: finance.month,
              spent: finance.monthExpense,
              budget: overall?.limit,
              members: family.members,
              onPrevMonth: () => finance.changeMonth(-1),
              onNextMonth: () => finance.changeMonth(1),
              onEditBudget: () => showBudgetForm(
                context,
                existing: overall,
                categoryId: Budget.overall,
              ),
            ),
            _SectionTitle(
              'Who’s spending',
              trailing:
                  '${spenders.length} '
                  '${spenders.length == 1 ? 'person' : 'people'}',
            ),
            SpendersCard(
              spenders: spenders,
              total: finance.monthExpense,
              onTap: (m) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MemberDetailScreen(memberId: m.id!),
                ),
              ),
            ),
            const _SectionTitle('Add someone'),
            addPeople(),
          ],
        ),
      ),
    );
  }
}

/// "Hoque Family · Synced just now", or that nothing is shared yet.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    final group = session.group;
    final offline = session.syncError != null;
    final (icon, color, text) = group == null
        ? (
            Icons.phone_iphone_rounded,
            AppColors.textMuted,
            'Only on this phone — not shared yet',
          )
        : (
            session.syncing
                ? Icons.sync_rounded
                : offline
                ? Icons.cloud_off_rounded
                : Icons.cloud_done_rounded,
            offline ? AppColors.orange : AppColors.blue,
            '${group.name} · ${session.syncStatus}',
          );
    return GestureDetector(
      onTap: group == null || session.syncing ? null : session.sync,
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final String? trailing;

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
      ],
    ),
  );
}
