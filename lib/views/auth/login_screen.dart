import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/preferences_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/zakat_provider.dart';
import 'register_screen.dart';
import '../dashboard/main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = PreferencesService.rememberMe;

  @override
  void initState() {
    super.initState();
    if (PreferencesService.savedEmail.isNotEmpty) {
      _emailController.text = PreferencesService.savedEmail;
      _rememberMe = true;
    } else if (_rememberMe) {
      _emailController.text = PreferencesService.savedEmail;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (_rememberMe) {
      await PreferencesService.setRememberMe(true);
      await PreferencesService.setSavedEmail(_emailController.text.trim());
    } else {
      await PreferencesService.setRememberMe(false);
      await PreferencesService.setSavedEmail('');
    }

    final success = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('مرحباً بك ${auth.user?.name ?? ""}، تم تسجيل الدخول بنجاح'),
          backgroundColor: AppColors.emeraldPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _navigateAfterAuth();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'فشل تسجيل الدخول'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onBiometricLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final emailText = _emailController.text.trim();
    final success = await auth.loginWithBiometrics(
      hintEmail: emailText.isNotEmpty ? emailText : null,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('أهلاً بك ${auth.user?.name ?? ""}، تم التحقق والمصادقة بالبصمة بنجاح'),
          backgroundColor: AppColors.emeraldPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _navigateAfterAuth();
    } else {
      final msg = auth.errorMessage ?? 'تعذرت المصادقة بالبصمة';
      final isNoAccount = msg.contains('لا يوجد حساب مسجل') || msg.contains('تسجيل الدخول بالبريد أولاً');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isNoAccount ? AppColors.emeraldPrimary : AppColors.warning,
          action: isNoAccount
              ? SnackBarAction(
                  label: 'إنشاء حساب',
                  textColor: AppColors.goldAccent,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                )
              : null,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _navigateAfterAuth() {
    Provider.of<ZakatProvider>(context, listen: false).loadRecords();
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      );
    }
  }

  void _loginAsGuest() {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop(false);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: Navigator.canPop(context)
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : AppColors.emeraldPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Heading
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.emeraldSubtle,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.goldAccent, width: 2),
                      ),
                      child: Image.asset(
                        'assets/images/MainIcon.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.account_balance_wallet,
                          size: 45,
                          color: AppColors.emeraldPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'تسجيل الدخول',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.emeraldPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'أهلاً بك مجدداً في تطبيق الهيئة العامة للزكاة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      hintText: 'example@domain.com',
                      prefixIcon: Icon(Icons.email_outlined, color: AppColors.emeraldPrimary),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال البريد الإلكتروني';
                      }
                      if (!value.contains('@')) {
                        return 'البريد الإلكتروني غير صحيح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.emeraldPrimary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال كلمة المرور';
                      }
                      if (value.length < 6) {
                        return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Remember me
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: AppColors.emeraldPrimary,
                        onChanged: (val) {
                          setState(() {
                            _rememberMe = val ?? false;
                          });
                        },
                      ),
                      const Text(
                        'تذكرني',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Login Button
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      return ElevatedButton(
                        onPressed: auth.isLoading ? null : _onLogin,
                        child: auth.isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('دخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // Biometric Authentication Button
                  OutlinedButton.icon(
                    onPressed: _onBiometricLogin,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.goldAccent, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.fingerprint, color: AppColors.goldDark, size: 28),
                    label: const Text(
                      'الدخول بالبصمة / Face ID',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.goldDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('ليس لديك حساب؟'),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const RegisterScreen()),
                          );
                        },
                        child: const Text(
                          'إنشاء حساب جديد',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.emeraldPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Guest Entry
                  TextButton.icon(
                    onPressed: _loginAsGuest,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('المتابعة بدون تسجيل كزائر'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
