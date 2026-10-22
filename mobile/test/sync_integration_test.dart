// Runs the app's data and sync code against a real backend, as one phone
// plus a second family member on "another phone" (plain API calls).
//
//   cd backend && PORT=3100 npm run dev
//   cd mobile && API_URL=http://localhost:3100/api flutter test test/sync_integration_test.dart
//
// Skipped when API_URL isn't set.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finance_tracker/core/api/api_client.dart';
import 'package:finance_tracker/core/data/app_database.dart';
import 'package:finance_tracker/core/data/photo_store.dart';
import 'package:finance_tracker/features/account/data/session_store.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/family/data/family_repository.dart';
import 'package:finance_tracker/features/family/models/budget.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/notifications/providers/activity_provider.dart';
import 'package:finance_tracker/features/plans/data/plan_repository.dart';
import 'package:finance_tracker/features/plans/models/plan.dart';
import 'package:finance_tracker/features/plans/models/plan_stats.dart';
import 'package:finance_tracker/features/plans/providers/plan_provider.dart';
import 'package:finance_tracker/features/transactions/data/transaction_repository.dart';
import 'package:finance_tracker/features/transactions/models/payment_method.dart';
import 'package:finance_tracker/features/transactions/models/transaction.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';
import 'package:finance_tracker/features/transfers/data/transfer_repository.dart';
import 'package:finance_tracker/features/transfers/models/transfer.dart';
import 'package:finance_tracker/features/transfers/providers/transfer_provider.dart';

/// Everything one phone holds, wired the way main.dart wires it.
class _Phone {
  _Phone() {
    session = SessionProvider(
      SessionStore(),
      onDataChanged: () async {
        await finance.load();
        await family.load();
        await plans.load();
        await transfers.load();
        await activity.load();
      },
    );
  }

  final finance = FinanceProvider(TransactionRepository());
  final family = FamilyProvider(FamilyRepository());
  final plans = PlanProvider(PlanRepository());
  final transfers = TransferProvider(TransferRepository());
  final activity = ActivityProvider();
  late final SessionProvider session;
}

void main() {
  final apiUrl = Platform.environment['API_URL'];
  final skip = apiUrl == null ? 'Set API_URL to run against a backend' : false;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<_Phone> freshPhone() async {
    final dir = await Directory.systemTemp.createTemp('ft_sync');
    AppDatabase.resetForTests('${dir.path}/db.sqlite');
    PhotoStore.directoryOverride = dir;
    SharedPreferences.setMockInitialValues({});
    final phone = _Phone();
    await phone.session.setServerUrl(apiUrl!);
    await phone.finance.load();
    await phone.family.load();
    return phone;
  }

  Future<ApiClient> otherPhone(String name, String email) async {
    final api = ApiClient(baseUrl: apiUrl!);
    final reg = await api.post('/auth/register', {
      'name': name,
      'email': email,
      'password': 'password123',
    });
    api.token = reg['token'] as String;
    return api;
  }

  test('every feature syncs between two phones', () async {
    final phone = await freshPhone();
    final finance = phone.finance;
    final family = phone.family;
    final plans = phone.plans;
    final transfers = phone.transfers;
    final session = phone.session;
    final stamp = DateTime.now().microsecondsSinceEpoch;

    // Something entered before signing up comes along into the family.
    await finance.add(
      TransactionItem(
        title: 'Before sign-up',
        amount: 99,
        type: TransactionType.expense,
        categoryId: 'food',
        date: DateTime.now(),
      ),
    );
    await session.register('Owner', 'owner$stamp@example.com', 'password123');
    await session.createGroup('Test Family');
    expect(session.syncError, isNull);
    final base = '/groups/${session.group!.id}';
    final myUserId = session.session!.userId;

    final partner = await otherPhone('Ana', 'ana$stamp@example.com');
    final joined = await partner.post('/groups/join', {
      'inviteCode': session.group!.inviteCode,
    });
    final anaId = (joined['member'] as Map<String, dynamic>)['id'] as String;
    List<dynamic> list(Map<String, dynamic> r, String k) => r[k] as List;

    final uploaded = list(
      await partner.get('$base/transactions'),
      'transactions',
    );
    expect(uploaded.single['title'], 'Before sign-up');

    // Ana joining shows up as a notification.
    await session.sync();
    expect(family.members, hasLength(2));
    expect(phone.activity.items.map((a) => a.kind), contains('member_joined'));
    expect(phone.activity.unreadFor(myUserId), greaterThan(0));
    await phone.activity.markSeen();
    expect(phone.activity.unreadFor(myUserId), 0);

    // Ana spends; the phone sees it, with a fresh notification.
    await partner.post('$base/transactions', {
      'title': 'Groceries',
      'amount': 450,
      'type': 'expense',
      'categoryId': 'groceries',
      'date': DateTime.now().millisecondsSinceEpoch,
      'memberId': anaId,
    });
    await session.sync();
    expect(finance.all.any((t) => t.title == 'Groceries'), isTrue);
    expect(phone.activity.unreadFor(myUserId), 1);

    // Members without accounts: add, rename, remove.
    await family.addMember(
      FamilyMember(name: 'Sam', color: FamilyMember.palette[2]),
    );
    await session.sync();
    var serverMembers = list(await partner.get('$base/members'), 'members');
    expect(serverMembers.map((m) => m['name']), contains('Sam'));
    final sam = family.members.firstWhere((m) => m.name == 'Sam');
    await family.editMember(sam.copyWith(name: 'Samuel'));
    await session.sync();
    serverMembers = list(await partner.get('$base/members'), 'members');
    expect(serverMembers.map((m) => m['name']), contains('Samuel'));
    await family.removeMember(sam.id!);
    await session.sync();
    serverMembers = list(await partner.get('$base/members'), 'members');
    expect(serverMembers.map((m) => m['name']), isNot(contains('Samuel')));

    // Budgets: set, then remove.
    await family.saveBudget(const Budget(categoryId: 'transport', limit: 250));
    await session.sync();
    expect(
      list(
        await partner.get('$base/budgets'),
        'budgets',
      ).map((b) => b['categoryId']),
      contains('transport'),
    );
    await family.removeBudget('transport');
    await session.sync();
    expect(list(await partner.get('$base/budgets'), 'budgets'), isEmpty);

    // A trip plan: create, rename, Ana spends from it.
    await plans.save(
      Plan(
        name: 'Baguio trip',
        kind: PlanKind.trip,
        destination: 'Baguio, Benguet',
        description: 'Strawberries and ukay-ukay',
        start: DateTime(2026, 10, 20),
        end: DateTime(2026, 10, 24),
        funds: const {PaymentMethod.cash: 6000, PaymentMethod.ewallet: 4000},
        shares: Plan.equalShares(10000, [
          for (final m in family.members) m.id!,
        ]),
        split: SplitMode.equal,
      ),
    );
    await session.sync();
    final plan = plans.plans.single;
    await plans.save(
      Plan(
        id: plan.id,
        name: 'Baguio weekend',
        kind: plan.kind,
        start: plan.start,
        end: plan.end,
        funds: plan.funds,
        shares: plan.shares,
        split: plan.split,
        destination: plan.destination,
        description: plan.description,
      ),
    );
    await session.sync();
    var serverPlans = list(await partner.get('$base/plans'), 'plans');
    expect(serverPlans.single['name'], 'Baguio weekend');
    expect(serverPlans.single['destination'], 'Baguio, Benguet');
    expect(serverPlans.single['description'], 'Strawberries and ukay-ukay');
    await partner.post('$base/transactions', {
      'title': 'Strawberries',
      'amount': 400,
      'type': 'expense',
      'categoryId': 'food',
      'date': DateTime(2026, 10, 21).millisecondsSinceEpoch,
      'memberId': anaId,
      'planId': plan.id,
      'paymentMethod': 'ewallet',
    });

    // Transfers: a wallet move on the phone, Ana giving money on hers.
    await transfers.add(
      Transfer(
        kind: TransferKind.wallet,
        amount: 1000,
        fromMethod: PaymentMethod.ewallet,
        toMethod: PaymentMethod.cash,
        planId: plan.id,
        date: DateTime.now(),
      ),
    );
    final me = family.memberForUser(myUserId)!;
    await partner.post('$base/transfers', {
      'kind': 'people',
      'amount': 500,
      'fromMemberId': anaId,
      'toMemberId': me.id,
      'fromMethod': 'cash',
      'planId': plan.id,
      'date': DateTime.now().millisecondsSinceEpoch,
    });
    await session.sync();
    expect(
      list(await partner.get('$base/transfers'), 'transfers'),
      hasLength(2),
    );
    expect(transfers.all, hasLength(2));
    final stats = PlanStats.of(
      plans.plans.single,
      finance.all,
      family,
      transfers: transfers.all,
    );
    expect(stats.spent, 400);
    expect(stats.byMember[anaId], 400);
    expect(stats.fundsIn(plan, PaymentMethod.ewallet), 3000);
    expect(stats.fundsIn(plan, PaymentMethod.cash), 7000);
    expect(stats.shareOf(plan, me.id!), 5500);
    expect(stats.shareOf(plan, anaId), 4500);

    // Deleting the plan keeps its expenses as normal transactions.
    await plans.remove(plan.id!);
    await finance.load();
    await session.sync();
    serverPlans = list(await partner.get('$base/plans'), 'plans');
    expect(serverPlans, isEmpty);
    final strawberries = list(
      await partner.get('$base/transactions'),
      'transactions',
    ).firstWhere((t) => t['title'] == 'Strawberries');
    expect(strawberries['planId'], isNull);

    // Expense add / edit / delete from the phone.
    await finance.add(
      TransactionItem(
        title: 'Phone dinner',
        amount: 300,
        type: TransactionType.expense,
        categoryId: 'food',
        date: DateTime.now(),
      ),
    );
    final dinner = finance.all.firstWhere((t) => t.title == 'Phone dinner');
    await finance.edit(
      TransactionItem(
        id: dinner.id,
        title: 'Phone dinner',
        amount: 320,
        type: TransactionType.expense,
        categoryId: 'food',
        date: dinner.date,
      ),
    );
    await session.sync();
    var serverTxns = list(
      await partner.get('$base/transactions'),
      'transactions',
    );
    expect(serverTxns.firstWhere((t) => t['id'] == dinner.id)['amount'], 320);
    await finance.remove(dinner.id!);
    await session.sync();
    serverTxns = list(await partner.get('$base/transactions'), 'transactions');
    expect(serverTxns.any((t) => t['id'] == dinner.id), isFalse);

    // Receipt photos: phone → family, family → phone, and removing.
    final jpeg = Uint8List.fromList([
      0xff,
      0xd8,
      0xff,
      0xe0,
      9,
      8,
      7,
      6,
      5,
      4,
      3,
      2,
    ]);
    final shot = File(
      '${(await Directory.systemTemp.createTemp('shot')).path}/r.jpg',
    )..writeAsBytesSync(jpeg);
    await finance.add(
      TransactionItem(
        title: 'With receipt',
        amount: 150,
        type: TransactionType.expense,
        categoryId: 'groceries',
        date: DateTime.now(),
      ),
      photo: shot,
    );
    final receipt = finance.all.firstWhere((t) => t.title == 'With receipt');
    expect(receipt.photoPath, isNotNull);
    await session.sync();
    final fromPhone = await partner.getBytes(
      '$base/transactions/${receipt.id}/photo',
    );
    expect(fromPhone, jpeg);

    final others = finance.all.firstWhere((t) => t.title == 'Groceries');
    final otherJpeg = Uint8List.fromList([
      0xff,
      0xd8,
      0xff,
      0xdb,
      1,
      1,
      2,
      2,
      3,
      3,
      4,
      4,
    ]);
    await partner.putBytes('$base/transactions/${others.id}/photo', otherJpeg);
    await session.sync();
    final downloaded = finance.all.firstWhere((t) => t.id == others.id);
    expect(downloaded.hasPhoto, isTrue);
    expect(File(downloaded.photoPath!).readAsBytesSync(), otherJpeg);

    await finance.setPhoto(receipt.id!, null);
    await session.sync();
    await expectLater(
      partner.getBytes('$base/transactions/${receipt.id}/photo'),
      throwsA(isA<ApiException>()),
    );
    expect(
      finance.all.firstWhere((t) => t.id == receipt.id).hasAnyPhoto,
      isFalse,
    );

    // Signing out leaves nothing behind on the phone.
    await session.logout();
    expect(session.signedIn, isFalse);
    expect(finance.all, isEmpty);
    expect(transfers.all, isEmpty);
    expect(phone.activity.items, isEmpty);
  }, skip: skip);

  test('a new family can start fresh instead of uploading', () async {
    final phone = await freshPhone();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    await phone.finance.add(
      TransactionItem(
        title: 'Old note',
        amount: 10,
        type: TransactionType.expense,
        categoryId: 'food',
        date: DateTime.now(),
      ),
    );
    await phone.session.register(
      'Fresh',
      'fresh$stamp@example.com',
      'password123',
    );
    await phone.session.createGroup('Fresh Family', keepLocalData: false);
    expect(phone.finance.all, isEmpty);
    final api = ApiClient(
      baseUrl: apiUrl!,
      token: phone.session.session!.token,
    );
    final txns = await api.get(
      '/groups/${phone.session.group!.id}/transactions',
    );
    expect(txns['transactions'], isEmpty);
  }, skip: skip);
}
