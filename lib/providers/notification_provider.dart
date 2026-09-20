import 'package:flutter/material.dart';
import '../core/services/notification_service.dart';
import '../core/database/preferences_service.dart';

class NotificationProvider extends ChangeNotifier {
  bool _notificationsEnabled = PreferencesService.notificationsEnabled;

  bool get notificationsEnabled => _notificationsEnabled;

  void toggleNotifications(bool enabled) {
    _notificationsEnabled = enabled;
    PreferencesService.setNotificationsEnabled(enabled);
    notifyListeners();
  }

  Future<void> sendHawlAlert({required int daysRemaining, required String dueDateStr}) async {
    if (!_notificationsEnabled) return;
    await NotificationService.showHawlAlert(
      daysRemaining: daysRemaining,
      dueDateStr: dueDateStr,
    );
  }

  Future<void> notifyEmailSent({required String subject}) async {
    if (!_notificationsEnabled) return;
    await NotificationService.showEmailSentNotification(subject: subject);
  }

  Future<void> notifyHawlCompleted({required String dueDateStr}) async {
    if (!_notificationsEnabled) return;
    await NotificationService.showHawlCompletedNotification(dueDateStr: dueDateStr);
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

  Future<void> scheduleHawlMilestones({
    required DateTime dueDate,
    required String dueDateStr,
  }) async {
    if (!_notificationsEnabled) return;
    await NotificationService.scheduleHawlAlerts(
      dueDate: dueDate,
      dueDateStr: dueDateStr,
    );
  }

  Future<void> cancelHawlAlerts() async {
    await NotificationService.cancelHawlAlerts();
  }
}
