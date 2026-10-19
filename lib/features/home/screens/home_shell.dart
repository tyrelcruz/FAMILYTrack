import 'package:finance_tracker/core/widgets/coming_soon.dart';
import 'package:finance_tracker/features/home/screens/home_screen.dart';
import 'package:finance_tracker/features/home/widgets/floating_nav_bar.dart';
import 'package:finance_tracker/features/stats/screens/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _items = [
    NavItem('Home', Icons.home_outlined, Icons.home_rounded),
    NavItem('Insights', Icons.bar_chart_rounded, Icons.bar_chart_rounded),
    NavItem('Cards', Icons.credit_card_outlined, Icons.credit_card),
    NavItem('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _index,
          children: [
            HomeScreen(onProfileTap: () => setState(() => _index = 3)),
            const SafeArea(child: StatsScreen()),
            const SafeArea(child: ComingSoon('Cards')),
            const SafeArea(child: ComingSoon('Profile')),
          ],
        ),
        bottomNavigationBar: FloatingNavBar(
          items: _items,
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}
