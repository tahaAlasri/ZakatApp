import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/zakat_constants.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/zakat_provider.dart';
import '../../providers/notification_provider.dart';
import '../permissions/permissions_screen.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showCurrencyPicker(BuildContext context, ZakatProvider zakatProv) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                    Navigator.pop(context);
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
    final goldCtrl = TextEditingController(text: zakatProv.goldPrice.toStringAsFixed(0));
    final silverCtrl = TextEditingController(text: zakatProv.silverPrice.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعديل أسعار الذهب والفضة اللحظية'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: goldCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'سعر جرام الذهب عيار 21 (${zakatProv.currency})',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: silverCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'سعر جرام الفضة (${zakatProv.currency})',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final g = double.tryParse(goldCtrl.text);
                final s = double.tryParse(silverCtrl.text);
                if (g != null && g > 0) zakatProv.updateGoldPrice(g);
                if (s != null && s > 0) zakatProv.updateSilverPrice(s);
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.emeraldPrimary,
                    child: Text(
                      authProv.user?.name.isNotEmpty == true
                          ? authProv.user!.name[0].toUpperCase()
                          : 'ز',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authProv.user?.name ?? 'مستخدم تطبيق زكاتي',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          authProv.user?.email ?? 'زائر',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
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
                  onChanged: (val) => themeProv.toggleTheme(),
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
                  onChanged: (val) => authProv.toggleBiometrics(val),
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
                      secondary: const Icon(Icons.notifications_active_outlined, color: AppColors.emeraldPrimary),
                      title: const Text('تنبيهات اكتمال الحول والزكاة'),
                      subtitle: const Text('استقبال إشعارات موعد الحول وتسجيل العمليات'),
                      value: notifProv.notificationsEnabled,
                      activeThumbColor: AppColors.emeraldPrimary,
                      onChanged: (val) => notifProv.toggleNotifications(val),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.send_outlined, color: AppColors.goldDark),
                      title: const Text('إرسال إشعار تجريبي فوري'),
                      subtitle: const Text('اختبار ظهور إشعار النظام على جهازك'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        await notifProv.sendTestNotification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم إرسال الإشعار التجريبي بنجاح إلى شريط الإشعارات!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Currency & Prices
          const Text('العملة وأسعار السوق', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.currency_exchange, color: AppColors.emeraldPrimary),
                  title: const Text('العملة المعتمدة للحساب'),
                  subtitle: Text(zakatProv.currency),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showCurrencyPicker(context, zakatProv),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.price_change_outlined, color: AppColors.goldDark),
                  title: const Text('تحديث أسعار الذهب والفضة'),
                  subtitle: Text('الذهب: ${zakatProv.goldPrice} ${zakatProv.currency} | الفضة: ${zakatProv.silverPrice}'),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: () => _showPriceEditor(context, zakatProv),
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
                      applicationName: 'زكــــاتــي',
                      applicationVersion: '1.0.0',
                      applicationIcon: Image.asset('assets/images/MainIcon.png', width: 48, height: 48),
                      children: const [
                        Text(
                          'تطبيق زكاتي هو نظام إسلامي شامل لحساب كافة أنواع الزكاة الشرعية مستوفٍ لمتطلبات المشاريع المتقدمة مع متتبع الحول وتصدير التقارير بصيغة PDF وقواعد البيانات المحلية والمصادقة الحيوية.',
                        ),
                      ],
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    await authProv.logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
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
