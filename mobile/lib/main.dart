import 'package:finance_tracker/app/app.dart';
import 'package:finance_tracker/features/account/data/session_store.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/family/data/family_repository.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/notifications/providers/activity_provider.dart';
import 'package:finance_tracker/features/plans/data/plan_repository.dart';
import 'package:finance_tracker/features/plans/providers/plan_provider.dart';
import 'package:finance_tracker/features/transactions/data/transaction_repository.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';
import 'package:finance_tracker/features/transfers/data/transfer_repository.dart';
import 'package:finance_tracker/features/transfers/providers/transfer_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final finance = FinanceProvider(TransactionRepository());
  final family = FamilyProvider(FamilyRepository());
  final plans = PlanProvider(PlanRepository());
  final transfers = TransferProvider(TransferRepository());
  final activity = ActivityProvider();
  final session = SessionProvider(
    SessionStore(),
    onDataChanged: () async {
      await finance.load();
      await family.load();
      await plans.load();
      await transfers.load();
      await activity.load();
    },
  )..init();
  finance.onLocalChange = session.scheduleSync;
  family.onLocalChange = session.scheduleSync;
  plans.onLocalChange = session.scheduleSync;
  transfers.onLocalChange = session.scheduleSync;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: finance),
        ChangeNotifierProvider.value(value: family),
        ChangeNotifierProvider.value(value: plans),
        ChangeNotifierProvider.value(value: transfers),
        ChangeNotifierProvider.value(value: activity),
        ChangeNotifierProvider.value(value: session),
      ],
      child: const FinanceTrackerApp(),
    ),
  );
}
