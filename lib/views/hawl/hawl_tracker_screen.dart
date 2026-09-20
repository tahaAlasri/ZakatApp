import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/hijri_date_picker.dart';
import '../../core/utils/auth_guard.dart';
import '../../providers/hawl_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';

class HawlTrackerScreen extends StatefulWidget {
  const HawlTrackerScreen({super.key});

  @override
  State<HawlTrackerScreen> createState() => _HawlTrackerScreenState();
}

class _HawlTrackerScreenState extends State<HawlTrackerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final hawlProv = Provider.of<HawlProvider>(context, listen: false);
      final notifProv = Provider.of<NotificationProvider>(context, listen: false);
      if (hawlProv.isHawlCompleted && hawlProv.expectedDueDate != null) {
        await PermissionService.requestNotificationPermission();
        await notifProv.notifyHawlCompleted(
          dueDateStr: AppFormatters.formatDate(hawlProv.expectedDueDate!),
        );
      }
    });
  }

  void _pickStartDate(BuildContext context) async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (!authProv.isAuthenticated) {
      final isAuth = await AuthGuard.requireAuth(
        context,
        title: 'حساب الحول الذكي',
        message: 'يتطلب ضبط متتبع الحول الهجري تسجيل الدخول لحفظ تاريخ بلوغ النصاب وتفعيل التنبيهات الشرعية باسمك.',
        icon: Icons.timer_outlined,
      );
      if (!isAuth) return;
      if (!context.mounted) return;
    }

    final hawlProv = Provider.of<HawlProvider>(context, listen: false);
    final picked = await showHijriDatePicker(
      context: context,
      initialDate: hawlProv.startDate ?? DateTime.now(),
      title: 'اختر تاريخ بلوغ النصاب بالهجري',
    );

    if (picked != null) {
      if (!context.mounted) return;
      final hawlProv = Provider.of<HawlProvider>(context, listen: false);
      final notifProv = Provider.of<NotificationProvider>(context, listen: false);

      await hawlProv.setHawlStartDate(picked);

      // Request notification permission & schedule smart background alerts
      await PermissionService.requestNotificationPermission();
      if (hawlProv.isHawlCompleted) {
        await notifProv.notifyHawlCompleted(
          dueDateStr: AppFormatters.formatDate(hawlProv.expectedDueDate!),
        );
      } else {
        await notifProv.sendHawlAlert(
          daysRemaining: hawlProv.daysRemaining,
          dueDateStr: AppFormatters.formatDate(hawlProv.expectedDueDate!),
        );

        // Schedule background reminders (30 days before, 7 days before, and due date)
        if (hawlProv.expectedDueDate != null) {
          await notifProv.scheduleHawlMilestones(
            dueDate: hawlProv.expectedDueDate!,
            dueDateStr: AppFormatters.formatDate(hawlProv.expectedDueDate!),
          );
        }
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hawlProv.isHawlCompleted
                ? 'تم ضبط تاريخ النصاب، وتم إرسال إشعار وجوب الزكاة اليوم إلى شريط التنبيهات!'
                : 'تم ضبط تاريخ النصاب وتفعيل الجدولة التلقائية للتنبيهات (قبل شهر، أسبوع، ويوم الحلول)!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _shareHawlStatus(HawlProvider hawl) {
    if (hawl.startDate == null) return;
    final buffer = StringBuffer();
    buffer.writeln('⏳ *تذكير الحول الشرعي للزكاة - الهيئة العامة للزكاة* ⏳');
    buffer.writeln('────────────────────');
    buffer.writeln('📅 *تاريخ بدء الحول:* ${AppFormatters.formatDate(hawl.startDate!)}');
    buffer.writeln('🎯 *موعد تمام الحول:* ${AppFormatters.formatDate(hawl.expectedDueDate!)}');
    if (hawl.isHawlCompleted) {
      buffer.writeln('📢 *الحالة:* اكتمل الحول القمري (354 يوماً) والزكاة واجبة الإخراج الآن! ✅');
    } else {
      buffer.writeln('⏳ *الأيام المتبقية:* ${hawl.daysRemaining} يوماً');
    }
    buffer.writeln('────────────────────');
    buffer.writeln('تم الضبط عبر تطبيق *الهيئة العامة للزكاة*');

    PdfService.shareLetterText(
      subject: 'تذكير موعد الحول الشرعي للزكاة',
      letterText: buffer.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);

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
                if (!authProv.isAuthenticated)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.goldAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, color: AppColors.goldDark, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'تسجيل الحساب مطلوب لضبط الحول',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                authProv.hasAccountOnDevice
                                    ? 'لديك حساب مسجل! يمكنك الدخول بالمصادقة لحفظ تنبيهات الحول.'
                                    : 'سجل دخولك أو أنشئ حساباً لحفظ تاريخ النصاب وتلقي التنبيهات.',
                                style: const TextStyle(fontSize: 11, color: Colors.brown),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => AuthGuard.requireAuth(
                            context,
                            title: 'حساب الحول الذكي',
                            message: 'يتطلب متتبع الحول الهجري تسجيل الدخول لحفظ تاريخ النصاب والتنبيهات باسمك.',
                            icon: Icons.timer_outlined,
                          ),
                          child: Text(
                            authProv.hasAccountOnDevice ? 'دخول / مصادقة' : 'تسجيل الدخول',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.emeraldPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
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

                // Main Hawl Display Card
                if (!hasDate)
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_month, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'لم يتم تحديد موعد بدء الحول بعد',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'سجل اليوم الذي بلغت فيه أموالك النصاب ليقوم التطبيق بمتابعة الحول الهجري وتنبيهك آلياً.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _pickStartDate(context),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('تسجيل تاريخ بلوغ النصاب'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: hawl.isHawlCompleted ? AppColors.goldAccent.withValues(alpha: 0.2) : AppColors.emeraldSubtle,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: hawl.isHawlCompleted ? AppColors.goldDark : AppColors.emeraldPrimary,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hawl.isHawlCompleted ? Icons.check_circle : Icons.hourglass_top,
                                  size: 18,
                                  color: hawl.isHawlCompleted ? AppColors.goldDark : AppColors.emeraldPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  hawl.isHawlCompleted ? 'اكتمل الحول الشرعي' : 'الحول جارٍ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: hawl.isHawlCompleted ? AppColors.goldDark : AppColors.emeraldDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Days Counter
                          Text(
                            hawl.isHawlCompleted ? '0' : '${hawl.daysRemaining}',
                            style: TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.bold,
                              color: hawl.isHawlCompleted ? AppColors.goldDark : AppColors.emeraldPrimary,
                            ),
                          ),
                          Text(
                            hawl.isHawlCompleted ? 'الزكاة واجبة الإخراج الآن' : 'يوماً متبقياً لاكتمال الحول',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 20),

                          // Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: hawl.progressPercentage,
                              minHeight: 12,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                hawl.isHawlCompleted ? AppColors.goldDark : AppColors.emeraldPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'مضى ${(hawl.progressPercentage * 100).toStringAsFixed(1)}% من الحول الهجري (354 يوماً)',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 24),

                          // Dates Detail Box
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
                          const SizedBox(height: 20),

                          if (hawl.isHawlCompleted) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await PermissionService.requestNotificationPermission();
                                  if (!context.mounted) return;
                                  final notifProv = Provider.of<NotificationProvider>(context, listen: false);
                                  await notifProv.notifyHawlCompleted(
                                    dueDateStr: AppFormatters.formatDate(hawl.expectedDueDate!),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('تم إرسال إشعار "اليوم موعد إخراج الزكاة" إلى شريط التنبيهات!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.goldDark,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                                label: const Text(
                                  'إرسال إشعار تذكير: اليوم موعد إخراج الزكاة',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

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
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _shareHawlStatus(hawl),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.emeraldSubtle,
                                  foregroundColor: AppColors.emeraldPrimary,
                                  padding: const EdgeInsets.all(12),
                                ),
                                icon: const Icon(Icons.share_outlined),
                                tooltip: 'مشاركة تذكير الحول عبر واتساب',
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('تأكيد إعادة الضبط'),
                                          ],
                                        ),
                                        content: const Text(
                                          'هل أنت متأكد من رغبتك في إعادة ضبط متتبع الحول وحذف التاريخ المسجل وإلغاء التنبيهات المجدولة؟',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('إلغاء'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('إعادة ضبط'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      await hawl.resetHawl();
                                      if (!context.mounted) return;
                                      await Provider.of<NotificationProvider>(context, listen: false).cancelHawlAlerts();
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('تمت إعادة ضبط متتبع الحول وإلغاء التنبيهات بنجاح'),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: Colors.black87,
                                        ),
                                      );
                                    }
                                  },
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
