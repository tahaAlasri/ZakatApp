import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/assistance_request.dart';
import '../constants/zakat_constants.dart';
import '../database/preferences_service.dart';
import '../database/local_db_service.dart';
import 'notification_service.dart';

class AnnouncementItem {
  final String id;
  final String title;
  final String content;
  final String priority; // 'urgent', 'warning', 'general'
  final DateTime createdAt;
  final bool isActive;

  AnnouncementItem({
    required this.id,
    required this.title,
    required this.content,
    this.priority = 'general',
    required this.createdAt,
    this.isActive = true,
  });

  factory AnnouncementItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AnnouncementItem(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
      priority: data['priority']?.toString() ?? 'general',
      isActive: data['isActive'] == true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final String type; // 'request', 'announcement', 'price'
  final DateTime timestamp;
  bool isRead;
  final String? targetId;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.targetId,
  });
}

class CloudSyncService extends ChangeNotifier {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Subscriptions
  StreamSubscription? _pricesSub;
  StreamSubscription? _announcementsSub;
  StreamSubscription? _requestsSub;

  // State
  double _wheatBagPriceYER = ZakatConstants.defaultWheatBagPriceYER;
  double _wheatBagWeightKg = ZakatConstants.defaultWheatBagWeightKg;
  double _fitrCashYER = ZakatConstants.defaultFitrCashYER;
  DateTime? _pricesLastUpdated;

  List<AnnouncementItem> _announcements = [];
  List<AssistanceRequest> _myRequests = [];
  final List<AppNotificationItem> _notifications = [];
  final Map<String, String> _knownRequestStatuses = {};

  // Getters
  double get wheatBagPriceYER => _wheatBagPriceYER;
  double get wheatBagWeightKg => _wheatBagWeightKg;
  double get fitrCashYER => _fitrCashYER;
  DateTime? get pricesLastUpdated => _pricesLastUpdated;
  List<AnnouncementItem> get announcements => _announcements;
  List<AssistanceRequest> get myRequests => _myRequests;
  List<AppNotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  /// Initialize real-time streams
  Future<void> init() async {
    _initPricesStream();
    _initAnnouncementsStream();
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _initRequestsStream(user.uid);
      } else {
        _requestsSub?.cancel();
        _myRequests = [];
        notifyListeners();
      }
    });
  }

  // --- 1. Dynamic Zakat Prices Sync ---
  void _initPricesStream() {
    try {
      _pricesSub?.cancel();
      _pricesSub = _firestore
          .collection('app_config')
          .doc('zakat_prices')
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          final double newWheat = (data['wheatBagPriceYER'] as num?)?.toDouble() ?? _wheatBagPriceYER;
          final double newWeight = (data['wheatBagWeightKg'] as num?)?.toDouble() ?? _wheatBagWeightKg;
          final double newCash = (data['fitrCashYER'] as num?)?.toDouble() ??
              (newWheat / (newWeight / ZakatConstants.fitrSaWeightKg));

          final bool priceChanged = (newWheat != _wheatBagPriceYER && _pricesLastUpdated != null);

          _wheatBagPriceYER = newWheat;
          _wheatBagWeightKg = newWeight;
          _fitrCashYER = newCash;
          _pricesLastUpdated = data['updatedAt'] != null
              ? (data['updatedAt'] as Timestamp).toDate()
              : DateTime.now();

          // Sync gold prices if set by admin
          if (data['gold24PriceYER'] != null) {
            PreferencesService.setGold24Price((data['gold24PriceYER'] as num).toDouble());
          }
          if (data['silverPriceYER'] != null) {
            PreferencesService.setSilverPrice((data['silverPriceYER'] as num).toDouble());
          }

          if (priceChanged) {
            _addNotification(
              AppNotificationItem(
                id: 'price_${DateTime.now().millisecondsSinceEpoch}',
                title: 'تحديث تسعيرة زكاة الفطرة الرسمية',
                body: 'تم اعتماد تسعيرة كيس القمح ($newWheat ر.ي) والصاع نقداً ($newCash ر.ي) من الهيئة.',
                type: 'price',
                timestamp: DateTime.now(),
              ),
            );
            NotificationService.showPriceUpdateNotification(
              title: 'تحديث رسمي: زكاة الفطرة',
              body: 'اعتمدت الهيئة سعر كيس القمح ($newWheat ر.ي) بواقع ($newCash ر.ي) للصاع.',
            );
          }

          notifyListeners();
        }
      }, onError: (err) {
        debugPrint('CloudSyncService: Prices stream error: $err');
      });
    } catch (e) {
      debugPrint('CloudSyncService: Failed to init prices stream: $e');
    }
  }

  // --- 2. Announcements Stream ---
  void _initAnnouncementsStream() {
    try {
      _announcementsSub?.cancel();
      _announcementsSub = _firestore
          .collection('announcements')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen((snapshot) {
        final List<AnnouncementItem> items = snapshot.docs
            .map((doc) => AnnouncementItem.fromFirestore(doc))
            .toList();

        // Sort descending by date
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Check for new announcements to notify
        if (_announcements.isNotEmpty && items.isNotEmpty) {
          final latestNew = items.first;
          if (!_announcements.any((a) => a.id == latestNew.id)) {
            _addNotification(
              AppNotificationItem(
                id: 'ann_${latestNew.id}',
                title: latestNew.title,
                body: latestNew.content,
                type: 'announcement',
                timestamp: latestNew.createdAt,
              ),
            );
            NotificationService.showAnnouncementNotification(
              title: latestNew.title,
              content: latestNew.content,
              priority: latestNew.priority,
            );
          }
        }

        _announcements = items;
        notifyListeners();
      }, onError: (err) {
        debugPrint('CloudSyncService: Announcements stream error: $err');
      });
    } catch (e) {
      debugPrint('CloudSyncService: Failed to init announcements stream: $e');
    }
  }

  // --- 3. User Assistance Requests Stream ---
  void _initRequestsStream(String uid) {
    try {
      _requestsSub?.cancel();
      _requestsSub = _firestore
          .collection('assistance_requests')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .listen((snapshot) {
        final List<AssistanceRequest> loaded = [];

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final req = AssistanceRequest(
            id: doc.id,
            referenceCode: data['referenceCode']?.toString() ?? doc.id,
            userId: data['userId']?.toString(),
            userEmail: data['userEmail']?.toString(),
            subject: data['subject']?.toString() ?? '',
            fullName: data['fullName']?.toString() ?? '',
            address: data['address']?.toString() ?? '',
            phone: data['phone']?.toString() ?? '',
            idNumber: data['idNumber']?.toString(),
            details: data['details']?.toString() ?? '',
            status: data['status']?.toString() ?? 'قيد المراجعة',
            adminResponse: data['adminResponse']?.toString(),
            createdAt: data['createdAt'] != null
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now(),
            updatedAt: data['updatedAt'] != null
                ? (data['updatedAt'] as Timestamp).toDate()
                : null,
          );
          loaded.add(req);

          // Check for status update notification
          final prevStatus = _knownRequestStatuses[req.id];
          if (prevStatus != null && prevStatus != req.status) {
            _addNotification(
              AppNotificationItem(
                id: 'req_status_${req.id}_${DateTime.now().millisecondsSinceEpoch}',
                title: 'تحديث حالة طلب المساعدة (${req.subject})',
                body: 'أصبحت حالة طلبكم: "${req.status}". ${req.adminResponse ?? ""}',
                type: 'request',
                timestamp: DateTime.now(),
                targetId: req.id,
              ),
            );
            NotificationService.showRequestStatusNotification(
              subject: req.subject,
              newStatus: req.status,
              adminReply: req.adminResponse,
            );
          }
          _knownRequestStatuses[req.id] = req.status;
        }

        // Sort descending
        loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _myRequests = loaded;
        notifyListeners();
      }, onError: (err) {
        debugPrint('CloudSyncService: Requests stream error: $err');
      });
    } catch (e) {
      debugPrint('CloudSyncService: Failed to init requests stream: $e');
    }
  }

  // --- 4. Submit Assistance Request Directly to Cloud ---
  Future<String> submitOfficialRequest(AssistanceRequest req) async {
    final user = _auth.currentUser;
    final now = DateTime.now();
    final randomSuffix = (1000 + (now.millisecondsSinceEpoch % 9000)).toString();
    final refCode = 'ZAK-${now.year}-$randomSuffix';

    final requestData = {
      'referenceCode': refCode,
      'userId': user?.uid ?? 'guest_${now.millisecondsSinceEpoch}',
      'userEmail': user?.email ?? req.userEmail ?? '',
      'subject': req.subject,
      'fullName': req.fullName,
      'address': req.address,
      'phone': req.phone,
      'idNumber': req.idNumber ?? '',
      'details': req.details,
      'status': 'قيد المراجعة',
      'adminResponse': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'statusHistory': [
        {
          'status': 'قيد المراجعة',
          'note': 'تم استلام الطلب رسمياً عبر بوابة الهيئة',
          'timestamp': now.toIso8601String(),
        }
      ],
    };

    final docRef = await _firestore.collection('assistance_requests').add(requestData);

    final updatedReq = req.copyWith(
      id: docRef.id,
      referenceCode: refCode,
      userId: user?.uid,
      userEmail: user?.email,
      status: 'قيد المراجعة',
      createdAt: now,
    );

    // Save locally in SQLite/Hive as well
    LocalDbService.saveAssistanceRequest(updatedReq);

    _knownRequestStatuses[docRef.id] = 'قيد المراجعة';

    _addNotification(
      AppNotificationItem(
        id: 'new_sub_${docRef.id}',
        title: 'تم تسجيل طلب المساعدة برقم ($refCode)',
        body: 'تم استلام طلبكم بخصوص "${req.subject}" وهو الآن قيد المراجعة من لجان الهيئة.',
        type: 'request',
        timestamp: now,
        targetId: docRef.id,
      ),
    );

    return refCode;
  }

  // --- Notification Management ---
  void _addNotification(AppNotificationItem item) {
    _notifications.insert(0, item);
    notifyListeners();
  }

  void markNotificationAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  void markAllNotificationsAsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void clearNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _pricesSub?.cancel();
    _announcementsSub?.cancel();
    _requestsSub?.cancel();
    super.dispose();
  }
}
