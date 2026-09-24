import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/hijri_date_picker.dart';
import '../../core/utils/auth_guard.dart';
import '../../core/utils/responsive_helper.dart';
import '../../models/hawl_item.dart';
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

  static const List<Map<String, String>> _categories = [
    {'key': 'money', 'name': 'النقود والمدخرات'},
    {'key': 'gold', 'name': 'الذهب والفضة'},
    {'key': 'trade', 'name': 'عروض التجارة'},
    {'key': 'crypto', 'name': 'العملات الرقمية المشفرة'},
    {'key': 'stocks', 'name': 'الأسهم والاستثمارات'},
    {'key': 'livestock', 'name': 'الأنعام والمواشي'},
    {'key': 'crops', 'name': 'الزروع والثمار'},
    {'key': 'other', 'name': 'أصول وأموال أخرى'},
  ];

  Future<void> _openAddEditHawlDialog(BuildContext context, [HawlItem? existing]) async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (!authProv.isAuthenticated) {
      final isAuth = await AuthGuard.requireAuth(
        context,
        title: 'حساب الحول الذكي',
        message: 'يتطلب متتبع الحول الهجري تسجيل الدخول لحفظ تاريخ النصاب وتفعيل التنبيهات الشرعية لأموالك.',
        icon: Icons.timer_outlined,
      );
      if (!isAuth) return;
      if (!context.mounted) return;
    }

    final titleController = TextEditingController(text: existing?.title ?? '');
    final amountController = TextEditingController(
      text: existing?.estimatedAmount != null ? existing!.estimatedAmount!.toStringAsFixed(0) : '',
    );
    final notesController = TextEditingController(text: existing?.notes ?? '');
    String selectedCategoryKey = existing?.categoryKey ?? 'money';
    DateTime selectedDate = existing?.startDate ?? DateTime.now();

    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            final categoryName = _categories.firstWhere(
              (c) => c['key'] == selectedCategoryKey,
              orElse: () => _categories.first,
            )['name']!;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: EdgeInsets.zero,
              content: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                width: double.maxFinite,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: isDark ? AppColors.darkSurface : Colors.white,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              existing == null ? Icons.add_alarm_rounded : Icons.edit_calendar_rounded,
                              color: AppColors.goldAccent,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                existing == null ? 'إضافة حول لوعاء مال جديد' : 'تعديل بيانات الحول',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Form Body
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Asset Title Field
                              TextFormField(
                                controller: titleController,
                                decoration: InputDecoration(
                                  labelText: 'اسم وعاء المال أو الحساب *',
                                  hintText: 'مثال: حساب التوفير، ذهب عيار 21، متجر الأقمشة',
                                  prefixIcon: const Icon(Icons.label_outline, color: AppColors.emeraldPrimary),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'يرجى إدخال اسم الوعاء أو الحساب';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Category Dropdown
                              DropdownButtonFormField<String>(
                                value: selectedCategoryKey,
                                isExpanded: true,
                                isDense: true,
                                decoration: InputDecoration(
                                  labelText: 'نوع الأصل الزكوي',
                                  prefixIcon: const Icon(Icons.category_outlined, color: AppColors.emeraldPrimary),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: _categories.map((c) {
                                  return DropdownMenuItem<String>(
                                    value: c['key'],
                                    child: Text(
                                      c['name']!,
                                      style: const TextStyle(fontSize: 14),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => selectedCategoryKey = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),

                              // Estimated Amount Field (Optional)
                              TextFormField(
                                controller: amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'المبلغ / القيمة التقديرية (اختياري)',
                                  hintText: 'مثال: 2500000',
                                  prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.emeraldPrimary),
                                  suffixText: 'ر.ي',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Start Date Selector (Hijri Picker)
                              InkWell(
                                onTap: () async {
                                  final picked = await showHijriDatePicker(
                                    context: dialogCtx,
                                    initialDate: selectedDate,
                                    title: 'اختر تاريخ بلوغ النصاب بالهجري',
                                  );
                                  if (picked != null) {
                                    setDialogState(() => selectedDate = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.5)),
                                    borderRadius: BorderRadius.circular(12),
                                    color: AppColors.emeraldSubtle.withValues(alpha: 0.3),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_month, color: AppColors.emeraldPrimary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'تاريخ بدء الحول (بلوغ النصاب):',
                                              style: TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              AppFormatters.formatDate(selectedDate),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: AppColors.emeraldPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.emeraldPrimary),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Notes Field (Optional)
                              TextFormField(
                                controller: notesController,
                                maxLines: 2,
                                decoration: InputDecoration(
                                  labelText: 'ملاحظات إضافية (اختياري)',
                                  hintText: 'أي تفاصيل عن مصدر المال أو الحساب...',
                                  prefixIcon: const Icon(Icons.notes, color: AppColors.emeraldPrimary),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Dialog Actions
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: const Text('إلغاء'),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;

                                final hawlProv = Provider.of<HawlProvider>(context, listen: false);
                                final notifProv = Provider.of<NotificationProvider>(context, listen: false);

                                final parsedAmount = double.tryParse(amountController.text.trim());
                                final newItem = HawlItem(
                                  id: existing?.id ?? 'hawl_${DateTime.now().millisecondsSinceEpoch}',
                                  title: titleController.text.trim(),
                                  categoryKey: selectedCategoryKey,
                                  categoryName: categoryName,
                                  startDate: selectedDate,
                                  estimatedAmount: parsedAmount,
                                  notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                                );

                                if (existing == null) {
                                  await hawlProv.addHawlItem(newItem);
                                } else {
                                  await hawlProv.updateHawlItem(newItem);
                                }

                                // Schedule smart alerts
                                await PermissionService.requestNotificationPermission();
                                if (newItem.isHawlCompleted) {
                                  await notifProv.notifyHawlCompleted(
                                    dueDateStr: newItem.hijriDueDateStr,
                                  );
                                } else {
                                  await notifProv.sendHawlAlert(
                                    daysRemaining: newItem.daysRemaining,
                                    dueDateStr: newItem.hijriDueDateStr,
                                  );
                                  await notifProv.scheduleHawlMilestones(
                                    dueDate: newItem.expectedDueDate,
                                    dueDateStr: newItem.hijriDueDateStr,
                                  );
                                }

                                if (!dialogCtx.mounted) return;
                                Navigator.pop(dialogCtx);

                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      existing == null
                                          ? 'تمت إضافة الحول بنجاح وتفعيل التنبيهات المجدولة!'
                                          : 'تم تحديث بيانات الحول بنجاح!',
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.emeraldPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.check, size: 18),
                              label: Text(
                                existing == null ? 'حفظ وتفعيل الحول' : 'تحديث الحول',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _shareHawlItem(HawlItem item) {
    final buffer = StringBuffer();
    buffer.writeln('⏳ *تذكير الحول الشرعي للزكاة - الهيئة العامة للزكاة* ⏳');
    buffer.writeln('────────────────────');
    buffer.writeln('🏷️ *وعاء المال:* ${item.title} (${item.categoryName})');
    if (item.estimatedAmount != null) {
      buffer.writeln('💰 *المبلغ التقديري:* ${AppFormatters.formatCurrency(item.estimatedAmount!)}');
    }
    buffer.writeln('📅 *تاريخ بدء الحول:* ${item.hijriStartDateStr}');
    buffer.writeln('🎯 *موعد تمام الحول:* ${item.hijriDueDateStr}');
    if (item.isHawlCompleted) {
      buffer.writeln('📢 *الحالة:* اكتمل الحول القمري (354 يوماً) والزكاة واجبة الإخراج الآن! ✅');
    } else {
      buffer.writeln('⏳ *الأيام المتبقية:* ${item.daysRemaining} يوماً');
    }
    buffer.writeln('────────────────────');
    buffer.writeln('تم الضبط عبر تطبيق *الهيئة العامة للزكاة*');

    PdfService.shareLetterText(
      subject: 'تذكير موعد الحول لـ ${item.title}',
      letterText: buffer.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('متتبع الأحوال الهجرية الذكي'),
        actions: [
          IconButton(
            onPressed: () => _openAddEditHawlDialog(context),
            tooltip: 'إضافة حول لوعاء مال جديد',
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: Consumer<HawlProvider>(
        builder: (context, hawl, _) {
          final items = hawl.items;

          return SingleChildScrollView(
            padding: context.rPadding(horizontal: 16, vertical: 16),
            child: ResponsiveConstraint(
              maxWidth: 760,
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

                // Statistics Strip
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: isDark ? AppColors.cardDarkGradient : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.access_time_filled, color: AppColors.goldAccent, size: 22),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'متابعة الأحوال المتعددة',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _openAddEditHawlDialog(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.goldAccent,
                              foregroundColor: AppColors.emeraldDark,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('إضافة حول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatBadge(
                              title: 'إجمالي الأوعية',
                              value: '${hawl.totalHawlsCount}',
                              icon: Icons.inventory_2_outlined,
                              color: Colors.white70,
                            ),
                          ),
                          Container(height: 35, width: 1, color: Colors.white24),
                          Expanded(
                            child: _buildStatBadge(
                              title: 'أحوال جارية',
                              value: '${hawl.activeHawlsCount}',
                              icon: Icons.hourglass_top,
                              color: AppColors.goldLight,
                            ),
                          ),
                          Container(height: 35, width: 1, color: Colors.white24),
                          Expanded(
                            child: _buildStatBadge(
                              title: 'أحوال اكتملت',
                              value: '${hawl.completedHawlsCount}',
                              icon: Icons.check_circle_outline,
                              color: Colors.greenAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // List of Hawl Items
                if (items.isEmpty)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_month, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'لم تسجل أي أحوال بعد',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'في الفقه الإسلامي، لكل مال مستقل بلغ النصاب حوله الخاص. يمكنك إضافة أحوال منفصلة للذهب، والمدخرات، والتجارة، والأصول المشفرة لمتابعة مواقيت وجوب زكاتها بدقة.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.6),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _openAddEditHawlDialog(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emeraldPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('تسجيل أول حول لمالك', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'الأوعية والأموال المسجلة (${items.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (items.length > 1)
                        TextButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('حذف جميع الأحوال'),
                                content: const Text('هل أنت متأكد من رغبتك في حذف كافة الأحوال المسجلة وإلغاء تنبيهاتها؟'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                    child: const Text('حذف الكل'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await hawl.resetHawl();
                              if (!context.mounted) return;
                              await Provider.of<NotificationProvider>(context, listen: false).cancelHawlAlerts();
                            }
                          },
                          icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red, size: 18),
                          label: const Text('حذف الكل', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...items.map((item) => _buildHawlCard(context, item, hawl)),
                ],

                const SizedBox(height: 20),

                // Fiqh Foundation Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.emeraldPrimary.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldSubtle,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.menu_book_outlined, color: AppColors.emeraldPrimary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'التأصيل الفقهي لتعدد الأحوال',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'قال أهل العلم: لكل مال مستفاد مستقل بلغ النصاب حوله الخاص من يوم ملكه، ولا يلزم ضم حول مال جديد إلى قديم، ويجوز للمزكي تعجيل إخراج زكاة المال الثاني مع الأول لتوحيد ميعاد الزكاة سنوياً تيسيراً وضبطاً.',
                                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _buildStatBadge({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildHawlCard(BuildContext context, HawlItem item, HawlProvider hawlProv) {
    final isCompleted = item.isHawlCompleted;
    final isNearing = item.isNearingCompletion;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isCompleted
              ? AppColors.goldDark
              : (isNearing ? AppColors.warning : AppColors.emeraldPrimary.withValues(alpha: 0.2)),
          width: isCompleted ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row: Category Icon + Title + Status Badge
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: item.categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.categoryColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            item.categoryName,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          if (item.estimatedAmount != null) ...[
                            Text(' • ', style: TextStyle(color: Colors.grey.shade400)),
                            Text(
                              AppFormatters.formatCurrency(item.estimatedAmount!),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.emeraldPrimary),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.goldAccent.withValues(alpha: 0.2)
                        : (isNearing ? AppColors.warning.withValues(alpha: 0.2) : AppColors.emeraldSubtle),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCompleted
                          ? AppColors.goldDark
                          : (isNearing ? AppColors.warning : AppColors.emeraldPrimary.withValues(alpha: 0.4)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCompleted
                            ? Icons.check_circle
                            : (isNearing ? Icons.warning_amber_rounded : Icons.hourglass_top),
                        size: 13,
                        color: isCompleted
                            ? AppColors.goldDark
                            : (isNearing ? Colors.orange.shade800 : AppColors.emeraldDark),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCompleted
                            ? 'اكتمل الحول'
                            : (isNearing ? 'قريب (${item.daysRemaining} يوماً)' : '${item.daysRemaining} يوماً متبقياً'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCompleted
                              ? AppColors.goldDark
                              : (isNearing ? Colors.orange.shade900 : AppColors.emeraldDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: item.progressPercentage,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? AppColors.goldDark : (isNearing ? AppColors.warning : AppColors.emeraldPrimary),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Dates Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تاريخ بدء الحول', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(item.hijriStartDateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  Container(height: 24, width: 1, color: Colors.grey.shade300),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('موعد تمام الحول', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        item.hijriDueDateStr,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.goldDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '📝 ${item.notes}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
              ),
            ],

            const SizedBox(height: 10),

            // Actions Toolbar
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              children: [
                // Notify / Send Reminder
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  onPressed: () async {
                    await PermissionService.requestNotificationPermission();
                    if (!context.mounted) return;
                    final notifProv = Provider.of<NotificationProvider>(context, listen: false);
                    if (item.isHawlCompleted) {
                      await notifProv.notifyHawlCompleted(dueDateStr: item.hijriDueDateStr);
                    } else {
                      await notifProv.sendHawlAlert(
                        daysRemaining: item.daysRemaining,
                        dueDateStr: item.hijriDueDateStr,
                      );
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم إرسال إشعار تذكير بخصوص "${item.title}" إلى شريط التنبيهات!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  tooltip: 'إرسال تنبيه تجريبي',
                  icon: const Icon(Icons.notifications_active_outlined, size: 20, color: AppColors.emeraldPrimary),
                ),
                // Share
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  onPressed: () => _shareHawlItem(item),
                  tooltip: 'مشاركة بطاقة الحول',
                  icon: const Icon(Icons.share_outlined, size: 20, color: AppColors.emeraldPrimary),
                ),
                // Renew / Reset this specific Hawl
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  onPressed: () async {
                    final picked = await showHijriDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      title: 'تجديد الحول: اختر تاريخ بدء الحول الجديد',
                    );
                    if (picked != null) {
                      await hawlProv.resetWithNewStartDate(picked, id: item.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم تجديد موعد الحول لـ "${item.title}" بنجاح!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    }
                  },
                  tooltip: 'تجديد الحول لعام جديد',
                  icon: const Icon(Icons.replay_rounded, size: 20, color: AppColors.goldDark),
                ),
                // Edit
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  onPressed: () => _openAddEditHawlDialog(context, item),
                  tooltip: 'تعديل البيانات',
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blueGrey),
                ),
                // Delete
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('حذف هذا الحول'),
                        content: Text('هل أنت متأكد من رغبتك في حذف حول "${item.title}"؟'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            child: const Text('حذف'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await hawlProv.deleteHawlItem(item.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم حذف حول "${item.title}" بنجاح'),
                            backgroundColor: Colors.black87,
                          ),
                        );
                      }
                    }
                  },
                  tooltip: 'حذف الحول',
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
