import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Building blocks shared by the quick-entry bottom sheets (Add Activity,
// Add Transfer).

/// Light grey rounded box used for every row on the sheet.
BoxDecoration get sheetBoxDecoration => BoxDecoration(
  color: const Color(0xFFF4F4FA),
  borderRadius: BorderRadius.circular(22),
);

/// "Label ............ Value ⌄" row that opens a menu of [options].
class SheetSelect<T> extends StatelessWidget {
  const SheetSelect({
    super.key,
    required this.label,
    required this.value,
    required this.display,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Widget Function(T) display;
  final List<T> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    const valueStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem(
            value: o,
            child: DefaultTextStyle.merge(style: valueStyle, child: display(o)),
          ),
      ],
      child: Container(
        height: 54,
        padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
        decoration: sheetBoxDecoration,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  DefaultTextStyle.merge(
                    style: valueStyle,
                    child: display(value),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Big centered "₱ 19.2" input; sizes itself to the typed amount.
class SheetBigAmount extends StatelessWidget {
  const SheetBigAmount({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: AppTheme.displayFont,
      fontFamilyFallback: AppTheme.displayFallback,
      fontSize: 45,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
      color: AppColors.textPrimary,
    );
    return Center(
      child: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 120),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: style,
            cursorColor: AppColors.forest,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: '0',
              hintStyle: style.copyWith(color: const Color(0xFFC9C9DA)),
              // A prefix icon stays visible before anything is typed.
              prefixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('₱', style: style),
              ),
              prefixIconConstraints: const BoxConstraints(),
            ),
          ),
        ),
      ),
    );
  }
}

class SheetNoteField extends StatelessWidget {
  const SheetNoteField({
    super.key,
    required this.controller,
    required this.hint,
  });

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: sheetBoxDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.sentences,
              // Grows for lists like "2 eggs, 2 kilos of manok, bigas".
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                // A wrapped hint would keep the box two lines tall.
                hintMaxLines: 1,
                hintStyle: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    super.key,
    this.label = 'Add',
    this.colors = const [AppColors.lime, AppColors.lime],
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final String label;

  /// Left-to-right gradient.
  final List<Color> colors;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : 0.55,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(colors: colors),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled && !busy ? onTap : null,
            borderRadius: BorderRadius.circular(26),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.forest,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.forest,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
