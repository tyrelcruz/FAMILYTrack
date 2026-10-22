import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:finance_tracker/core/theme/app_colors.dart';

/// What the user chose in [chooseReceiptPhoto].
sealed class PhotoChoice {
  const PhotoChoice();
}

class PhotoPicked extends PhotoChoice {
  const PhotoPicked(this.file);

  final File file;
}

class PhotoRemoved extends PhotoChoice {
  const PhotoRemoved();
}

/// Asks camera or gallery (or remove, when there's already a photo) and
/// returns the choice; null if cancelled. Photos are shrunk to keep uploads
/// small.
Future<PhotoChoice?> chooseReceiptPhoto(
  BuildContext context, {
  bool canRemove = false,
}) async {
  final choice = await showModalBottomSheet<Object>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            _Option(
              icon: Icons.photo_camera_outlined,
              label: 'Take a photo',
              onTap: () => Navigator.pop(sheet, ImageSource.camera),
            ),
            _Option(
              icon: Icons.photo_library_outlined,
              label: 'Choose from gallery',
              onTap: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
            if (canRemove)
              _Option(
                icon: Icons.delete_outline_rounded,
                label: 'Remove photo',
                color: AppColors.expenseRed,
                onTap: () => Navigator.pop(sheet, 'remove'),
              ),
          ],
        ),
      ),
    ),
  );
  if (choice == 'remove') return const PhotoRemoved();
  if (choice is! ImageSource) return null;
  if (!context.mounted) return null;
  try {
    final shot = await ImagePicker().pickImage(
      source: choice,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    return shot == null ? null : PhotoPicked(File(shot.path));
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              choice == ImageSource.camera
                  ? 'Couldn’t open the camera. Check the app’s camera permission.'
                  : 'Couldn’t open your photos. Check the app’s photo permission.',
            ),
          ),
        );
    }
    return null;
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color == AppColors.textPrimary
            ? AppColors.blueTint
            : AppColors.redTint,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color == AppColors.textPrimary ? AppColors.blue : color,
      ),
    ),
    title: Text(
      label,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
    ),
    onTap: onTap,
  );
}

/// Rounded thumbnail; tap opens the full photo. When the photo exists on the
/// server but hasn't been downloaded yet, shows a placeholder.
class ReceiptThumb extends StatelessWidget {
  const ReceiptThumb({
    super.key,
    required this.path,
    this.size = 84,
    this.onTap,
  });

  final String? path;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final file = path == null ? null : File(path!);
    final ok = file != null && file.existsSync();
    return GestureDetector(
      onTap: ok ? (onTap ?? () => openReceiptPhoto(context, path!)) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: size,
          height: size,
          child: ok
              ? Image.file(file, fit: BoxFit.cover)
              : const ColoredBox(
                  color: AppColors.neutralTint,
                  child: Icon(
                    Icons.cloud_download_outlined,
                    color: AppColors.textMuted,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Full-screen photo with pinch to zoom.
void openReceiptPhoto(BuildContext context, String path) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Receipt'),
        ),
        body: Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.file(File(path), fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}

/// "Add a photo" row, or the chosen photo with change / remove actions.
/// Used where a photo is picked before the transaction exists.
class ReceiptField extends StatelessWidget {
  const ReceiptField({
    super.key,
    required this.path,
    required this.onChanged,
    this.compact = false,
  });

  final String? path;

  /// Called with a new file, or null when removed.
  final ValueChanged<File?> onChanged;

  /// Shorter, for the quick-add sheet.
  final bool compact;

  Future<void> _tap(BuildContext context) async {
    final choice = await chooseReceiptPhoto(context, canRemove: path != null);
    switch (choice) {
      case PhotoPicked(:final file):
        onChanged(file);
      case PhotoRemoved():
        onChanged(null);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = path != null;
    return Material(
      color: const Color(0xFFF4F4FA),
      borderRadius: BorderRadius.circular(compact ? 18 : 22),
      child: InkWell(
        onTap: () => _tap(context),
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        child: Padding(
          padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 10, 14, 10),
          child: Row(
            children: [
              if (has)
                ReceiptThumb(path: path, size: compact ? 40 : 52)
              else
                Container(
                  width: compact ? 40 : 52,
                  height: compact ? 40 : 52,
                  decoration: BoxDecoration(
                    color: AppColors.blueTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_outlined,
                    color: AppColors.blue,
                    size: 21,
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  has ? 'Photo attached' : 'Add a photo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: has ? FontWeight.w600 : FontWeight.w500,
                    color: has
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              if (has)
                IconButton(
                  tooltip: 'Remove photo',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textMuted,
                  onPressed: () => onChanged(null),
                )
              else
                const Text(
                  'Receipt or item',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
