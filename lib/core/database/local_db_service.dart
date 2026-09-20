import 'dart:typed_data';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/zakat_record.dart';
import '../../models/favorite_item.dart';
import '../../models/assistance_request.dart';
import '../services/auth_service.dart';
import '../services/encryption_service.dart';

class LocalDbService {
  static const String zakatRecordsBoxName = 'zakat_records_box';
  static const String favoritesBoxName = 'favorites_box';
  static const String assistanceRequestsBoxName = 'assistance_requests_box';

  static Box? _zakatBox;
  static Box? _favoritesBox;
  static Box? _requestsBox;

  static Future<void> init() async {
    try {
      await Hive.initFlutter();
    } catch (_) {
      // In test environments, Hive.init(tempDir) is used
    }
    await _ensureZakatBoxOpen();
    _favoritesBox = await Hive.openBox(favoritesBoxName);
    await _ensureRequestsBoxOpen();
    await applyDataRetentionPolicy();
  }

  static Future<void> _ensureZakatBoxOpen() async {
    if (_zakatBox != null && _zakatBox!.isOpen) return;
    if (Hive.isBoxOpen(zakatRecordsBoxName)) {
      _zakatBox = Hive.box(zakatRecordsBoxName);
      return;
    }
    try {
      final cipher = await EncryptionService.getHiveCipher();
      _zakatBox = await Hive.openBox(zakatRecordsBoxName, encryptionCipher: cipher);
    } catch (_) {
      _zakatBox = await Hive.openBox(zakatRecordsBoxName);
    }
  }

  static Future<void> _ensureRequestsBoxOpen() async {
    if (_requestsBox != null && _requestsBox!.isOpen) return;
    if (Hive.isBoxOpen(assistanceRequestsBoxName)) {
      _requestsBox = Hive.box(assistanceRequestsBoxName);
      return;
    }
    try {
      final cipher = await EncryptionService.getHiveCipher();
      _requestsBox = await Hive.openBox(assistanceRequestsBoxName, encryptionCipher: cipher);
    } catch (_) {
      _requestsBox = await Hive.openBox(assistanceRequestsBoxName);
    }
  }

  // --- ZAKAT RECORDS ---
  static Future<void> saveZakatRecord(ZakatRecord record) async {
    if (_zakatBox == null || !_zakatBox!.isOpen) {
      await _ensureZakatBoxOpen();
    }
    final recordToSave = (record.userId == null && AuthService.currentUser?.id != null)
        ? record.copyWith(userId: AuthService.currentUser?.id)
        : record;
    await _zakatBox?.put(recordToSave.id, recordToSave.toMap());
  }

  static List<ZakatRecord> getAllZakatRecords({String? userId, bool filterByUser = true}) {
    if (_zakatBox == null) {
      if (Hive.isBoxOpen(zakatRecordsBoxName)) {
        _zakatBox = Hive.box(zakatRecordsBoxName);
      } else {
        return [];
      }
    }
    final list = <ZakatRecord>[];
    for (var key in _zakatBox!.keys) {
      final data = _zakatBox!.get(key);
      if (data != null && data is Map) {
        list.add(ZakatRecord.fromMap(data));
      }
    }
    list.sort((a, b) => b.date.compareTo(a.date));

    if (!filterByUser) return list;

    final currentUserId = userId ?? AuthService.currentUser?.id;
    if (currentUserId != null) {
      return list.where((r) => r.userId == currentUserId).toList();
    }
    return list.where((r) => r.userId == null).toList();
  }

  static Future<void> deleteZakatRecord(String id) async {
    await _zakatBox?.delete(id);
  }

  static Future<void> clearAllZakatRecords() async {
    await _zakatBox?.clear();
  }

  // --- FAVORITES ---
  static Future<void> saveFavorite(FavoriteItem item) async {
    if (_favoritesBox == null && Hive.isBoxOpen(favoritesBoxName)) {
      _favoritesBox = Hive.box(favoritesBoxName);
    }
    await _favoritesBox?.put(item.id, item.toMap());
  }

  static Future<void> removeFavorite(String id) async {
    await _favoritesBox?.delete(id);
  }

  static bool isFavorite(String id) {
    if (_favoritesBox == null) {
      if (Hive.isBoxOpen(favoritesBoxName)) {
        _favoritesBox = Hive.box(favoritesBoxName);
      } else {
        return false;
      }
    }
    return _favoritesBox!.containsKey(id);
  }

  static List<FavoriteItem> getAllFavorites() {
    if (_favoritesBox == null) {
      if (Hive.isBoxOpen(favoritesBoxName)) {
        _favoritesBox = Hive.box(favoritesBoxName);
      } else {
        return [];
      }
    }
    final list = <FavoriteItem>[];
    for (var key in _favoritesBox!.keys) {
      final data = _favoritesBox!.get(key);
      if (data != null && data is Map) {
        list.add(FavoriteItem.fromMap(data));
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // --- ASSISTANCE REQUESTS ---
  static Future<void> saveAssistanceRequest(AssistanceRequest request) async {
    await _ensureRequestsBoxOpen();
    final key = await EncryptionService.getMasterKey();
    final map = request.toMap(encryptionKey: key);
    await _requestsBox?.put(request.id, map);
  }

  static List<AssistanceRequest> getAllAssistanceRequests({Uint8List? key}) {
    if (_requestsBox == null) {
      if (Hive.isBoxOpen(assistanceRequestsBoxName)) {
        _requestsBox = Hive.box(assistanceRequestsBoxName);
      } else {
        return [];
      }
    }
    final list = <AssistanceRequest>[];
    for (var boxKey in _requestsBox!.keys) {
      final data = _requestsBox!.get(boxKey);
      if (data != null && data is Map) {
        list.add(AssistanceRequest.fromMap(data, encryptionKey: key));
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<List<AssistanceRequest>> getAllAssistanceRequestsDecrypted() async {
    await _ensureRequestsBoxOpen();
    final key = await EncryptionService.getMasterKey();
    return getAllAssistanceRequests(key: key);
  }

  static Future<void> deleteAssistanceRequest(String id) async {
    await _ensureRequestsBoxOpen();
    await _requestsBox?.delete(id);
  }

  /// Complete deletion and purge of all assistance requests and sensitive data
  static Future<void> deleteAllAssistanceRequestsAndPurgeSensitiveData() async {
    await _ensureRequestsBoxOpen();
    await _requestsBox?.clear();
    EncryptionService.purgeKey();
  }

  /// Data retention policy: Automatically purges assistance requests and sensitive data
  /// older than maxAge (default: 30 days) to minimize sensitive data exposure.
  static Future<int> applyDataRetentionPolicy({Duration maxAge = const Duration(days: 30)}) async {
    await _ensureRequestsBoxOpen();
    if (_requestsBox == null) return 0;

    final now = DateTime.now();
    final keysToDelete = <dynamic>[];

    for (var key in _requestsBox!.keys) {
      final data = _requestsBox!.get(key);
      if (data != null && data is Map) {
        final createdAtStr = data['createdAt']?.toString();
        if (createdAtStr != null) {
          final createdAt = DateTime.tryParse(createdAtStr);
          if (createdAt != null && now.difference(createdAt) > maxAge) {
            keysToDelete.add(key);
          }
        }
      }
    }

    for (var k in keysToDelete) {
      await _requestsBox!.delete(k);
    }

    return keysToDelete.length;
  }
}

