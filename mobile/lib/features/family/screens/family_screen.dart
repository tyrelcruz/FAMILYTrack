import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/core/widgets/breakdown_layout.dart';
import 'package:finance_tracker/core/widgets/form_sheet.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/family/models/budget.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/family/screens/budget_form.dart';
import 'package:finance_tracker/features/family/screens/member_detail_screen.dart';
import 'package:finance_tracker/features/family/screens/member_form.dart';
import 'package:finance_tracker/features/family/widgets/add_people_card.dart';
import 'package:finance_tracker/features/family/widgets/avatar_stack.dart';
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

    final spent = finance.monthExpense;
    final limit = overall?.limit;
    final over = limit != null && spent > limit;

    return ColoredBox(
      color: Colors.white,
      child: RefreshIndicator(
        onRefresh: session.sync,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            PageHero(
              patches: PatchBackdrop.family,
              children: [
                PageTitle(
                  'Family',
                  subtitle: Center(child: _StatusLine(session: session)),
                ),
                const SizedBox(height: 20),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      children: [
                        Text(
                          DateFormat('MMMM y').format(finance.month),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        HeroAmount(
                          formatAmount(spent),
                          color: over
                              ? AppColors.expenseRed
                              : AppColors.textPrimary,
                        ),
                        const SizedBox(height: 4),
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
                                limit == null
                                    ? 'spent · '
                                    : over
                                    ? '${formatAmount(spent - limit)} over '
                                    : 'spent of ',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                limit == null
                                    ? 'set a limit'
                                    : formatAmount(limit),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.blue,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.edit_outlined,
                                size: 14.5,
                                color: AppColors.forest,
                              ),
                            ],
                          ),
                        ),
                        if (limit != null) ...[
                          const SizedBox(height: 12),
                          TealBar(
                            value: limit == 0 ? 1 : spent / limit,
                            width: 170,
                            over: over,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AvatarStack(members: family.members, size: 26),
                            const SizedBox(width: 10),
                            Text(
                              '${family.members.length} '
                              '${family.members.length == 1 ? 'member' : 'members'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      left: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: MintSideArrow(
                          left: true,
                          onTap: () => finance.changeMonth(-1),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: MintSideArrow(
                          left: false,
                          onTap: () => finance.changeMonth(1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                MintPill(
                  label: 'Add someone',
                  icon: Icons.person_add_alt_rounded,
                  onTap: () => showFormSheet(
                    context,
                    title: 'Add someone',
                    subtitle: 'Choose how they’ll be part of the family.',
                    child: addPeople(),
                  ),
                ),
              ],
            ),
            FloatingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CardHeading(
                    'Who’s spending',
                    trailing:
                        '${spenders.length} '
                        '${spenders.length == 1 ? 'person' : 'people'}',
                  ),
                  SpendersCard(
                    spenders: spenders,
                    total: spent,
                    onTap: (m) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MemberDetailScreen(memberId: m.id!),
                      ),
                    ),
                  ),
                  const CardHeading('Add someone'),
                  addPeople(),
                ],
              ),
            ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.5, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
