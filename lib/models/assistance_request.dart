class AssistanceRequest {
  final String id;
  final String subject;
  final String fullName;
  final String address;
  final String phone;
  final String idNumber;
  final String details;
  final String status; // 'قيد المراجعة', 'تمت الموافقة', 'مكتمل'
  final DateTime createdAt;

  AssistanceRequest({
    required this.id,
    required this.subject,
    required this.fullName,
    required this.address,
    required this.phone,
    required this.idNumber,
    required this.details,
    this.status = 'قيد المراجعة',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String generateFormalLetter() {
    return '''بسم الله الرحمن الرحيم
الأخ رئيس الهيئة العامة للزكاة                                            المحترم
تحية طيبة... وبعد،،،

الموضوع/ $subject

نص الرسالة:
$details

معلومات مقدم الطلب:
الاسم: $fullName
العنوان: $address
رقم الجوال: $phone
رقم البطاقة الشخصية: $idNumber
التاريخ: ${createdAt.year}/${createdAt.month}/${createdAt.day}
''';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subject,
      'fullName': fullName,
      'address': address,
      'phone': phone,
      'idNumber': idNumber,
      'details': details,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AssistanceRequest.fromMap(Map<dynamic, dynamic> map) {
    return AssistanceRequest(
      id: map['id']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      idNumber: map['idNumber']?.toString() ?? '',
      details: map['details']?.toString() ?? '',
      status: map['status']?.toString() ?? 'قيد المراجعة',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
