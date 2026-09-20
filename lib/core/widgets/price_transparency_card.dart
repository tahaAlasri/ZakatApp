import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/market_price_service.dart';

class PriceTransparencyCard extends StatelessWidget {
  final PriceSnapshot snapshot;
  final bool isNearNisab;
  final bool isPriceConfirmed;
  final VoidCallback? onConfirmPrice;
  final VoidCallback? onEditPrice;

  const PriceTransparencyCard({
    super.key,
    required this.snapshot,
    this.isNearNisab = false,
    this.isPriceConfirmed = false,
    this.onConfirmPrice,
    this.onEditPrice,
  });

  String _formatDateTime(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Market Price Source & Timestamp Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          color: Colors.grey.shade50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      snapshot.isFallback ? Icons.store_mall_directory_outlined : Icons.language,
                      size: 18,
                      color: AppColors.emeraldPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'المصدر: ${snapshot.source}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: snapshot.isFallback
                            ? Colors.blueGrey.shade100
                            : AppColors.emeraldLight.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        snapshot.isFallback ? 'سعر إقليمي' : 'سوق لحظي',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: snapshot.isFallback ? Colors.blueGrey.shade800 : AppColors.emeraldDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'آخر تحديث: ${_formatDateTime(snapshot.updatedAt)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                // Exchange Rate Pegged Alert
                if (snapshot.isExchangeRateFixed && snapshot.exchangeRateNote != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            snapshot.exchangeRateNote!,
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Silver Estimation Alert
                if (snapshot.isSilverEstimated && snapshot.silverNote != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_outlined, size: 16, color: Colors.orange.shade800),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            snapshot.silverNote!,
                            style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Near-Nisab Price Confirmation Box
        if (isNearNisab) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPriceConfirmed ? AppColors.emeraldLight.withValues(alpha: 0.15) : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPriceConfirmed ? AppColors.emeraldPrimary : Colors.amber.shade400,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isPriceConfirmed ? Icons.check_circle_outline : Icons.notification_important_outlined,
                      color: isPriceConfirmed ? AppColors.emeraldPrimary : Colors.amber.shade900,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isPriceConfirmed
                            ? 'تم تأكيد دقة السعر المعتمد لحساب النصاب'
                            : 'تنبيه: المبلغ المدخل قريب جداً من حد النصاب الشرعي',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isPriceConfirmed ? AppColors.emeraldPrimary : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isPriceConfirmed
                      ? 'تم التحقق من مطابقة السعر لسوق اليوم واعتماده لاحتساب الفريضة بدقة.'
                      : 'نظراً لأن تغير سعر الذهب قد يغيّر وجوب الزكاة، يُشترط التأكد من دقة سعر السوق اليوم وتأكيده قبل اعتماد الحساب.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isPriceConfirmed ? Colors.grey.shade800 : Colors.amber.shade900,
                  ),
                ),
                if (!isPriceConfirmed && onConfirmPrice != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      key: const Key('btn_confirm_price_near_nisab'),
                      onPressed: onConfirmPrice,
                      icon: const Icon(Icons.verified_outlined, size: 18),
                      label: const Text('أؤكد دقة السعر الحالي للمتابعة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
