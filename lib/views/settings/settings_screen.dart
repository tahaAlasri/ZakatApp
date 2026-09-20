import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/zakat_constants.dart';
import '../../core/services/market_price_service.dart';
import '../../core/utils/app_input_formatters.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/notification_provider.dart';
import '../permissions/permissions_screen.dart';
import '../auth/login_screen.dart';
import '../../core/utils/auth_guard.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showMarketCityPicker(BuildContext context, ZakatProvider zakatProv) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.location_city, color: AppColors.emeraldPrimary),
                    SizedBox(width: 8),
                    Text('اختر السوق والمدينة لتسعير الذهب والفضة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...MarketPriceService.supportedMarkets.map((m) {
                final isSelected = zakatProv.marketCity == m.id;
                return ListTile(
                  title: Text(m.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text('عيار 21: ${m.defaultGold21.toStringAsFixed(0)} ${m.currency} | فضة: ${m.defaultSilver.toStringAsFixed(0)} ${m.currency}'),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.emeraldPrimary) : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final res = await zakatProv.fetchAndApplyMarketPrices(cityId: m.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.message),
                          backgroundColor: res.isLiveApi ? AppColors.emeraldPrimary : AppColors.goldDark,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showCurrencyPicker(BuildContext context, ZakatProvider zakatProv) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'اختر عملة الحساب',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ...ZakatConstants.supportedCurrencies.map((cur) {
                final shortCur = cur.split(' ').first;
                return ListTile(
                  title: Text(cur),
                  trailing: zakatProv.currency == shortCur
                      ? const Icon(Icons.check, color: AppColors.emeraldPrimary)
                      : null,
                  onTap: () {
                    zakatProv.updateCurrency(shortCur);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم اعتماد العملة: $cur'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.emeraldPrimary,
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showPriceEditor(BuildContext context, ZakatProvider zakatProv) {
    final goldCtrl = TextEditingController(text: zakatProv.gold24Price.toStringAsFixed(0));
    final silverCtrl = TextEditingController(text: zakatProv.silverPrice.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('تعديل أسعار الذهب والفضة اللحظية'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: goldCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [AppInputFormatters.decimal],
                  validator: AppValidators.requiredPositiveNumber('سعر جرام الذهب عيار 24'),
                  decoration: InputDecoration(
                    labelText: 'سعر جرام الذهب عيار 24 الخالص (${zakatProv.currency})',
                    hintText: 'الأساس الشرعي المعتمد لاحتساب النصاب',
                    prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.goldDark),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: silverCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [AppInputFormatters.decimal],
                  validator: AppValidators.requiredPositiveNumber('سعر جرام الفضة'),
                  decoration: InputDecoration(
                    labelText: 'سعر جرام الفضة (${zakatProv.currency})',
                    prefixIcon: const Icon(Icons.circle_outlined, color: Colors.blueGrey),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                final g = AppInputFormatters.tryParseDouble(goldCtrl.text);
                final s = AppInputFormatters.tryParseDouble(silverCtrl.text);
                if (g != null && g > 0) zakatProv.updateGold24Price(g);
                if (s != null && s > 0) zakatProv.updateSilverPrice(s);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حفظ أسعار الذهب والفضة المحدثة بنجاح'),
                    backgroundColor: AppColors.emeraldPrimary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthProvider authProv) async {
    if (!authProv.isAuthenticated) {
      final isAuth = await AuthGuard.requireAuth(
        context,
        title: 'تعديل الملف الشخصي',
        message: 'يتطلب تعديل بيانات الملف الشخصي تسجيل الدخول بحسابك أولاً.',
        icon: Icons.person_outline,
      );
      if (!isAuth) return;
      if (!context.mounted) return;
    }

    final rawName = authProv.user?.name ?? '';
    final initialName = (rawName == 'مستخدم البصمة' || rawName == 'المستخدم الكريم') ? '' : rawName;
    final nameCtrl = TextEditingController(text: initialName);
    final phoneCtrl = TextEditingController(text: authProv.user?.phone ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.badge_outlined, color: AppColors.emeraldPrimary),
              SizedBox(width: 8),
              Text('تعديل الاسم والملف الشخصي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سيظهر هذا الاسم في بطاقة الترحيب والتقارير الرسمية وعند الدخول بالبصمة.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    keyboardType: TextInputType.name,
                    inputFormatters: [AppInputFormatters.lettersOnly],
                    validator: AppValidators.personName('اسمك الكامل'),
                    decoration: const InputDecoration(
                      labelText: 'اسمك الكامل',
                      hintText: 'مثال: طه العسري (حروف فقط)',
                      prefixIcon: Icon(Icons.person, color: AppColors.emeraldPrimary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [AppInputFormatters.digitsOnly],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return null;
                      return AppValidators.phoneNumber('رقم الهاتف')(val);
                    },
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف (اختياري)',
                      hintText: '777000111 (أرقام فقط)',
                      prefixIcon: Icon(Icons.phone, color: AppColors.emeraldPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newName = nameCtrl.text.trim();
                Navigator.pop(ctx);
                final success = await authProv.updateProfile(
                  name: newName,
                  phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                );
                if (context.mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث الاسم والملف الشخصي بنجاح'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تعذر حفظ التغييرات'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  void _showProfileImagePicker(BuildContext context, AuthProvider authProv) async {
    if (!authProv.isAuthenticated) {
      final isAuth = await AuthGuard.requireAuth(
        context,
        title: 'صورة الملف الشخصي',
        message: 'يتطلب تعيين وتحديث صورة الملف الشخصي تسجيل الدخول بحسابك.',
        icon: Icons.camera_alt_outlined,
      );
      if (!isAuth) return;
      if (!context.mounted) return;
    }

    final hasImage = authProv.user?.profileImagePath != null &&
        authProv.user!.profileImagePath!.isNotEmpty &&
        File(authProv.user!.profileImagePath!).existsSync();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'صورة الملف الشخصي',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.emeraldPrimary),
                title: const Text('التقاط صورة جديدة بالكاميرا'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final success = await authProv.pickAndSaveProfileImage(ImageSource.camera);
                  if (context.mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث صورة الحساب بنجاح'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.goldDark),
                title: const Text('اختيار صورة من معرض الصور'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final success = await authProv.pickAndSaveProfileImage(ImageSource.gallery);
                  if (context.mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث صورة الحساب بنجاح'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
              ),
              if (hasImage)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('حذف صورة الحساب', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await authProv.removeProfileImage();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم حذف صورة الحساب بنجاح'),
                          backgroundColor: AppColors.emeraldPrimary,
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);
    final authProv = Provider.of<AuthProvider>(context);
    final zakatProv = Provider.of<ZakatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات والتفضيلات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => _showProfileImagePicker(context, authProv),
                        borderRadius: BorderRadius.circular(30),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: authProv.isAuthenticated
                                  ? AppColors.emeraldPrimary
                                  : Colors.grey.shade400,
                              backgroundImage: (authProv.isAuthenticated &&
                                      authProv.user?.profileImagePath != null &&
                                      File(authProv.user!.profileImagePath!).existsSync())
                                  ? FileImage(File(authProv.user!.profileImagePath!))
                                  : null,
                              child: (authProv.isAuthenticated &&
                                      authProv.user?.profileImagePath != null &&
                                      File(authProv.user!.profileImagePath!).existsSync())
                                  ? null
                                  : authProv.isAuthenticated
                                      ? Text(
                                          authProv.user?.name.isNotEmpty == true
                                              ? authProv.user!.name[0].toUpperCase()
                                              : 'ز',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : const Icon(Icons.person_outline, color: Colors.white, size: 28),
                            ),
                            if (authProv.isAuthenticated)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.goldAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authProv.isAuthenticated
                                  ? (authProv.user?.name ?? 'مستخدم تطبيق الهيئة العامة للزكاة')
                                  : 'مرحباً بك (حساب زائر)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              authProv.isAuthenticated
                                  ? (authProv.user?.email ?? '')
                                  : 'تصفح كزائر، ويمكنك تسجيل الدخول في أي وقت',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: AppColors.emeraldPrimary, size: 28),
                        tooltip: 'تعديل الاسم والملف الشخصي',
                        onPressed: () => _showEditProfileDialog(context, authProv),
                      ),
                    ],
                  ),
                  if (!authProv.isAuthenticated) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (authProv.hasAccountOnDevice) {
                            AuthGuard.requireAuth(
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
                        icon: Icon(
                          authProv.hasAccountOnDevice ? Icons.fingerprint : Icons.login,
                          size: 18,
                        ),
                        label: Text(
                          authProv.hasAccountOnDevice
                              ? 'الدخول بحسابك أو بالمصادقة'
                              : 'تسجيل الدخول / إنشاء حساب جديد',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emeraldPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Appearance & Theme
          const Text('المظهر والعرض', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.emeraldPrimary),
                  title: const Text('الوضع الداكن (Dark Mode)'),
                  subtitle: const Text('تبديل الثيم الليلي والنهاري'),
                  value: themeProv.isDarkMode,
                  activeThumbColor: AppColors.emeraldPrimary,
                  onChanged: (val) {
                    themeProv.toggleTheme();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(val ? 'تم تفعيل الوضع الليلي الداكن' : 'تم تفعيل الوضع النهاري الفاتح'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Security & Biometrics
          const Text('الأمان والمصادقة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint, color: AppColors.goldDark),
                  title: const Text('المصادقة بالبصمة / Face ID'),
                  subtitle: const Text('استخدام البصمة لتسجيل الدخول السريع'),
                  value: authProv.isBiometricEnabled,
                  activeThumbColor: AppColors.goldAccent,
                  onChanged: (val) async {
                    await authProv.toggleBiometrics(val);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'تم تفعيل الدخول بالبصمة / Face ID' : 'تم إلغاء تفعيل الدخول بالبصمة'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_outlined, color: AppColors.emeraldPrimary),
                  title: const Text('إدارة أذونات وصلاحيات التطبيق'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const PermissionsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Notifications & Alerts
          const Text('التنبيهات والإشعارات', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Consumer<NotificationProvider>(
            builder: (context, notifProv, _) {
              return Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.timer_outlined, color: AppColors.emeraldPrimary),
                      title: const Text('تنبيهات اكتمال الحول والزكاة'),
                      subtitle: const Text('استقبال إشعارات موعد الحول وتسجيل العمليات'),
                      value: notifProv.notificationsEnabled,
                      activeThumbColor: AppColors.emeraldPrimary,
                      onChanged: (val) {
                        notifProv.toggleNotifications(val);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(val ? 'تم تفعيل تنبيهات وإشعارات الزكاة' : 'تم تعطيل التنبيهات المجدولة'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Currency & Market Prices
          const Text('العملة وأسعار السوق الإقليمية', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_city, color: AppColors.goldDark),
                  title: const Text('السوق الإقليمي المعتمد'),
                  subtitle: Text(MarketPriceService.getMarketById(zakatProv.marketCity).name),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showMarketCityPicker(context, zakatProv),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.currency_exchange, color: AppColors.emeraldPrimary),
                  title: const Text('العملة المعتمدة للحساب'),
                  subtitle: Text(zakatProv.currency),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showCurrencyPicker(context, zakatProv),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.price_change_outlined, color: AppColors.emeraldDark),
                  title: const Text('أسعار الذهب والفضة (تعديل يدوي)'),
                  subtitle: Text('الذهب (عيار 24 خالص): ${zakatProv.gold24Price.toStringAsFixed(0)} ${zakatProv.currency} | عيار 21: ${zakatProv.gold21Price.toStringAsFixed(0)} | الفضة: ${zakatProv.silverPrice.toStringAsFixed(0)}'),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: () => _showPriceEditor(context, zakatProv),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: zakatProv.isFetchingPrices
                              ? null
                              : () async {
                                  final res = await zakatProv.fetchAndApplyMarketPrices();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res.message),
                                        backgroundColor: res.isLiveApi ? AppColors.emeraldPrimary : AppColors.goldDark,
                                      ),
                                    );
                                  }
                                },
                          icon: zakatProv.isFetchingPrices
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.cloud_sync_outlined),
                          label: Text(
                            zakatProv.isFetchingPrices ? 'جاري الاتصال بالسوق...' : 'تحديث الأسعار الآن (عبر الإنترنت)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emeraldPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        zakatProv.lastPricesResult != null
                            ? 'آخر تحديث: ${zakatProv.lastPricesResult!.isLiveApi ? "مباشر عبر الإنترنت" : "الأسعار السائدة المعتمدة"} (${zakatProv.lastPricesResult!.updatedAt.hour}:${zakatProv.lastPricesResult!.updatedAt.minute.toString().padLeft(2, "0")})'
                            : 'اضغط لجلب آخر تحديث لحظي للذهب والفضة من السوق',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // About & Logout
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppColors.emeraldPrimary),
                  title: const Text('عن التطبيق ومشروع الزكاة'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'الهيئة العامة للزكاة',
                      applicationVersion: '1.0.0',
                      applicationIcon: Image.asset(
                        'assets/images/MainIcon.png',
                        width: 48,
                        height: 48,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.calculate,
                          size: 40,
                          color: AppColors.emeraldPrimary,
                        ),
                      ),
                      children: const [
                        Text(
                          'تطبيق الهيئة العامة للزكاة هو نظام شامل لحساب كافة أنواع الزكاة الشرعية مستوفٍ لمتطلبات المشاريع المتقدمة مع متتبع الحول وتصدير التقارير بصيغة PDF وقواعد البيانات المحلية والمصادقة الحيوية.',
                        ),
                      ],
                    );
                  },
                ),
                const Divider(height: 1),
                if (authProv.isAuthenticated)
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    subtitle: const Text('التبديل إلى وضع الزائر دون حذف البيانات المحلية'),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('تأكيد تسجيل الخروج'),
                          content: const Text('هل ترغب بتسجيل الخروج؟ ستتمكن من مواصلة استخدام كافة ميزات التطبيق وحسابات الزكاة كزائر.'),
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
                              child: const Text('تسجيل الخروج'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await authProv.logout();
                        if (!context.mounted) return;
                        Provider.of<ZakatProvider>(context, listen: false).clearInMemoryRecords();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم تسجيل الخروج، أنت الآن تتصفح كزائر'),
                            backgroundColor: AppColors.emeraldPrimary,
                          ),
                        );
                      }
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.login, color: AppColors.emeraldPrimary),
                    title: const Text('تسجيل الدخول أو إنشاء حساب', style: TextStyle(color: AppColors.emeraldPrimary, fontWeight: FontWeight.bold)),
                    subtitle: const Text('لإدارة حسابك وحفظ بياناتك وتوثيق الطلبات'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
