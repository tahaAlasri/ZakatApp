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
import '../../core/services/market_price_service.dart';
import '../requests/my_requests_screen.dart';
import '../notifications/notifications_center_screen.dart';
import '../payment/zakat_payment_screen.dart';

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
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/MainIcon.png',
                width: 28,
                height: 28,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.calculate,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Text('الهيئة العامة للزكاة'),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          Consumer<CloudSyncService>(
            builder: (context, cloudSync, _) {
              final unread = cloudSync.unreadNotificationsCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    tooltip: 'مركز الإشعارات',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationsCenterScreen()),
                      );
                    },
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unread',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
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
        color: AppColors.goldAccent,
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        onRefresh: () async {
          final cloudSync = Provider.of<CloudSyncService>(context, listen: false);
          MarketPricesResult? priceResult;
          try {
            final fSync = cloudSync.refreshAll();
            final fPrices = zakatProv.fetchAndApplyMarketPrices();
            await fSync.timeout(const Duration(seconds: 4));
            priceResult = await fPrices.timeout(const Duration(seconds: 4));
          } catch (_) {}
          zakatProv.reloadPricesFromPreferences();
          zakatProv.loadRecords();
          if (context.mounted) {
            final isLive = priceResult?.isLiveApi ?? false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      isLive ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isLive
                            ? '🌐 تم تحديث الأسعار اللحظية والبيانات بنجاح من البورصة والسحابة'
                            : (priceResult?.message ?? '📴 الجهاز غير متصل بالإنترنت - تم تطبيق الأسعار السائدة المعتمدة محلياً'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                backgroundColor: isLive ? AppColors.emeraldPrimary : AppColors.warning,
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: context.rPadding(horizontal: 16, vertical: 16),
          child: ResponsiveConstraint(
            maxWidth: 950,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // User Greeting & Welcome Banner
              Container(
                padding: EdgeInsets.all(context.rSpacing(16)),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top row: Authority badge and Hijri Date badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified, size: 12, color: AppColors.goldLight),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'الهيئة العامة للزكاة',
                                    style: TextStyle(
                                      fontSize: context.rFont(10.5),
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.goldAccent.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.goldAccent.withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, size: 11, color: AppColors.goldLight),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    AppFormatters.formatDate(DateTime.now()),
                                    style: TextStyle(
                                      fontSize: context.rFont(10.5),
                                      color: AppColors.goldLight,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Main Greeting Row: Avatar + Full Name / Greeting taking full horizontal width
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: context.rWidth(48),
                          height: context.rWidth(48),
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
                                      authProv.isAuthenticated && authProv.user?.name.isNotEmpty == true
                                          ? authProv.user!.name[0].toUpperCase()
                                          : 'ز',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(width: context.rSpacing(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                authProv.isAuthenticated && authProv.user?.name.isNotEmpty == true
                                    ? 'أهلاً بك، ${authProv.user!.name}'
                                    : 'أهلاً بك، ضيفنا الكريم',
                                style: TextStyle(
                                  fontSize: context.rFont(17),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.visible,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '﴿وَأَقِيمُوا الصَّلَاةَ وَآتُوا الزَّكَاةَ﴾',
                                style: TextStyle(
                                  fontSize: context.rFont(12.5),
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (!authProv.isAuthenticated) ...[
                      const SizedBox(height: 14),
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
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                authProv.hasAccountOnDevice ? Icons.fingerprint : Icons.login,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  authProv.hasAccountOnDevice
                                      ? 'دخول بحسابك (${authProv.lastKnownUser?.name ?? ''}) أو بالمصادقة'
                                      : 'تسجيل الدخول / إنشاء حساب للمزامنة',
                                  style: TextStyle(
                                    fontSize: context.rFont(12.5),
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
              const SizedBox(height: 12),

              // Dynamic Announcements Banner from Admin
              Consumer<CloudSyncService>(
                builder: (context, cloudSync, _) {
                  if (cloudSync.announcements.isEmpty) return const SizedBox.shrink();
                  final announcement = cloudSync.announcements.first;
                  final isUrgent = announcement.priority == 'urgent';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUrgent
                          ? AppColors.error.withValues(alpha: 0.12)
                          : AppColors.goldAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isUrgent
                            ? AppColors.error.withValues(alpha: 0.4)
                            : AppColors.goldDark.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isUrgent ? Icons.campaign : Icons.campaign_outlined,
                          color: isUrgent ? AppColors.error : AppColors.goldDark,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                announcement.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isUrgent ? AppColors.error : Colors.brown.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                announcement.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                icon: Icon(
                                  Icons.campaign_rounded,
                                  color: isUrgent ? AppColors.error : AppColors.emeraldPrimary,
                                  size: 36,
                                ),
                                title: Text(announcement.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                content: Text(announcement.content, style: const TextStyle(fontSize: 13, height: 1.6)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
                                ],
                              ),
                            );
                          },
                          child: const Text('التفاصيل', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Quick Requests Tracking Card
              Consumer<CloudSyncService>(
                builder: (context, cloudSync, _) {
                  final reqCount = cloudSync.myRequests.length;
                  if (reqCount == 0) return const SizedBox.shrink();
                  final pendingCount = cloudSync.myRequests.where((r) => r.status == 'قيد المراجعة' || r.status == 'قيد الدراسة').length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.assignment_turned_in_outlined, color: AppColors.emeraldPrimary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                pendingCount > 0
                                    ? 'لديك ($pendingCount) طلب مساعدة قيد المتابعة'
                                    : 'متابعة سجل طلبات المساعدة السابقة ($reqCount)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 13, color: AppColors.emeraldPrimary),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),

              // Live Gold & Silver Prices Strip
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 8, color: AppColors.goldAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ذهب 24 (خالص)', style: TextStyle(fontSize: 10.5, color: Colors.grey), overflow: TextOverflow.ellipsis),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '${AppFormatters.formatNumber(zakatProv.gold24Price, decimals: 0)} ${zakatProv.currency}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 28, width: 1, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4)),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 8, color: Colors.blueGrey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('فضة (جرام)', style: TextStyle(fontSize: 10.5, color: Colors.grey), overflow: TextOverflow.ellipsis),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '${AppFormatters.formatNumber(zakatProv.silverPrice, decimals: 0)} ${zakatProv.currency}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 28, width: 1, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4)),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.balance, size: 12, color: AppColors.emeraldPrimary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('نصاب النقد', style: TextStyle(fontSize: 10.5, color: Colors.grey), overflow: TextOverflow.ellipsis),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '${AppFormatters.formatNumber(zakatProv.gold24Price * 85, decimals: 0)} ${zakatProv.currency}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.emeraldPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

              // Zakat Payment & Masaref Quick Action Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark
                        ? AppColors.goldAccent.withValues(alpha: 0.3)
                        : AppColors.goldDark.withValues(alpha: 0.25),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ZakatPaymentScreen()),
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
                                ? AppColors.goldDark.withValues(alpha: 0.25)
                                : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.payments_outlined, color: AppColors.goldDark, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'قنوات سداد وتوجيه الزكاة الرسمية',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'الحسابات المعتمدة (كاك بنك، الكريمي، ون كاش، فلوسك) والمصارف الشرعية',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
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
              const SizedBox(height: 12),

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
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              icon: const Icon(Icons.share_outlined, color: AppColors.emeraldPrimary, size: 18),
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
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.goldDark, size: 18),
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
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 18),
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
      ),
    );
  }
}
