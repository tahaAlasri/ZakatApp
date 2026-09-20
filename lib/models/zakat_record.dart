class ZakatRecord {
  final String id;
  final String? userId; // معرف المستخدم المرتبط بالسجل
  final String typeName; // e.g. 'زكاة المال', 'زكاة الذهب', 'زكاة الإبل'
  final String categoryKey; // e.g. 'money', 'gold', 'camel'
  final double totalWealth;
  final double zakatAmount;
  final String zakatInKindDescription; // e.g. 'شاه جذع' for livestock
  final String currency;
  final bool reachedNisab;
  final String notes;
  final double? appliedPrice; // السعر المطبق للوحدة أو الجرام وقت العملية
  final double? nisabThreshold; // قيمة النصاب المالي المعتمد وقت العملية
  final int? goldKarat; // عيار الذهب في حال كانت العملية زكاة ذهب
  final double? exchangeRate; // سعر الصرف المعتمد للتحويل وقت العملية
  final String? priceSource; // مصدر السعر المعتمد (مثال: 'يدوي', 'البنك المركزي')
  final DateTime? priceUpdatedAt; // تاريخ ووقت اعتماد أو تحديث السعر
  final Map<String, dynamic> inputs; // كافة المدخلات التي أدت إلى النتيجة
  final String calculationPolicy; // السياسة أو المنهج الفقهي المعتمد للحساب
  final DateTime date;

  ZakatRecord({
    required this.id,
    this.userId,
    required this.typeName,
    required this.categoryKey,
    required this.totalWealth,
    required this.zakatAmount,
    this.zakatInKindDescription = '',
    required this.currency,
    required this.reachedNisab,
    this.notes = '',
    this.appliedPrice,
    this.nisabThreshold,
    this.goldKarat,
    this.exchangeRate,
    this.priceSource = 'يدوي',
    this.priceUpdatedAt,
    this.inputs = const {},
    this.calculationPolicy = 'السياسة الشرعية المعتمدة',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'typeName': typeName,
      'categoryKey': categoryKey,
      'totalWealth': totalWealth,
      'zakatAmount': zakatAmount,
      'zakatInKindDescription': zakatInKindDescription,
      'currency': currency,
      'reachedNisab': reachedNisab,
      'notes': notes,
      'appliedPrice': appliedPrice,
      'nisabThreshold': nisabThreshold,
      'goldKarat': goldKarat,
      'exchangeRate': exchangeRate,
      'priceSource': priceSource,
      'priceUpdatedAt': priceUpdatedAt?.toIso8601String(),
      'inputs': inputs,
      'calculationPolicy': calculationPolicy,
      'date': date.toIso8601String(),
    };
  }

  factory ZakatRecord.fromMap(Map<dynamic, dynamic> map) {
    return ZakatRecord(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString(),
      typeName: map['typeName']?.toString() ?? '',
      categoryKey: map['categoryKey']?.toString() ?? '',
      totalWealth: (map['totalWealth'] as num?)?.toDouble() ?? 0.0,
      zakatAmount: (map['zakatAmount'] as num?)?.toDouble() ?? 0.0,
      zakatInKindDescription: map['zakatInKindDescription']?.toString() ?? '',
      currency: map['currency']?.toString() ?? 'ر.ي',
      reachedNisab: map['reachedNisab'] == true,
      notes: map['notes']?.toString() ?? '',
      appliedPrice: (map['appliedPrice'] as num?)?.toDouble(),
      nisabThreshold: (map['nisabThreshold'] as num?)?.toDouble(),
      goldKarat: (map['goldKarat'] as num?)?.toInt(),
      exchangeRate: (map['exchangeRate'] as num?)?.toDouble(),
      priceSource: map['priceSource']?.toString() ?? 'يدوي',
      priceUpdatedAt: map['priceUpdatedAt'] != null
          ? DateTime.tryParse(map['priceUpdatedAt'].toString())
          : null,
      inputs: map['inputs'] != null && map['inputs'] is Map
          ? Map<String, dynamic>.from(map['inputs'] as Map)
          : {},
      calculationPolicy: map['calculationPolicy']?.toString() ?? 'السياسة الشرعية المعتمدة',
      date: map['date'] != null
          ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  ZakatRecord copyWith({
    String? id,
    String? userId,
    String? typeName,
    String? categoryKey,
    double? totalWealth,
    double? zakatAmount,
    String? zakatInKindDescription,
    String? currency,
    bool? reachedNisab,
    String? notes,
    double? appliedPrice,
    double? nisabThreshold,
    int? goldKarat,
    double? exchangeRate,
    String? priceSource,
    DateTime? priceUpdatedAt,
    Map<String, dynamic>? inputs,
    String? calculationPolicy,
    DateTime? date,
  }) {
    return ZakatRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      typeName: typeName ?? this.typeName,
      categoryKey: categoryKey ?? this.categoryKey,
      totalWealth: totalWealth ?? this.totalWealth,
      zakatAmount: zakatAmount ?? this.zakatAmount,
      zakatInKindDescription: zakatInKindDescription ?? this.zakatInKindDescription,
      currency: currency ?? this.currency,
      reachedNisab: reachedNisab ?? this.reachedNisab,
      notes: notes ?? this.notes,
      appliedPrice: appliedPrice ?? this.appliedPrice,
      nisabThreshold: nisabThreshold ?? this.nisabThreshold,
      goldKarat: goldKarat ?? this.goldKarat,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      priceSource: priceSource ?? this.priceSource,
      priceUpdatedAt: priceUpdatedAt ?? this.priceUpdatedAt,
      inputs: inputs ?? this.inputs,
      calculationPolicy: calculationPolicy ?? this.calculationPolicy,
      date: date ?? this.date,
    );
  }
}
