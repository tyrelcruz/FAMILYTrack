import 'package:flutter/material.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/theme/app_theme.dart';

// The layout every tab shares: a white page with faint travel patches
// behind a centered header and hero, then a floating white card with the
// details, split by uppercase headings.

/// One sticker: file, center x and y (fractions of the area), width (a
/// fraction of the width) and a slight turn.
typedef PatchSpot = (String name, double x, double y, double w, double turn);

/// Travel stickers scattered faintly behind a page's header.
class PatchBackdrop extends StatelessWidget {
  const PatchBackdrop(this.spots, {super.key});

  final List<PatchSpot> spots;

  static const home = <PatchSpot>[
    ('travel_more', 0.12, 0.25, 0.24, -0.12),
    ('globe', 0.90, 0.28, 0.19, 0.0),
    ('paper_plane', 0.72, 0.42, 0.08, 0.0),
    ('passport', 0.91, 0.47, 0.18, 0.1),
    ('mountains', 0.10, 0.55, 0.21, -0.15),
    ('good_vibes', 0.76, 0.57, 0.19, 0.0),
    ('suitcase', 0.10, 0.83, 0.18, -0.1),
    ('airmail', 0.90, 0.95, 0.23, 0.0),
  ];

  static const plans = <PatchSpot>[
    ('passport', 0.10, 0.12, 0.2, -0.12),
    ('paper_plane', 0.86, 0.10, 0.1, 0.2),
    ('mountains', 0.92, 0.36, 0.2, 0.1),
    ('suitcase', 0.08, 0.48, 0.18, 0.12),
    ('airmail', 0.12, 0.88, 0.22, -0.08),
    ('globe', 0.90, 0.84, 0.18, 0.0),
  ];

  static const family = <PatchSpot>[
    ('good_vibes', 0.12, 0.14, 0.22, -0.1),
    ('globe', 0.90, 0.16, 0.18, 0.0),
    ('travel_more', 0.08, 0.62, 0.2, 0.1),
    ('paper_plane', 0.82, 0.55, 0.09, -0.2),
    ('suitcase', 0.92, 0.84, 0.18, -0.08),
  ];

  static const profile = <PatchSpot>[
    ('airmail', 0.12, 0.18, 0.24, -0.1),
    ('passport', 0.90, 0.2, 0.2, 0.12),
    ('paper_plane', 0.18, 0.72, 0.09, 0.15),
    ('good_vibes', 0.86, 0.78, 0.2, 0.0),
  ];

  /// Two quiet corners for sub-pages (transactions, a trip's form…).
  static const sub = <PatchSpot>[
    ('paper_plane', 0.06, 0.86, 0.09, -0.2),
    ('globe', 0.95, 0.9, 0.15, 0.0),
  ];

  /// Wraps a sub-page's body with [sub] patches behind its header.
  static Widget behind(Widget body) => Stack(
    children: [
      const Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 240,
        child: PatchBackdrop(sub),
      ),
      body,
    ],
  );

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: LayoutBuilder(
      builder: (context, c) => Opacity(
        opacity: 0.13,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            for (final (name, x, y, w, turn) in spots)
              Positioned(
                left: c.maxWidth * (x - w / 2),
                top: c.maxHeight * y - c.maxWidth * w / 2,
                width: c.maxWidth * w,
                child: Transform.rotate(
                  angle: turn,
                  child: Image.asset('assets/images/patches/$name.png'),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// The top of a page: patches behind [children], below the status bar.
class PageHero extends StatelessWidget {
  const PageHero({
    super.key,
    required this.patches,
    required this.children,
    this.bottomGap = 30,
  });

  final List<PatchSpot> patches;
  final List<Widget> children;
  final double bottomGap;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: PatchBackdrop(patches)),
      Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 18,
          bottom: bottomGap,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ],
  );
}

/// "OCTOBER'S BREAKDOWN"-style title with an optional grey line under it.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle});

  final String title;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      children: [
        Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTheme.displayFont,
            fontFamilyFallback: AppTheme.displayFallback,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          DefaultTextStyle.merge(
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            child: subtitle!,
          ),
        ],
      ],
    ),
  );
}

/// Big centered amount in the display font, as on Home.
class HeroAmount extends StatelessWidget {
  const HeroAmount(this.text, {super.key, this.color = AppColors.textPrimary});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      text,
      style: TextStyle(
        fontFamily: AppTheme.displayFont,
        fontFamilyFallback: AppTheme.displayFallback,
        fontSize: 38,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.1,
      ),
    ),
  );
}

/// Thin teal progress bar on a mint track.
class TealBar extends StatelessWidget {
  const TealBar({
    super.key,
    required this.value,
    this.width = 128,
    this.over = false,
  });

  final double value;
  final double width;

  /// Red when past the limit.
  final bool over;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: width,
      height: 5,
      decoration: BoxDecoration(
        color: AppColors.mintTrack,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: over ? AppColors.expenseRed : AppColors.teal,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    ),
  );
}

/// The white card under a page's hero: rounded, thin grey edge and a soft
/// shadow so it lifts off the page.
class FloatingCard extends StatelessWidget {
  const FloatingCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(0, 10, 0, 20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      12,
      0,
      12,
      MediaQuery.paddingOf(context).bottom + 16,
    ),
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    ),
  );
}

/// "RECENT ACTIVITY →" heading inside a card: uppercase display font, with
/// grey [trailing] text, a teal [action] link or an arrow when tappable.
class CardHeading extends StatelessWidget {
  const CardHeading(
    this.title, {
    super.key,
    this.trailing,
    this.action,
    this.onTap,
  });

  final String title;
  final String? trailing;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontFamily: AppTheme.displayFont,
                fontFamilyFallback: AppTheme.displayFallback,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tealDark,
                ),
              ),
            )
          else if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 22.5,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    ),
  );
}

/// Round white chevron button near a screen edge, e.g. previous / next month.
class MintSideArrow extends StatelessWidget {
  const MintSideArrow({super.key, required this.left, required this.onTap});

  final bool left;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      border: Border.all(color: AppColors.divider),
      boxShadow: [
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: AppColors.mint,
        highlightColor: AppColors.mint.withValues(alpha: 0.6),
        child: Icon(
          left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
          color: AppColors.forest,
          size: 26,
        ),
      ),
    ),
  );
}

/// Small mint pill button with an icon, for a page's main action.
class MintPill extends StatelessWidget {
  const MintPill({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Center(
    child: Material(
      color: AppColors.mint,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 18, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16.5, color: AppColors.tealDark),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.tealDark,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Two-way switch with a mint selected pill, e.g. My Plans / Shared.
class MintToggle extends StatelessWidget {
  const MintToggle({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: AppColors.divider),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: i == index ? AppColors.mint : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: i == index
                        ? AppColors.tealDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
