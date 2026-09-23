import 'package:flutter/material.dart';
import '../core/database/local_db_service.dart';
import '../core/database/preferences_service.dart';
import '../models/hawl_item.dart';

class HawlProvider extends ChangeNotifier {
  List<HawlItem> _items = [];
  DateTime? _legacyStartDate;

  List<HawlItem> get items => List.unmodifiable(_items);

  static const double _lunarYearDaysExact = 354.37;
  static const int lunarYearDays = 354;
  static const int nearingThresholdDays = 30;

  HawlProvider() {
    _loadHawlData();
  }

  void _loadHawlData() {
    try {
      _items = LocalDbService.getAllHawlItems();
    } catch (_) {
      _items = [];
    }

    final saved = PreferencesService.hawlStartDate;
    if (saved != null) {
      _legacyStartDate = DateTime.tryParse(saved);
      // Auto-migrate legacy date to items if items list is empty
      if (_items.isEmpty && _legacyStartDate != null) {
        final migratedItem = HawlItem(
          id: 'migrated_primary_hawl',
          title: 'الحول الأساسي (النقود والمدخرات)',
          categoryKey: 'money',
          categoryName: 'النقود والمدخرات',
          startDate: _legacyStartDate!,
        );
        _items.add(migratedItem);
        LocalDbService.saveHawlItem(migratedItem);
      }
    }
  }

  /// Returns the nearest active Hawl item, or the first item in the list
  HawlItem? get primaryHawl {
    if (_items.isEmpty) return null;
    // Prefer the active Hawl that is nearest to completion
    final activeItems = _items.where((h) => !h.isHawlCompleted).toList();
    if (activeItems.isNotEmpty) {
      activeItems.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
      return activeItems.first;
    }
    return _items.first;
  }

  DateTime? get startDate => primaryHawl?.startDate ?? _legacyStartDate;

  int get daysPassed {
    if (primaryHawl != null) return primaryHawl!.daysPassed;
    if (_legacyStartDate == null) return 0;
    final diff = DateTime.now().difference(_legacyStartDate!).inDays;
    return diff < 0 ? 0 : diff;
  }

  int get daysRemaining {
    if (primaryHawl != null) return primaryHawl!.daysRemaining;
    if (_legacyStartDate == null) return lunarYearDays;
    final remaining = lunarYearDays - daysPassed;
    return remaining < 0 ? 0 : remaining;
  }

  double get progressPercentage {
    if (primaryHawl != null) return primaryHawl!.progressPercentage;
    if (_legacyStartDate == null) return 0.0;
    final progress = daysPassed / _lunarYearDaysExact;
    return progress > 1.0 ? 1.0 : progress;
  }

  bool get isHawlCompleted {
    if (_items.isNotEmpty) {
      return _items.any((h) => h.isHawlCompleted);
    }
    return _legacyStartDate != null && daysRemaining <= 0;
  }

  bool get isNearingCompletion {
    if (_items.isNotEmpty) {
      return _items.any((h) => h.isNearingCompletion);
    }
    return _legacyStartDate != null &&
        !isHawlCompleted &&
        daysRemaining <= nearingThresholdDays;
  }

  DateTime? get expectedDueDate {
    if (primaryHawl != null) return primaryHawl!.expectedDueDate;
    if (_legacyStartDate == null) return null;
    return _legacyStartDate!.add(const Duration(days: lunarYearDays));
  }

  int get totalHawlsCount => _items.length;
  int get activeHawlsCount => _items.where((h) => !h.isHawlCompleted).length;
  int get completedHawlsCount => _items.where((h) => h.isHawlCompleted).length;

  Future<void> reload() async {
    _loadHawlData();
    notifyListeners();
  }

  Future<void> addHawlItem(HawlItem item) async {
    _items.removeWhere((h) => h.id == item.id);
    _items.add(item);
    _items.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    await LocalDbService.saveHawlItem(item);
    if (_items.isNotEmpty) {
      _legacyStartDate = _items.first.startDate;
      await PreferencesService.setHawlStartDate(_legacyStartDate!.toIso8601String());
    }
    notifyListeners();
  }

  Future<void> updateHawlItem(HawlItem item) async {
    final idx = _items.indexWhere((h) => h.id == item.id);
    if (idx != -1) {
      _items[idx] = item;
    } else {
      _items.add(item);
    }
    _items.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    await LocalDbService.saveHawlItem(item);
    if (_items.isNotEmpty) {
      _legacyStartDate = _items.first.startDate;
      await PreferencesService.setHawlStartDate(_legacyStartDate!.toIso8601String());
    }
    notifyListeners();
  }

  Future<void> deleteHawlItem(String id) async {
    _items.removeWhere((h) => h.id == id);
    await LocalDbService.deleteHawlItem(id);
    if (_items.isNotEmpty) {
      _legacyStartDate = _items.first.startDate;
      await PreferencesService.setHawlStartDate(_legacyStartDate!.toIso8601String());
    } else {
      _legacyStartDate = null;
      await PreferencesService.setHawlStartDate(null);
    }
    notifyListeners();
  }

  Future<void> setHawlStartDate(
    DateTime date, {
    String? title,
    String? categoryKey,
    String? categoryName,
    double? amount,
    String? currency,
    String? notes,
  }) async {
    _legacyStartDate = date;
    await PreferencesService.setHawlStartDate(date.toIso8601String());

    if (_items.isEmpty) {
      final newItem = HawlItem(
        id: 'hawl_${DateTime.now().millisecondsSinceEpoch}',
        title: title ?? 'الحول الأساسي (النقود والمدخرات)',
        categoryKey: categoryKey ?? 'money',
        categoryName: categoryName ?? 'النقود والمدخرات',
        startDate: date,
        estimatedAmount: amount,
        currency: currency,
        notes: notes,
      );
      await addHawlItem(newItem);
    } else {
      final updated = _items.first.copyWith(
        startDate: date,
        title: title,
        categoryKey: categoryKey,
        categoryName: categoryName,
        estimatedAmount: amount,
        currency: currency,
        notes: notes,
      );
      await updateHawlItem(updated);
    }
    notifyListeners();
  }

  Future<void> resetWithNewStartDate(DateTime date, {String? id}) async {
    if (id != null) {
      final idx = _items.indexWhere((h) => h.id == id);
      if (idx != -1) {
        final updated = _items[idx].copyWith(startDate: date);
        await updateHawlItem(updated);
        return;
      }
    }
    if (_items.isNotEmpty) {
      final updated = _items.first.copyWith(startDate: date);
      await updateHawlItem(updated);
    } else {
      await setHawlStartDate(date);
    }
  }

  Future<void> resetHawl([String? id]) async {
    if (id != null) {
      await deleteHawlItem(id);
    } else {
      _items.clear();
      _legacyStartDate = null;
      await LocalDbService.clearAllHawlItems();
      await PreferencesService.setHawlStartDate(null);
      notifyListeners();
    }
  }
}
