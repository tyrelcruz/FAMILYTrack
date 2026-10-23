import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/api/api_client.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/features/account/models/session.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/core/widgets/breakdown_layout.dart';
import 'package:finance_tracker/core/widgets/form_sheet.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';

/// Profile tab: who you are up top; your family and app settings below.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    if (!session.ready) return const Center(child: CircularProgressIndicator());
    final s = session.session;
    final group = session.group;

    final name = s?.name ?? '';
    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          PageHero(
            patches: PatchBackdrop.profile,
            children: [
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.teal.withValues(alpha: 0.2),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: const TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontFamilyFallback: AppTheme.displayFallback,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: AppColors.tealDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              PageTitle(
                name.isEmpty ? 'Profile' : name,
                subtitle: Text(s?.email ?? 'Not signed in'),
              ),
              if (group != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          size: 14.5,
                          color: AppColors.tealDark,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${group.name} · ${session.syncStatus}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tealDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (s != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      final ok = await _confirm(
                        context,
                        title: 'Sign out?',
                        message:
                            'This phone goes back to a fresh offline tracker. '
                            'Your family’s data stays on the server.',
                        action: 'Sign Out',
                        danger: true,
                      );
                      if (ok) await session.logout();
                    },
                    style: TextButton.styleFrom(foregroundColor: AppColors.red),
                    icon: const Icon(Icons.logout_rounded, size: 15.5),
                    label: const Text(
                      'Sign out',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
          FloatingCard(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardHeading(
                  group == null ? 'Set up your family' : 'Your family',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (group != null) ...[
                        _GroupCard(group: group),
                        const SizedBox(height: 14),
                        _GroupActions(group: group),
                      ] else ...[
                        if (session.syncError != null) ...[
                          Notice(session.syncError!),
                          const SizedBox(height: 16),
                        ],
                        const FamilySetupCard(),
                      ],
                    ],
                  ),
                ),
                const CardHeading('App'),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ServerCard(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Runs [action], showing the server's message if it fails.
Future<bool> _attempt(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } on ApiException catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: danger ? AppColors.red : AppColors.textPrimary,
            shape: const StadiumBorder(),
          ),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok == true;
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: AppColors.divider),
    ),
    child: child,
  );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.title, [this.subtitle]);

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.orangeTint,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.orange),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
        ),
      ],
    ),
  );
}

/// Where the API lives; needed when testing on a real phone.
Future<void> showServerSettings(BuildContext context) async {
  final session = context.read<SessionProvider>();
  final controller = TextEditingController(text: session.serverUrl);
  await showFormSheet(
    context,
    title: 'Server address',
    subtitle:
        'Use your computer’s Wi-Fi address when testing on a phone, '
        'e.g. http://192.168.1.10:3000/api',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: sheetInputDecoration(hint: defaultApiUrl()),
        ),
        const SizedBox(height: 24),
        Builder(
          builder: (context) => SheetPrimaryButton(
            label: 'Save',
            onPressed: () async {
              await session.setServerUrl(controller.text);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
      ],
    ),
  );
  controller.dispose();
}

class ServerCard extends StatelessWidget {
  const ServerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final url = context.watch<SessionProvider>().serverUrl;
    return _Card(
      child: InkWell(
        onTap: () => showServerSettings(context),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: AppColors.neutralTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.dns_outlined,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Server',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Signed in ──────────────────────────────────────────────────────────

class FamilySetupCard extends StatefulWidget {
  const FamilySetupCard({super.key});

  @override
  State<FamilySetupCard> createState() => _FamilySetupCardState();
}

class _FamilySetupCardState extends State<FamilySetupCard> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _creating = false;
  bool _joining = false;

  /// Upload what's already on this phone into the new family.
  bool _keepLocal = true;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final session = context.read<SessionProvider>();
    setState(() => _creating = true);
    await _attempt(
      context,
      () => session.createGroup(name, keepLocalData: _keepLocal),
    );
    if (mounted) setState(() => _creating = false);
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    final session = context.read<SessionProvider>();
    final ok = await _confirm(
      context,
      title: 'Join this family?',
      message:
          'This phone will show the family’s spending and budgets instead of '
          'what’s on it now.',
      action: 'Join',
    );
    if (!ok || !mounted) return;
    setState(() => _joining = true);
    await _attempt(context, () => session.joinGroup(code));
    if (mounted) setState(() => _joining = false);
  }

  @override
  Widget build(BuildContext context) {
    const fieldStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
    final localCount = context.watch<FinanceProvider>().all.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CardTitle(
                'Create a family',
                'You’ll get a code to invite others.',
              ),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                style: fieldStyle,
                decoration: sheetInputDecoration(hint: 'e.g. Hoque Family'),
              ),
              if (localCount > 0) ...[
                const SizedBox(height: 10),
                // Its own Material so the card's color doesn't hide the
                // tap effect.
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _keepLocal,
                    onChanged: (v) => setState(() => _keepLocal = v),
                    title: Text(
                      'Bring the $localCount '
                      '${localCount == 1 ? 'entry' : 'entries'} on this phone',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Turn off to start the family fresh.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SheetPrimaryButton(
                label: 'Create Family',
                busy: _creating,
                onPressed: _joining ? null : _create,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _CardTitle(
                'Join a family',
                'Ask the family owner for their 6-character invite code.',
              ),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                maxLength: 6,
                style: fieldStyle.copyWith(letterSpacing: 4),
                decoration: sheetInputDecoration(
                  hint: 'ABC123',
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: 16),
              SheetPrimaryButton(
                label: 'Join Family',
                busy: _joining,
                onPressed: _creating ? null : _join,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Gradient card, matching the home balance card, with the invite code and
/// sync state.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final LinkedGroup group;

  static const _white70 = Color(0xD9FFFFFF);

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: AppColors.cardGradient,
          stops: [0, 0.45, 0.78, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardGradient[1].withValues(alpha: 0.30),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontFamilyFallback: AppTheme.displayFallback,
                    color: Colors.white,
                    fontSize: 21.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Text(
                '${group.memberCount} '
                '${group.memberCount == 1 ? 'member' : 'members'}',
                style: const TextStyle(color: _white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Invite code',
            style: TextStyle(
              color: _white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    group.inviteCode,
                    style: const TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontFamilyFallback: AppTheme.displayFallback,
                      color: Colors.white,
                      fontSize: 37,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              _Pill(
                icon: Icons.copy_rounded,
                label: 'Copy',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: group.inviteCode));
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('Invite code copied')),
                    );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Icon(
                  session.syncError != null
                      ? Icons.cloud_off_rounded
                      : Icons.cloud_done_rounded,
                  color: Colors.white,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.syncStatus,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: session.syncing ? null : session.sync,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: _white70,
                  ),
                  child: const Text(
                    'Sync now',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 9, 18, 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.textPrimary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 13),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupActions extends StatelessWidget {
  const _GroupActions({required this.group});

  final LinkedGroup group;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionProvider>();
    if (group.isOwner) {
      return SheetDangerButton(
        label: 'Reset Invite Code',
        icon: Icons.refresh_rounded,
        onPressed: () async {
          final ok = await _confirm(
            context,
            title: 'Reset invite code?',
            message:
                'The current code stops working. People already in the '
                'family stay in it.',
            action: 'Reset',
          );
          if (ok && context.mounted) {
            await _attempt(context, session.newInviteCode);
          }
        },
      );
    }
    return SheetDangerButton(
      label: 'Leave Family',
      icon: Icons.exit_to_app_rounded,
      onPressed: () async {
        final ok = await _confirm(
          context,
          title: 'Leave ${group.name}?',
          message:
              'Your spending stays with the family. This phone goes back '
              'to a fresh offline tracker.',
          action: 'Leave',
          danger: true,
        );
        if (ok && context.mounted) await _attempt(context, session.leaveGroup);
      },
    );
  }
}
