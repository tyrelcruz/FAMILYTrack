import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Where money is kept or paid from. Names match the sync API.
enum PaymentMethod {
  cash('Cash', Icons.payments_outlined, AppColors.green, AppColors.greenTint),
  ewallet(
    'E-wallet',
    Icons.account_balance_wallet_outlined,
    AppColors.blue,
    AppColors.blueTint,
  ),
  card(
    'Card',
    Icons.credit_card_rounded,
    AppColors.purple,
    AppColors.purpleTint,
  ),
  bank(
    'Bank',
    Icons.account_balance_outlined,
    AppColors.orange,
    AppColors.orangeTint,
  );

  const PaymentMethod(this.label, this.icon, this.color, this.tint);

  final String label;
  final IconData icon;
  final Color color;
  final Color tint;

  static PaymentMethod? tryParse(Object? name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return null;
  }
}
