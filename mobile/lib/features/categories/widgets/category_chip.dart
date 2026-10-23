import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/features/categories/models/category.dart';
import 'package:flutter/material.dart';

/// Selectable pill with a tinted icon circle, used to pick a category.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  CategoryChip.of(
    Category c, {
    Key? key,
    required bool selected,
    required VoidCallback onTap,
  }) : this(
         key: key,
         label: c.name,
         icon: c.icon,
         color: c.color,
         tint: c.tint,
         selected: selected,
         onTap: onTap,
       );

  final String label;
  final IconData icon;
  final Color color;
  final Color tint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        decoration: BoxDecoration(
          color: selected ? tint : AppColors.background,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppColors.surface : tint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 14.5),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
