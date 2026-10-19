import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:finance_tracker/core/widgets/circle_button.dart';
import 'package:finance_tracker/core/widgets/empty_state.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/family/screens/member_form.dart';
import 'package:finance_tracker/features/family/widgets/member_avatar.dart';
import 'package:finance_tracker/features/family/widgets/section_card.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';
import 'package:finance_tracker/features/transactions/screens/add_activity_sheet.dart';
import 'package:finance_tracker/features/transactions/screens/add_transaction_screen.dart';
import 'package:finance_tracker/features/transactions/widgets/month_selector.dart';
import 'package:finance_tracker/features/transactions/widgets/transaction_row.dart';

/// One member's spending for the selected month.
class MemberDetailScreen extends StatelessWidget {
  const MemberDetailScreen({super.key, required this.memberId});

  final String memberId;

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> _confirmDelete(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: Text(
          'Remove $name?',
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Their transactions stay and move to the group owner.',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final family = context.read<FamilyProvider>();
    final finance = context.read<FinanceProvider>();
    Navigator.of(context).pop();
    await family.removeMember(memberId);
    await finance.load();
  }

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilyProvider>();
    final finance = context.watch<FinanceProvider>();
    final member = family.memberFor(memberId);
    // In a synced family the server only lets the owner manage others.
    final session = context.watch<SessionProvider>();
    final group = session.group;
    final canEdit =
        group == null ||
        group.isOwner ||
        member.userId == session.session?.userId;
    final canDelete = !member.isOwner && (group == null || group.isOwner);
    final items = finance.monthItems
        .where((t) => family.memberFor(t.memberId).id == member.id)
        .toList();
    double sum(bool expense) => items
        .where((t) => t.isExpense == expense)
        .fold(0.0, (s, t) => s + t.amount);
    final spent = sum(true);
    final familySpent = finance.monthExpense;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showAddActivitySheet(context, memberId: member.id),
          backgroundColor: AppColors.textPrimary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: const StadiumBorder(),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Add Expense',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              MediaQuery.paddingOf(context).bottom + 110,
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
                  const Spacer(),
                  if (canEdit)
                    CircleButton(
                      onTap: () => showMemberForm(context, existing: member),
                      child: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  if (canDelete) ...[
                    const SizedBox(width: 12),
                    CircleButton(
                      onTap: () => _confirmDelete(context, member.name),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.red,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              _MemberSummaryCard(
                member: member,
                month: finance.month,
                spent: spent,
                income: sum(false),
                count: items.length,
                share: familySpent == 0 ? 0 : spent / familySpent * 100,
              ),
              const SizedBox(height: 12),
              const MonthSelector(),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Transactions',
                onAdd: () => showAddActivitySheet(context, memberId: member.id),
                children: [
                  if (items.isEmpty)
                    const EmptyState('No transactions this month'),
                  for (final t in items)
                    TransactionRow(
                      item: t,
                      onTap: () =>
                          _push(context, AddTransactionScreen(existing: t)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient card, matching the home balance card, with the member's totals.
class _MemberSummaryCard extends StatelessWidget {
  const _MemberSummaryCard({
    required this.member,
    required this.month,
    required this.spent,
    required this.income,
    required this.count,
    required this.share,
  });

  final FamilyMember member;
  final DateTime month;
  final double spent;
  final double income;
  final int count;
  final double share;

  static const _white70 = Color(0xD9FFFFFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: AppColors.cardGradient,
          stops: [0, 0.45, 0.78, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardGradient[1].withValues(alpha: 0.30),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberAvatar(member, size: 56, ring: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.isOwner ? 'Group owner' : 'Family member',
                      style: const TextStyle(color: _white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Spent in ${formatMonth(month)}',
            style: const TextStyle(
              color: _white70,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(spent),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                _Stat('Income', formatMoney(income)),
                _divider(),
                _Stat('Transactions', '$count'),
                _divider(),
                _Stat('Family share', '${share.round()}%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 32,
    color: Colors.white.withValues(alpha: 0.25),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _MemberSummaryCard._white70,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
