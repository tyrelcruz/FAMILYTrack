import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/features/family/screens/budget_form.dart';
import 'package:finance_tracker/features/home/widgets/floating_nav_bar.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:finance_tracker/features/transactions/screens/add_activity_sheet.dart';
import 'package:finance_tracker/features/transfers/screens/transfer_sheet.dart';

/// Frosted full-screen menu that opens from the center "+" button: the
/// button turns into an X and the choices fan out above it.
Future<void> showQuickAddMenu(BuildContext context) {
  // The page underneath, so the chosen action opens over it once we close.
  final host = context;
  HapticFeedback.selectionClick();
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: 'Close menu',
      barrierColor: Colors.transparent,
      // Opens unhurried, closes quickly.
      transitionDuration: const Duration(milliseconds: 480),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, _) => _QuickAddMenu(
        animation: animation,
        onPick: (action) {
          HapticFeedback.lightImpact();
          Navigator.of(context).pop();
          action(host);
        },
      ),
    ),
  );
}

typedef _Action = void Function(BuildContext host);

class _Choice {
  const _Choice(this.label, this.icon, this.action);

  final String label;
  final IconData icon;
  final _Action action;
}

class _QuickAddMenu extends StatelessWidget {
  const _QuickAddMenu({required this.animation, required this.onPick});

  final Animation<double> animation;
  final ValueChanged<_Action> onPick;

  // Rows from top to bottom, like the reference's stepped layout.
  static final _rows = <List<_Choice>>[
    [
      _Choice(
        'Add New Category',
        Icons.create_new_folder_outlined,
        (c) => showBudgetForm(c),
      ),
    ],
    [
      _Choice(
        'Add Subscription',
        Icons.workspace_premium_outlined,
        (c) => showAddActivitySheet(
          c,
          initialCategoryId: 'bills',
          noteHint: 'This subscription for…',
        ),
      ),
      _Choice(
        'Add Transfer',
        Icons.swap_horiz_rounded,
        (c) => showTransferSheet(c),
      ),
    ],
    [
      _Choice(
        'Add Income',
        Icons.south_east_rounded,
        (c) => showAddActivitySheet(c, initialType: TransactionType.income),
      ),
      _Choice(
        'Add Expense',
        Icons.north_east_rounded,
        (c) => showAddActivitySheet(c),
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final backdrop = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    final button = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.7, curve: Curves.easeOutBack),
      reverseCurve: Curves.easeInCubic,
    );
    // Pills appear bottom row first, left to right, one after another.
    var order = 0;
    final delays = <List<int>>[
      for (var r = _rows.length - 1; r >= 0; r--)
        [for (final _ in _rows[r]) 60 + 70 * order++],
    ].reversed.toList();
    // Closing just fades the whole stack out together.
    final content = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.5, curve: Curves.easeOut),
      reverseCurve: const Interval(0.4, 1, curve: Curves.easeIn),
    );
    // Same spot as the nav bar's "+" so the X appears to replace it.
    final buttonBottom =
        math.max(MediaQuery.paddingOf(context).bottom, 12.0) + 8;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: AnimatedBuilder(
              animation: backdrop,
              builder: (context, _) => BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 20 * backdrop.value,
                  sigmaY: 20 * backdrop.value,
                ),
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.74 * backdrop.value),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: buttonBottom + 56 + 26,
          child: FadeTransition(
            opacity: content,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < _rows.length; r++) ...[
                  if (r > 0) const SizedBox(height: 18),
                  // Shrinks a row slightly on narrow phones instead of overflowing.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < _rows[r].length; i++) ...[
                            if (i > 0) const SizedBox(width: 16),
                            _Pill(
                              choice: _rows[r][i],
                              delay: delays[r][i],
                              onTap: () => onPick(_rows[r][i].action),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          bottom: buttonBottom,
          left: 0,
          right: 0,
          child: Center(
            child: RotationTransition(
              // Starts at the nav patch's tilt and straightens out.
              turns: Tween(begin: -0.025, end: 0.0).animate(button),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lime.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: StitchPainter(),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(18),
                      child: RotationTransition(
                        // The "+" turns a quarter-eighth into an "X".
                        turns: Tween(begin: 0.0, end: 0.125).animate(button),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.choice, required this.delay, required this.onTap});

  final _Choice choice;

  /// Milliseconds after the menu starts opening before this pill appears.
  final int delay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 13, 24, 13),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(choice.icon, size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 16),
                    Text(
                      choice.label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate(delay: delay.ms)
        .fadeIn(duration: 260.ms, curve: Curves.easeOut)
        .slideY(begin: 0.7, end: 0, duration: 420.ms, curve: Curves.easeOutBack)
        .scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          alignment: Alignment.bottomCenter,
          duration: 420.ms,
          curve: Curves.easeOutBack,
        );
  }
}
