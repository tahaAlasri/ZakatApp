import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/permission_service.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  List<PermissionItem> _permissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  void _loadPermissions() async {
    final list = await PermissionService.getAppPermissions();
    if (!mounted) return;
    setState(() {
      _permissions = list;
      _isLoading = false;
    });
  }

  void _request(PermissionItem item) async {
    final status = await PermissionService.requestPermission(item.permission);
    setState(() {
      item.status = status;
    });

    if (!mounted) return;
    if (status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم منح ${item.title} بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لم يتم منح ${item.title}، يمكنك تفعيلها من إعدادات النظام'),
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: 'الإعدادات',
            textColor: Colors.white,
            onPressed: () => PermissionService.openSettings(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الصلاحيات والأذونات'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.emeraldSubtle,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.security, color: AppColors.emeraldPrimary, size: 28),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'أذونات وصلاحيات التطبيق',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'يلتزم تطبيق الهيئة العامة للزكاة بحماية خصوصيتك ويطلب الصلاحيات الضرورية فقط لتشغيل الميزات.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                ..._permissions.map((item) {
                  final isGranted = item.status.isGranted;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isGranted ? Icons.check_circle : Icons.warning_amber_rounded,
                                color: isGranted ? AppColors.success : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isGranted ? Colors.green.shade50 : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isGranted ? Colors.green : Colors.orange,
                                  ),
                                ),
                                child: Text(
                                  isGranted ? 'ممنوحة' : 'غير مفعّلة',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isGranted ? Colors.green.shade800 : Colors.orange.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.description,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          if (!isGranted)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => _request(item),
                                child: const Text('طلب ومنح الصلاحية'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    onPressed: () => PermissionService.openSettings(),
                    icon: const Icon(Icons.settings),
                    label: const Text('فتح إعدادات النظام للتطبيق'),
                  ),
                ),
              ],
            ),
    );
  }
}
