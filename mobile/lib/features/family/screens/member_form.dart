import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:finance_tracker/features/family/models/family_member.dart';
import 'package:finance_tracker/features/family/providers/family_provider.dart';
import 'package:finance_tracker/core/widgets/form_sheet.dart';
import 'package:finance_tracker/features/family/widgets/member_avatar.dart';

Future<void> showMemberForm(BuildContext context, {FamilyMember? existing}) =>
    showFormSheet(
      context,
      title: existing == null ? 'Add member' : 'Edit member',
      subtitle: 'Members share the family budget and spending.',
      child: _MemberForm(existing: existing),
    );

class _MemberForm extends StatefulWidget {
  const _MemberForm({this.existing});

  final FamilyMember? existing;

  @override
  State<_MemberForm> createState() => _MemberFormState();
}

class _MemberFormState extends State<_MemberForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late Color _color;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name);
    // New members get the next unused color so avatars stay distinct.
    final count = context.read<FamilyProvider>().members.length;
    _color =
        e?.color ?? FamilyMember.palette[count % FamilyMember.palette.length];
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<FamilyProvider>();
    final e = widget.existing;
    final name = _name.text.trim();
    e == null
        ? await provider.addMember(FamilyMember(name: name, color: _color))
        : await provider.editMember(e.copyWith(name: name, color: _color));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Live preview of the avatar as the name and color change.
    final preview = FamilyMember(
      name: _name.text.isEmpty ? '?' : _name.text,
      color: _color,
    );
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: MemberAvatar(preview, size: 76)),
          const SizedBox(height: 24),
          const SheetLabel('Name'),
          TextFormField(
            controller: _name,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: sheetInputDecoration(hint: 'e.g. Maria'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
          ),
          const SizedBox(height: 22),
          const SheetLabel('Color'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in FamilyMember.palette)
                _ColorDot(
                  color: c,
                  selected: c == _color,
                  onTap: () => setState(() => _color = c),
                ),
            ],
          ),
          const SizedBox(height: 28),
          SheetPrimaryButton(
            label: widget.existing == null ? 'Add Member' : 'Save Changes',
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 42,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }
}
