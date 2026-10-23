import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/widgets/breakdown_layout.dart';
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

/// Plans tab: the plan happening now up top, the rest and templates in the
/// card below.
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
    // On or coming up: a sideways strip up top. Everything else: slim rows.
    final strip = shown.where((p) => rank(p) < 2).take(6).toList();
    final rest = shown.where((p) => !strip.contains(p)).toList();
    double spent(Plan p) => PlanStats.of(p, finance.all, family).spent;

    final activeCount = shown.where((p) => p.isActive(now)).length;
    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          PageHero(
            patches: PatchBackdrop.plans,
            children: [
              PageTitle(
                'Plans',
                subtitle: Text(
                  shown.isEmpty
                      ? 'Trips, events and monthly budgets'
                      : '${shown.length} '
                            '${shown.length == 1 ? 'plan' : 'plans'}'
                            '${activeCount > 0 ? ' · $activeCount happening now' : ''}',
                ),
              ),
              const SizedBox(height: 14),
              MintPill(
                label: 'New plan',
                icon: Icons.add_rounded,
                onTap: () => _push(const PlanFormScreen()),
              ),
              const SizedBox(height: 18),
              MintToggle(
                labels: const ['My Plans', 'Shared With Me'],
                index: _shared ? 1 : 0,
                onChanged: (i) => setState(() => _shared = i == 1),
              ),
              const SizedBox(height: 18),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _EmptyTab(
                    shared: _shared,
                    onCreate: () => _push(const PlanFormScreen()),
                  ),
                )
              else if (strip.isNotEmpty)
                _PlanStrip(
                  // Fresh position when switching tabs.
                  key: ValueKey(_shared),
                  plans: strip,
                  spent: spent,
                  memberCount: (p) => p.shares.length,
                  onOpen: (p) => _push(PlanDetailScreen(planId: p.id!)),
                ),
            ],
          ),
          FloatingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (rest.isNotEmpty) ...[
                  CardHeading(
                    strip.isEmpty
                        ? (_shared ? 'Shared With Me' : 'Your Plans')
                        : 'Earlier & More',
                    trailing: '${rest.length}',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < rest.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                indent: 70,
                                color: AppColors.divider,
                              ),
                            PlanRow(
                              plan: rest[i],
                              spent: spent(rest[i]),
                              onTap: () =>
                                  _push(PlanDetailScreen(planId: rest[i].id!)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                CardHeading(
                  'Plan Templates',
                  action: 'View all',
                  onTap: _showAllTemplates,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _TemplateGrid(
                    templates: PlanTemplate.all.take(4).toList(),
                    onPick: (t) => _push(PlanFormScreen(template: t)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sideways strip of plan cards that snap one at a time, the next one
/// peeking in; dots show where you are once there's more than one.
class _PlanStrip extends StatefulWidget {
  const _PlanStrip({
    super.key,
    required this.plans,
    required this.spent,
    required this.memberCount,
    required this.onOpen,
  });

  final List<Plan> plans;
  final double Function(Plan) spent;
  final int Function(Plan) memberCount;
  final ValueChanged<Plan> onOpen;

  @override
  State<_PlanStrip> createState() => _PlanStripState();
}

class _PlanStripState extends State<_PlanStrip> {
  late final _controller = PageController(viewportFraction: 0.88);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plans = widget.plans;
    return Column(
      children: [
        SizedBox(
          height: PlanStripCard.height,
          child: PageView.builder(
            controller: _controller,
            padEnds: plans.length == 1,
            itemCount: plans.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.fromLTRB(
                plans.length == 1 ? 20 : (i == 0 ? 20 : 5),
                0,
                plans.length == 1 ? 20 : 5,
                0,
              ),
              child: PlanStripCard(
                plan: plans[i],
                spent: widget.spent(plans[i]),
                memberCount: widget.memberCount(plans[i]),
                onTap: () => widget.onOpen(plans[i]),
              ),
            ),
          ),
        ),
        if (plans.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < plans.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: i == _page ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.teal : AppColors.mintTrack,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
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
      border: Border.all(color: AppColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
          child: Icon(
            shared ? Icons.group_outlined : Icons.luggage_outlined,
            color: AppColors.tealDark,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          shared ? 'Nothing shared yet' : 'No plans yet',
          style: const TextStyle(
            fontSize: 16.5,
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
            fontSize: 12,
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
