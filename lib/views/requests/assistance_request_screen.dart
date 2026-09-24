// ============================================================
// FIXED: assistance_request_screen.dart
// إصلاحات:
// 1. إضافة await لـ LocalDbService.saveAssistanceRequest في _generateLetter
// 2. إضافة await لـ cloudSync.submitOfficialRequest + معالجة الخطأ
// 3. حماية mounted check بعد كل عملية async
// 4. إيقاف loading indicator صحيح عند الفشل
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/local_db_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/app_input_formatters.dart';
import '../../models/assistance_request.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/auth_guard.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/services/cloud_sync_service.dart';
import '../auth/login_screen.dart';
import 'my_requests_screen.dart';

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
  bool _saveIdLocally = false;
  bool _isSubmitting = false; // FIX: حالة التحميل للزر الرسمي

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      if (authProv.isAuthenticated && authProv.user != null) {
        if (_nameController.text.isEmpty) {
          _nameController.text = authProv.user!.name;
        }
        if (_phoneController.text.isEmpty) {
          _phoneController.text = authProv.user!.phone;
        }
      }
    });
  }

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

  // FIX: أضفنا async وأضفنا await لعملية الحفظ المحلي
  Future<void> _generateLetter() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تصحيح الأخطاء في حقول الطلب والمتابعة'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (!authProv.isAuthenticated) {
      final isAuth = await AuthGuard.requireAuth(
        context,
        title: 'تقديم طلب للهيئة العامة للزكاة',
        message: 'يتطلب تقديم طلب مساعدة رسمي تسجيل حساب وتوثيق هويتك لمتابعة حالة الطلب.',
        icon: Icons.assignment_outlined,
      );

      if (!isAuth) return;
      if (!mounted) return; // FIX: mounted check

      final updatedAuth = Provider.of<AuthProvider>(context, listen: false);
      if (updatedAuth.user != null) {
        if (_nameController.text.isEmpty) _nameController.text = updatedAuth.user!.name;
        if (_phoneController.text.isEmpty) _phoneController.text = updatedAuth.user!.phone;
      }
    }

    final idText = _idNumberController.text.trim();
    final request = AssistanceRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      subject: _subjectController.text.trim(),
      fullName: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      idNumber: idText.isNotEmpty ? idText : null,
      details: _messageController.text.trim(),
      saveIdLocally: _saveIdLocally,
    );

    setState(() {
      _currentRequest = request;
      _generatedLetter = request.generateFormalLetter();
    });

    // FIX: كانت بدون await - الآن تنتظر اكتمال الحفظ
    await LocalDbService.saveAssistanceRequest(request);

    if (!mounted) return; // FIX: mounted check بعد await
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إنشاء مسودة طلب وتجهيز خطاب للمشاركة بنجاح!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // FIX: async + await + error handling كامل
  Future<void> _submitOfficialRequest() async {
    FocusScope.of(context).unfocus();

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (!authProv.canSubmitOfficialRequest) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.lock_outline, color: AppColors.warning, size: 40),
          title: const Text('تسجيل الدخول مطلوب', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'يتطلب تقديم طلب رسمي تسجيل الدخول بحساب موثق لدى الهيئة.\n\nيمكنك في وضع الزائر إنشاء مسودة طلب وحفظها محلياً أو مشاركتها.',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.login_rounded, size: 18),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              label: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      );
      return;
    }

    if (!AuthService.isFirebaseAuthenticated) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.cloud_off_outlined, color: AppColors.warning, size: 40),
          title: const Text('تسجيل الدخول بالإنترنت مطلوب', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'لتقديم طلب رسمي يصل إلى الهيئة العامة للزكاة، يجب تسجيل الدخول بحسابك عبر الإنترنت.\n\nإذا سجلت بالبصمة فقط أو بدون إنترنت، يرجى إعادة تسجيل الدخول بالبريد وكلمة المرور.',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.login_rounded, size: 18),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              label: const Text('تسجيل الدخول'),
            ),
          ],
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إكمال الحقول المطلوبة للمتابعة'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final cloudSync = Provider.of<CloudSyncService>(context, listen: false);
    if (!cloudSync.allowRequests) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عذراً، استقبال طلبات المساعدة متوقف مؤقتاً من إدارة الهيئة لأعمال المراجعة السنوية.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isSubmitting) return; // منع الضغط المزدوج
    setState(() => _isSubmitting = true);

    try {
      final idText = _idNumberController.text.trim();
      final request = AssistanceRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        subject: _subjectController.text.trim(),
        fullName: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        idNumber: idText.isNotEmpty ? idText : null,
        details: _messageController.text.trim(),
        saveIdLocally: _saveIdLocally,
      );

      final cloudSync = Provider.of<CloudSyncService>(context, listen: false);

      // FIX: كانت بدون await - الآن ننتظر النتيجة ونعالج الخطأ
      final refCode = await cloudSync.submitOfficialRequest(request);

      if (!mounted) return;
      setState(() {
        _currentRequest = request.copyWith(referenceCode: refCode);
        _generatedLetter = _currentRequest!.generateFormalLetter();
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم تقديم الطلب رسمياً برقم المرجع: $refCode'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );

      // الانتقال لصفحة متابعة الطلبات
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ فشل تقديم الطلب: ${e.toString().replaceAll('Exception:', '').trim()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _sendEmail() async {
    if (_generatedLetter == null) return;
    final uri = Uri(
      scheme: 'mailto',
      path: 'info@zakat.gov.ye',
      query: 'subject=${Uri.encodeComponent(_subjectController.text.trim())}&body=${Uri.encodeComponent(_generatedLetter!)}',
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق البريد الإلكتروني')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _shareLetter() async {
    if (_generatedLetter == null) return;
    final encoded = Uri.encodeComponent(_generatedLetter!);
    final uri = Uri.parse('https://wa.me/?text=$encoded');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _exportPdf() async {
    if (_currentRequest == null) return;
    final pdfBytes = await PdfService.generateAssistancePdf(_currentRequest!);
    if (!mounted) return;
    await PdfService.showExportOptions(
      context,
      pdfData: pdfBytes,
      filename: 'zakat_request_draft.pdf',
      title: 'مسودة طلب المساعدة',
    );
  }

  Future<void> _purgeAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المسودة والبيانات الحساسة'),
        content: const Text('سيتم حذف جميع مسودات الطلبات والبيانات الحساسة المحفوظة على هذا الجهاز نهائياً. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await LocalDbService.deleteAllAssistanceRequestsAndPurgeSensitiveData();
    if (!mounted) return;
    setState(() {
      _generatedLetter = null;
      _currentRequest = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف جميع البيانات الحساسة بنجاح'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب مساعدة من الهيئة'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'طلباتي السابقة',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyRequestsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: context.rPadding(horizontal: 16, vertical: 16),
        child: ResponsiveConstraint(
          maxWidth: 680,
          child: Form(
            key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice if requests submission is disabled by admin
              if (!Provider.of<CloudSyncService>(context).allowRequests)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.pause_circle_outline, color: Colors.amber.shade900, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تنبيه رسمي: تم إيقاف استقبال طلبات المساعدة مؤقتاً لأعمال الجرد السنوي. يمكنك تجهيز مسودة الطلب وحفظها محلياً.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              // Data retention & privacy notice
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.emeraldPrimary, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سياسة حماية واحتفاظ بالبيانات: بياناتك مشفرة محلياً، ولا يتم تخزين رقم الهوية إلا بموافقتك.',
                        style: TextStyle(fontSize: 12, color: AppColors.emeraldDark),
                      ),
                    ),
                  ],
                ),
              ),

              // Auth status banner
              // Auth status banner for guests
              if (!authProv.canSubmitOfficialRequest)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'أنت تتصفح كزائر. يمكنك إنشاء مسودة وتصديرها PDF، ولتقديم طلب رسمي يلزم تسجيل الدخول.',
                          style: TextStyle(fontSize: 12, color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),

              // Subject
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'موضوع الطلب',
                  prefixIcon: Icon(Icons.title, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.textNotPureNumbers('موضوع الطلب'),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _nameController,
                keyboardType: TextInputType.name,
                inputFormatters: [AppInputFormatters.lettersOnly],
                decoration: const InputDecoration(
                  labelText: 'اسم مقدم الطلب الرباعي',
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.personName('اسم مقدم الطلب الرباعي'),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'العنوان بالتفصيل',
                  hintText: 'المحافظة - المديرية - الحي',
                  prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.textNotPureNumbers('العنوان بالتفصيل'),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [AppInputFormatters.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'رقم الجوال للتواصل',
                  hintText: '777000111',
                  prefixIcon: Icon(Icons.phone_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.phoneNumber('رقم الجوال'),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _idNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [AppInputFormatters.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'رقم البطاقة الشخصية (اختياري)',
                  prefixIcon: Icon(Icons.badge_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: (val) {
                  if (val != null && val.trim().isNotEmpty) {
                    return AppValidators.idNumber('رقم البطاقة الشخصية')(val);
                  }
                  return null;
                },
              ),
              CheckboxListTile(
                value: _saveIdLocally,
                onChanged: (val) => setState(() => _saveIdLocally = val ?? false),
                title: const Text('حفظ رقم الهوية محلياً على هذا الجهاز', style: TextStyle(fontSize: 13)),
                subtitle: const Text('حفاظاً على الخصوصية، لن يُحفظ رقم الهوية محلياً إلا بموافقتك.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'شرح وتفاصيل الحالة والطلب',
                  hintText: 'اشرح ظروفك وظروف الأسرة واحتياجك بدقة...',
                  alignLabelWithHint: true,
                ),
                validator: AppValidators.textNotPureNumbers('شرح وتفاصيل الحالة والطلب'),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                key: const Key('btn_create_draft_request'),
                onPressed: _generateLetter,
                icon: const Icon(Icons.edit_document),
                label: const Text('إنشاء مسودة طلب', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 10),

              // FIX: أضفنا CircularProgressIndicator عند التحميل
              OutlinedButton.icon(
                key: const Key('btn_submit_official_request'),
                onPressed: _isSubmitting ? null : _submitOfficialRequest,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined, size: 20),
                label: Text(
                  _isSubmitting ? 'جارٍ التقديم...' : 'تقديم طلب رسمي',
                  style: const TextStyle(fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: authProv.canSubmitOfficialRequest ? AppColors.emeraldPrimary : Colors.grey,
                  side: BorderSide(
                    color: authProv.canSubmitOfficialRequest ? AppColors.emeraldPrimary : Colors.grey.shade400,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('btn_purge_request_data'),
                onPressed: _purgeAllData,
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red, size: 20),
                label: const Text('حذف المسودة وتطهير البيانات الحساسة', style: TextStyle(fontSize: 14, color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 24),

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
                            Expanded(
                              child: Text(
                                'تجهيز خطاب للمشاركة',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.emeraldDark),
                              ),
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
                                icon: const Icon(Icons.email, size: 16),
                                label: const Text('فتح تطبيق البريد', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _shareLetter,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.emeraldPrimary,
                                side: const BorderSide(color: AppColors.emeraldPrimary),
                                padding: const EdgeInsets.all(12),
                              ),
                              icon: const Icon(Icons.share_outlined),
                              tooltip: 'مشاركة الخطاب',
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                key: const Key('btn_export_draft_pdf'),
                                onPressed: _exportPdf,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.goldAccent,
                                  foregroundColor: Colors.black,
                                ),
                                icon: const Icon(Icons.picture_as_pdf, size: 16),
                                label: const Text('تصدير PDF', style: TextStyle(fontSize: 12)),
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
    ),
  );
  }
}
