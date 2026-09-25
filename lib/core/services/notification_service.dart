import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../firebase_options.dart';

/// معالج إشعارات الخلفية ونظام أندرويد المعزول
/// (يعمل حتى والتطبيق مغلق تماماً وغير موجود في الرام / Killed / Terminated)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error in background handler: $e');
  }

  debugPrint('📩 FCM Background message received: ${message.messageId}');
  debugPrint('FCM Data: ${message.data}');
  debugPrint('FCM Notification: ${message.notification?.title} - ${message.notification?.body}');

  // تهيئة الإشعارات في بيئة الخلفية المعزولة لضمان ظهور التنبيه
  final FlutterLocalNotificationsPlugin bgPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/launcher_icon');
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
  );
  try {
    await bgPlugin.initialize(initSettings);
  } catch (e) {
    debugPrint('Error initializing local notifications in bg handler: $e');
  }

  const androidChannel = AndroidNotificationChannel(
    NotificationService.channelId,
    NotificationService.channelName,
    description: NotificationService.channelDescription,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  final androidPlatform = bgPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlatform?.createNotificationChannel(androidChannel);

  // استخراج العنوان والمحتوى
  String title = message.notification?.title ?? message.data['title']?.toString() ?? 'الهيئة العامة للزكاة';
  String body = message.notification?.body ?? message.data['body']?.toString() ?? message.data['content']?.toString() ?? '';
  final priority = message.data['priority']?.toString();

  if (priority == 'urgent' && !title.contains('[عاجل]')) {
    title = '🚨 [عاجل] $title';
  } else if (!title.contains('📢') && !title.contains('🚨') && !title.contains('⚠️') && !title.contains('🔔')) {
    title = '📢 $title';
  }

  // إذا لم تحتوِ الرسالة على Notification أصلي وعولجت كـ Data-only، نعرضها محلياً فوراً
  if (message.notification == null && body.isNotEmpty) {
    final dynamicBigText = AndroidNotificationDetails(
      NotificationService.channelId,
      NotificationService.channelName,
      channelDescription: NotificationService.channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      showWhen: true,
      playSound: true,
      enableVibration: true,
      ticker: 'إشعار جديد من الهيئة العامة للزكاة',
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'الهيئة العامة للزكاة',
      ),
    );

    await bgPlugin.show(
      (message.data['id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch) % 100000,
      title,
      body,
      NotificationDetails(android: dynamicBigText),
      payload: message.data['targetId']?.toString() ?? message.data['id']?.toString(),
    );
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static FirebaseMessaging? get _fcm {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseMessaging.instance;
      }
    } catch (_) {}
    return null;
  }

  static const String channelId = 'zakat_alerts_channel';
  static const String channelName = 'تنبيهات الزكاة والحول والإعلانات';
  static const String channelDescription =
      'قناة مخصصة لإرسال إشعارات مواقيت الزكاة، تذكيرات الحول الهجري، والإعلانات والتعميمات الرسمية.';

  // Scheduled notification IDs for Hawl milestones
  static const int hawl30DaysAlertId = 1101;
  static const int hawl7DaysAlertId = 1102;
  static const int hawlDueDateAlertId = 1103;

  static Future<void> init() async {
    // 1. Initialize timezone database for smart scheduled alarms
    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Error initializing timezone: $e');
    }

    // 2. Initialize Local Notifications Plugin
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationTap(response.payload);
        },
      ).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('NotificationPlugin init error: $e');
    }

    // 3. Create Notification Channel for Android
    try {
      const androidChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(androidChannel);
    } catch (e) {
      debugPrint('NotificationService: create channel error: $e');
    }

    // 4. Initialize Firebase Cloud Messaging (FCM) in background (non-blocking)
    _initFCM().catchError((e) {
      debugPrint('FCM init background error: $e');
    });
  }

  static Future<void> _initFCM() async {
    final fcm = _fcm;
    if (fcm == null) return;

    try {
      // طلب إذن الإشعارات من المستخدم لنظام iOS و Android 13+
      await fcm.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      ).timeout(const Duration(seconds: 3));

      // تفعيل إظهار الإشعارات في الواجهة الأمامية
      await fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      ).timeout(const Duration(seconds: 2));

      // الاشتراك التلقائي في قنوات ومواضيع البث العام في الخلفية
      fcm.subscribeToTopic('announcements').catchError((_) {});
      fcm.subscribeToTopic('zakat_alerts').catchError((_) {});
      fcm.subscribeToTopic('all_users').catchError((_) {});

      // جلب توكن الجهاز
      fcm.getToken().then((token) {
        debugPrint('FCM Device Token: $token');
      }).catchError((_) {});

      // الاستماع للرسائل أثناء وجود التطبيق في الواجهة الأمامية (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM Foreground message received: ${message.data}');
        final notification = message.notification;
        if (notification != null) {
          showNotification(
            id: message.messageId.hashCode % 100000,
            title: notification.title ?? 'الهيئة العامة للزكاة',
            body: notification.body ?? '',
            payload: message.data['targetId']?.toString() ?? message.data['id']?.toString(),
          );
        } else if (message.data.isNotEmpty) {
          final title = message.data['title']?.toString() ?? 'الهيئة العامة للزكاة';
          final body = message.data['body']?.toString() ?? message.data['content']?.toString() ?? '';
          if (body.isNotEmpty) {
            showNotification(
              id: (message.data['id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch) % 100000,
              title: title,
              body: body,
              payload: message.data['targetId']?.toString() ?? message.data['id']?.toString(),
            );
          }
        }
      });

      // التعامل مع فتح التطبيق بالنقر على الإشعار من شريط الإشعارات أثناء وجوده في الخلفية
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM Notification tapped (from background): ${message.data}');
        _handleNotificationTap(message.data['targetId']?.toString() ?? message.data['id']?.toString());
      });

      // التعامل مع فتح التطبيق بالنقر على الإشعار عندما كان التطبيق مغلقاً تماماً (Terminated / Killed)
      final initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM Initial message found (app launched from notification): ${initialMessage.data}');
        _handleNotificationTap(initialMessage.data['targetId']?.toString() ?? initialMessage.data['id']?.toString());
      }
    } catch (e) {
      debugPrint('FCM Initialization error: $e');
    }
  }

  static Future<void> subscribeToUserTopic(String uid) async {
    try {
      await _fcm?.subscribeToTopic('user_$uid');
      debugPrint('FCM: Subscribed to user topic user_$uid');
    } catch (e) {
      debugPrint('FCM: Error subscribing to user topic: $e');
    }
  }

  static Future<void> unsubscribeFromUserTopic(String uid) async {
    try {
      await _fcm?.unsubscribeFromTopic('user_$uid');
      debugPrint('FCM: Unsubscribed from user topic user_$uid');
    } catch (e) {
      debugPrint('FCM: Error unsubscribing from user topic: $e');
    }
  }

  static void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty) return;
    debugPrint('Notification clicked with payload: $payload');
  }

  static Future<void> showTestNotification() async {
    await showNotification(
      id: 999,
      title: '🔔 إشعار تجريبي من الهيئة العامة للزكاة',
      body: 'نظام الإشعارات والتنبيهات يعمل بنجاح على هاتفك مع الصوت والاهتزاز!',
    );
  }

  static Future<void> showNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      showWhen: true,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'الهيئة العامة للزكاة',
      ),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
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

  /// Schedules future background notifications for Hawl milestones:
  /// 1. 30 days before due date
  /// 2. 7 days before due date
  /// 3. On the exact due date at 09:00 AM
  static Future<void> scheduleHawlAlerts({
    required DateTime dueDate,
    required String dueDateStr,
  }) async {
    await cancelHawlAlerts();

    final now = DateTime.now();

    // 1. 30 Days Milestone
    final date30Days = dueDate.subtract(const Duration(days: 30));
    if (date30Days.isAfter(now)) {
      final scheduledTz = tz.TZDateTime.from(
        DateTime(date30Days.year, date30Days.month, date30Days.day, 10, 0),
        tz.local,
      );
      await _scheduleSingle(
        id: hawl30DaysAlertId,
        title: '🌙 اقترب موعد الحول: متبقي شهر واحد',
        body: 'نحيطكم علماً باقتراب موعد تمام الحول الشرعي لأموالكم في ($dueDateStr). بادر بجرد مدخراتك ومراجعة أموالك الزكوية.',
        scheduledDate: scheduledTz,
      );
    }

    // 2. 7 Days Milestone
    final date7Days = dueDate.subtract(const Duration(days: 7));
    if (date7Days.isAfter(now)) {
      final scheduledTz = tz.TZDateTime.from(
        DateTime(date7Days.year, date7Days.month, date7Days.day, 10, 0),
        tz.local,
      );
      await _scheduleSingle(
        id: hawl7DaysAlertId,
        title: '⏳ تذكير الحول: متبقي أسبوع واحد',
        body: 'متبقي 7 أيام فقط على اكتمال الحول الشرعي لأموالك بتاريخ ($dueDateStr). جهّز زكاتك المفروضة لأدائها في وقتها.',
        scheduledDate: scheduledTz,
      );
    }

    // 3. Exact Due Date Milestone
    if (dueDate.isAfter(now)) {
      final scheduledTz = tz.TZDateTime.from(
        DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0),
        tz.local,
      );
      await _scheduleSingle(
        id: hawlDueDateAlertId,
        title: '📢 اليوم حلّ موعد إخراج الزكاة المفروضة!',
        body: 'اكتمل الحول القمري الشرعي (354 يوماً) لأموالك اليوم ($dueDateStr). طهّر مالك ونمّه بأداء الزكاة طيبةً بها نفسك.',
        scheduledDate: scheduledTz,
      );
    }
  }

  static Future<void> _scheduleSingle({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
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

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      // Inexact fallback if exact alarms are restricted
      try {
        await _notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e2) {
        debugPrint('Error scheduling notification: $e2');
      }
    }
  }

  static Future<void> cancelHawlAlerts() async {
    try {
      await _notificationsPlugin.cancel(hawl30DaysAlertId);
      await _notificationsPlugin.cancel(hawl7DaysAlertId);
      await _notificationsPlugin.cancel(hawlDueDateAlertId);
    } catch (_) {}
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

  static Future<void> showHawlCompletedNotification({required String dueDateStr}) async {
    await showNotification(
      id: 102,
      title: '📢 اليوم موعد إخراج الزكاة!',
      body: 'اكتمل الحول القمري الشرعي (354 يوماً) بتاريخ ($dueDateStr). اليوم هو موعد إخراج الزكاة المفروضة وتطهير مالك.',
    );
  }

  static Future<void> showEmailSentNotification({required String subject}) async {
    await showNotification(
      id: 201,
      title: '📨 تم إرسال البريد وتجهيز مسودة الخطاب',
      body: 'تم إرسال طلب المساعدة بنجاح عبر البريد الإلكتروني وتجهيز مسودة خطاب للمشاركة وتصديرها بخصوص "$subject".',
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

  static Future<void> showRequestStatusNotification({
    required String subject,
    required String newStatus,
    String? adminReply,
  }) async {
    String statusLabel = newStatus;
    if (newStatus == 'approved' || newStatus == 'تمت الموافقة') {
      statusLabel = 'تمت الموافقة على طلبكم ✅';
    } else if (newStatus == 'rejected' || newStatus == 'مرفوض') {
      statusLabel = 'تمت مراجعة الطلب مع الاعتذار ❌';
    } else if (newStatus == 'under_review' || newStatus == 'قيد الدراسة') {
      statusLabel = 'طلبكم قيد الدراسة الميدانية 📋';
    } else if (newStatus == 'completed' || newStatus == 'جاهز للصرف') {
      statusLabel = 'طلبكم جاهز للصرف والإنجاز 💵';
    }

    final body = adminReply != null && adminReply.isNotEmpty
        ? '$statusLabel بخصوص "$subject". رد الهيئة: $adminReply'
        : '$statusLabel بخصوص "$subject". انقر للاطلاع على تفاصيل الطلب.';

    await showNotification(
      id: 301 + (DateTime.now().millisecondsSinceEpoch % 1000),
      title: '🔔 الهيئة العامة للزكاة - تحديث الطلب',
      body: body,
    );
  }

  static Future<void> showAnnouncementNotification({
    required String title,
    required String content,
    String? priority,
  }) async {
    final prefix = priority == 'urgent' ? '🚨 [عاجل] ' : '📢 ';
    await showNotification(
      id: 401 + (DateTime.now().millisecondsSinceEpoch % 1000),
      title: '$prefix الهيئة العامة للزكاة: $title',
      body: content,
    );
  }

  static Future<void> showPriceUpdateNotification({
    required String title,
    required String body,
  }) async {
    await showNotification(
      id: 501,
      title: '🌾 $title',
      body: body,
    );
  }

  static Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}
