import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'models.dart';

/// Everything the user entered, as one JSON document. The server URL and app token are
/// left out on purpose: the token is a secret and the URL is per-device.
class Backup {
  static const appId = 'grow_buddy';
  static const currentVersion = 1;

  final List<MyPlant> plants;
  final List<Sale> sales;
  final double sunHours;
  final String exportedAt;

  Backup({required this.plants, required this.sales, required this.sunHours, String? exportedAt})
      : exportedAt = exportedAt ?? DateTime.now().toIso8601String();

  String get fileName => 'grow-buddy-backup-${exportedAt.substring(0, 10)}.json';

  String encode() => const JsonEncoder.withIndent('  ').convert({
        'app': appId,
        'version': currentVersion,
        'exportedAt': exportedAt,
        'sunHours': sunHours,
        'plants': plants.map((p) => p.toJson()).toList(),
        'sales': sales.map((s) => s.toJson()).toList(),
      });

  /// Throws [FormatException] with a message that is fine to show the user.
  factory Backup.decode(String raw) {
    final Object? doc;
    try {
      doc = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('That file is not valid JSON.');
    }
    if (doc is! Map<String, dynamic> || doc['app'] != appId) {
      throw const FormatException('That file is not a Grow Buddy backup.');
    }
    final version = doc['version'];
    if (version is! int || version > currentVersion) {
      throw const FormatException('This backup is from a newer Grow Buddy. Update the app first.');
    }
    try {
      return Backup(
        plants: (doc['plants'] as List)
            .map((e) => MyPlant.fromJson(e as Map<String, dynamic>))
            .toList(),
        sales: (doc['sales'] as List)
            .map((e) => Sale.fromJson(e as Map<String, dynamic>))
            .toList(),
        sunHours: (doc['sunHours'] as num?)?.toDouble() ?? 4,
        exportedAt: doc['exportedAt'] as String?,
      );
    } on TypeError {
      throw const FormatException('The backup file is damaged or incomplete.');
    }
  }
}

/// File access for backups, behind an interface so tests can swap it out.
abstract class BackupIo {
  static BackupIo current = FilePickerBackupIo();

  /// Returns false if the user cancelled.
  Future<bool> save(String fileName, String text);

  /// Returns the picked file's text, or null if the user cancelled.
  Future<String?> pickText();
}

class FilePickerBackupIo implements BackupIo {
  @override
  Future<bool> save(String fileName, String text) async {
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(text)),
      mimeType: 'application/json',
      dialogTitle: 'Save Grow Buddy backup',
    );
    // The web build downloads straight away and always returns null.
    return kIsWeb || saved != null;
  }

  @override
  Future<String?> pickText() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      dialogTitle: 'Choose a Grow Buddy backup',
    );
    if (file == null) return null;
    return utf8.decode(await file.readAsBytes());
  }
}
