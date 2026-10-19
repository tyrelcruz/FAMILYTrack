/// A monthly spending limit, either for one expense category or for the
/// whole family ([overall]). Applies to every month.
class Budget {
  const Budget({required this.categoryId, required this.limit});

  static const overall = 'overall';

  final String categoryId;
  final double limit;

  bool get isOverall => categoryId == overall;

  Map<String, Object?> toMap() => {'category': categoryId, 'amount': limit};

  factory Budget.fromMap(Map<String, Object?> m) => Budget(
    categoryId: m['category'] as String,
    limit: (m['amount'] as num).toDouble(),
  );

  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
    categoryId: j['categoryId'] as String,
    limit: (j['limit'] as num).toDouble(),
  );
}
