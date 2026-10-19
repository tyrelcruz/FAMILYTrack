import 'package:finance_tracker/core/constants/user_profile.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.onMenuTap,
    required this.onNotificationsTap,
    required this.onProfileTap,
  });

  final VoidCallback onMenuTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _CircleButton(onTap: onMenuTap, child: const _MenuGlyph()),
            const Spacer(),
            _CircleButton(
              onTap: onNotificationsTap,
              child: const _BellWithDot(),
            ),
            const SizedBox(width: 16),
            _Avatar(onTap: onProfileTap),
          ],
        ),
        const SizedBox(height: 22),
        const Row(
          children: [
            Flexible(
              child: Text(
                'Hello ${UserProfile.firstName}!',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(width: 8),
            Text('👋', style: TextStyle(fontSize: 30)),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Let’s make your money work harder\ntomorrow.',
          style: TextStyle(
            fontSize: 17,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _MenuGlyph extends StatelessWidget {
  const _MenuGlyph();

  @override
  Widget build(BuildContext context) {
    Widget bar() => Container(
      width: 20,
      height: 2,
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bar(),
        const SizedBox(height: 5),
        bar(),
        const SizedBox(height: 5),
        bar(),
      ],
    );
  }
}

class _BellWithDot extends StatelessWidget {
  const _BellWithDot();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(
          Icons.notifications_none_rounded,
          size: 27,
          color: AppColors.textPrimary,
        ),
        Positioned(
          top: -1,
          right: 0,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFFEF2B2B),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 3),
          boxShadow: AppColors.softShadow,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDCE6F5), Color(0xFFB9C9E4)],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          UserProfile.firstName[0],
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF34466B),
          ),
        ),
      ),
    );
  }
}
