import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/features/family/screens/budget_form.dart';
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
    // Pills appear bottom row first, left to right, one after another;
    // closing plays the same stagger backwards.
    var order = 0;
    final starts = <List<double>>[
      for (var r = _rows.length - 1; r >= 0; r--)
        [for (final _ in _rows[r]) 0.10 + 0.07 * order++],
    ].reversed.toList();
    // Same spot as the nav bar's "+" so the X appears to replace it.
    final buttonBottom =
        math.max(MediaQuery.paddingOf(context).bottom, 8.0) + 3;

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
          bottom: buttonBottom + 60 + 30,
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
                            parent: animation,
                            start: starts[r][i],
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
        Positioned(
          bottom: buttonBottom,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 74,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7DB4F4), Color(0xFF9AD4F6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentBlue.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(18),
                  child: RotationTransition(
                    // The "+" spins into an "X" as the menu opens.
                    turns: Tween(begin: -0.125, end: 0.0).animate(button),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                      weight: 300,
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
  const _Pill({
    required this.choice,
    required this.parent,
    required this.start,
    required this.onTap,
  });

  final _Choice choice;
  final Animation<double> parent;

  /// Where in the menu's animation (0–1) this pill starts appearing.
  final double start;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: parent,
      curve: Interval(start, math.min(start + 0.25, 1), curve: Curves.easeOut),
    );
    // A slight overshoot so each pill settles into place.
    final move = CurvedAnimation(
      parent: parent,
      curve: Interval(
        start,
        math.min(start + 0.5, 1),
        curve: Curves.easeOutBack,
      ),
    );
    return AnimatedBuilder(
      animation: parent,
      builder: (context, child) => Opacity(
        opacity: fade.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 40 * (1 - move.value)),
          child: Transform.scale(
            scale: 0.82 + 0.18 * move.value,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        ),
      ),
      child: Container(
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
                  Icon(choice.icon, size: 23, color: AppColors.textSecondary),
                  const SizedBox(width: 16),
                  Text(
                    choice.label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
