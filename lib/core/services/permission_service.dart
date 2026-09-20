import 'package:permission_handler/permission_handler.dart';

class PermissionItem {
  final Permission permission;
  final String title;
  final String description;
  PermissionStatus status;

  PermissionItem({
    required this.permission,
    required this.title,
    required this.description,
    this.status = PermissionStatus.denied,
  });
}

class PermissionService {
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static Future<bool> requestStoragePermission() async {
    if (await Permission.storage.request().isGranted) {
      return true;
    }
    // For Android 13+ photos
    final photos = await Permission.photos.request();
    return photos.isGranted;
  }

  static Future<List<PermissionItem>> getAppPermissions() async {
    final notificationStatus = await Permission.notification.status;
    var storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      final photosStatus = await Permission.photos.status;
      if (photosStatus.isGranted) {
        storageStatus = photosStatus;
      }
    }
    final cameraStatus = await Permission.camera.status;

    return [
      PermissionItem(
        permission: Permission.notification,
        title: 'صلاحية الإشعارات والتنبيهات',
        description: 'تُستخدم لتنبيهك عند اكتمال الحول الهجري ومواقيت إخراج الزكاة.',
        status: notificationStatus,
      ),
      PermissionItem(
        permission: Permission.storage,
        title: 'صلاحية حفظ الملفات والتقارير',
        description: 'تُستخدم لحفظ شهادات وإقرارات الزكاة بصيغة PDF على جهازك.',
        status: storageStatus,
      ),
      PermissionItem(
        permission: Permission.camera,
        title: 'صلاحية الكاميرا والصور',
        description: 'تُستخدم لالتقاط وتحديد صورة حسابك الشخصي أو إرفاق مستندات المساعدة.',
        status: cameraStatus,
      ),
    ];
  }

  static Future<PermissionStatus> requestPermission(Permission permission) async {
    if (permission == Permission.storage) {
      final status = await Permission.storage.request();
      if (status.isGranted) return status;
      return await Permission.photos.request();
    }
    return await permission.request();
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
