import 'dart:math' as math;

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Floating white pill like the page's cards: two tabs, the "Add" patch,
/// two tabs. Each tab is an icon over its label; the selected one turns
/// green, the rest stay grey.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
  }) : assert(items.length == 4);

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  static const _idle = Color(0xFFA9B5B1);

  @override
  Widget build(BuildContext context) {
    Widget tab(int i) => _Tab(
      item: items[i],
      selected: i == currentIndex,
      onTap: () => onTap(i),
    );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              tab(0),
              tab(1),
              Expanded(
                child: Center(child: _AddPatch(onTap: onAdd)),
              ),
              tab(2),
              tab(3),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.forest : FloatingNavBar._idle;
    return Expanded(
      child: Semantics(
        label: item.label,
        selected: selected,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 22,
                color: color,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Add" as a tilted teal sticker with a stitched edge, like the travel
/// patches behind the pages. It straightens and dips when pressed.
class _AddPatch extends StatefulWidget {
  const _AddPatch({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AddPatch> createState() => _AddPatchState();
}

class _AddPatchState extends State<_AddPatch> {
  bool _down = false;

  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Add',
      button: true,
      child: GestureDetector(
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.9 : 1,
          duration: const Duration(milliseconds: 140),
          child: AnimatedRotation(
            turns: _down ? 0 : -0.025,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
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
    );
  }
}

/// Dashed inner border, the embroidered edge of a patch.
class StitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(5),
      const Radius.circular(13),
    );
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      const dash = 3.5, gap = 3.0;
      final n = (metric.length / (dash + gap)).floor();
      final step = metric.length / math.max(n, 1);
      for (var d = 0.0; d < metric.length; d += step) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(StitchPainter oldDelegate) => false;
}
