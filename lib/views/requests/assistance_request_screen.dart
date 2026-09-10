import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/local_db_service.dart';
import '../../core/services/pdf_service.dart';
import '../../models/assistance_request.dart';

class AssistanceRequestScreen extends StatefulWidget {
  const AssistanceRequestScreen({super.key});

  @override
  State<AssistanceRequestScreen> createState() => _AssistanceRequestScreenState();
}

class _AssistanceRequestScreenState extends State<AssistanceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _messageController = TextEditingController();

  String? _generatedLetter;
  AssistanceRequest? _currentRequest;

  @override
  void dispose() {
    _subjectController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _generateLetter() {
    if (!_formKey.currentState!.validate()) return;

    final request = AssistanceRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      subject: _subjectController.text.trim(),
      fullName: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      idNumber: _idNumberController.text.trim(),
      details: _messageController.text.trim(),
    );

    setState(() {
      _currentRequest = request;
      _generatedLetter = request.generateFormalLetter();
    });

    LocalDbService.saveAssistanceRequest(request);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم توليد الخطاب الرسمي وحفظ الطلب بنجاح!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _sendEmail() async {
    if (_generatedLetter == null || _currentRequest == null) return;

    const email = 'Khalil.moftah@gmail.com';
    final subject = Uri.encodeComponent(_currentRequest!.subject);
    final body = Uri.encodeComponent(_generatedLetter!);
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح تطبيق البريد، يمكنك نسخ الخطاب أو تصديره كـ PDF'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح تطبيق البريد الإلكتروني، يمكنك نسخ نص الخطاب أو تصديره كـ PDF'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  void _exportPdf() async {
    if (_currentRequest == null) return;
    final pdfBytes = await PdfService.generateAssistancePdf(_currentRequest!);
    await PdfService.shareOrPrintPdf(pdfBytes, 'zakat_assistance_request.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب مساعدة مالية'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
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
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.emeraldSubtle,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.mark_email_read_outlined, color: AppColors.emeraldPrimary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تقديم طلب مساعدة للهيئة العامة للزكاة',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'قم بتعبئة بياناتك ليتم توليد خطاب رسمي موثق يمكنك إرساله أو تصديره كـ PDF.',
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

              // Subject
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'موضوع الطلب',
                  hintText: 'مثال: طلب مساعدة علاجية أو إعسار معيشي',
                  prefixIcon: Icon(Icons.title, color: AppColors.emeraldPrimary),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'يرجى إدخال موضوع الطلب' : null,
              ),
              const SizedBox(height: 14),

              // Full name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم مقدم الطلب الرباعي',
                  hintText: 'أدخل اسمك كاملاً',
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.emeraldPrimary),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'يرجى إدخال الاسم' : null,
              ),
              const SizedBox(height: 14),

              // Address
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان بالتفصيل',
                  hintText: 'المحافظة - المديرية - الحي',
                  prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'يرجى إدخال العنوان' : null,
              ),
              const SizedBox(height: 14),

              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رقم الجوال للتواصل',
                  hintText: '777000111',
                  prefixIcon: Icon(Icons.phone_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'يرجى إدخال رقم الجوال' : null,
              ),
              const SizedBox(height: 14),

              // ID number
              TextFormField(
                controller: _idNumberController,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رقم البطاقة الشخصية / الهوية الوطنية',
                  hintText: 'أدخل الرقم الوطني للبطاقة',
                  prefixIcon: Icon(Icons.badge_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'يرجى إدخال رقم البطاقة' : null,
              ),
              const SizedBox(height: 14),

              // Message Details
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'شرح وتفاصيل الحالة والطلب',
                  hintText: 'اشرح ظروفك وظروف الأسرة واحتياجك بدقة...',
                  alignLabelWithHint: true,
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'يرجى كتابة نص الرسالة' : null,
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _generateLetter,
                icon: const Icon(Icons.article_outlined),
                label: const Text('توليد الخطاب الرسمي للزكاة', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 24),

              // Letter Preview
              if (_generatedLetter != null) ...[
                Card(
                  color: Colors.amber.shade50,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    side: BorderSide(color: AppColors.goldDark, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.markunread_mailbox_outlined, color: AppColors.emeraldPrimary),
                            SizedBox(width: 8),
                            Text(
                              'معاينة الخطاب الموجه للهيئة',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.emeraldDark),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        SelectableText(
                          _generatedLetter!,
                          style: const TextStyle(fontSize: 14, height: 1.8, color: Colors.black87),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _sendEmail,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.emeraldPrimary,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.email),
                                label: const Text('إرسال بالإيميل'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _exportPdf,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.goldAccent,
                                  foregroundColor: Colors.black,
                                ),
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text('تصدير PDF'),
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
        ),
      ),
    );
  }
}
