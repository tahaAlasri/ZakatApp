import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/cloud_sync_service.dart';
import '../requests/my_requests_screen.dart';
import '../calculators/fitr_calc_screen.dart';

class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() => _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final cloudSync = Provider.of<CloudSyncService>(context);
    final allNotifications = cloudSync.notifications;

    final filtered = allNotifications.where((n) {
      if (_selectedFilter == 'all') return true;
      return n.type == _selectedFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز الإشعارات'),
        centerTitle: true,
        actions: [
          if (allNotifications.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'mark_read') {
                  cloudSync.markAllNotificationsAsRead();
                } else if (val == 'clear') {
                  cloudSync.clearNotifications();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'mark_read',
                  child: Row(
                    children: [
                      Icon(Icons.done_all, size: 18, color: AppColors.emeraldPrimary),
                      SizedBox(width: 8),
                      Text('تحديد الكل كمقروء'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined, size: 18, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('مسح السجل'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).cardColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'الكل (${allNotifications.length})'),
                  const SizedBox(width: 8),
                  _buildFilterChip('request', 'طلبات المساعدة'),
                  const SizedBox(width: 8),
                  _buildFilterChip('announcement', 'الإعلانات والتعميمات'),
                  const SizedBox(width: 8),
                  _buildFilterChip('price', 'تسعيرة الزكاة'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Notification List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'لا توجد إشعارات حالياً',
                          style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'ستصلك إشعارات فورية عند تحديث حالة طلبك أو صدور تعميمات جديدة',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notif = filtered[index];
                      return _buildNotificationCard(context, notif, cloudSync);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: AppColors.emeraldPrimary,
      checkmarkColor: Colors.white,
      onSelected: (_) {
        setState(() {
          _selectedFilter = key;
        });
      },
    );
  }

  Widget _buildNotificationCard(
      BuildContext context, AppNotificationItem notif, CloudSyncService sync) {
    Color iconColor;
    IconData iconData;
    String typeLabel;

    switch (notif.type) {
      case 'request':
        iconColor = AppColors.goldDark;
        iconData = Icons.assignment_outlined;
        typeLabel = 'طلب مساعدة';
        break;
      case 'announcement':
        iconColor = Colors.blue.shade700;
        iconData = Icons.campaign_rounded;
        typeLabel = 'إعلان رسمي';
        break;
      case 'price':
        iconColor = AppColors.emeraldPrimary;
        iconData = Icons.grain_rounded;
        typeLabel = 'تسعيرة الزكاة';
        break;
      default:
        iconColor = Colors.grey;
        iconData = Icons.notifications_rounded;
        typeLabel = 'تنبيه';
    }

    return Card(
      elevation: notif.isRead ? 0.5 : 2,
      color: notif.isRead ? Theme.of(context).cardColor : AppColors.goldAccent.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: notif.isRead ? Colors.grey.shade200 : AppColors.goldDark.withValues(alpha: 0.4),
          width: notif.isRead ? 1 : 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          sync.markNotificationAsRead(notif.id);
          if (notif.type == 'request') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
            );
          } else if (notif.type == 'price') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FitrCalcScreen()),
            );
          } else {
            _showAnnouncementDialog(context, notif.title, notif.body);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(fontSize: 10, color: iconColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          DateFormat('hh:mm a - MM/dd', 'ar').format(notif.timestamp),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notif.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.body,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notif.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 8, right: 6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.goldDark,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnnouncementDialog(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.campaign_rounded, color: AppColors.emeraldPrimary, size: 36),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(body, style: const TextStyle(fontSize: 13, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
