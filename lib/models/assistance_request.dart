import 'dart:typed_data';
import '../core/services/encryption_service.dart';

class AssistanceRequest {
  final String id;
  final String? referenceCode;
  final String? userId;
  final String? userEmail;
  final String subject;
  final String fullName;
  final String address;
  final String phone;
  final String? idNumber; // رقم الهوية اختياري ومحمي
  final String details;
  final String status; // 'قيد المراجعة', 'قيد الدراسة', 'تمت الموافقة', 'مرفوض', 'جاهز للصرف'
  final String? adminResponse; // رد الإدارة الرسمي
  final bool saveIdLocally; // هل تم السماح بحفظ رقم الهوية محلياً على الجهاز
  final bool isEncrypted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AssistanceRequest({
    required this.id,
    this.referenceCode,
    this.userId,
    this.userEmail,
    required this.subject,
    required this.fullName,
    required this.address,
    required this.phone,
    this.idNumber,
    required this.details,
    this.status = 'قيد المراجعة',
    this.adminResponse,
    this.saveIdLocally = false,
    this.isEncrypted = false,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String generateFormalLetter() {
    final idText = (idNumber != null && idNumber!.trim().isNotEmpty)
        ? idNumber!.trim()
        : 'مُقدم عند المراجعة الرسمية';
    final ref = referenceCode != null ? ' (رقم التتبع: $referenceCode)' : '';

    return '''بسم الله الرحمن الرحيم
الأخ رئيس الهيئة العامة للزكاة                                            المحترم
تحية طيبة... وبعد،،،

الموضوع/ $subject$ref

نص الرسالة:
$details

معلومات مقدم الطلب:
الاسم: $fullName
العنوان: $address
رقم الجوال: $phone
رقم البطاقة الشخصية: $idText
التاريخ: ${createdAt.year}/${createdAt.month}/${createdAt.day}
''';
  }

  Map<String, dynamic> toMap({Uint8List? encryptionKey}) {
    final bool shouldEncrypt = encryptionKey != null;
    final storedId = saveIdLocally ? idNumber : null;

    final resolvedAddress = shouldEncrypt && address.isNotEmpty
        ? EncryptionService.encryptString(address, encryptionKey)
        : address;

    final resolvedDetails = shouldEncrypt && details.isNotEmpty
        ? EncryptionService.encryptString(details, encryptionKey)
        : details;

    final resolvedId = shouldEncrypt && storedId != null && storedId.isNotEmpty
        ? EncryptionService.encryptString(storedId, encryptionKey)
        : storedId;

    final map = <String, dynamic>{
      'id': id,
      'referenceCode': referenceCode ?? id,
      if (userId != null) 'userId': userId,
      if (userEmail != null) 'userEmail': userEmail,
      'subject': subject,
      'fullName': fullName,
      'address': resolvedAddress,
      'phone': phone,
      'details': resolvedDetails,
      'status': status,
      if (adminResponse != null) 'adminResponse': adminResponse,
      'saveIdLocally': saveIdLocally,
      'isEncrypted': shouldEncrypt,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };

    if (saveIdLocally && resolvedId != null && resolvedId.isNotEmpty) {
      map['idNumber'] = resolvedId;
    } else if (idNumber != null && !shouldEncrypt) {
      // For cloud sync when authorized
      map['idNumber'] = idNumber;
    }

    return map;
  }

  factory AssistanceRequest.fromMap(Map<dynamic, dynamic> map, {Uint8List? encryptionKey}) {
    final bool isEnc = map['isEncrypted'] == true;
    String rawAddress = map['address']?.toString() ?? '';
    String rawDetails = map['details']?.toString() ?? '';
    String? rawIdNumber = map['idNumber']?.toString();

    if (isEnc && encryptionKey != null) {
      rawAddress = EncryptionService.decryptString(rawAddress, encryptionKey);
      rawDetails = EncryptionService.decryptString(rawDetails, encryptionKey);
      if (rawIdNumber != null && rawIdNumber.isNotEmpty) {
        rawIdNumber = EncryptionService.decryptString(rawIdNumber, encryptionKey);
      }
    }

    return AssistanceRequest(
      id: map['id']?.toString() ?? '',
      referenceCode: map['referenceCode']?.toString() ?? map['id']?.toString(),
      userId: map['userId']?.toString(),
      userEmail: map['userEmail']?.toString(),
      subject: map['subject']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? '',
      address: rawAddress,
      phone: map['phone']?.toString() ?? '',
      idNumber: rawIdNumber,
      details: rawDetails,
      status: map['status']?.toString() ?? 'قيد المراجعة',
      adminResponse: map['adminResponse']?.toString(),
      saveIdLocally: map['saveIdLocally'] == true,
      isEncrypted: isEnc,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  AssistanceRequest copyWith({
    String? id,
    String? referenceCode,
    String? userId,
    String? userEmail,
    String? subject,
    String? fullName,
    String? address,
    String? phone,
    String? idNumber,
    String? details,
    String? status,
    String? adminResponse,
    bool? saveIdLocally,
    bool? isEncrypted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssistanceRequest(
      id: id ?? this.id,
      referenceCode: referenceCode ?? this.referenceCode,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      subject: subject ?? this.subject,
      fullName: fullName ?? this.fullName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      idNumber: idNumber ?? this.idNumber,
      details: details ?? this.details,
      status: status ?? this.status,
      adminResponse: adminResponse ?? this.adminResponse,
      saveIdLocally: saveIdLocally ?? this.saveIdLocally,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
