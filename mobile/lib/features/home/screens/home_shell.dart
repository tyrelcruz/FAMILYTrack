import 'package:finance_tracker/features/account/screens/account_screen.dart';
import 'package:finance_tracker/features/family/screens/family_screen.dart';
import 'package:finance_tracker/features/home/screens/home_screen.dart';
import 'package:finance_tracker/features/home/widgets/floating_nav_bar.dart';
import 'package:finance_tracker/features/home/widgets/quick_add_menu.dart';
import 'package:finance_tracker/features/plans/screens/plans_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _profileTab = 3;

  static const _items = [
    NavItem('Home', Icons.home_outlined, Icons.home_rounded),
    NavItem('Plans', Icons.luggage_outlined, Icons.luggage_rounded),
    NavItem('Family', Icons.groups_outlined, Icons.groups_rounded),
    NavItem('Profile', Icons.settings_outlined, Icons.settings_rounded),
  ];

  void _goToProfile() => setState(() => _index = _profileTab);

  @override
  Widget build(BuildContext context) {
    // Home sits on a blue header, so its status bar icons are white.
    final overlay = _index == 0
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: [
            HomeScreen(onProfileTap: _goToProfile),
            const PlansScreen(),
            FamilyScreen(onConnect: _goToProfile),
            const AccountScreen(),
          ],
        ),
        bottomNavigationBar: FloatingNavBar(
          items: _items,
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          onAdd: () => showQuickAddMenu(context),
        ),
      ),
    );
  }
}
