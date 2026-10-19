import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Top of the home screen on the sky-blue gradient: wordmark, header
/// actions and the "Safe to spend" amount.
class HomeHero extends StatelessWidget {
  const HomeHero({
    super.key,
    required this.userInitial,
    required this.amount,
    required this.caption,
    required this.hidden,
    required this.onToggleHidden,
    required this.onAmountTap,
    required this.onNotificationsTap,
    required this.onInfoTap,
    this.unread = 0,
    required this.onProfileTap,
  });

  final String userInitial;
  final String amount;
  final String caption;
  final bool hidden;
  final VoidCallback onToggleHidden;
  final VoidCallback onAmountTap;
  final VoidCallback onNotificationsTap;

  /// New family activity; shows a red dot on the bell.
  final int unread;
  final VoidCallback onInfoTap;
  final VoidCallback onProfileTap;

  static const _white80 = Color(0xE6FFFFFF);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'familytrack',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
              ),
            ),
            const Spacer(),
            _HeaderIcon(
              icon: Icons.notifications_none_rounded,
              onTap: onNotificationsTap,
              dot: unread > 0,
            ),
            const SizedBox(width: 8),
            _HeaderIcon(icon: Icons.info_outline_rounded, onTap: onInfoTap),
            const SizedBox(width: 12),
            _Avatar(initial: userInitial, onTap: onProfileTap),
          ],
        ),
        const SizedBox(height: 40),
        GestureDetector(
          onTap: onToggleHidden,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Safe to spend',
                style: TextStyle(
                  color: _white80,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _white80,
                size: 21,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onAmountTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 50,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.5,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                caption,
                style: const TextStyle(
                  color: _white80,
                  fontSize: 14.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.onTap,
    this.dot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool dot;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    icon: Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: Colors.white, size: 26),
        if (dot)
          Positioned(
            right: 1,
            top: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFEF2B2B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    ),
    visualDensity: VisualDensity.compact,
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.onTap});

  final String initial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white, width: 2.5),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3E6DA), Color(0xFFD9C3B0)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B4E3A),
          ),
        ),
      ),
    );
  }
}
