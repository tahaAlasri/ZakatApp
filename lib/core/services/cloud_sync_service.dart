// ============================================================
// FIXED: cloud_sync_service.dart
// إصلاحات:
// 1. إضافة await لـ LocalDbService.saveAssistanceRequest في submitOfficialRequest
// 2. إضافة try/catch أفضل في _initPricesStream
// 3. تعديل في _initPricesStream: التحقق من صحة البيانات قبل تطبيقها
// 4. إضافة مؤشر hasError للحالة والوصول إليه
// ============================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/assistance_request.dart';
import '../database/preferences_service.dart';
import '../database/local_db_service.dart';
import 'notification_service.dart';

class AnnouncementItem {
  final String id;
  final String title;
  final String content;
  final String priority;
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

class RequestSubmissionResult {
  final String referenceCode;
  final bool isCloudSaved;
  final String userMessage;

  const RequestSubmissionResult({
    required this.referenceCode,
    required this.isCloudSaved,
    required this.userMessage,
  });

  @override
  String toString() => referenceCode;
}

class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final String type;
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
  static CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  @visibleForTesting
  static void resetForTesting() {
    _instance = CloudSyncService._internal();
  }

  FirebaseFirestore? get _firestore {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return null;
  }

  FirebaseAuth? get _auth {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance;
      }
    } catch (_) {}
    return null;
  }

  StreamSubscription? _pricesSub;
  StreamSubscription? _announcementsSub;
  StreamSubscription? _requestsSub;
  StreamSubscription? _generalSettingsSub;
  final List<StreamSubscription> _localRequestSubs = [];

  double _wheatBagPriceYER = PreferencesService.lastKnownWheatPrice;
  double _wheatBagWeightKg = PreferencesService.lastKnownWheatWeight;
  double _fitrCashYER = PreferencesService.lastKnownFitrCash;
  DateTime? _pricesLastUpdated;
  bool _hasPriceError = false;

  // أسعار الذهب والفضة الرسمية المعتمدة من لوحة المشرف
  double? _gold24PriceYER;
  double? _gold21PriceYER;
  double? _gold18PriceYER;
  double? _silverPriceYER;
  double? _gold24Aden;
  double? _silverAden;

  // إعدادات النظام وقنوات التواصل وحسابات السداد من لوحة المشرف
  String _hotline = '8000000';
  String _whatsapp = '+967 777 000 111';
  String _officialEmail = 'info@zakat.gov.ye';
  bool _allowRequests = true;
  bool _maintenanceMode = false;
  String _latestVersion = '1.0.1';
  List<Map<String, dynamic>> _bankAccounts = PreferencesService.cachedBankAccounts;

  List<AnnouncementItem> _announcements = [];
  List<AssistanceRequest> _myRequests = [];
  final List<AppNotificationItem> _notifications = [];
  final Map<String, String> _knownRequestStatuses = {};

  double get wheatBagPriceYER => _wheatBagPriceYER;
  double get wheatBagWeightKg => _wheatBagWeightKg;
  double get fitrCashYER => _fitrCashYER;
  DateTime? get pricesLastUpdated => _pricesLastUpdated;
  bool get hasPriceError => _hasPriceError;

  double? get gold24PriceYER => _gold24PriceYER;
  double? get gold21PriceYER => _gold21PriceYER;
  double? get gold18PriceYER => _gold18PriceYER;
  double? get silverPriceYER => _silverPriceYER;
  double? get gold24Aden => _gold24Aden;
  double? get silverAden => _silverAden;

  String get hotline => _hotline;
  String get whatsapp => _whatsapp;
  String get officialEmail => _officialEmail;
  bool get allowRequests => _allowRequests;
  bool get maintenanceMode => _maintenanceMode;
  String get latestVersion => _latestVersion;
  List<Map<String, dynamic>> get bankAccounts => List.unmodifiable(_bankAccounts);

  List<AnnouncementItem> get announcements => _announcements;
  List<AssistanceRequest> get myRequests => _myRequests;
  List<AppNotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  Future<void> init() async {
    _initPricesStream();
    _initAnnouncementsStream();
    _initGeneralSettingsStream();

    // تحميل ومراقبة الطلبات المحلية فوراً حتى لو لم يكن المستخدم مسجلاً بحساب
    final localReqs = LocalDbService.getAllAssistanceRequests();
    if (localReqs.isNotEmpty) {
      _myRequests = localReqs;
      for (final r in localReqs) {
        _knownRequestStatuses[r.id] = r.status;
        PreferencesService.setKnownRequestStatus(r.id, r.status);
      }
    }
    _listenToLocalRequests();

    final auth = _auth;
    if (auth != null) {
      String? currentUid;
      auth.authStateChanges().listen((user) {
        if (user != null) {
          currentUid = user.uid;
          NotificationService.subscribeToUserTopic(user.uid);
          _initRequestsStream(user.uid);
          _reUploadPendingLocalRequests(); // إعادة رفع الطلبات المعلقة محلياً
        } else {
          if (currentUid != null) {
            NotificationService.unsubscribeFromUserTopic(currentUid!);
            currentUid = null;
          }
          _requestsSub?.cancel();
          _myRequests = LocalDbService.getAllAssistanceRequests();
          _listenToLocalRequests();
          notifyListeners();
        }
      });
    }
  }

  // تطبيق بيانات الأسعار السحابية وتحديث التخزين المحلي
  bool _applyPricesData(Map<String, dynamic> data) {
    final rawWheatPrice = data['wheatBagPriceYER'];
    final rawWeightKg = data['wheatBagWeightKg'];
    final rawFitrCash = data['fitrCashYER'];

    // استخراج أسعار الذهب والفضة الرسمية المعتمدة
    final rawG24 = data['gold24PriceYER'];
    final rawG21 = data['gold21PriceYER'];
    final rawG18 = data['gold18PriceYER'];
    final rawSilver = data['silverPriceYER'];
    final rawG24Aden = data['gold24Aden'];
    final rawSilverAden = data['silverAden'];

    if (rawG24 is num && rawG24 > 0) _gold24PriceYER = rawG24.toDouble();
    if (rawG21 is num && rawG21 > 0) _gold21PriceYER = rawG21.toDouble();
    if (rawG18 is num && rawG18 > 0) _gold18PriceYER = rawG18.toDouble();
    if (rawSilver is num && rawSilver > 0) _silverPriceYER = rawSilver.toDouble();
    if (rawG24Aden is num && rawG24Aden > 0) _gold24Aden = rawG24Aden.toDouble();
    if (rawSilverAden is num && rawSilverAden > 0) _silverAden = rawSilverAden.toDouble();

    final newWheatPrice = (rawWheatPrice is num)
        ? rawWheatPrice.toDouble()
        : double.tryParse(rawWheatPrice?.toString() ?? '');

    final newWeightKg = (rawWeightKg is num)
        ? rawWeightKg.toDouble()
        : double.tryParse(rawWeightKg?.toString() ?? '');

    final newFitrCash = (rawFitrCash is num)
        ? rawFitrCash.toDouble()
        : double.tryParse(rawFitrCash?.toString() ?? '');

    bool changed = false;

    if (newWheatPrice != null && newWheatPrice > 0) {
      _wheatBagPriceYER = newWheatPrice;
      changed = true;
    }
    if (newWeightKg != null && newWeightKg > 0) {
      _wheatBagWeightKg = newWeightKg;
      changed = true;
    }
    if (newFitrCash != null && newFitrCash > 0) {
      _fitrCashYER = newFitrCash;
      changed = true;
    } else if (newWheatPrice != null && newWheatPrice > 0) {
      final saCount = _wheatBagWeightKg > 0 ? (_wheatBagWeightKg / 2.5) : 20.0;
      _fitrCashYER = saCount > 0 ? (_wheatBagPriceYER / saCount) : 1200.0;
      changed = true;
    }

    if (rawG24 != null || rawSilver != null || rawG24Aden != null) {
      changed = true;
    }

    if (changed) {
      _pricesLastUpdated = DateTime.now();
      _hasPriceError = false;

      // حفظ في SharedPreferences للوضع غير المتصل
      PreferencesService.setLastKnownWheatPrice(_wheatBagPriceYER);
      PreferencesService.setLastKnownWheatWeight(_wheatBagWeightKg);
      PreferencesService.setLastKnownFitrCash(_fitrCashYER);
      if (_gold24PriceYER != null && _gold24PriceYER! > 0) {
        PreferencesService.setGold24Price(_gold24PriceYER!);
      }
      if (_gold21PriceYER != null && _gold21PriceYER! > 0) {
        PreferencesService.setGold21Price(_gold21PriceYER!);
      }
      if (_gold18PriceYER != null && _gold18PriceYER! > 0) {
        PreferencesService.setGold18Price(_gold18PriceYER!);
      }
      if (_silverPriceYER != null && _silverPriceYER! > 0) {
        PreferencesService.setSilverPrice(_silverPriceYER!);
      }
      if (_gold24Aden != null && _gold24Aden! > 0) {
        PreferencesService.setGold24Aden(_gold24Aden!);
      }
      if (_silverAden != null && _silverAden! > 0) {
        PreferencesService.setSilverAden(_silverAden!);
      }

      notifyListeners();
    }
    return changed;
  }

  // تطبيق الإعدادات العامة والحسابات البنكية
  void _applyGeneralSettingsData(Map<String, dynamic> data) {
    if (data['hotline'] != null) _hotline = data['hotline'].toString();
    if (data['whatsapp'] != null) _whatsapp = data['whatsapp'].toString();
    if (data['officialEmail'] != null) _officialEmail = data['officialEmail'].toString();
    if (data['allowRequests'] != null) _allowRequests = data['allowRequests'] == true;
    if (data['maintenanceMode'] != null) _maintenanceMode = data['maintenanceMode'] == true;
    if (data['latestVersion'] != null) _latestVersion = data['latestVersion'].toString();

    if (data['bankAccounts'] is List) {
      final List<Map<String, dynamic>> parsed = [];
      for (final item in data['bankAccounts']) {
        if (item is Map) {
          parsed.add(Map<String, dynamic>.from(item));
        }
      }
      _bankAccounts = parsed;
      PreferencesService.setCachedBankAccounts(parsed);
    }
    notifyListeners();
  }

  /// تحديث يدوي شامل لجميع الأسعار والإعدادات والإعلانات والطلبات من Firestore مباشرة
  Future<void> refreshAll() async {
    final fs = _firestore;
    if (fs == null) return;
    try {
      // 1. جلب أسعار الزكاة المحدثة مباشرة
      final priceDoc = await fs.collection('app_config').doc('zakat_prices').get();
      if (priceDoc.exists && priceDoc.data() != null) {
        _applyPricesData(priceDoc.data()!);
      }

      // 2. جلب الإعدادات العامة مباشرة
      final settingsDoc = await fs.collection('app_config').doc('general_settings').get();
      if (settingsDoc.exists && settingsDoc.data() != null) {
        _applyGeneralSettingsData(settingsDoc.data()!);
      }

      // 3. جلب أحدث الإعلانات
      final annSnap = await fs
          .collection('announcements')
          .where('isActive', isEqualTo: true)
          .get();
      final items = annSnap.docs.map((doc) => AnnouncementItem.fromFirestore(doc)).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _announcements = items;

      // 4. جلب طلبات المستخدم الحالية إن وجد
      final auth = _auth;
      if (auth?.currentUser != null) {
        final reqSnap = await fs
            .collection('assistance_requests')
            .where('userId', isEqualTo: auth!.currentUser!.uid)
            .get();
        final cloudReqs = reqSnap.docs.map((d) {
          final data = d.data();
          return AssistanceRequest(
            id: d.id,
            referenceCode: data['referenceCode']?.toString() ?? d.id,
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
        }).toList();
        if (cloudReqs.isNotEmpty) {
          _myRequests = cloudReqs;
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('CloudSyncService.refreshAll error: $e');
    }
  }

  void _initPricesStream() {
    final fs = _firestore;
    if (fs == null) return;
    try {
      _pricesSub?.cancel();
      _pricesSub = fs
          .collection('app_config')
          .doc('zakat_prices')
          .snapshots()
          .listen(
        (snapshot) {
          if (!snapshot.exists) return;
          final data = snapshot.data();
          if (data == null) return;

          final bool changed = _applyPricesData(data);
          if (changed) {
            _addNotification(
              AppNotificationItem(
                id: 'price_update_${DateTime.now().millisecondsSinceEpoch}',
                title: 'تحديث أسعار الزكاة',
                body: 'تم تحديث أسعار الزكاة المعتمدة رسمياً من لوحة التحكم.',
                type: 'price',
                timestamp: DateTime.now(),
              ),
            );
          }
        },
        onError: (err) {
          _hasPriceError = true;
          debugPrint('CloudSyncService: Prices stream error: $err');
        },
      );
    } catch (e) {
      _hasPriceError = true;
      debugPrint('CloudSyncService: Failed to init prices stream: $e');
    }
  }

  void _initGeneralSettingsStream() {
    final fs = _firestore;
    if (fs == null) return;
    try {
      _generalSettingsSub?.cancel();
      _generalSettingsSub = fs
          .collection('app_config')
          .doc('general_settings')
          .snapshots()
          .listen((snapshot) {
        if (!snapshot.exists) return;
        final data = snapshot.data();
        if (data == null) return;

        _applyGeneralSettingsData(data);
      }, onError: (err) {
        debugPrint('CloudSyncService: General settings stream error: $err');
      });
    } catch (e) {
      debugPrint('CloudSyncService: Failed to init general settings stream: $e');
    }
  }

  void _initAnnouncementsStream() {
    final fs = _firestore;
    if (fs == null) return;
    try {
      _announcementsSub?.cancel();
      _announcementsSub = fs
          .collection('announcements')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .listen((snapshot) {
        final items = snapshot.docs
            .map((doc) => AnnouncementItem.fromFirestore(doc))
            .toList();
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final seenIds = PreferencesService.seenAnnouncementIds;
        final bool isFirstRunEver = seenIds.isEmpty;

        for (final ann in items) {
          if (!seenIds.contains(ann.id)) {
            PreferencesService.addSeenAnnouncementId(ann.id);

            // إرسال إشعار فوري إذا كان إعلاناً جديداً أو في أول تشغيل وكان حديثاً (خلال 72 ساعة)
            final isRecent = DateTime.now().difference(ann.createdAt).inHours < 72;
            if (!isFirstRunEver || isRecent) {
              _addNotification(
                AppNotificationItem(
                  id: 'ann_${ann.id}',
                  title: ann.title,
                  body: ann.content,
                  type: 'announcement',
                  timestamp: ann.createdAt,
                ),
              );
              NotificationService.showAnnouncementNotification(
                title: ann.title,
                content: ann.content,
                priority: ann.priority,
              );
            }
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

  void _initRequestsStream(String uid) {
    final fs = _firestore;
    if (fs == null) return;
    try {
      _requestsSub?.cancel();
      _requestsSub = fs
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

          final prevStatus = PreferencesService.getKnownRequestStatus(req.id) ?? _knownRequestStatuses[req.id];
          final prevReply = PreferencesService.getKnownAdminReply(req.id);

          final bool statusChanged = prevStatus != null && prevStatus != req.status;
          final bool replyChanged = req.adminResponse != null && req.adminResponse!.isNotEmpty && req.adminResponse != prevReply;

          if (statusChanged || replyChanged) {
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
          PreferencesService.setKnownRequestStatus(req.id, req.status);
          if (req.adminResponse != null) {
            PreferencesService.setKnownAdminReply(req.id, req.adminResponse!);
          }
        }

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

  /// مراقبة طلبات المستخدم المحفوظة في الجهاز بشكل فردي ومباشر في السحاب
  /// لضمان وصول الإشعارات حتى لو لم يكن المستخدم مسجلاً بحساب رسمي
  void _listenToLocalRequests() {
    final fs = _firestore;
    if (fs == null) return;

    for (final sub in _localRequestSubs) {
      sub.cancel();
    }
    _localRequestSubs.clear();

    final localReqs = LocalDbService.getAllAssistanceRequests();
    for (final req in localReqs) {
      if (req.id.isEmpty || req.id.startsWith('loc_')) continue;

      try {
        final sub = fs
            .collection('assistance_requests')
            .doc(req.id)
            .snapshots()
            .listen((docSnap) {
          if (!docSnap.exists) return;
          final data = docSnap.data();
          if (data == null) return;

          final newStatus = data['status']?.toString() ?? req.status;
          final newReply = data['adminResponse']?.toString();

          final prevStatus = PreferencesService.getKnownRequestStatus(req.id) ?? _knownRequestStatuses[req.id];
          final prevReply = PreferencesService.getKnownAdminReply(req.id);

          final bool statusChanged = prevStatus != null && prevStatus != newStatus;
          final bool replyChanged = newReply != null && newReply.isNotEmpty && newReply != prevReply;

          if (statusChanged || replyChanged) {
            final subject = data['subject']?.toString() ?? req.subject;
            _addNotification(
              AppNotificationItem(
                id: 'req_status_${req.id}_${DateTime.now().millisecondsSinceEpoch}',
                title: 'تحديث حالة طلب المساعدة ($subject)',
                body: 'أصبحت حالة طلبكم: "$newStatus". ${newReply ?? ""}',
                type: 'request',
                timestamp: DateTime.now(),
                targetId: req.id,
              ),
            );

            NotificationService.showRequestStatusNotification(
              subject: subject,
              newStatus: newStatus,
              adminReply: newReply,
            );

            final updated = req.copyWith(
              status: newStatus,
              adminResponse: newReply,
              updatedAt: DateTime.now(),
            );
            LocalDbService.saveAssistanceRequest(updated);

            final idx = _myRequests.indexWhere((r) => r.id == req.id);
            if (idx != -1) {
              _myRequests[idx] = updated;
            } else {
              _myRequests.insert(0, updated);
            }
            notifyListeners();
          }

          _knownRequestStatuses[req.id] = newStatus;
          PreferencesService.setKnownRequestStatus(req.id, newStatus);
          if (newReply != null) {
            PreferencesService.setKnownAdminReply(req.id, newReply);
          }
        }, onError: (err) {
          debugPrint('Local request listener error for ${req.id}: $err');
        });

        _localRequestSubs.add(sub);
      } catch (e) {
        debugPrint('Failed to attach listener for ${req.id}: $e');
      }
    }
  }

  /// إعادة رفع الطلبات المحفوظة محلياً فقط إلى Firebase عند توفر الاتصال
  Future<void> _reUploadPendingLocalRequests() async {
    final fs = _firestore;
    final user = _auth?.currentUser;
    if (fs == null || user == null) return;

    final localReqs = LocalDbService.getAllAssistanceRequests();
    bool hasChanges = false;

    for (final req in localReqs) {
      // فقط إعادة رفع الطلبات المحفوظة محلياً (لم تُرفع سحابياً)
      if (!req.status.contains('محلياً')) continue;

      try {
        final requestData = {
          'referenceCode': req.referenceCode ?? req.id,
          'userId': user.uid,
          'userEmail': user.email ?? req.userEmail ?? '',
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
              'note': 'تم رفع الطلب بعد استعادة الاتصال',
              'timestamp': DateTime.now().toIso8601String(),
            }
          ],
        };

        final docRef = await fs
            .collection('assistance_requests')
            .add(requestData)
            .timeout(const Duration(seconds: 10));

        // تحديث الطلب المحلي بالمعرف السحابي والحالة الجديدة
        final updated = req.copyWith(
          id: docRef.id,
          status: 'قيد المراجعة',
          updatedAt: DateTime.now(),
        );

        await LocalDbService.deleteAssistanceRequest(req.id);
        await LocalDbService.saveAssistanceRequest(updated);
        hasChanges = true;

        _addNotification(
          AppNotificationItem(
            id: 'reupload_${DateTime.now().millisecondsSinceEpoch}',
            title: 'تم رفع طلب معلق',
            body: 'تم رفع طلبك "${req.subject}" إلى الهيئة بعد استعادة الاتصال.',
            type: 'request',
            timestamp: DateTime.now(),
            targetId: docRef.id,
          ),
        );

        debugPrint('Successfully re-uploaded local request: ${req.id} \u2192 ${docRef.id}');
      } catch (e) {
        debugPrint('Failed to re-upload request ${req.id}: $e');
      }
    }

    if (hasChanges) {
      _myRequests = LocalDbService.getAllAssistanceRequests();
      _listenToLocalRequests();
      notifyListeners();
    }
  }

  // FIX: مهلة زمنية ذكية وحفظ محلي فوري لمنع تعليق التطبيق
  Future<RequestSubmissionResult> submitOfficialRequest(AssistanceRequest req) async {
    final user = _auth?.currentUser;
    final now = DateTime.now();
    final randomSuffix = (1000 + (now.millisecondsSinceEpoch % 9000)).toString();
    final refCode = 'ZAK-${now.year}-$randomSuffix';

    String docId = 'req_${now.millisecondsSinceEpoch}';
    bool cloudSaved = false;

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

    final fs = _firestore;
    if (fs != null) {
      try {
        final docRef = await fs
            .collection('assistance_requests')
            .add(requestData)
            .timeout(const Duration(seconds: 15));
        docId = docRef.id;
        cloudSaved = true;
      } catch (e) {
        debugPrint('CloudSyncService: Cloud submission timed out or failed ($e). Saving locally.');
      }
    }

    final updatedReq = req.copyWith(
      id: docId,
      referenceCode: refCode,
      userId: user?.uid,
      userEmail: user?.email,
      status: cloudSaved ? 'قيد المراجعة' : 'محفوظ محلياً (بانتظار الإنترنت)',
      createdAt: now,
    );

    await LocalDbService.saveAssistanceRequest(updatedReq);
    _listenToLocalRequests();

    _knownRequestStatuses[docId] = 'قيد المراجعة';

    final userMessage = cloudSaved
        ? 'تم إرسال طلبك رسمياً إلى خوادم الهيئة برقم المرجع: $refCode'
        : 'تم حفظ طلبك محلياً على جهازك برقم المرجع: $refCode (سيتم رفعه تلقائياً فور توفر الإنترنت)';

    _addNotification(
      AppNotificationItem(
        id: 'notif_${now.millisecondsSinceEpoch}',
        title: cloudSaved ? 'تم إرسال طلب المساعدة سحابياً' : 'تم حفظ طلب المساعدة محلياً',
        body: cloudSaved
            ? 'تم إرسال طلبك برقم مرجعي: $refCode إلى الهيئة العامة للزكاة بنجاح.'
            : 'تم حفظ طلبك برقم مرجعي: $refCode محلياً على جهازك، وسيتم رفعه تلقائياً فور توفر الإنترنت.',
        type: 'request',
        timestamp: now,
        targetId: docId,
      ),
    );

    return RequestSubmissionResult(
      referenceCode: refCode,
      isCloudSaved: cloudSaved,
      userMessage: userMessage,
    );
  }

  void _addNotification(AppNotificationItem item) {
    // FIX: منع التكرار بنفس الإشعار
    if (_notifications.any((n) => n.id == item.id)) return;
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
    _generalSettingsSub?.cancel();
    for (final sub in _localRequestSubs) {
      sub.cancel();
    }
    _localRequestSubs.clear();
    super.dispose();
  }
}
