import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/widgets/member_avatar.dart';
import 'package:flutter/material.dart';

/// Selectable pill with the member's avatar and name.
class MemberChip extends StatelessWidget {
  const MemberChip({
    super.key,
    required this.member,
    required this.selected,
    required this.onTap,
  });

  final FamilyMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
        decoration: BoxDecoration(
          color: selected
              ? member.color.withValues(alpha: 0.12)
              : AppColors.background,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? member.color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemberAvatar(member, size: 26),
            const SizedBox(width: 8),
            Text(
              member.name,
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
