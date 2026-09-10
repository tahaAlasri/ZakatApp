import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'zakat_alerts_channel';
  static const String channelName = 'تنبيهات الزكاة والحول';
  static const String channelDescription =
      'قناة مخصصة لإرسال إشعارات مواقيت الزكاة، تذكيرات الحول الهجري، وسجلات الحسابات.';

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification click if needed
      },
    );

    // Create Notification Channel for Android
    const androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  static Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  static Future<void> showHawlAlert({required int daysRemaining, required String dueDateStr}) async {
    final String title = daysRemaining <= 0
        ? '⚠️ تنبيه: وجوب إخراج الزكاة اليوم!'
        : '🌙 تذكير الحول: متبقي $daysRemaining يوماً';
    final String body = daysRemaining <= 0
        ? 'اكتمل الحول القمري الشرعي لأموالك بالكامل. حان وقت إخراج الزكاة وتطهير مالك.'
        : 'يقترب موعد اكتمال الحول الهجري في ($dueDateStr). بادر بمراجعة وحساب زكاتك.';

    await showNotification(
      id: 101,
      title: title,
      body: body,
    );
  }

  static Future<void> showZakatSavedNotification({
    required String typeName,
    required String zakatAmount,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '✅ تم تسجيل حساب الزكاة',
      body: 'تم حفظ عملية "$typeName" بمقدار ($zakatAmount) في سجلك الخاص بنجاح.',
    );
  }

  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
