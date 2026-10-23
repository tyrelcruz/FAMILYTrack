import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:finance_tracker/core/theme/app_theme.dart';
import 'package:finance_tracker/core/api/api_client.dart';
import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/features/account/models/session.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/core/widgets/breakdown_layout.dart';
import 'package:finance_tracker/core/widgets/form_sheet.dart';
import 'package:finance_tracker/features/categories/models/category.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/family/screens/member_detail_screen.dart';
import 'package:finance_tracker/features/family/widgets/member_avatar.dart';
import 'package:finance_tracker/features/notifications/providers/activity_provider.dart';
import 'package:finance_tracker/features/notifications/screens/notifications_screen.dart';
import 'package:finance_tracker/features/transactions/providers/finance_provider.dart';
import 'package:finance_tracker/features/transactions/screens/transactions_screen.dart';

/// Profile tab: who you are up top; account, family and app settings below.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    if (!session.ready) return const Center(child: CircularProgressIndicator());
    final s = session.session;
    final group = session.group;
    final family = context.watch<FamilyProvider>();
    final unread = context.watch<ActivityProvider>().unreadFor(s?.userId);

    final name = s?.name ?? '';
    final entries = context.watch<FinanceProvider>().all.length;
    return ColoredBox(
      color: Colors.white,
      child: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: session.sync,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            PageHero(
              patches: PatchBackdrop.profile,
              children: [
                Center(
                  child: _Avatar(
                    name: name,
                    onEdit: s == null ? null : () => _editName(context),
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
              ],
            ),
            FloatingCard(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s != null) ...[
                    const CardHeading('Account'),
                    _Group(
                      children: [
                        _Row(
                          icon: Icons.person_outline_rounded,
                          label: 'Name',
                          value: s.name,
                          onTap: () => _editName(context),
                        ),
                        _Row(
                          icon: Icons.alternate_email_rounded,
                          label: 'Email',
                          value: s.email,
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: s.email));
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(content: Text('Email copied')),
                              );
                          },
                        ),
                        _Row(
                          icon: Icons.lock_outline_rounded,
                          label: 'Change password',
                          onTap: () => _changePassword(context),
                        ),
                      ],
                    ),
                  ],
                  CardHeading(
                    group == null ? 'Set up your family' : 'Your family',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: group != null
                        ? _GroupCard(group: group)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (session.syncError != null) ...[
                                Notice(session.syncError!),
                                const SizedBox(height: 16),
                              ],
                              const FamilySetupCard(),
                            ],
                          ),
                  ),
                  if (group != null) ...[
                    const SizedBox(height: 12),
                    _GroupActions(group: group),
                    CardHeading('People', trailing: '${family.members.length}'),
                    _Group(
                      children: [
                        for (final m in family.members)
                          _MemberRow(
                            member: m,
                            you: m.userId != null && m.userId == s?.userId,
                            onTap: m.id == null
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          MemberDetailScreen(memberId: m.id!),
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ],
                  const CardHeading('Your data'),
                  _Group(
                    children: [
                      _Row(
                        icon: Icons.receipt_long_rounded,
                        label: 'All entries',
                        value: '$entries',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const TransactionsScreen(),
                          ),
                        ),
                      ),
                      _Row(
                        icon: Icons.notifications_none_rounded,
                        label: 'Notifications',
                        badge: unread,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                      ),
                      _Row(
                        icon: Icons.ios_share_rounded,
                        label: 'Export to spreadsheet',
                        value: '.csv',
                        onTap: () => _exportCsv(context),
                      ),
                    ],
                  ),
                  const CardHeading('App'),
                  _Group(
                    children: [
                      _Row(
                        icon: Icons.dns_outlined,
                        label: 'Server address',
                        value: Uri.tryParse(session.serverUrl)?.host,
                        onTap: () => showServerSettings(context),
                      ),
                    ],
                  ),
                  if (s != null) ...[
                    const SizedBox(height: 22),
                    _Group(
                      children: [
                        _Row(
                          icon: Icons.logout_rounded,
                          label: 'Sign out',
                          danger: true,
                          onTap: () async {
                            final ok = await _confirm(
                              context,
                              title: 'Sign out?',
                              message:
                                  'This phone goes back to a fresh offline '
                                  'tracker. Your family’s data stays on the '
                                  'server.',
                              action: 'Sign Out',
                              danger: true,
                            );
                            if (ok) await session.logout();
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every entry as a CSV file, opened in the share sheet.
Future<void> _exportCsv(BuildContext context) async {
  final finance = context.read<FinanceProvider>();
  final family = context.read<FamilyProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final items = [...finance.all]..sort((a, b) => b.date.compareTo(a.date));
  if (items.isEmpty) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Nothing to export yet')));
    return;
  }
  String cell(String v) => '"${v.replaceAll('"', '""')}"';
  final rows = [
    'Date,Title,Type,Category,Amount,Person,Payment,Note',
    for (final t in items)
      [
        DateFormat('yyyy-MM-dd HH:mm').format(t.date),
        cell(t.title),
        t.isExpense ? 'Expense' : 'Income',
        cell(Category.byId(t.categoryId).name),
        t.amount.toStringAsFixed(2),
        cell(family.memberFor(t.memberId).name),
        cell(t.paymentMethod?.label ?? ''),
        cell(t.note),
      ].join(','),
  ];
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/familytrack-export.csv');
  await file.writeAsString(rows.join('\n'));
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]),
  );
}

Future<void> _editName(BuildContext context) async {
  final session = context.read<SessionProvider>();
  final family = context.read<FamilyProvider>();
  final controller = TextEditingController(text: session.session?.name);
  await showFormSheet(
    context,
    title: 'Your name',
    subtitle: 'Shown to your family on everything you add.',
    child: _SheetForm(
      fields: [
        TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: sheetInputDecoration(hint: 'e.g. Muminu'),
        ),
      ],
      label: 'Save',
      onSave: () async {
        final name = controller.text.trim();
        if (name.isEmpty) return 'Enter a name';
        await session.updateName(name);
        // Offline, the phone's own member carries the name.
        if (!session.linked) {
          await family.editMember(family.owner.copyWith(name: name));
        }
        return null;
      },
    ),
  );
  controller.dispose();
}

Future<void> _changePassword(BuildContext context) async {
  final session = context.read<SessionProvider>();
  final current = TextEditingController();
  final next = TextEditingController();
  await showFormSheet(
    context,
    title: 'Change password',
    subtitle: 'At least 8 characters.',
    child: _SheetForm(
      fields: [
        TextField(
          controller: current,
          obscureText: true,
          autofocus: true,
          decoration: sheetInputDecoration(hint: 'Current password'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: next,
          obscureText: true,
          decoration: sheetInputDecoration(hint: 'New password'),
        ),
      ],
      label: 'Update Password',
      onSave: () async {
        if (next.text.length < 8) return 'Use at least 8 characters';
        await session.changePassword(current.text, next.text);
        return null;
      },
      done: 'Password updated',
    ),
  );
  current.dispose();
  next.dispose();
}

Future<void> _renameFamily(BuildContext context, LinkedGroup group) async {
  final session = context.read<SessionProvider>();
  final controller = TextEditingController(text: group.name);
  await showFormSheet(
    context,
    title: 'Family name',
    subtitle: 'Everyone in the family sees the new name.',
    child: _SheetForm(
      fields: [
        TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: sheetInputDecoration(hint: 'e.g. Hoque Family'),
        ),
      ],
      label: 'Save',
      onSave: () async {
        final name = controller.text.trim();
        if (name.isEmpty) return 'Enter a name';
        await session.renameGroup(name);
        return null;
      },
    ),
  );
  controller.dispose();
}

/// Fields, an inline error and a save button; closes the sheet on success.
class _SheetForm extends StatefulWidget {
  const _SheetForm({
    required this.fields,
    required this.label,
    required this.onSave,
    this.done,
  });

  final List<Widget> fields;
  final String label;

  /// Returns an error to show, or null when saved.
  final Future<String?> Function() onSave;

  /// Snack bar shown after saving, if any.
  final String? done;

  @override
  State<_SheetForm> createState() => _SheetFormState();
}

class _SheetFormState extends State<_SheetForm> {
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      error = await widget.onSave();
    } on ApiException catch (e) {
      error = e.message;
    }
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (widget.done != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(widget.done!)));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ...widget.fields,
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(
          _error!,
          style: const TextStyle(fontSize: 12, color: AppColors.expenseRed),
        ),
      ],
      const SizedBox(height: 24),
      SheetPrimaryButton(label: widget.label, busy: _busy, onPressed: _save),
    ],
  );
}

/// Initial in a mint circle, with a small pencil to edit the name.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.onEdit});

  final String name;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onEdit,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 84,
          height: 84,
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
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AppColors.tealDark,
            ),
          ),
        ),
        if (onEdit != null)
          Positioned(
            right: -2,
            bottom: 2,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider),
              ),
              child: const Icon(
                Icons.edit_rounded,
                size: 14,
                color: AppColors.forest,
              ),
            ),
          ),
      ],
    ),
  );
}

/// A family member: avatar, name and role; opens their page.
class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.you, this.onTap});

  final FamilyMember member;
  final bool you;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          children: [
            MemberAvatar(member, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                you ? '${member.name} (you)' : member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (member.isOwner)
              const Text(
                'Owner',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    ),
  );
}

/// White block of settings rows with dividers, like Home's activity blocks.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 62, color: AppColors.divider),
            children[i],
          ],
        ],
      ),
    ),
  );
}

/// Icon circle, label, optional value or badge, and a chevron when tappable.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.value,
    this.badge = 0,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final int badge;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.expenseRed : AppColors.textPrimary;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: danger ? AppColors.redTint : AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: danger ? AppColors.expenseRed : AppColors.forest,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value ?? '',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.lime,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              if (onTap != null && !danger) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: AppColors.textMuted,
                ),
              ],
            ],
          ),
        ),
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

/// White card with the family name, the invite code and sync state.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final LinkedGroup group;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final offline = session.syncError != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${group.memberCount} '
                '${group.memberCount == 1 ? 'member' : 'members'}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Invite code',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  group.inviteCode,
                  style: const TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontFamilyFallback: AppTheme.displayFallback,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: AppColors.forest,
                  ),
                ),
              ),
              MintPill(
                label: 'Copy',
                icon: Icons.copy_rounded,
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              color: offline ? AppColors.orangeTint : AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  offline ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                  size: 16,
                  color: offline ? AppColors.orange : AppColors.forest,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.syncStatus,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: session.syncing ? null : session.sync,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.tealDark,
                  ),
                  child: Text(
                    session.syncing ? 'Syncing…' : 'Sync now',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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

/// Owner: rename and reset the code. Everyone else: leave.
class _GroupActions extends StatelessWidget {
  const _GroupActions({required this.group});

  final LinkedGroup group;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionProvider>();
    if (!group.isOwner) {
      return _Group(
        children: [
          _Row(
            icon: Icons.exit_to_app_rounded,
            label: 'Leave family',
            danger: true,
            onTap: () async {
              final ok = await _confirm(
                context,
                title: 'Leave ${group.name}?',
                message:
                    'Your spending stays with the family. This phone goes '
                    'back to a fresh offline tracker.',
                action: 'Leave',
                danger: true,
              );
              if (ok && context.mounted) {
                await _attempt(context, session.leaveGroup);
              }
            },
          ),
        ],
      );
    }
    return _Group(
      children: [
        _Row(
          icon: Icons.edit_outlined,
          label: 'Rename family',
          onTap: () => _renameFamily(context, group),
        ),
        _Row(
          icon: Icons.refresh_rounded,
          label: 'Reset invite code',
          onTap: () async {
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
        ),
      ],
    );
  }
}
