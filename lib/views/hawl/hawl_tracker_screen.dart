import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/permission_service.dart';
import '../../core/utils/formatters.dart';
import '../../providers/hawl_provider.dart';
import '../../providers/notification_provider.dart';

class HawlTrackerScreen extends StatelessWidget {
  const HawlTrackerScreen({super.key});

  void _pickStartDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 400)),
      lastDate: now,
      helpText: 'اختر تاريخ بلوغ أموالك النصاب الشرعي',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );

    if (picked != null) {
      if (!context.mounted) return;
      final hawlProv = Provider.of<HawlProvider>(context, listen: false);
      final notifProv = Provider.of<NotificationProvider>(context, listen: false);

      await hawlProv.setHawlStartDate(picked);

      // Request notification permission & send alert
      await PermissionService.requestNotificationPermission();
      await notifProv.sendHawlAlert(
        daysRemaining: hawlProv.daysRemaining,
        dueDateStr: AppFormatters.formatDate(hawlProv.expectedDueDate!),
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم ضبط تاريخ النصاب وإرسال إشعار تذكير الحول إلى شريط التنبيهات!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('متتبع الحول الهجري الذكي'),
      ),
      body: Consumer<HawlProvider>(
        builder: (context, hawl, _) {
          final hasDate = hawl.startDate != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            color: AppColors.emeraldSubtle,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.alarm_on_outlined, color: AppColors.emeraldPrimary, size: 30),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'شرط تمام الحول (354 يوماً)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'لا تجب الزكاة في الأموال حتى يحول عليها حول قمري كامل من وقت بلوغ النصاب.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (!hasDate) ...[
                  // Not configured yet
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.event_note, size: 70, color: AppColors.goldAccent),
                          const SizedBox(height: 16),
                          const Text(
                            'لم تقم بتحديد تاريخ النصاب بعد',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'حدد تاريخ اليوم الذي بلغ فيه مالك النصاب ليتتبع التطبيق الأيام المتبقية تلقائياً.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _pickStartDate(context),
                            icon: const Icon(Icons.calendar_month),
                            label: const Text('تحديد تاريخ النصاب الآن'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Progress Card
                  Card(
                    color: hawl.isHawlCompleted ? Colors.amber.shade50 : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: hawl.isHawlCompleted ? AppColors.goldDark : AppColors.emeraldPrimary.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: hawl.isHawlCompleted ? AppColors.goldAccent : AppColors.emeraldSubtle,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              hawl.isHawlCompleted ? '🎉 اكتمل الحول الشرعي - الزكاة واجبة الآن' : 'الحول جارٍ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: hawl.isHawlCompleted ? Colors.black : AppColors.emeraldPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Circular Progress
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 170,
                                height: 170,
                                child: CircularProgressIndicator(
                                  value: hawl.progressPercentage,
                                  strokeWidth: 14,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    hawl.isHawlCompleted ? AppColors.goldAccent : AppColors.emeraldPrimary,
                                  ),
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    hawl.isHawlCompleted ? '0' : '${hawl.daysRemaining}',
                                    style: const TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.emeraldDark,
                                    ),
                                  ),
                                  Text(
                                    hawl.isHawlCompleted ? 'يوم متبقي' : 'يوماً متبقياً',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Details Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('تاريخ البدء', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppFormatters.formatDate(hawl.startDate!),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              Container(height: 30, width: 1, color: Colors.grey.shade300),
                              Column(
                                children: [
                                  const Text('موعد تمام الحول', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    AppFormatters.formatDate(hawl.expectedDueDate!),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.goldDark),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Actions
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickStartDate(context),
                                  icon: const Icon(Icons.edit_calendar),
                                  label: const Text('تعديل التاريخ'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () => hawl.resetHawl(),
                                  icon: const Icon(Icons.restart_alt, color: Colors.red),
                                  label: const Text('إعادة ضبط', style: TextStyle(color: Colors.red)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
