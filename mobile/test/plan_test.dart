import 'package:flutter_test/flutter_test.dart';

import 'package:finance_tracker/features/plans/models/plan.dart';
import 'package:finance_tracker/features/transactions/models/payment_method.dart';

void main() {
  Plan trip(DateTime start, DateTime end) => Plan(
    name: 'Trip',
    kind: PlanKind.trip,
    start: start,
    end: end,
    funds: const {PaymentMethod.cash: 6000, PaymentMethod.ewallet: 4000},
    shares: const {},
    split: SplitMode.equal,
  );

  test('equal split adds up to the total, to the centavo', () {
    final shares = Plan.equalShares(1000, ['a', 'b', 'c']);
    expect(shares['a'], 333.34);
    expect(shares['b'], 333.33);
    expect(shares.values.fold(0.0, (s, v) => s + v), closeTo(1000, 0.001));
  });

  test('status and days left follow the dates, both days included', () {
    final p = trip(DateTime(2026, 10, 20), DateTime(2026, 10, 24));
    expect(p.total, 10000);
    expect(p.totalDays, 5);
    expect(p.isUpcoming(DateTime(2026, 10, 19, 23)), isTrue);
    expect(p.daysLeft(DateTime(2026, 10, 19)), 5);
    expect(p.isActive(DateTime(2026, 10, 24, 22)), isTrue);
    expect(p.daysLeft(DateTime(2026, 10, 24, 9)), 1);
    expect(p.isPast(DateTime(2026, 10, 25)), isTrue);
  });

  test('round-trips through the database and API shapes', () {
    final p = trip(
      DateTime(2026, 10, 20),
      DateTime(2026, 10, 24),
    ).copyWith(shares: {'m1': 5000, 'm2': 5000});
    final back = Plan.fromMap({...p.toMap(), 'id': 'x'});
    expect(back.funds[PaymentMethod.ewallet], 4000);
    expect(back.shares['m2'], 5000);
    expect(p.toJson()['funds'], {'cash': 6000.0, 'ewallet': 4000.0});
  });
}
