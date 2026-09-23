import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/zakat_constants.dart';

class PreferencesService {
  static const String _keyThemeMode = 'app_theme_mode'; // 'light' or 'dark'
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyRememberMe = 'remember_me';
  static const String _keySavedEmail = 'saved_email';
  static const String _keyCurrency = 'selected_currency';
  static const String _keyHawlStartDate = 'hawl_start_date';
  static const String _keyGoldPrice = 'custom_gold_price'; // Gold 24k benchmark
  static const String _keyGold21Price = 'custom_gold_21_price';
  static const String _keyGold18Price = 'custom_gold_18_price';
  static const String _keySilverPrice = 'custom_silver_price';
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyMarketCity = 'market_city';
  static const String _keyLastKnownWheatPrice = 'last_known_wheat_price';
  static const String _keyLastKnownWheatWeight = 'last_known_wheat_weight';
  static const String _keyLastKnownFitrCash = 'last_known_fitr_cash';
  static const String _keyCachedBankAccounts = 'cached_bank_accounts_json';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Theme
  static bool get isDarkMode => _prefs?.getString(_keyThemeMode) == 'dark';
  static Future<void> setDarkMode(bool isDark) async {
    await _prefs?.setString(_keyThemeMode, isDark ? 'dark' : 'light');
  }

  // Onboarding
  static bool get isOnboardingCompleted => _prefs?.getBool(_keyOnboardingCompleted) ?? false;
  static Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs?.setBool(_keyOnboardingCompleted, completed);
  }

  // Biometrics
  static bool get isBiometricEnabled => _prefs?.getBool(_keyBiometricEnabled) ?? false;
  static Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs?.setBool(_keyBiometricEnabled, enabled);
  }

  // Remember me & saved email
  static bool get rememberMe => _prefs?.getBool(_keyRememberMe) ?? false;
  static Future<void> setRememberMe(bool remember) async {
    await _prefs?.setBool(_keyRememberMe, remember);
  }

  static String get savedEmail => _prefs?.getString(_keySavedEmail) ?? '';
  static Future<void> setSavedEmail(String email) async {
    await _prefs?.setString(_keySavedEmail, email);
  }

  // Currency
  static String get currency => _prefs?.getString(_keyCurrency) ?? 'ر.ي';
  static Future<void> setCurrency(String cur) async {
    await _prefs?.setString(_keyCurrency, cur);
  }

  // Hawl Tracker Date
  static String? get hawlStartDate => _prefs?.getString(_keyHawlStartDate);
  static Future<void> setHawlStartDate(String? isoDate) async {
    if (isoDate == null) {
      await _prefs?.remove(_keyHawlStartDate);
    } else {
      await _prefs?.setString(_keyHawlStartDate, isoDate);
    }
  }

  // Gold & Silver Prices
  static double get goldPrice => gold24Price;
  static double get gold24Price => _prefs?.getDouble(_keyGoldPrice) ?? 62850.0;
  static Future<void> setGoldPrice(double price) async {
    await setGold24Price(price);
  }
  static Future<void> setGold24Price(double price) async {
    await _prefs?.setDouble(_keyGoldPrice, price);
  }

  static double get gold21Price => _prefs?.getDouble(_keyGold21Price) ?? (gold24Price * 21 / 24);
  static Future<void> setGold21Price(double price) async {
    await _prefs?.setDouble(_keyGold21Price, price);
  }

  static double get gold18Price => _prefs?.getDouble(_keyGold18Price) ?? (gold24Price * 18 / 24);
  static Future<void> setGold18Price(double price) async {
    await _prefs?.setDouble(_keyGold18Price, price);
  }

  static double get silverPrice => _prefs?.getDouble(_keySilverPrice) ?? 700.0;
  static Future<void> setSilverPrice(double price) async {
    await _prefs?.setDouble(_keySilverPrice, price);
  }

  // Notifications Enabled
  static bool get notificationsEnabled => _prefs?.getBool(_keyNotificationsEnabled) ?? true;
  static Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs?.setBool(_keyNotificationsEnabled, enabled);
  }

  // Market City
  static String get marketCity => _prefs?.getString(_keyMarketCity) ?? 'sanaa';
  static Future<void> setMarketCity(String city) async {
    await _prefs?.setString(_keyMarketCity, city);
  }

  // Wheat & Fitr offline cache
  static double get lastKnownWheatPrice =>
      _prefs?.getDouble(_keyLastKnownWheatPrice) ?? ZakatConstants.defaultWheatBagPriceYER;
  static Future<void> setLastKnownWheatPrice(double price) async {
    await _prefs?.setDouble(_keyLastKnownWheatPrice, price);
  }

  static double get lastKnownWheatWeight =>
      _prefs?.getDouble(_keyLastKnownWheatWeight) ?? ZakatConstants.defaultWheatBagWeightKg;
  static Future<void> setLastKnownWheatWeight(double weight) async {
    await _prefs?.setDouble(_keyLastKnownWheatWeight, weight);
  }

  static double get lastKnownFitrCash =>
      _prefs?.getDouble(_keyLastKnownFitrCash) ?? ZakatConstants.defaultFitrCashYER;
  static Future<void> setLastKnownFitrCash(double cash) async {
    await _prefs?.setDouble(_keyLastKnownFitrCash, cash);
  }

  // Persistent tracking for announcements & request notifications
  static const String _keySeenAnnouncements = 'seen_announcement_ids';
  static const String _keyKnownRequestStatuses = 'known_request_statuses_map';

  static List<String> get seenAnnouncementIds =>
      _prefs?.getStringList(_keySeenAnnouncements) ?? [];

  static Future<void> addSeenAnnouncementId(String id) async {
    final list = seenAnnouncementIds.toList();
    if (!list.contains(id)) {
      list.add(id);
      await _prefs?.setStringList(_keySeenAnnouncements, list);
    }
  }

  static String? getKnownRequestStatus(String reqId) {
    final raw = _prefs?.getStringList(_keyKnownRequestStatuses) ?? [];
    for (final item in raw) {
      final parts = item.split(':::');
      if (parts.length >= 2 && parts[0] == reqId) {
        return parts[1];
      }
    }
    return null;
  }

  static Future<void> setKnownRequestStatus(String reqId, String status) async {
    final raw = _prefs?.getStringList(_keyKnownRequestStatuses) ?? [];
    final updated = raw.where((item) => !item.startsWith('$reqId:::')).toList();
    updated.add('$reqId:::$status');
    await _prefs?.setStringList(_keyKnownRequestStatuses, updated);
  }

  static const String _keyKnownAdminReplies = 'known_admin_replies_map';

  static String? getKnownAdminReply(String reqId) {
    final raw = _prefs?.getStringList(_keyKnownAdminReplies) ?? [];
    for (final item in raw) {
      final parts = item.split(':::');
      if (parts.length >= 2 && parts[0] == reqId) {
        return parts.sublist(1).join(':::');
      }
    }
    return null;
  }

  static Future<void> setKnownAdminReply(String reqId, String reply) async {
    final raw = _prefs?.getStringList(_keyKnownAdminReplies) ?? [];
    final updated = raw.where((item) => !item.startsWith('$reqId:::')).toList();
    updated.add('$reqId:::$reply');
    await _prefs?.setStringList(_keyKnownAdminReplies, updated);
  }

  // Cached Bank Accounts & Payment Channels from Admin Dashboard
  static List<Map<String, dynamic>> get cachedBankAccounts {
    final raw = _prefs?.getString(_keyCachedBankAccounts);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> setCachedBankAccounts(List<Map<String, dynamic>> accounts) async {
    final raw = jsonEncode(accounts);
    await _prefs?.setString(_keyCachedBankAccounts, raw);
  }
}
