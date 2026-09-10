import 'package:flutter/material.dart';
import '../core/services/notification_service.dart';
import '../core/services/permission_service.dart';

class NotificationProvider extends ChangeNotifier {
  bool _notificationsEnabled = true;

  bool get notificationsEnabled => _notificationsEnabled;

  void toggleNotifications(bool enabled) {
    _notificationsEnabled = enabled;
    notifyListeners();
  }

  Future<void> sendTestNotification() async {
    // Request permission first
    await PermissionService.requestNotificationPermission();

    await NotificationService.showNotification(
      id: 999,
      title: '🔔 إشعار تجريبي من تطبيق زكاتي',
      body: 'نظام الإشعارات والتنبيهات يعمل بنجاح تام وفق متطلبات المشروع!',
    );
  }

  Future<void> sendHawlAlert({required int daysRemaining, required String dueDateStr}) async {
    if (!_notificationsEnabled) return;
    await NotificationService.showHawlAlert(
      daysRemaining: daysRemaining,
      dueDateStr: dueDateStr,
    );
  }

  Future<void> notifyZakatSaved({
    required String typeName,
    required String zakatAmount,
  }) async {
    if (!_notificationsEnabled) return;
    await NotificationService.showZakatSavedNotification(
      typeName: typeName,
      zakatAmount: zakatAmount,
    );
  }
}
