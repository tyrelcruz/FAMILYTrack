import 'package:finance_tracker/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The two ways to add someone, spelled out: invite a person who has their
/// own phone, or track spending for someone without an account.
class AddPeopleCard extends StatelessWidget {
  const AddPeopleCard({
    super.key,
    required this.inviteCode,
    required this.onSetUpSync,
    required this.onAddWithoutAccount,
  });

  /// Null until this phone is signed in and in a synced family.
  final String? inviteCode;
  final VoidCallback onSetUpSync;
  final VoidCallback onAddWithoutAccount;

  @override
  Widget build(BuildContext context) {
    final code = inviteCode;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          _Option(
            icon: Icons.qr_code_2_rounded,
            color: AppColors.blue,
            tint: AppColors.blueTint,
            title: 'Invite with a code',
            subtitle: code == null
                ? 'For people with their own phone. Sign in first to get a code.'
                : 'They sign up and enter this code on their own phone.',
            trailing: code == null
                ? _PillButton(label: 'Set up', onTap: onSetUpSync)
                : _CodeButton(code: code),
            onTap: code == null ? onSetUpSync : null,
          ),
          const Divider(height: 1, indent: 60, color: AppColors.divider),
          _Option(
            icon: Icons.child_care_rounded,
            color: AppColors.purple,
            tint: AppColors.purpleTint,
            title: 'Add without an account',
            subtitle: 'For kids or anyone you track spending for.',
            trailing: _PillButton(label: 'Add', onTap: onAddWithoutAccount),
            onTap: onAddWithoutAccount,
          ),
        ],
      ),
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
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing,
        ],
      ),
    ),
  );
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.textPrimary,
    shape: const StadiumBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

/// The invite code itself; tap to copy.
class _CodeButton extends StatelessWidget {
  const _CodeButton({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.blueTint,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Invite code $code copied')));
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              code,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.copy_rounded, size: 15, color: AppColors.blue),
          ],
        ),
      ),
    ),
  );
}
