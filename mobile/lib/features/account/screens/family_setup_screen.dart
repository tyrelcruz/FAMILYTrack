import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/account/screens/account_screen.dart';

/// After signing in, before the app: start a family or join one.
class FamilySetupScreen extends StatelessWidget {
  const FamilySetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final name = session.session?.name ?? '';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hi ${name.split(' ').first}!',
                      style: const TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontFamilyFallback: AppTheme.displayFallback,
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: session.logout,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Your spending lives in a family. Start one, or join the one '
                'someone invited you to.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              if (session.syncError != null) ...[
                Notice(session.syncError!),
                const SizedBox(height: 18),
              ],
              const FamilySetupCard(),
            ],
          ),
        ),
      ),
    );
  }
}
