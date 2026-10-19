import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/widgets/form_sheet.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/plans/models/plan.dart';
import 'package:finance_tracker/features/plans/models/plan_stats.dart';
import 'package:finance_tracker/features/plans/models/plan_template.dart';
import 'package:finance_tracker/features/plans/providers/plan_provider.dart';
import 'package:finance_tracker/features/plans/screens/plan_detail_screen.dart';
import 'package:finance_tracker/features/plans/screens/plan_form_screen.dart';
import 'package:finance_tracker/features/plans/widgets/plan_card.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';

/// Plans tab: the plans you made, the ones others shared, and templates to
/// start a new one.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  bool _shared = false;

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  void _showAllTemplates() => showFormSheet(
    context,
    title: 'Plan templates',
    subtitle: 'Pick one to start; you can change everything after.',
    child: Builder(
      builder: (sheet) => _TemplateGrid(
        templates: PlanTemplate.all,
        onPick: (t) {
          Navigator.of(sheet).pop();
          _push(PlanFormScreen(template: t));
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>();
    final finance = context.watch<FinanceProvider>();
    final family = context.watch<FamilyProvider>();
    final myUserId = context.watch<SessionProvider>().session?.userId;
    if (plans.loading || finance.loading || family.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final now = DateTime.now();

    // Plans made on this phone before signing in count as yours.
    bool mine(Plan p) => p.createdBy == null || p.createdBy == myUserId;
    int rank(Plan p) => p.isActive(now) ? 0 : (p.isUpcoming(now) ? 1 : 2);
    final shown = plans.plans.where((p) => mine(p) != _shared).toList()
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        // Active: ending soonest; upcoming: starting soonest; past: latest.
        return switch (rank(a)) {
          0 => a.end.compareTo(b.end),
          1 => a.start.compareTo(b.start),
          _ => b.end.compareTo(a.end),
        };
      });
    final featured = shown.isEmpty ? null : shown.first;
    final rest = shown.skip(1).toList();
    double spent(Plan p) => PlanStats.of(p, finance.all, family).spent;

    return Stack(
      children: [
        // Soft blue wash behind the header, like the home screen.
        Container(
          height: 300,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFD6E8FB), AppColors.background],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              MediaQuery.paddingOf(context).bottom + 24,
            ),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Plans',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Material(
                    color: AppColors.surface,
                    shape: const CircleBorder(),
                    elevation: 2,
                    shadowColor: AppColors.shadow.withValues(alpha: 0.3),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _push(const PlanFormScreen()),
                      child: const SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(
                          Icons.add_rounded,
                          color: AppColors.blue,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _PlanTabs(
                shared: _shared,
                onChanged: (v) => setState(() => _shared = v),
              ),
              const SizedBox(height: 18),
              if (featured == null)
                _EmptyTab(
                  shared: _shared,
                  onCreate: () => _push(const PlanFormScreen()),
                )
              else
                FeaturedPlanCard(
                  plan: featured,
                  spent: spent(featured),
                  members: [
                    for (final m in family.members)
                      if (featured.shares.containsKey(m.id)) m,
                  ],
                  onTap: () => _push(PlanDetailScreen(planId: featured.id!)),
                ),
              if (rest.isNotEmpty) ...[
                _SectionTitle(_shared ? 'Shared With Me' : 'My Plans'),
                for (final p in rest) ...[
                  PlanListCard(
                    plan: p,
                    spent: spent(p),
                    onTap: () => _push(PlanDetailScreen(planId: p.id!)),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
              _SectionTitle(
                'Plan Templates',
                action: 'View all',
                onAction: _showAllTemplates,
              ),
              _TemplateGrid(
                templates: PlanTemplate.all.take(4).toList(),
                onPick: (t) => _push(PlanFormScreen(template: t)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "My Plans" / "Shared With Me" switch with a blue selected pill.
class _PlanTabs extends StatelessWidget {
  const _PlanTabs({required this.shared, required this.onChanged});

  final bool shared;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value) {
      final selected = shared == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF2F7CF6), Color(0xFF4F98F8)],
                    )
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.blue.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [tab('My Plans', false), tab('Shared With Me', true)],
      ),
    );
  }
}

class _TemplateGrid extends StatelessWidget {
  const _TemplateGrid({required this.templates, required this.onPick});

  final List<PlanTemplate> templates;
  final ValueChanged<PlanTemplate> onPick;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final t in templates)
              SizedBox(
                width: w,
                child: PlanTemplateTile(template: t, onTap: () => onPick(t)),
              ),
          ],
        );
      },
    );
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.shared, required this.onCreate});

  final bool shared;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(26),
      boxShadow: AppColors.softShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: AppColors.blueTint,
            shape: BoxShape.circle,
          ),
          child: Icon(
            shared ? Icons.group_outlined : Icons.luggage_outlined,
            color: AppColors.blue,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          shared ? 'Nothing shared yet' : 'No plans yet',
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          shared
              ? 'Plans that others in your family make show up here.'
              : 'Plan a trip or a month: set the budget, where the money is, '
                    'and who’s in. Or start from a template below.',
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        if (!shared) ...[
          const SizedBox(height: 18),
          SheetPrimaryButton(label: 'Create a Plan', onPressed: onCreate),
        ],
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 26, 2, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (action != null)
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
    ),
  );
}
