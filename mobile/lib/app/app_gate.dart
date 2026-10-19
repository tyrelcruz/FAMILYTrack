import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/account/screens/family_setup_screen.dart';
import 'package:finance_tracker/features/account/screens/welcome_screen.dart';
import 'package:finance_tracker/features/home/screens/home_shell.dart';

/// Signed out → welcome; signed in without a family → setup; else the app.
/// Everything lives on the server, so there's no way in without both.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final Widget page;
    if (!session.ready) {
      page = const ColoredBox(
        key: ValueKey('loading'),
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (!session.signedIn) {
      page = const WelcomeScreen(key: ValueKey('welcome'));
    } else if (!session.linked) {
      page = const FamilySetupScreen(key: ValueKey('setup'));
    } else {
      page = const HomeShell(key: ValueKey('app'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: page,
    );
  }
}
