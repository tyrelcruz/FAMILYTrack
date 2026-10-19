import 'dart:math' as math;

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// White "Current Balance" card with a dark bank card and gold coins drawn
/// on the right.
class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.amount, required this.onTap});

  final String amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 124,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppColors.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                const Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: 196,
                  child: _CardsAndCoins(),
                ),
                Positioned(
                  left: 30,
                  top: 0,
                  bottom: 0,
                  right: 176,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Balance',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 17,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          amount,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardsAndCoins extends StatelessWidget {
  const _CardsAndCoins();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Back card, peeking out below the front one.
        const Positioned(
          left: 52,
          top: 34,
          child: _BankCard(
            colors: [Color(0xFF3B3C40), Color(0xFF1B1C1F)],
            showDetails: false,
          ),
        ),
        const Positioned(
          left: 44,
          top: 18,
          child: _BankCard(
            colors: [Color(0xFF66686E), Color(0xFF2A2B2F)],
            showDetails: true,
          ),
        ),
        const Positioned(left: 8, top: -26, child: _Coin(angle: -0.5)),
        const Positioned(left: 16, top: 12, child: _Coin(angle: 0.2)),
        const Positioned(left: 6, top: 50, child: _Coin(angle: -0.2)),
        Positioned(
          right: 26,
          top: 38,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.accentBlue,
              size: 26,
            ),
          ),
        ),
      ],
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({required this.colors, required this.showDetails});

  final List<Color> colors;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    return Transform(
      // Tilted back, as if lying on a table.
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0015)
        ..rotateX(0.45)
        ..rotateZ(-0.22),
      child: Container(
        width: 200,
        height: 128,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: showDetails
            ? Stack(
                children: [
                  Positioned(
                    left: 34,
                    top: 42,
                    child: Container(
                      width: 30,
                      height: 22,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD9D9D9), Color(0xFF8F9094)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: Text(
                      'VISA',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _Coin extends StatelessWidget {
  const _Coin({required this.angle});

  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateY(math.pi / 7),
        child: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.3, -0.4),
              colors: [Color(0xFFFFEB9C), Color(0xFFF2C14E), Color(0xFFD8962A)],
              stops: [0, 0.55, 1],
            ),
            border: Border.all(color: const Color(0xFFE0A63A), width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB7791F).withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: const Text(
            '₱',
            style: TextStyle(
              color: Color(0xFFB8761C),
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
