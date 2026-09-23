import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/zakat_record.dart';
import '../../models/hawl_item.dart';
import '../../models/favorite_item.dart';
import '../database/local_db_service.dart';
import '../database/preferences_service.dart';
import 'encryption_service.dart';

class BackupService {
  /// Exports an encrypted backup payload of all user records, hawls, and favorites
  static Future<String> generateEncryptedBackupPayload() async {
    final records = LocalDbService.getAllZakatRecords(filterByUser: false);
    final hawls = LocalDbService.getAllHawlItems();
    final favorites = LocalDbService.getAllFavorites();

    final backupData = {
      'app': 'ZakatApp',
      'version': '2.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'currency': PreferencesService.currency,
      'marketCity': PreferencesService.marketCity,
      'records': records.map((r) => r.toMap()).toList(),
      'hawls': hawls.map((h) => h.toMap()).toList(),
      'favorites': favorites.map((f) => f.toMap()).toList(),
    };

    final rawJson = jsonEncode(backupData);
    final masterKey = await EncryptionService.getMasterKey();
    return EncryptionService.encryptString(rawJson, masterKey);
  }

  /// Saves backup payload to a local file and returns the file path
  static Future<String?> exportBackupToFile() async {
    try {
      final encryptedPayload = await generateEncryptedBackupPayload();
      final bytes = utf8.encode(encryptedPayload);

      Directory? dir;
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          dir = downloadDir;
        } else {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      dir ??= await getApplicationDocumentsDirectory();
      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'zakat_backup_$dateStr.zakatbackup';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      return file.path;
    } catch (e) {
      debugPrint('Error exporting backup to file: $e');
      return null;
    }
  }

  /// Shares backup payload via system share dialog (WhatsApp, Drive, Email, etc.)
  static Future<void> shareBackup() async {
    final filePath = await exportBackupToFile();
    if (filePath != null) {
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'نسخة احتياطية مشفرة - تطبيق زكاتي',
        text: 'مرفق ملف النسخة الاحتياطية المشفرة لسجلات وأحوال الزكاة.',
      );
    } else {
      final payload = await generateEncryptedBackupPayload();
      await Share.share(
        payload,
        subject: 'كود النسخة الاحتياطية المشفرة - تطبيق زكاتي',
      );
    }
  }

  /// Restores data from encrypted payload string or file content
  static Future<({int recordsRestored, int hawlsRestored, int favoritesRestored})> restoreFromPayload(String payload) async {
    final masterKey = await EncryptionService.getMasterKey();
    final decryptedJson = EncryptionService.decryptString(payload.trim(), masterKey);

    Map<String, dynamic> data;
    try {
      data = jsonDecode(decryptedJson) as Map<String, dynamic>;
    } catch (e) {
      throw const FormatException('فشل فك تشفير النسخة الاحتياطية أو صيغة الملف غير صالحة.');
    }

    if (data['app'] != 'ZakatApp') {
      throw const FormatException('هذا الملف لا يخص تطبيق زكاتي.');
    }

    int recordsCount = 0;
    int hawlsCount = 0;
    int favoritesCount = 0;

    // Restore Zakat Records
    if (data['records'] is List) {
      for (final item in data['records'] as List) {
        if (item is Map) {
          final record = ZakatRecord.fromMap(item);
          await LocalDbService.saveZakatRecord(record);
          recordsCount++;
        }
      }
    }

    // Restore Hawl Items
    if (data['hawls'] is List) {
      for (final item in data['hawls'] as List) {
        if (item is Map) {
          final hawl = HawlItem.fromMap(item);
          await LocalDbService.saveHawlItem(hawl);
          hawlsCount++;
        }
      }
    }

    // Restore Favorites
    if (data['favorites'] is List) {
      for (final item in data['favorites'] as List) {
        if (item is Map) {
          final fav = FavoriteItem.fromMap(item);
          await LocalDbService.saveFavorite(fav);
          favoritesCount++;
        }
      }
    }

    return (
      recordsRestored: recordsCount,
      hawlsRestored: hawlsCount,
      favoritesRestored: favoritesCount,
    );
  }
}
