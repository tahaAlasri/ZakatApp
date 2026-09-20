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
import '../auth/login_screen.dart';

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

  void _generateLetter() async {
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
        message: 'يتطلب تقديم طلب مساعدة رسمي تسجيل حساب وتوثيق هويتك لمتابعة حالة الطلب والاعتماد لدى الهيئة.',
        icon: Icons.assignment_outlined,
      );

      if (!isAuth) return;
      if (!mounted) return;

      final updatedAuth = Provider.of<AuthProvider>(context, listen: false);
      if (updatedAuth.user != null) {
        if (_nameController.text.isEmpty) {
          _nameController.text = updatedAuth.user!.name;
        }
        if (_phoneController.text.isEmpty) {
          _phoneController.text = updatedAuth.user!.phone;
        }
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

    LocalDbService.saveAssistanceRequest(request);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إنشاء مسودة طلب وتجهيز خطاب للمشاركة بنجاح!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Strict rule: Only firebaseAuthenticated or officiallyVerified can submit official requests.
  /// Local authentication (offline mode) or guest cannot submit official requests.
  void _submitOfficialRequest() {
    FocusScope.of(context).unfocus();
    final authProv = Provider.of<AuthProvider>(context, listen: false);

    if (authProv.authStatus == AuthStatus.guest ||
        authProv.authStatus == AuthStatus.localAuthenticated) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.gpp_bad_outlined, color: AppColors.error, size: 40),
          title: const Text('غير متاح للمصادقة المحلية', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            authProv.authStatus == AuthStatus.localAuthenticated
                ? 'المصادقة الحالية محلية دون اتصال ولا تعني أن الحساب موثق رسمياً لدى الهيئة. لا يُسمح بتقديم طلب رسمي إلا بحساب موثق سحابياً أو معتمد رسمياً.\n\nيمكنك بدلاً من ذلك: إنشاء مسودة طلب، وتجهيز خطاب للمشاركة، وتصدير مسودة بصيغة PDF.'
                : 'يتطلب تقديم طلب رسمي تسجيل الدخول بحساب موثق رسمياً لدى الهيئة.\n\nيمكنك بدلاً من ذلك: إنشاء مسودة طلب وتجهيز خطاب للمشاركة.',
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً، فهمت'),
            ),
            if (authProv.authStatus == AuthStatus.guest)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
                child: const Text('تسجيل الدخول'),
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

    try {
      final cloudSync = Provider.of<CloudSyncService>(context, listen: false);
      cloudSync.submitOfficialRequest(request).then((refCode) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 48),
            title: const Text('تم إرسال الطلب بنجاح', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تم إرسال طلبكم رسمياً وبشكل مباشر إلى لوحة تحكم الهيئة وهو الآن قيد المراجعة.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.emeraldPrimary),
                  ),
                  child: Text(
                    'رقم التتبع: $refCode',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.emeraldPrimary),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('ستصلك إشعارات فورية على هاتفك عند قيام الإدارة بالرد أو تحديث حالة الطلب.', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MyRequestsScreen()));
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldPrimary, foregroundColor: Colors.white),
                child: const Text('متابعة حالة الطلب'),
              ),
            ],
          ),
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ المسودة محلياً. تعذر الربط السحابي: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _sendEmail() async {
    if (_generatedLetter == null || _currentRequest == null) return;

    const email = 'info@zakat.gov.ye';
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': _currentRequest!.subject,
        'body': _generatedLetter!,
      },
    );

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;

      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم فتح تطبيق البريد. يرجى مراجعة الرسالة وإرسالها يدويًا.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر فتح تطبيق البريد تلقائياً، يمكنك نسخ الخطاب أو تصديره كـ PDF'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح تطبيق البريد الإلكتروني، يمكنك نسخ نص الخطاب أو تصديره كـ PDF'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _purgeAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف والتطهير الكامل', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'هل أنت متأكد من حذف مسودة الطلب وتطهير كافة البيانات الحساسة (الهوية، العنوان، الرسالة) نهائياً من الذاكرة والتخزين المحلي؟ لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('حذف نهائي وتطهير'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await LocalDbService.deleteAllAssistanceRequestsAndPurgeSensitiveData();
      setState(() {
        _generatedLetter = null;
        _currentRequest = null;
        _subjectController.clear();
        _addressController.clear();
        _idNumberController.clear();
        _messageController.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المسودة وتطهير كافة البيانات الحساسة بنجاح.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _exportPdf() async {
    if (_currentRequest == null) return;
    final pdfBytes = await PdfService.generateAssistancePdf(_currentRequest!);
    if (!mounted) return;
    await PdfService.showExportOptions(
      context,
      pdfData: pdfBytes,
      filename: 'zakat_assistance_request.pdf',
      title: 'طلب مساعدة مالية',
    );
  }

  void _shareLetter() {
    if (_generatedLetter == null || _currentRequest == null) return;
    PdfService.shareLetterText(
      subject: _currentRequest!.subject,
      letterText: _generatedLetter!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب مساعدة مالية'),
        actions: [
          IconButton(
            key: const Key('btn_purge_request_data_appbar'),
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
            tooltip: 'حذف وتطهير كافة البيانات',
            onPressed: _purgeAllData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
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
                      const Icon(Icons.shield_outlined, color: AppColors.goldDark, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'توثيق الحساب مطلوب لتقديم الطلب الرسمي',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              authProv.hasAccountOnDevice
                                  ? 'يمكنك ملء البيانات لإنشاء مسودة طلب، ثم تسجيل الدخول السحابي لاعتماده رسمياً.'
                                  : 'يتطلب تقديم طلب رسمي تسجيل الدخول بحساب موثق لدى الهيئة. يمكنك حالياً إنشاء مسودة طلب.',
                              style: const TextStyle(fontSize: 11, color: Colors.brown),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => AuthGuard.requireAuth(
                          context,
                          title: 'تقديم طلب للهيئة',
                          message: 'يتطلب تقديم طلب مساعدة رسمي تسجيل حساب وتوثيق هويتك لمتابعة الطلب.',
                          icon: Icons.assignment_outlined,
                        ),
                        child: Text(
                          authProv.hasAccountOnDevice ? 'دخول / مصادقة' : 'تسجيل الدخول',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.emeraldPrimary),
                        ),
                      ),
                    ],
                  ),
                ),

              if (authProv.authStatus == AuthStatus.localAuthenticated)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blueGrey.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.offline_bolt_outlined, color: Colors.blueGrey, size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'أنت مسجل بالمصادقة المحلية (دون اتصال). تتيح لك إنشاء مسودة طلب وتجهيز خطاب للمشاركة وتصدير مسودة بصيغة PDF، بينما يتطلب تقديم طلب رسمي توثيق الحساب عبر الإنترنت.',
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

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
                              'مسودة طلب مساعدة للهيئة العامة للزكاة',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'قم بتعبئة بياناتك لـ إنشاء مسودة طلب، ثم تجهيز خطاب للمشاركة أو تصدير مسودة بصيغة PDF.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Data Retention and Privacy Notice Banner
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_clock_outlined, color: Colors.blue, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'سياسة حماية واحتفاظ بالبيانات: البيانات الحساسة مشفرة محلياً بمفتاح آمن (FlutterSecureStorage)، وتُحذف المسودات تلقائياً بعد 30 يوماً، ويمكنك تطهيرها فوراً بزر الحذف.',
                        style: TextStyle(fontSize: 11, color: Colors.blueGrey, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Guest Notice Banner
              if (!authProv.isAuthenticated)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.goldAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.goldDark.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.goldDark, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'تقديم طلبات المساعدة يستلزم توثيق هويتك عبر تسجيل الدخول لمتابعة الرد.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'تسجيل دخول',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.emeraldPrimary, fontSize: 13),
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
                  hintText: 'مثال: طلب مساعدة علاجية أو إعسار معيشي',
                  prefixIcon: Icon(Icons.title, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.textNotPureNumbers('موضوع الطلب'),
              ),
              const SizedBox(height: 14),

              // Full name
              TextFormField(
                controller: _nameController,
                keyboardType: TextInputType.name,
                inputFormatters: [AppInputFormatters.lettersOnly],
                decoration: const InputDecoration(
                  labelText: 'اسم مقدم الطلب الرباعي',
                  hintText: 'أدخل اسمك كاملاً (حروف فقط)',
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.personName('اسم مقدم الطلب الرباعي'),
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
                validator: AppValidators.textNotPureNumbers('العنوان بالتفصيل'),
              ),
              const SizedBox(height: 14),

              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [AppInputFormatters.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'رقم الجوال للتواصل',
                  hintText: '777000111 (أرقام فقط)',
                  prefixIcon: Icon(Icons.phone_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: AppValidators.phoneNumber('رقم الجوال'),
              ),
              const SizedBox(height: 14),

              // ID number (optional locally unless explicitly desired)
              TextFormField(
                controller: _idNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [AppInputFormatters.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'رقم البطاقة الشخصية / الهوية الوطنية (اختياري محلياً)',
                  hintText: 'أدخل الرقم الوطني أو رقم الهوية (أرقام فقط)',
                  prefixIcon: Icon(Icons.badge_outlined, color: AppColors.emeraldPrimary),
                ),
                validator: (val) {
                  if (val != null && val.trim().isNotEmpty) {
                    return AppValidators.idNumber('رقم البطاقة الشخصية / الهوية')(val);
                  }
                  return null;
                },
              ),
              CheckboxListTile(
                value: _saveIdLocally,
                onChanged: (val) => setState(() => _saveIdLocally = val ?? false),
                title: const Text('حفظ رقم الهوية محلياً على هذا الجهاز', style: TextStyle(fontSize: 13)),
                subtitle: const Text('إذا لم يتم تفعيله، لن يتم تخزين رقم الهوية في قاعدة البيانات المحلية حفاظاً على الخصوصية.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
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
              OutlinedButton.icon(
                key: const Key('btn_submit_official_request'),
                onPressed: _submitOfficialRequest,
                icon: const Icon(Icons.verified_outlined, size: 20),
                label: const Text('تقديم طلب رسمي', style: TextStyle(fontSize: 15)),
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
                              'تجهيز خطاب للمشاركة',
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
                              tooltip: 'مشاركة الخطاب عبر واتساب',
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
                                label: const Text('تصدير مسودة بصيغة PDF', style: TextStyle(fontSize: 12)),
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
