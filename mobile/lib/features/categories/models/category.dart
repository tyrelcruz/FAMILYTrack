import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:flutter/material.dart';

class Category {
  const Category(
    this.id,
    this.name,
    this.icon,
    this.color,
    this.type, {
    this.customTint,
    this.tripOnly = false,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final TransactionType type;
  final Color? customTint;

  /// Only offered for trip expenses, e.g. Accommodation.
  final bool tripOnly;

  /// Pastel background behind the category icon.
  Color get tint => customTint ?? color.withValues(alpha: 0.12);

  static const all = <Category>[
    Category(
      'food',
      'Food & Dining',
      Icons.restaurant,
      AppColors.purple,
      TransactionType.expense,
      customTint: AppColors.purpleTint,
    ),
    Category(
      'groceries',
      'Groceries',
      Icons.shopping_cart_outlined,
      AppColors.orange,
      TransactionType.expense,
      customTint: AppColors.orangeTint,
    ),
    Category(
      'housing',
      'House Rent',
      Icons.home_outlined,
      AppColors.red,
      TransactionType.expense,
      customTint: AppColors.redTint,
    ),
    Category(
      'internet',
      'Internet & Phone',
      Icons.language,
      AppColors.green,
      TransactionType.expense,
      customTint: AppColors.greenTint,
    ),
    Category(
      'bills',
      'Bills & Utilities',
      Icons.receipt_long_outlined,
      Color(0xFFE53935),
      TransactionType.expense,
    ),
    Category(
      'transport',
      'Transport',
      Icons.directions_bus_outlined,
      Color(0xFF1E88E5),
      TransactionType.expense,
    ),
    Category(
      'shopping',
      'Shopping',
      Icons.shopping_bag_outlined,
      Color(0xFF8E24AA),
      TransactionType.expense,
    ),
    Category(
      'health',
      'Health',
      Icons.favorite_border,
      Color(0xFFD81B60),
      TransactionType.expense,
    ),
    Category(
      'entertainment',
      'Entertainment',
      Icons.movie_outlined,
      Color(0xFF3949AB),
      TransactionType.expense,
    ),
    Category(
      'education',
      'Education',
      Icons.school_outlined,
      Color(0xFF00897B),
      TransactionType.expense,
    ),
    Category(
      'lodging',
      'Accommodation',
      Icons.hotel_outlined,
      Color(0xFF0D9488),
      TransactionType.expense,
      tripOnly: true,
    ),
    Category(
      'activities',
      'Tours & Activities',
      Icons.hiking_rounded,
      Color(0xFFEA580C),
      TransactionType.expense,
      tripOnly: true,
    ),
    Category(
      'fuel',
      'Gas & Tolls',
      Icons.local_gas_station_outlined,
      Color(0xFF475569),
      TransactionType.expense,
      tripOnly: true,
    ),
    Category(
      'souvenirs',
      'Pasalubong',
      Icons.redeem_rounded,
      Color(0xFFDB2777),
      TransactionType.expense,
      tripOnly: true,
    ),
    Category(
      'other_expense',
      'Other',
      Icons.more_horiz,
      Color(0xFF757575),
      TransactionType.expense,
    ),
    Category(
      'salary',
      'Salary',
      Icons.payments_outlined,
      Color(0xFF2E7D32),
      TransactionType.income,
    ),
    Category(
      'business',
      'Business',
      Icons.storefront_outlined,
      Color(0xFF00ACC1),
      TransactionType.income,
    ),
    Category(
      'gift',
      'Gift',
      Icons.card_giftcard,
      Color(0xFFF9A825),
      TransactionType.income,
    ),
    Category(
      'investment',
      'Investment',
      Icons.trending_up,
      Color(0xFF558B2F),
      TransactionType.income,
    ),
    Category(
      'other_income',
      'Other',
      Icons.more_horiz,
      Color(0xFF757575),
      TransactionType.income,
    ),
  ];

  /// Everyday categories; trip-only ones are left out.
  static List<Category> forType(TransactionType type) =>
      all.where((c) => c.type == type && !c.tripOnly).toList();

  /// Expense categories for a trip, most common first.
  static List<Category> forTrip() => [
    for (final id in const [
      'transport',
      'lodging',
      'food',
      'activities',
      'fuel',
      'souvenirs',
      'groceries',
      'shopping',
      'health',
      'other_expense',
    ])
      byId(id),
  ];

  static Category byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => all.last);
}
