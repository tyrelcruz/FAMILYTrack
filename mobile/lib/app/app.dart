import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/app/app_gate.dart';
import 'package:flutter/material.dart';

class FinanceTrackerApp extends StatelessWidget {
  const FinanceTrackerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Finance Tracker',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const AppGate(),
  );
}
