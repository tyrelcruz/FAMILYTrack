import 'package:finance_tracker/app/app.dart';
import 'package:finance_tracker/features/transactions/data/transaction_repository.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => FinanceProvider(TransactionRepository()),
      child: const FinanceTrackerApp(),
    ),
  );
}
