import 'package:hive_flutter/hive_flutter.dart';
import '../../models/zakat_record.dart';
import '../../models/favorite_item.dart';
import '../../models/assistance_request.dart';

class LocalDbService {
  static const String zakatRecordsBoxName = 'zakat_records_box';
  static const String favoritesBoxName = 'favorites_box';
  static const String assistanceRequestsBoxName = 'assistance_requests_box';

  static late Box _zakatBox;
  static late Box _favoritesBox;
  static late Box _requestsBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _zakatBox = await Hive.openBox(zakatRecordsBoxName);
    _favoritesBox = await Hive.openBox(favoritesBoxName);
    _requestsBox = await Hive.openBox(assistanceRequestsBoxName);
  }

  // --- ZAKAT RECORDS ---
  static Future<void> saveZakatRecord(ZakatRecord record) async {
    await _zakatBox.put(record.id, record.toMap());
  }

  static List<ZakatRecord> getAllZakatRecords() {
    final list = <ZakatRecord>[];
    for (var key in _zakatBox.keys) {
      final data = _zakatBox.get(key);
      if (data != null && data is Map) {
        list.add(ZakatRecord.fromMap(data));
      }
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static Future<void> deleteZakatRecord(String id) async {
    await _zakatBox.delete(id);
  }

  static Future<void> clearAllZakatRecords() async {
    await _zakatBox.clear();
  }

  // --- FAVORITES ---
  static Future<void> saveFavorite(FavoriteItem item) async {
    await _favoritesBox.put(item.id, item.toMap());
  }

  static Future<void> removeFavorite(String id) async {
    await _favoritesBox.delete(id);
  }

  static bool isFavorite(String id) {
    return _favoritesBox.containsKey(id);
  }

  static List<FavoriteItem> getAllFavorites() {
    final list = <FavoriteItem>[];
    for (var key in _favoritesBox.keys) {
      final data = _favoritesBox.get(key);
      if (data != null && data is Map) {
        list.add(FavoriteItem.fromMap(data));
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // --- ASSISTANCE REQUESTS ---
  static Future<void> saveAssistanceRequest(AssistanceRequest request) async {
    await _requestsBox.put(request.id, request.toMap());
  }

  static List<AssistanceRequest> getAllAssistanceRequests() {
    final list = <AssistanceRequest>[];
    for (var key in _requestsBox.keys) {
      final data = _requestsBox.get(key);
      if (data != null && data is Map) {
        list.add(AssistanceRequest.fromMap(data));
      }
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<void> deleteAssistanceRequest(String id) async {
    await _requestsBox.delete(id);
  }
}
