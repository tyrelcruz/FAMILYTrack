import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/widgets/member_avatar.dart';
import 'package:flutter/material.dart';

/// Overlapping member avatars, at most four.
class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.members, this.size = 30});

  final List<FamilyMember> members;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(4).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final step = size * 0.68;
    return SizedBox(
      width: size + step * (shown.length - 1),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: step * i,
              child: MemberAvatar(shown[i], size: size, ring: true),
            ),
        ],
      ),
    );
  }
}
