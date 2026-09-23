import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/cloud_sync_service.dart';
import '../../core/services/pdf_service.dart';
import '../../models/assistance_request.dart';
import 'assistance_request_screen.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
      case 'تمت الموافقة':
        return AppColors.success;
      case 'rejected':
      case 'مرفوض':
      case 'اعتذار':
        return AppColors.error;
      case 'under_review':
      case 'قيد الدراسة':
        return Colors.blue.shade700;
      case 'completed':
      case 'جاهز للصرف':
        return AppColors.emeraldPrimary;
      case 'pending':
      case 'قيد المراجعة':
      default:
        return AppColors.warning;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
      case 'تمت الموافقة':
        return Icons.check_circle_rounded;
      case 'rejected':
      case 'مرفوض':
      case 'اعتذار':
        return Icons.cancel_rounded;
      case 'under_review':
      case 'قيد الدراسة':
        return Icons.manage_search_rounded;
      case 'completed':
      case 'جاهز للصرف':
        return Icons.payments_rounded;
      case 'pending':
      case 'قيد المراجعة':
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  int _getStepIndex(String status) {
    switch (status) {
      case 'pending':
      case 'قيد المراجعة':
        return 1;
      case 'under_review':
      case 'قيد الدراسة':
        return 2;
      case 'approved':
      case 'تمت الموافقة':
        return 3;
      case 'completed':
      case 'جاهز للصرف':
        return 4;
      case 'rejected':
      case 'مرفوض':
        return 3; // Terminal step
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cloudSync = Provider.of<CloudSyncService>(context);
    final requests = cloudSync.myRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('متابعة طلباتي'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'تقديم طلب جديد',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AssistanceRequestScreen()),
              );
            },
          ),
        ],
      ),
      body: requests.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        size: 64,
                        color: AppColors.emeraldPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'لا توجد طلبات مساعدة مسجلة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'عند تقديم طلب مساعدة رسمي للهيئة العامة للزكاة، ستتمكن من متابعة حالته وردود الإدارة لحظة بلحظة من هذه الشاشة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AssistanceRequestScreen()),
                        );
                      },
                      icon: const Icon(Icons.post_add),
                      label: const Text('تقديم طلب مساعدة الآن'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final req = requests[index];
                final statusColor = _getStatusColor(req.status);
                final statusIcon = _getStatusIcon(req.status);
                final currentStep = _getStepIndex(req.status);
                final isRejected = req.status == 'rejected' || req.status == 'مرفوض';

                final isDark = Theme.of(context).brightness == Brightness.dark;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Ref Code & Status Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tag, size: 14, color: isDark ? AppColors.goldAccent : AppColors.emeraldPrimary),
                                  const SizedBox(width: 4),
                                  Text(
                                    req.referenceCode ?? req.id,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      fontFamily: 'Courier',
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, size: 16, color: statusColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    req.status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Subject & Date
                        Text(
                          req.subject,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'تاريخ التقديم: ${DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(req.createdAt)}',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                        const SizedBox(height: 14),

                        // Stepper Progress Indicator
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStepIndicator(
                                stepNum: 1,
                                label: 'تم الاستلام',
                                isPassed: currentStep >= 1,
                                isCurrent: currentStep == 1,
                                color: AppColors.emeraldPrimary,
                                isDark: isDark,
                              ),
                              _buildStepLine(isPassed: currentStep >= 2, isDark: isDark),
                              _buildStepIndicator(
                                stepNum: 2,
                                label: 'قيد الفحص',
                                isPassed: currentStep >= 2,
                                isCurrent: currentStep == 2,
                                color: Colors.blue,
                                isDark: isDark,
                              ),
                              _buildStepLine(isPassed: currentStep >= 3, isDark: isDark),
                              _buildStepIndicator(
                                stepNum: 3,
                                label: isRejected ? 'مرفوض' : 'الاعتماد',
                                isPassed: currentStep >= 3,
                                isCurrent: currentStep == 3,
                                color: isRejected ? AppColors.error : AppColors.success,
                                icon: isRejected ? Icons.close : null,
                                isDark: isDark,
                              ),
                              _buildStepLine(isPassed: currentStep >= 4, isDark: isDark),
                              _buildStepIndicator(
                                stepNum: 4,
                                label: 'الصرف',
                                isPassed: currentStep >= 4,
                                isCurrent: currentStep == 4,
                                color: AppColors.emeraldPrimary,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),

                        // Admin Response / Instructions (if available)
                        if (req.adminResponse != null && req.adminResponse!.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isRejected
                                  ? AppColors.error.withValues(alpha: 0.08)
                                  : AppColors.emeraldPrimary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isRejected
                                    ? AppColors.error.withValues(alpha: 0.3)
                                    : AppColors.emeraldPrimary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.mark_email_read_outlined,
                                      size: 18,
                                      color: isRejected ? AppColors.error : AppColors.emeraldPrimary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'توجيه ورد إدارة الهيئة:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isRejected ? AppColors.error : AppColors.emeraldPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  req.adminResponse!,
                                  style: const TextStyle(fontSize: 12.5, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 8),

                        // Action buttons: Export PDF & View Details
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final pdfBytes = await PdfService.generateAssistancePdf(req);
                                if (context.mounted) {
                                  await PdfService.showExportOptions(
                                    context,
                                    pdfData: pdfBytes,
                                    filename: 'zakat_request_${req.referenceCode ?? req.id}.pdf',
                                    title: 'طلب مساعدة رقم: ${req.referenceCode ?? req.id}',
                                  );
                                }
                              },
                              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                              label: const Text('تصدير PDF', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () {
                                _showDetailsSheet(context, req);
                              },
                              icon: const Icon(Icons.visibility_outlined, size: 16),
                              label: const Text('تفاصيل الطلب', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStepIndicator({
    required int stepNum,
    required String label,
    required bool isPassed,
    required bool isCurrent,
    required Color color,
    required bool isDark,
    IconData? icon,
  }) {
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPassed ? color : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
            border: isCurrent ? Border.all(color: AppColors.goldAccent, width: 2) : null,
          ),
          child: Center(
            child: icon != null
                ? Icon(icon, size: 14, color: Colors.white)
                : (isPassed
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '$stepNum',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      )),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isPassed
                ? (isDark ? Colors.white70 : Colors.black87)
                : (isDark ? Colors.grey.shade500 : Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine({required bool isPassed, required bool isDark}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: isPassed ? AppColors.emeraldPrimary : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
      ),
    );
  }

  void _showDetailsSheet(BuildContext context, AssistanceRequest req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    req.subject,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'رقم الطلب: ${req.referenceCode ?? req.id}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Divider(height: 24),
                  const Text('نص تفاصيل الطلب:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(req.details, style: const TextStyle(fontSize: 13, height: 1.6)),
                  ),
                  const SizedBox(height: 16),
                  const Text('بيانات مقدم الطلب:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.person_outline, 'الاسم', req.fullName),
                  _buildDetailRow(Icons.phone_outlined, 'الهاتف', req.phone),
                  _buildDetailRow(Icons.location_on_outlined, 'العنوان', req.address),
                  if (req.idNumber != null && req.idNumber!.isNotEmpty)
                    _buildDetailRow(Icons.badge_outlined, 'رقم الهوية', req.idNumber!),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.emeraldPrimary),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
