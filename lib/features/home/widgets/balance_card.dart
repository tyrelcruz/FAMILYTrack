import 'package:finance_tracker/core/constants/user_profile.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/utils/formatters.dart';
import 'package:flutter/material.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    required this.changePercent,
    required this.onAddCard,
  });

  final double balance;
  final double? changePercent;
  final VoidCallback onAddCard;

  static const _white70 = Color(0xD9FFFFFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: AppColors.cardGradient,
          stops: [0, 0.45, 0.78, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardGradient[1].withValues(alpha: 0.30),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _WavePainter())),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.apple, color: Colors.white, size: 38),
                      Spacer(),
                      Text(
                        '••••  ••••  ••••  ${UserProfile.cardLast4}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _balanceBlock()),
                      const Padding(
                        padding: EdgeInsets.only(top: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Exp. Date',
                              style: TextStyle(color: _white70, fontSize: 13),
                            ),
                            SizedBox(height: 4),
                            Text(
                              UserProfile.cardExpiry,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account',
                              style: TextStyle(color: _white70, fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              UserProfile.fullName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _AddCardButton(onTap: onAddCard),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceBlock() {
    final change = changePercent;
    final up = (change ?? 0) >= 0;
    final trendColor = up ? AppColors.trendUp : AppColors.trendDown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Total Balance',
          style: TextStyle(
            color: _white70,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatMoney(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              height: 1.15,
            ),
          ),
        ),
        if (change != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                up ? Icons.north_east_rounded : Icons.south_east_rounded,
                color: trendColor,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                '${up ? '+' : ''}${change.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: trendColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'vs. last month',
                style: TextStyle(color: _white70, fontSize: 15),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AddCardButton extends StatelessWidget {
  const _AddCardButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 9, 20, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.textPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Add Card',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two soft translucent waves layered across the lower half of the card.
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.09);

    final hill = Path()
      ..moveTo(w * 0.30, h)
      ..quadraticBezierTo(w * 0.62, h * 0.28, w, h * 0.78)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hill, paint);

    final sweep = Path()
      ..moveTo(w * 0.58, h)
      ..cubicTo(w * 0.70, h * 0.55, w * 0.84, h * 0.22, w, h * 0.14)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(sweep, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
