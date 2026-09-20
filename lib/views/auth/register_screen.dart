import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_input_formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/zakat_provider.dart';
import '../dashboard/main_navigation_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = true;
  bool _enableBiometrics = false;
  String? _selectedImagePath;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _selectedImagePath = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر التقاط الصورة: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showImagePickerSheet() {
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
                child: Text('اختر صورة الحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.emeraldPrimary),
                title: const Text('التقاط صورة بالكاميرا'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.goldDark),
                title: const Text('اختيار من معرض الصور'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_selectedImagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('حذف الصورة المحددة', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _selectedImagePath = null);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _onRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى الموافقة على الشروط والأحكام للمتابعة'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      profileImagePath: _selectedImagePath,
      enableBiometrics: _enableBiometrics,
    );

    if (!mounted) return;

    if (success) {
      if (mounted) {
        Provider.of<ZakatProvider>(context, listen: false).loadRecords();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الحساب بنجاح! أهلاً بك في التطبيق'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'فشل إنشاء الحساب'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب جديد'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'انضم إلى تطبيق الهيئة العامة للزكاة',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.emeraldPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'أنشئ حسابك لتتبع نصابك وسجلاتك وحساباتك السنوية بكل أمان',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Avatar Picker
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.emeraldPrimary.withValues(alpha: 0.1),
                          border: Border.all(color: AppColors.emeraldPrimary, width: 2),
                        ),
                        child: ClipOval(
                          child: _selectedImagePath != null
                              ? Image.file(
                                  File(_selectedImagePath!),
                                  fit: BoxFit.cover,
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: AppColors.emeraldPrimary,
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _showImagePickerSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.goldAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: _showImagePickerSheet,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                    label: Text(
                      _selectedImagePath != null ? 'تغيير صورة الحساب' : 'إضافة صورة للملف الشخصي (اختياري)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                TextFormField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  inputFormatters: [AppInputFormatters.lettersOnly],
                  validator: AppValidators.personName('الاسم الكامل'),
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل',
                    hintText: 'مثال: أحمد محمد (حروف فقط)',
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.emeraldPrimary),
                  ),
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    hintText: 'name@example.com',
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.emeraldPrimary),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'يرجى إدخال البريد الإلكتروني';
                    if (!val.contains('@')) return 'البريد غير صحيح';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [AppInputFormatters.digitsOnly],
                  validator: AppValidators.phoneNumber('رقم الهاتف'),
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف / الجوال',
                    hintText: '777000111 (أرقام فقط)',
                    prefixIcon: Icon(Icons.phone_outlined, color: AppColors.emeraldPrimary),
                  ),
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.emeraldPrimary),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (val) => (val == null || val.length < 6) ? 'كلمة المرور 6 أحرف على الأقل' : null,
                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    prefixIcon: const Icon(Icons.lock_reset, color: AppColors.emeraldPrimary),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (val) {
                    if (val != _passwordController.text) return 'كلمتا المرور غير متطابقتين';
                    return null;
                  },
                ),
                // Biometrics Quick Login Opt-in
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldPrimary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fingerprint, color: AppColors.goldDark, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المصادقة بالبصمة لتسجيل الدخول السريع',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'تمكين تسجيل الدخول السريع بالبصمة عند الحاجة بدلاً من كلمة المرور',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enableBiometrics,
                        activeThumbColor: AppColors.emeraldPrimary,
                        onChanged: (val) {
                          setState(() {
                            _enableBiometrics = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Accept terms
                Row(
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      activeColor: AppColors.emeraldPrimary,
                      onChanged: (val) => setState(() => _acceptTerms = val ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        'أوافق على الشروط والأحكام وسياسة الخصوصية',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Submit Button
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return ElevatedButton(
                      onPressed: auth.isLoading ? null : _onRegister,
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('تسجيل حساب جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
