import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Receipt photos kept in the app's own folder, one file per transaction.
class PhotoStore {
  PhotoStore._();

  /// Set in tests to avoid the platform's documents folder.
  @visibleForTesting
  static Directory? directoryOverride;

  static Future<Directory> _dir() async {
    final base = directoryOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'receipts'));
    return dir.create(recursive: true);
  }

  /// Copies [source] in as the photo for [transactionId]; returns its path.
  /// A fresh file name each time so image caches never show a stale photo.
  static Future<String> save(String transactionId, File source) async {
    final dir = await _dir();
    await _removeFor(dir, transactionId);
    final name = '$transactionId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = File(p.join(dir.path, name));
    await source.copy(dest.path);
    return dest.path;
  }

  /// Stores downloaded bytes as the photo for [transactionId].
  static Future<String> saveBytes(String transactionId, Uint8List bytes) async {
    final dir = await _dir();
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
    final dir = await _dir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Deletes every file whose path isn't in [keep].
  static Future<void> prune(Set<String> keep) async {
    final dir = await _dir();
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
