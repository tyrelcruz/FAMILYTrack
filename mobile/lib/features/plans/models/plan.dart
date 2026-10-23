import 'dart:convert';

import 'package:finance_tracker/features/transactions/models/payment_method.dart';

/// Trip and event have a place; monthly covers one calendar month; custom
/// is any other dates.
enum PlanKind { trip, event, monthly, custom }

enum SplitMode { equal, custom }

/// A shared budget for a trip or a month: how much there is, where it's
/// kept and how it's divided between family members.
class Plan {
  const Plan({
    this.id,
    required this.name,
    required this.kind,
    required this.start,
    required this.end,
    required this.funds,
    required this.shares,
    required this.split,
    this.createdBy,
    this.destination = '',
    this.description = '',
    this.coverPath,
    this.hasCover = false,
  });

  /// UUID; null until saved.
  final String? id;
  final String name;
  final PlanKind kind;

  /// First and last day, both included.
  final DateTime start;
  final DateTime end;

  /// Money kept in each place, e.g. ₱6,000 cash and ₱4,000 e-wallet.
  final Map<PaymentMethod, double> funds;

  /// Each member's share of the budget, by member id.
  final Map<String, double> shares;
  final SplitMode split;

  /// User id of whoever made it; null for plans made before signing in.
  final String? createdBy;

  /// Where it is, e.g. "Tokyo, Japan"; empty when it isn't somewhere.
  final String destination;
  final String description;

  /// Cover photo on this phone, and whether the server has one. Kept out of
  /// [toMap] so editing a plan never touches them.
  final String? coverPath;
  final bool hasCover;

  double get total => funds.values.fold(0.0, (s, v) => s + v);

  DateTime get _endOfLastDay => DateTime(end.year, end.month, end.day + 1);

  bool isPast(DateTime now) => !now.isBefore(_endOfLastDay);
  bool isUpcoming(DateTime now) =>
      now.isBefore(DateTime(start.year, start.month, start.day));
  bool isActive(DateTime now) => !isPast(now) && !isUpcoming(now);

  /// Days left including today, or every day if it hasn't started.
  int daysLeft(DateTime now) {
    if (isPast(now)) return 0;
    final from = isUpcoming(now)
        ? start
        : DateTime(now.year, now.month, now.day);
    return _endOfLastDay.difference(from).inDays;
  }

  int get totalDays => _endOfLastDay
      .difference(DateTime(start.year, start.month, start.day))
      .inDays;

  /// Splits [total] equally between [memberIds], to the centavo.
  static Map<String, double> equalShares(double total, List<String> memberIds) {
    if (memberIds.isEmpty) return const {};
    final cents = (total * 100).round();
    final each = cents ~/ memberIds.length;
    var leftover = cents - each * memberIds.length;
    return {
      for (final id in memberIds) id: (each + (leftover-- > 0 ? 1 : 0)) / 100,
    };
  }

  Plan copyWith({Map<String, double>? shares}) => Plan(
    id: id,
    name: name,
    kind: kind,
    start: start,
    end: end,
    funds: funds,
    shares: shares ?? this.shares,
    split: split,
    createdBy: createdBy,
    destination: destination,
    description: description,
    coverPath: coverPath,
    hasCover: hasCover,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'start_date': start.millisecondsSinceEpoch,
    'end_date': end.millisecondsSinceEpoch,
    'funds': jsonEncode(_fundsJson),
    'shares': jsonEncode(shares),
    'split': split.name,
    'created_by': createdBy,
    'destination': destination,
    'description': description,
  };

  factory Plan.fromMap(Map<String, Object?> m) => Plan(
    id: m['id'] as String?,
    name: m['name'] as String,
    kind: PlanKind.values.byName(m['kind'] as String),
    start: DateTime.fromMillisecondsSinceEpoch(m['start_date'] as int),
    end: DateTime.fromMillisecondsSinceEpoch(m['end_date'] as int),
    funds: _parseFunds(jsonDecode(m['funds'] as String)),
    shares: _parseShares(jsonDecode(m['shares'] as String)),
    split: SplitMode.values.byName(m['split'] as String),
    createdBy: m['created_by'] as String?,
    destination: (m['destination'] as String?) ?? '',
    description: (m['description'] as String?) ?? '',
    coverPath: m['cover_path'] as String?,
    hasCover: (m['has_cover'] as int? ?? 0) == 1,
  );

  /// Shape the sync API sends and accepts.
  Map<String, Object?> toJson() => {
    'name': name,
    'kind': kind.name,
    'startDate': start.millisecondsSinceEpoch,
    'endDate': end.millisecondsSinceEpoch,
    'funds': _fundsJson,
    'shares': shares,
    'split': split.name,
    'destination': destination,
    'description': description,
  };

  Map<String, double> get _fundsJson => {
    for (final e in funds.entries)
      if (e.value > 0) e.key.name: e.value,
  };

  static Map<PaymentMethod, double> _parseFunds(Object? raw) => {
    for (final e in (raw as Map).entries)
      // Unknown methods from a newer app version are skipped.
      ?PaymentMethod.tryParse(e.key): (e.value as num).toDouble(),
  };

  static Map<String, double> _parseShares(Object? raw) => {
    for (final e in (raw as Map).entries)
      e.key as String: (e.value as num).toDouble(),
  };
}
