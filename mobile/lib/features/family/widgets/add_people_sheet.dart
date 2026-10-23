import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/core/widgets/form_sheet.dart';
import 'package:finance_tracker/features/account/providers/session_provider.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/features/family/widgets/member_avatar.dart';

/// Add friends or relatives right where they're needed (e.g. a plan's
/// "Who's going"): by name, from the phone's contacts, or by sharing the
/// family invite code. Returns the ids of people added.
Future<List<String>> showAddPeopleSheet(
  BuildContext context, {
  String title = 'Add people',
}) async {
  final added = <String>[];
  await showFormSheet(
    context,
    title: title,
    subtitle: 'Friends, family or anyone you split costs with.',
    child: _AddPeople(onAdded: added.add),
  );
  return added;
}

class _AddPeople extends StatefulWidget {
  const _AddPeople({required this.onAdded});

  final ValueChanged<String> onAdded;

  @override
  State<_AddPeople> createState() => _AddPeopleState();
}

class _AddPeopleState extends State<_AddPeople> {
  final _name = TextEditingController();
  final _added = <FamilyMember>[];
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add(String raw) async {
    final name = raw.trim();
    if (name.isEmpty || _busy) return;
    final family = context.read<FamilyProvider>();
    // Someone already in the family is just picked, not added twice.
    for (final m in family.members) {
      if (m.name.toLowerCase() == name.toLowerCase()) {
        widget.onAdded(m.id!);
        setState(() => _added.add(m));
        _name.clear();
        return;
      }
    }
    setState(() => _busy = true);
    final member = FamilyMember(
      name: name,
      color: FamilyMember
          .palette[family.members.length % FamilyMember.palette.length],
    );
    final id = await family.addMember(member);
    widget.onAdded(id);
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() {
      _added.add(family.memberFor(id));
      _busy = false;
    });
    _name.clear();
  }

  Future<void> _fromContacts() async {
    try {
      // The system picker needs no contacts permission; we only read the
      // chosen person's name.
      final contact = await FlutterContacts.native.showPicker();
      final name = contact?.displayName;
      if (name != null && name.trim().isNotEmpty) await _add(name);
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t open your contacts.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = context.watch<SessionProvider>().group?.inviteCode;
    const fieldStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetLabel('Add by name'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: _add,
                style: fieldStyle,
                decoration: sheetInputDecoration(hint: 'e.g. Tita Bing'),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _busy ? null : () => _add(_name.text),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Add'),
              ),
            ),
          ],
        ),
        if (_added.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _added)
                Chip(
                  avatar: MemberAvatar(m, size: 20.5),
                  label: Text(m.name),
                  backgroundColor: m.color.withValues(alpha: 0.1),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_added.length} added — they’re ticked for this plan.',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: 18),
        _Option(
          icon: Icons.contacts_outlined,
          color: AppColors.green,
          tint: AppColors.greenTint,
          title: 'From your contacts',
          subtitle: 'Pick someone from your phone.',
          onTap: _fromContacts,
        ),
        const SizedBox(height: 10),
        _Option(
          icon: Icons.qr_code_2_rounded,
          color: AppColors.blue,
          tint: AppColors.blueTint,
          title: 'Invite with the family code',
          subtitle: code == null
              ? 'Sign in to get a code.'
              : 'They join on their own phone with code $code.',
          onTap: code == null
              ? null
              : () => SharePlus.instance.share(
                  ShareParams(
                    subject: 'Join our family on familytrack',
                    text:
                        'Join our family on familytrack so we can track '
                        'spending and plan trips together. Sign up, tap '
                        '“Join a family” and enter the code: $code',
                  ),
                ),
          trailing: code == null
              ? null
              : IconButton(
                  tooltip: 'Copy code',
                  icon: const Icon(Icons.copy_rounded, size: 17),
                  color: AppColors.blue,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(content: Text('Invite code $code copied')),
                      );
                  },
                ),
        ),
        const SizedBox(height: 18),
        SheetPrimaryButton(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.color,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
            if (trailing == null && onTap != null)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
