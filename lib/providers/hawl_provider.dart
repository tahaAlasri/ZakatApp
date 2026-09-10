import 'package:flutter/material.dart';
import '../core/database/preferences_service.dart';

class HawlProvider extends ChangeNotifier {
  DateTime? _startDate;

  DateTime? get startDate => _startDate;

  HawlProvider() {
    _loadHawlDate();
  }

  void _loadHawlDate() {
    final saved = PreferencesService.hawlStartDate;
    if (saved != null) {
      _startDate = DateTime.tryParse(saved);
    }
  }

  // Lunar Hijri Year is approximately 354 days
  static const int lunarYearDays = 354;

  int get daysPassed {
    if (_startDate == null) return 0;
    final diff = DateTime.now().difference(_startDate!).inDays;
    return diff < 0 ? 0 : diff;
  }

  int get daysRemaining {
    if (_startDate == null) return lunarYearDays;
    final remaining = lunarYearDays - daysPassed;
    return remaining < 0 ? 0 : remaining;
  }

  double get progressPercentage {
    if (_startDate == null) return 0.0;
    final progress = daysPassed / lunarYearDays;
    return progress > 1.0 ? 1.0 : progress;
  }

  bool get isHawlCompleted {
    return _startDate != null && daysRemaining <= 0;
  }

  DateTime? get expectedDueDate {
    if (_startDate == null) return null;
    return _startDate!.add(const Duration(days: lunarYearDays));
  }

  Future<void> setHawlStartDate(DateTime date) async {
    _startDate = date;
    await PreferencesService.setHawlStartDate(date.toIso8601String());
    notifyListeners();
  }

  Future<void> resetHawl() async {
    _startDate = null;
    await PreferencesService.setHawlStartDate(null);
    notifyListeners();
  }
}
