class ZakatRecord {
  final String id;
  final String typeName; // e.g. 'زكاة المال', 'زكاة الذهب', 'زكاة الإبل'
  final String categoryKey; // e.g. 'money', 'gold', 'camel'
  final double totalWealth;
  final double zakatAmount;
  final String zakatInKindDescription; // e.g. 'شاه جذع' for livestock
  final String currency;
  final bool reachedNisab;
  final String notes;
  final DateTime date;

  ZakatRecord({
    required this.id,
    required this.typeName,
    required this.categoryKey,
    required this.totalWealth,
    required this.zakatAmount,
    this.zakatInKindDescription = '',
    required this.currency,
    required this.reachedNisab,
    this.notes = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'typeName': typeName,
      'categoryKey': categoryKey,
      'totalWealth': totalWealth,
      'zakatAmount': zakatAmount,
      'zakatInKindDescription': zakatInKindDescription,
      'currency': currency,
      'reachedNisab': reachedNisab,
      'notes': notes,
      'date': date.toIso8601String(),
    };
  }

  factory ZakatRecord.fromMap(Map<dynamic, dynamic> map) {
    return ZakatRecord(
      id: map['id']?.toString() ?? '',
      typeName: map['typeName']?.toString() ?? '',
      categoryKey: map['categoryKey']?.toString() ?? '',
      totalWealth: (map['totalWealth'] as num?)?.toDouble() ?? 0.0,
      zakatAmount: (map['zakatAmount'] as num?)?.toDouble() ?? 0.0,
      zakatInKindDescription: map['zakatInKindDescription']?.toString() ?? '',
      currency: map['currency']?.toString() ?? 'ر.ي',
      reachedNisab: map['reachedNisab'] == true,
      notes: map['notes']?.toString() ?? '',
      date: map['date'] != null
          ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
