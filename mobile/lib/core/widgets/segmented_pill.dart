import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class SegmentOption<T> {
  const SegmentOption(this.value, this.label, {this.icon, this.color});

  final T value;
  final String label;
  final IconData? icon;

  /// Icon color when selected.
  final Color? color;
}

/// Grey track with a white sliding pill marking the selected option.
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.neutralTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(o.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: o.value == value
                        ? AppColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: o.value == value ? AppColors.softShadow : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (o.icon != null) ...[
                        Icon(
                          o.icon,
                          size: 18,
                          color: o.value == value
                              ? (o.color ?? AppColors.textPrimary)
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        o.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: o.value == value
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
