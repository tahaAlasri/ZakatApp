import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/pdf_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/hawl_provider.dart';
import '../../core/constants/zakat_categories.dart';
import '../hawl/hawl_tracker_screen.dart';
import '../auth/login_screen.dart';
import '../../core/utils/auth_guard.dart';
import '../../core/widgets/category_icon_badge.dart';
import '../analytics/zakat_analytics_screen.dart';
import '../history/zakat_history_screen.dart';
import '../../core/services/cloud_sync_service.dart';
import '../requests/my_requests_screen.dart';
import '../notifications/notifications_center_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);
    final zakatProv = Provider.of<ZakatProvider>(context);
    final hawlProv = Provider.of<HawlProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;


    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/MainIcon.png',
              width: 30,
              height: 30,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.calculate,
                size: 26,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Text('الهيئة العامة للزكاة'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'التحليلات والرسوم البيانية',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ZakatAnalyticsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          zakatProv.loadRecords();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Greeting & Welcome Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emeraldPrimary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.goldAccent, width: 2),
                                  color: Colors.white24,
                                ),
                                child: ClipOval(
                                  child: (authProv.isAuthenticated &&
                                          authProv.user?.profileImagePath != null &&
                                          File(authProv.user!.profileImagePath!).existsSync())
                                      ? Image.file(
                                          File(authProv.user!.profileImagePath!),
                                          fit: BoxFit.cover,
                                        )
                                      : Center(
                                          child: Text(
                                            authProv.user?.name.isNotEmpty == true
                                                ? authProv.user!.name[0].toUpperCase()
                                                : 'ز',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      authProv.isAuthenticated && authProv.user?.name.isNotEmpty == true
                                          ? 'أهلاً بك، ${authProv.user!.name}'
                                          : 'أهلاً بك، ضيفنا الكريم',
                                      style: TextStyle(
                                        fontSize: context.rFont(17),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '{وَأَقِيمُوا الصَّلَاةَ وَآتُوا الزَّكَاةَ}',
                                      style: TextStyle(
                                        fontSize: context.rFont(12),
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.goldAccent.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.goldAccent),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 14, color: AppColors.goldLight),
                              const SizedBox(width: 6),
                              Text(
                                AppFormatters.formatDate(DateTime.now()),
                                style: const TextStyle(fontSize: 12, color: AppColors.goldLight, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!authProv.isAuthenticated) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          if (authProv.hasAccountOnDevice) {
                            await AuthGuard.requireAuth(
                              context,
                              title: 'تسجيل الدخول',
                              message: 'يمكنك الدخول السريع بالمصادقة (البصمة) أو كلمة المرور للمتابعة بحسابك.',
                              icon: Icons.fingerprint,
                            );
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                authProv.hasAccountOnDevice ? Icons.fingerprint : Icons.login,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                authProv.hasAccountOnDevice
                                    ? 'دخول بحسابك (${authProv.lastKnownUser?.name ?? ''}) أو بالمصادقة'
                                    : 'تسجيل الدخول / إنشاء حساب',
                                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Live Gold & Silver Prices Strip
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 10, color: AppColors.goldAccent),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ذهب 24 (خالص)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                '${AppFormatters.formatNumber(zakatProv.gold24Price, decimals: 0)} ${zakatProv.currency}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 10, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('فضة (جرام)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                '${AppFormatters.formatNumber(zakatProv.silverPrice, decimals: 0)} ${zakatProv.currency}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      Row(
                        children: [
                          const Icon(Icons.balance, size: 14, color: AppColors.emeraldPrimary),
                          const SizedBox(width: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('نصاب النقد (85غ)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                '${AppFormatters.formatNumber(zakatProv.gold24Price * 85, decimals: 0)} ${zakatProv.currency}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.emeraldPrimary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Smart Hawl Tracker Strip (Creative Idea #1)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final isAuth = await AuthGuard.requireAuth(
                    context,
                    title: 'متتبع الحول الهجري الذكي',
                    message: 'يتطلب متتبع الحول الهجري تسجيل الدخول لحفظ تاريخ بلوغ النصاب ومتابعة الأيام المتبقية وتفعيل التنبيهات باسمك.',
                    icon: Icons.timer_outlined,
                  );
                  if (!context.mounted) return;
                  if (isAuth) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const HawlTrackerScreen()),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: hawlProv.isHawlCompleted
                        ? Colors.amber.shade100
                        : (isDark ? AppColors.darkCard : AppColors.emeraldSubtle),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: hawlProv.isHawlCompleted ? AppColors.goldDark : AppColors.emeraldPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: hawlProv.isHawlCompleted ? AppColors.goldAccent : AppColors.emeraldPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: hawlProv.isHawlCompleted
                            ? Image.asset(
                                'assets/images/MainIcon.png',
                                width: 20,
                                height: 20,
                                color: Colors.white,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              )
                            : const Icon(
                                Icons.hourglass_bottom,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hawlProv.startDate == null
                                  ? 'متتبع الحول الهجري الذكي'
                                  : (hawlProv.isHawlCompleted
                                      ? 'اكتمل الحول الشرعي - الزكاة واجبة!'
                                      : 'الحول جارٍ: متبقي ${hawlProv.daysRemaining} يوماً'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              hawlProv.startDate == null
                                  ? 'انقر لضبط تاريخ بلوغ النصاب والتنبيهات'
                                  : 'موعد إخراج الزكاة: ${AppFormatters.formatDate(hawlProv.expectedDueDate!)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Categories Grid Title
              const Text(
                'حاسبات الزكاة الشرعية',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Grid of 10 categories
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                ),
                itemCount: appZakatCategories.length,
                itemBuilder: (context, index) {
                  final cat = appZakatCategories[index];
                  return Card(
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => cat.targetScreen),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CategoryIconBadge(
                              imagePath: cat.imagePath,
                              size: 46,
                              iconSize: 44,
                              useContainer: false,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat.shortTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Visual Analytics Quick Banner Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? AppColors.emeraldPrimary.withValues(alpha: 0.3)
                        : AppColors.emeraldPrimary.withValues(alpha: 0.15),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ZakatAnalyticsScreen()),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.emeraldPrimary.withValues(alpha: 0.25)
                                : AppColors.emeraldSubtle,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.pie_chart, color: AppColors.emeraldPrimary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'الرسوم البيانية والتحليلات',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                zakatProv.records.isNotEmpty
                                    ? 'توزيع بياني لـ ${zakatProv.records.length} عمليات زكوية ومسار الحول'
                                    : 'عرض توزيع أموال الزكاة ومسار الحول القمري بصرياً',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Recent Calculations History Section
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'سجل العمليات الأخيرة',
                      style: TextStyle(
                        fontSize: context.rFont(16),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (zakatProv.records.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const ZakatHistoryScreen()),
                            );
                          },
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.filter_list, size: 15, color: AppColors.emeraldPrimary),
                          label: const Text(
                            'تصفية وبحث',
                            style: TextStyle(color: AppColors.emeraldPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('مسح السجل بالكامل'),
                                content: const Text(
                                  'هل أنت متأكد من رغبتك في حذف جميع العمليات المحفوظة؟ لا يمكن التراجع عن هذا الإجراء.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('إلغاء'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('مسح الكل'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await zakatProv.clearAll();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم مسح كامل السجل بنجاح'),
                                    backgroundColor: AppColors.emeraldPrimary,
                                  ),
                                );
                              }
                            }
                          },
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('مسح السجل', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (zakatProv.records.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.history_toggle_off, size: 40, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            'لم تقم بأي عملية حسابية بعد، اختر حاسبة من الأعلى للبدء!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: zakatProv.records.take(5).length,
                  itemBuilder: (context, index) {
                    final rec = zakatProv.records[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: rec.reachedNisab ? AppColors.emeraldSubtle : Colors.orange.shade50,
                          child: Icon(
                            rec.reachedNisab ? Icons.check_circle : Icons.info,
                            color: rec.reachedNisab ? AppColors.emeraldPrimary : Colors.orange,
                          ),
                        ),
                        title: Text(rec.typeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rec.zakatInKindDescription.isNotEmpty
                                  ? rec.zakatInKindDescription
                                  : 'الواجب: ${rec.zakatAmount.toStringAsFixed(2)} ${rec.currency}',
                              style: TextStyle(
                                fontSize: 12,
                                color: rec.reachedNisab ? AppColors.emeraldPrimary : Colors.brown,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppFormatters.formatDate(rec.date),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share_outlined, color: AppColors.emeraldPrimary, size: 20),
                              tooltip: 'مشاركة الملخص',
                              onPressed: () {
                                PdfService.shareSummaryText(
                                  title: rec.typeName,
                                  totalWealth: rec.totalWealth,
                                  zakatAmount: rec.zakatAmount,
                                  currency: rec.currency,
                                  reachedNisab: rec.reachedNisab,
                                  inKindDescription: rec.zakatInKindDescription,
                                  notes: rec.notes,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.goldDark, size: 20),
                              tooltip: 'تصدير PDF',
                              onPressed: () async {
                                final bytes = await PdfService.generateZakatReceipt(rec);
                                if (!context.mounted) return;
                                await PdfService.showExportOptions(
                                  context,
                                  pdfData: bytes,
                                  filename: 'zakat_receipt_${rec.id}.pdf',
                                  title: 'تقرير ${rec.typeName}',
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 20),
                              tooltip: 'حذف من السجل',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('حذف العملية'),
                                    content: Text('هل أنت متأكد من حذف حساب "${rec.typeName}" من السجل؟'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: const Text('إلغاء'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        child: const Text('حذف'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await zakatProv.deleteRecord(rec.id);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تم حذف عملية "${rec.typeName}" من السجل'),
                                      backgroundColor: AppColors.emeraldPrimary,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (zakatProv.records.length > 5) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const ZakatHistoryScreen()),
                      );
                    },
                    icon: const Icon(Icons.history, color: AppColors.emeraldPrimary),
                    label: Text('عرض والبحث في كامل السجل (${zakatProv.records.length} عملية)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.emeraldPrimary,
                      side: const BorderSide(color: AppColors.emeraldPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
