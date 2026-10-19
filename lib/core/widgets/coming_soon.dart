import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class ComingSoon extends StatelessWidget {
  const ComingSoon(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      '$title — coming soon',
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
    ),
  );
}

void showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$feature is coming soon')));
}
