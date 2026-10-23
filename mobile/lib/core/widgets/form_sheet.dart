import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/widgets/sheet_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Opens [child] in a rounded bottom sheet that lifts above the keyboard.
Future<void> showFormSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Widget child,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  constraints: sheetConstraints(context),
  backgroundColor: AppColors.surface,
  barrierColor: AppColors.textPrimary.withValues(alpha: 0.35),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
  ),
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: AppTheme.displayFont,
                          fontFamilyFallback: AppTheme.displayFallback,
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const SheetCloseButton(),
              ],
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    ),
  ),
);

/// Small caption above a sheet field.
class SheetLabel extends StatelessWidget {
  const SheetLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

/// Borderless grey field used on the sheets.
InputDecoration sheetInputDecoration({String? hint, Widget? prefix}) {
  const radius = BorderRadius.all(Radius.circular(18));
  const none = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide.none,
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textMuted),
    prefixIcon: prefix,
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: none,
    enabledBorder: none,
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.blue, width: 1.5),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.red, width: 1.5),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.red, width: 1.5),
    ),
  );
}

/// Large peso amount input, like the balance on the home card.
class SheetAmountField extends StatelessWidget {
  const SheetAmountField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: controller.text.isEmpty,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      style: const TextStyle(
        fontFamily: AppTheme.displayFont,
        fontFamilyFallback: AppTheme.displayFallback,
        fontSize: 29,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: AppColors.textPrimary,
      ),
      decoration: sheetInputDecoration(
        hint: '0.00',
        prefix: const Padding(
          padding: EdgeInsets.only(left: 18, right: 6),
          child: Text(
            '₱',
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontFamilyFallback: AppTheme.displayFallback,
              fontSize: 29,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ).copyWith(prefixIconConstraints: const BoxConstraints()),
      validator: (v) {
        final n = double.tryParse(v ?? '');
        return (n == null || n <= 0) ? 'Enter an amount greater than 0' : null;
      },
    );
  }
}

/// Full-width dark pill, the sheet's main action.
class SheetPrimaryButton extends StatelessWidget {
  const SheetPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Shows a spinner and ignores taps while work is running.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.lime.withValues(alpha: 0.55),
          disabledForegroundColor: Colors.white,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Full-width red-tint pill for removing something.
class SheetDangerButton extends StatelessWidget {
  const SheetDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.delete_outline_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label),
        style: TextButton.styleFrom(
          backgroundColor: AppColors.redTint,
          foregroundColor: AppColors.red,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
