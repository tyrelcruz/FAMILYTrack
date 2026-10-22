import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/api/api_client.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/widgets/form_sheet.dart';
import 'package:finance_tracker/core/widgets/sheet_parts.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/account/screens/account_screen.dart';

const _blue = AppColors.forest;
const _fieldBorder = Color(0xFFE2E2EE);

/// First screen when signed out: log in, or switch to creating an account.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _switchMode() => setState(() {
    _register = !_register;
    _error = null;
  });

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text.trim();
    final problem = _register && name.isEmpty
        ? 'Enter your name'
        : !email.contains('@')
        ? 'Enter your email address'
        : _register && password.length < 8
        ? 'Use at least 8 characters for the password'
        : password.isEmpty
        ? 'Enter your password'
        : null;
    if (problem != null) return setState(() => _error = problem);

    FocusScope.of(context).unfocus();
    final session = context.read<SessionProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _register
          ? await session.register(name, email, password)
          : await session.login(email, password);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgotPassword() => showFormSheet(
    context,
    title: 'Forgot password?',
    subtitle:
        'Resetting by email isn’t set up yet. If you’re locked out, create '
        'a new account and ask your family owner for the invite code — the '
        'family’s data stays safe on the server.',
    child: Builder(
      builder: (c) => SheetPrimaryButton(
        label: 'Got it',
        onPressed: () => Navigator.of(c).pop(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const Positioned.fill(child: _SoftBackground()),
            Positioned(
              top: pad.top + 6,
              right: 8,
              width: 150,
              height: 140,
              child: const CustomPaint(painter: _WalletPainter()),
            ),
            ListView(
              padding: EdgeInsets.fromLTRB(
                24,
                pad.top + 64,
                24,
                pad.bottom + 16,
              ),
              children: [
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [AppColors.forest, AppColors.blue],
                  ).createShader(r),
                  child: const Text(
                    'familytrack',
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontFamilyFallback: AppTheme.displayFallback,
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _register ? 'CREATE ACCOUNT' : 'WELCOME BACK',
                  style: const TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontFamilyFallback: AppTheme.displayFallback,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _register
                      ? 'Start tracking money with your family.'
                      : 'Your money, together.',
                  style: const TextStyle(
                    fontSize: 16.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 30),
                if (_register) ...[
                  _Field(
                    controller: _name,
                    icon: Icons.person_outline_rounded,
                    hint: 'Your name',
                    capitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 14),
                ],
                _Field(
                  controller: _email,
                  icon: Icons.mail_outline_rounded,
                  hint: 'Email address',
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: _password,
                  icon: Icons.lock_outline_rounded,
                  hint: _register ? 'Password (8+ characters)' : 'Password',
                  obscure: _hidePassword,
                  onSubmitted: _submit,
                  trailing: IconButton(
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                ),
                if (!_register)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      style: TextButton.styleFrom(foregroundColor: _blue),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.expenseRed,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 8),
                GradientActionButton(
                  label: _register ? 'Create Account' : 'Log In',
                  colors: const [AppColors.lime, AppColors.lime],
                  enabled: true,
                  busy: _busy,
                  onTap: _submit,
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _register
                          ? 'Already have an account?'
                          : 'New to familytrack?',
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: _switchMode,
                      style: TextButton.styleFrom(foregroundColor: _blue),
                      child: Text(
                        _register ? 'Log in' : 'Create account',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 44),
                    Expanded(
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => showServerSettings(context),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textMuted,
                          ),
                          icon: const Icon(Icons.dns_outlined, size: 16),
                          label: Text(
                            context.watch<SessionProvider>().serverUrl,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.groups_2_outlined,
                      size: 44,
                      color: _blue.withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.icon,
    required this.hint,
    this.keyboard,
    this.obscure = false,
    this.trailing,
    this.onSubmitted,
    this.capitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType? keyboard;
  final bool obscure;
  final Widget? trailing;
  final VoidCallback? onSubmitted;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(18));
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      autocorrect: false,
      textCapitalization: capitalization,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Icon(icon, color: _blue, size: 24),
        ),
        prefixIconConstraints: const BoxConstraints(),
        suffixIcon: trailing,
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        border: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: _fieldBorder),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: _fieldBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: _blue, width: 1.5),
        ),
      ),
    );
  }
}

/// Pale blue wash with soft blobs, behind everything.
class _SoftBackground extends StatelessWidget {
  const _SoftBackground();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        top: -120,
        right: -100,
        child: _blob(320, const Color(0xFFE6E5FF)),
      ),
      Positioned(
        bottom: -140,
        left: -120,
        child: _blob(340, const Color(0xFFEEEDFF)),
      ),
      Positioned(
        bottom: -60,
        right: -80,
        child: _blob(220, const Color(0xFFE1E0FF)),
      ),
    ],
  );

  static Widget _blob(double size, Color c) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

/// Blue wallet with a peso coin and a little sparkle.
class _WalletPainter extends CustomPainter {
  const _WalletPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.38, w * 0.78, h * 0.52),
      Radius.circular(w * 0.1),
    );
    canvas.drawRRect(
      body.shift(const Offset(0, 6)),
      Paint()
        ..color = _blue.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5653E3), AppColors.forest],
        ).createShader(body.outerRect),
    );
    // Flap with a clasp.
    final flap = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.6, h * 0.52, w * 0.34, h * 0.22),
      Radius.circular(h * 0.08),
    );
    canvas.drawRRect(flap, Paint()..color = AppColors.lime);
    canvas.drawCircle(
      Offset(w * 0.7, h * 0.63),
      h * 0.035,
      Paint()..color = AppColors.forest,
    );
    // Coin peeking out of the top.
    final c = Offset(w * 0.46, h * 0.3);
    final r = w * 0.17;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFF3B0), AppColors.gold],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0xFFE0A800)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final peso = TextPainter(
      text: TextSpan(
        text: '₱',
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: r * 1.1,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF8A6500),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    peso.paint(canvas, c - Offset(peso.width / 2, peso.height / 2));
    // Sparkle lines.
    final line = Paint()
      ..color = _blue.withValues(alpha: 0.7)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final a in [-1.9, -1.4, -0.9]) {
      final from = c + Offset(math.cos(a), math.sin(a)) * (r + 8);
      final to = c + Offset(math.cos(a), math.sin(a)) * (r + 18);
      canvas.drawLine(from, to, line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
