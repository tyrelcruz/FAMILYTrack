import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';

/// Two stacks of mixed ₱1, ₱5 and ₱20 coins, like the reference: money
/// **In** on the left, money **Out** on the right (plans at the bottom, then
/// everyday spending), with see-through coins showing how high the monthly
/// limit goes. The top coin of each section shows its face.
class CoinBreakdown extends StatefulWidget {
  const CoinBreakdown({
    super.key,
    required this.income,
    required this.spent,
    required this.plans,
    required this.limit,
  });

  final double income;

  /// Everyday expenses (not part of a trip or plan).
  final double spent;

  /// Expenses that belong to a plan.
  final double plans;

  /// Monthly limit; null when no budget is set.
  final double? limit;

  static const _maxCoins = 14;
  static const _rx = 44.0; // half coin width
  static const _ry = 12.0; // half coin ellipse height
  static const _thick = 13.0; // coin thickness

  /// Tall enough for the highest possible stack, no more.
  static const height = _maxCoins * _thick + _ry * 2 + 10;

  @override
  State<CoinBreakdown> createState() => _CoinBreakdownState();
}

class _CoinBreakdownState extends State<CoinBreakdown> {
  /// Indexed by [_Face]: ₱20, ₱1, ₱5.
  static const _assets = [
    'assets/images/peso_coin.png',
    'assets/images/peso_coin_1.png',
    'assets/images/peso_coin_5.png',
  ];
  final _faces = List<ui.Image?>.filled(_assets.length, null);
  final _streams = List<ImageStream?>.filled(_assets.length, null);
  late final _listeners = [
    for (var i = 0; i < _assets.length; i++)
      ImageStreamListener((info, _) {
        if (mounted) setState(() => _faces[i] = info.image);
      }),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final config = createLocalImageConfiguration(context);
    for (var i = 0; i < _assets.length; i++) {
      _streams[i]?.removeListener(_listeners[i]);
      _streams[i] = AssetImage(_assets[i]).resolve(config)
        ..addListener(_listeners[i]);
    }
  }

  @override
  void dispose() {
    for (var i = 0; i < _assets.length; i++) {
      _streams[i]?.removeListener(_listeners[i]);
    }
    super.dispose();
  }

  int _coins(double v, double max) =>
      v <= 0 ? 0 : math.max(1, (v / max * CoinBreakdown._maxCoins).round());

  @override
  Widget build(BuildContext context) {
    const rx = CoinBreakdown._rx;
    const ry = CoinBreakdown._ry;
    const thick = CoinBreakdown._thick;
    const height = CoinBreakdown.height;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final out = widget.spent + widget.plans;
        final max = [
          widget.income,
          out,
          widget.limit ?? 0,
          1.0,
        ].reduce(math.max);
        final inCoins = _coins(widget.income, max);
        final planCoins = _coins(widget.plans, max);
        final spentCoins = _coins(widget.spent, max);
        final limitCoins = widget.limit == null
            ? 0
            : _coins(widget.limit!, max);
        final ghostCoins = math.max(0, limitCoins - planCoins - spentCoins);
        final inX = w * 0.36;
        final outX = w * 0.64;
        final base = height - ry - 6;
        double topOf(int count) => base - count * thick - ry;

        // Labels beside the stacks; nudged apart so they never overlap.
        final rightLabels = <_Label>[
          if (widget.limit != null)
            _Label(
              'Limit',
              topOf(planCoins + spentCoins + ghostCoins),
              AppColors.lime,
              AppColors.textPrimary,
            ),
          if (spentCoins > 0)
            _Label(
              'Spent',
              topOf(planCoins + spentCoins),
              AppColors.tangerine,
              AppColors.textPrimary,
            ),
          if (planCoins > 0)
            _Label(
              'Plans',
              topOf(planCoins),
              AppColors.gold,
              AppColors.textPrimary,
            ),
        ];
        for (var i = 1; i < rightLabels.length; i++) {
          final prev = rightLabels[i - 1];
          if (rightLabels[i].y - prev.y < 24) {
            rightLabels[i] = rightLabels[i].copyWith(y: prev.y + 24);
          }
        }

        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _StacksPainter(
                    faces: List.of(_faces),
                    inX: inX,
                    outX: outX,
                    base: base,
                    inCoins: inCoins,
                    planCoins: planCoins,
                    income: widget.income,
                    spent: widget.spent,
                    plans: widget.plans,
                    spentCoins: spentCoins,
                    ghostCoins: ghostCoins,
                  ),
                ),
              ),
              // Nothing logged yet: say so instead of empty coins only.
              if (inCoins == 0 && planCoins == 0 && spentCoins == 0)
                Positioned(
                  left: 0,
                  right: w - inX + rx,
                  bottom: 40,
                  child: Text(
                    'No income or\nspending yet\nthis month',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              if (inCoins > 0)
                Positioned(
                  right: w - inX + rx + 6,
                  top: topOf(inCoins) - 2,
                  child: const _Pill(
                    'Income',
                    AppColors.lime,
                    AppColors.textPrimary,
                  ),
                ),
              for (final l in rightLabels)
                Positioned(
                  left: outX + rx + 6,
                  top: l.y - 2,
                  child: _Pill(l.text, l.bg, l.fg),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Label {
  const _Label(this.text, this.y, this.bg, this.fg);

  final String text;
  final double y;
  final Color bg;
  final Color fg;

  _Label copyWith({required double y}) => _Label(text, y, bg, fg);
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.bg, this.fg);

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
    ),
  );
}

/// How one kind of coin looks: edge colors and how its face is tinted.
class _Look {
  const _Look({
    required this.rim,
    required this.edge,
    required this.notch,
    required this.shade,
    this.faceFilter,
    this.faceOpacity = 1,
    this.face = _Face.twenty,
  });

  /// Light top lip of the edge.
  final Color rim;

  /// The coin's edge band.
  final Color edge;

  /// Short marks around the edge, like reeding.
  final Color notch;

  /// Thin dark line under each coin, separating it from the next.
  final Color shade;

  /// Recolors the ₱20 face (null keeps the real gold and silver).
  final ColorFilter? faceFilter;
  final double faceOpacity;

  /// Which coin's face is on top.
  final _Face face;
}

/// Order matches `_CoinBreakdownState._assets`.
enum _Face { twenty, one, five }

/// The real ₱1, all silver.
const _onePeso = _Look(
  rim: Color(0xFFF2F3F7),
  edge: Color(0xFFC3C7D2),
  notch: Color(0xFF8E94A3),
  shade: Color(0xFF6F7585),
  face: _Face.one,
);

/// The real ₱5, antique brass.
const _fivePeso = _Look(
  rim: Color(0xFFE8D58A),
  edge: Color(0xFFC6A443),
  notch: Color(0xFF8F7420),
  shade: Color(0xFF6F5912),
  face: _Face.five,
);

/// The real ₱20, gold ring and silver center.
const _twentyPeso = _Look(
  rim: Color(0xFFFFE08A),
  edge: Color(0xFFF2B630),
  notch: Color(0xFFC98A10),
  shade: Color(0xFFA86F05),
);

/// See-through coins: the room left under the limit.
const _ghost = _Look(
  rim: Color(0x40FFFFFF),
  edge: Color(0x24FFFFFF),
  notch: Color(0x33FFFFFF),
  shade: Color(0x26000000),
  faceOpacity: 0.16,
  faceFilter: ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcATop),
);

class _StacksPainter extends CustomPainter {
  const _StacksPainter({
    required this.faces,
    required this.inX,
    required this.outX,
    required this.base,
    required this.inCoins,
    required this.income,
    required this.spent,
    required this.plans,
    required this.planCoins,
    required this.spentCoins,
    required this.ghostCoins,
  });

  /// Decoded coin faces, indexed by [_Face].
  final List<ui.Image?> faces;
  final double inX;
  final double outX;
  final double base;
  final int inCoins;

  /// Amounts behind each section; they decide the mix of coins.
  final double income;
  final double spent;
  final double plans;
  final int planCoins;
  final int spentCoins;
  final int ghostCoins;

  static const _rx = CoinBreakdown._rx;
  static const _ry = CoinBreakdown._ry;
  static const _thick = CoinBreakdown._thick;

  @override
  void paint(Canvas canvas, Size size) {
    _stack(canvas, inX, [_mix(inCoins, income)], seed: 3);
    _stack(canvas, outX, [
      _mix(planCoins, plans),
      _mix(spentCoins, spent),
      [for (var i = 0; i < ghostCoins; i++) _ghost],
    ], seed: 7);
  }

  /// [count] coins mixing ₱1, ₱5 and ₱20 like real change: always the most
  /// ₱1, then ₱5, then the fewest ₱20 (bigger amounts lean a little more
  /// toward ₱5 and ₱20). Shuffled the same way for the same amount, so the
  /// stack only changes when the money does.
  static List<_Look> _mix(int count, double amount) {
    if (count == 0) return const [];
    final big = (amount / 15000).clamp(0.0, 1.0);
    // Shares stay ₱1 > ₱5 > ₱20; rounding down keeps that true for any count.
    final twenties = (count * (0.15 + 0.07 * big)).floor();
    final fives = (count * (0.28 + 0.04 * big)).floor();
    return [
      for (var i = 0; i < twenties; i++) _twentyPeso,
      for (var i = 0; i < fives; i++) _fivePeso,
      for (var i = 0; i < count - twenties - fives; i++) _onePeso,
    ]..shuffle(math.Random(amount.round()));
  }

  /// Sections drawn bottom-up with a little sideways wobble, like a real
  /// stack; the top coin of each section shows its face.
  void _stack(
    Canvas canvas,
    double cx,
    List<List<_Look>> sections, {
    required int seed,
  }) {
    final coins = [
      for (final section in sections)
        for (var i = 0; i < section.length; i++)
          (section[i], i == section.length - 1),
    ];
    if (coins.isEmpty) return;
    final rnd = math.Random(seed);
    // Soft shadow under the stack.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, base + 4),
        width: _rx * 2.2,
        height: _ry * 2.2,
      ),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    for (var i = 0; i < coins.length; i++) {
      final dx = (rnd.nextDouble() - 0.5) * 5;
      final (look, top) = coins[i];
      _coin(canvas, cx + dx, i, look, showFace: top);
    }
  }

  void _coin(
    Canvas canvas,
    double cx,
    int index,
    _Look look, {
    required bool showFace,
  }) {
    final y = base - (index + 1) * _thick;
    final top = Rect.fromCenter(
      center: Offset(cx, y),
      width: _rx * 2,
      height: _ry * 2,
    );
    final bottom = top.shift(const Offset(0, _thick));

    // Edge band.
    final band = Path()
      ..moveTo(cx - _rx, y)
      ..lineTo(cx - _rx, y + _thick)
      ..arcTo(bottom, math.pi, -math.pi, false)
      ..lineTo(cx + _rx, y)
      ..close();
    canvas.drawPath(
      band,
      Paint()
        ..shader = LinearGradient(
          colors: [look.notch, look.edge, look.rim, look.edge, look.notch],
          stops: const [0, 0.25, 0.5, 0.75, 1],
        ).createShader(Rect.fromLTRB(cx - _rx, y, cx + _rx, y + _thick)),
    );
    // Reeding notches, like the reference's ticks on the edge.
    final notch = Paint()
      ..color = look.notch
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var a = 0.35; a < math.pi; a += 0.42) {
      final x = cx - _rx * math.cos(a);
      final yy = y + _ry * math.sin(a);
      canvas.drawLine(Offset(x, yy + 3), Offset(x, yy + _thick - 3), notch);
    }
    // Dark seam under the coin.
    canvas.drawArc(
      bottom,
      0,
      math.pi,
      false,
      Paint()
        ..color = look.shade
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // See-through coins only show their top on the highest one, or every
    // hidden lip would show through as a ring.
    if (identical(look, _ghost) && !showFace) return;

    // Top: the ₱20 face in perspective, or a plain lip for coins that
    // another coin of the same kind covers.
    final img = faces[look.face.index];
    if (showFace && img != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(top));
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        top,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = look.faceFilter
          ..color = Color.fromRGBO(0, 0, 0, look.faceOpacity),
      );
      canvas.restore();
    } else {
      canvas.drawOval(top, Paint()..color = look.rim);
      canvas.drawOval(
        top.deflate(5),
        Paint()
          ..color = look.edge.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    canvas.drawOval(
      top,
      Paint()
        ..color = look.rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _StacksPainter old) =>
      !listEquals(old.faces, faces) ||
      old.inCoins != inCoins ||
      old.income != income ||
      old.spent != spent ||
      old.plans != plans ||
      old.planCoins != planCoins ||
      old.spentCoins != spentCoins ||
      old.ghostCoins != ghostCoins ||
      old.inX != inX;
}
