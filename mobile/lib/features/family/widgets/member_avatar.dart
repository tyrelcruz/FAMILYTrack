import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:flutter/material.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar(
    this.member, {
    super.key,
    this.size = 50,
    this.ring = false,
  });

  final FamilyMember member;
  final double size;

  /// White border, for avatars overlapping a gradient or each other.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.alphaBlend(
          member.color.withValues(alpha: 0.15),
          AppColors.surface,
        ),
        border: ring ? Border.all(color: AppColors.surface, width: 2) : null,
      ),
      child: Text(
        member.initial,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: member.color,
        ),
      ),
    );
  }
}
