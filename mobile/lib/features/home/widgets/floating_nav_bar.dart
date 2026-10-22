import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Plain white tab bar with outline icons and labels: two tabs, "Add",
/// two tabs. The selected tab is dark; the rest are light grey.
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

  static const _idle = Color(0xFFB3B3C4);

  @override
  Widget build(BuildContext context) {
    Widget tab(int i) => Expanded(
      child: _Tab(
        label: items[i].label,
        icon: i == currentIndex ? items[i].selectedIcon : items[i].icon,
        selected: i == currentIndex,
        onTap: () => onTap(i),
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              tab(0),
              tab(1),
              Expanded(
                child: _Tab(
                  label: 'Add',
                  icon: Icons.add_box_outlined,
                  selected: false,
                  accent: true,
                  onTap: onAdd,
                ),
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
  const _Tab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  /// The Add button: indigo so it stands out without breaking the row.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent
        ? AppColors.forest
        : (selected ? AppColors.textPrimary : FloatingNavBar._idle);
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 29),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected || accent
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
