import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Photos kept in the app's own folders: receipts (one per transaction) and
/// plan covers (one per plan).
class PhotoStore {
  PhotoStore._();

  /// Set in tests to avoid the platform's documents folder.
  @visibleForTesting
  static Directory? directoryOverride;

  static Future<Directory> _base() async =>
      directoryOverride ?? await getApplicationDocumentsDirectory();

  static Future<Directory> _dir(String folder) async {
    final base = await _base();
    return Directory(p.join(base.path, folder)).create(recursive: true);
  }

  /// Covers picked before they synced lived in `plan_covers`, named
  /// `<planId>.<time>.jpg`. Empty once they've been imported.
  static Future<List<File>> legacyPlanCovers() async {
    final dir = Directory(p.join((await _base()).path, 'plan_covers'));
    if (!await dir.exists()) return const [];
    return dir.list().where((e) => e is File).cast<File>().toList();
  }

  static Future<void> deleteLegacyPlanCovers() async {
    final dir = Directory(p.join((await _base()).path, 'plan_covers'));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Copies [source] in as the photo for [transactionId] (or plan id for
  /// covers); returns its path.
  /// A fresh file name each time so image caches never show a stale photo.
  static Future<String> save(
    String transactionId,
    File source, {
    String folder = 'receipts',
  }) async {
    final dir = await _dir(folder);
    await _removeFor(dir, transactionId);
    final name = '$transactionId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File(p.join(dir.path, name));
    await source.copy(dest.path);
    return dest.path;
  }

  /// Stores downloaded bytes as the photo for [transactionId].
  static Future<String> saveBytes(
    String transactionId,
    Uint8List bytes, {
    String folder = 'receipts',
  }) async {
    final dir = await _dir(folder);
    await _removeFor(dir, transactionId);
    final name = '$transactionId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File(p.join(dir.path, name));
    await dest.writeAsBytes(bytes, flush: true);
    return dest.path;
  }

  static Future<void> delete(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  static Future<void> deleteAll() async {
    for (final folder in ['receipts', 'covers']) {
      final dir = await _dir(folder);
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  }

  /// Deletes every file whose path isn't in [keep].
  static Future<void> prune(
    Set<String> keep, {
    String folder = 'receipts',
  }) async {
    final dir = await _dir(folder);
    await for (final e in dir.list()) {
      if (e is File && !keep.contains(e.path)) await e.delete();
    }
  }

  static Future<void> _removeFor(Directory dir, String id) async {
    await for (final e in dir.list()) {
      if (e is File && p.basename(e.path).startsWith('$id-')) await e.delete();
    }
  }
}
