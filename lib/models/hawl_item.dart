import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import 'package:flutter/material.dart';

class HawlItem {
  final String id;
  final String title; // اسم الوعاء، مثل: "حساب التوفير - بنك التضامن"
  final String categoryKey; // 'money', 'gold', 'trade', 'crypto', 'stocks', 'livestock', 'crops', 'other'
  final String categoryName; // e.g. "النقود والمدخرات", "الذهب والفضة", "عروض التجارة", etc.
  final DateTime startDate; // تاريخ بدء الحول (بلوغ النصاب)
  final double? estimatedAmount; // المبلغ المقدر عند بدء الحول
  final String? currency;
  final String? notes;
  final DateTime createdAt;

  static const int lunarYearDays = 354;
  static const double lunarYearDaysExact = 354.37;
  static const int nearingThresholdDays = 30;

  HawlItem({
    required this.id,
    required this.title,
    required this.categoryKey,
    required this.categoryName,
    required this.startDate,
    this.estimatedAmount,
    this.currency,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get daysPassed {
    final diff = DateTime.now().difference(startDate).inDays;
    return diff < 0 ? 0 : diff;
  }

  int get daysRemaining {
    final remaining = lunarYearDays - daysPassed;
    return remaining < 0 ? 0 : remaining;
  }

  double get progressPercentage {
    final progress = daysPassed / lunarYearDaysExact;
    return progress > 1.0 ? 1.0 : (progress < 0 ? 0.0 : progress);
  }

  bool get isHawlCompleted => daysRemaining <= 0;

  bool get isNearingCompletion => !isHawlCompleted && daysRemaining <= nearingThresholdDays;

  DateTime get expectedDueDate => startDate.add(const Duration(days: lunarYearDays));

  String get hijriStartDateStr => AppFormatters.formatDate(startDate);
  String get hijriDueDateStr => AppFormatters.formatDate(expectedDueDate);

  IconData get icon {
    switch (categoryKey) {
      case 'gold':
        return Icons.diamond_outlined;
      case 'trade':
        return Icons.storefront_outlined;
      case 'crypto':
        return Icons.currency_bitcoin;
      case 'stocks':
        return Icons.trending_up;
      case 'livestock':
        return Icons.pets_outlined;
      case 'crops':
        return Icons.eco_outlined;
      case 'money':
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  Color get categoryColor {
    switch (categoryKey) {
      case 'gold':
        return AppColors.goldDark;
      case 'trade':
        return Colors.teal;
      case 'crypto':
        return Colors.deepOrange;
      case 'stocks':
        return Colors.indigo;
      case 'livestock':
        return Colors.brown;
      case 'crops':
        return Colors.green;
      case 'money':
      default:
        return AppColors.emeraldPrimary;
    }
  }

  HawlItem copyWith({
    String? id,
    String? title,
    String? categoryKey,
    String? categoryName,
    DateTime? startDate,
    double? estimatedAmount,
    String? currency,
    String? notes,
    DateTime? createdAt,
  }) {
    return HawlItem(
      id: id ?? this.id,
      title: title ?? this.title,
      categoryKey: categoryKey ?? this.categoryKey,
      categoryName: categoryName ?? this.categoryName,
      startDate: startDate ?? this.startDate,
      estimatedAmount: estimatedAmount ?? this.estimatedAmount,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'categoryKey': categoryKey,
      'categoryName': categoryName,
      'startDate': startDate.toIso8601String(),
      'estimatedAmount': estimatedAmount,
      'currency': currency,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory HawlItem.fromMap(Map<dynamic, dynamic> map) {
    return HawlItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      categoryKey: map['categoryKey']?.toString() ?? 'money',
      categoryName: map['categoryName']?.toString() ?? 'النقود والمدخرات',
      startDate: map['startDate'] != null
          ? DateTime.tryParse(map['startDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      estimatedAmount: map['estimatedAmount'] != null
          ? double.tryParse(map['estimatedAmount'].toString())
          : null,
      currency: map['currency']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
