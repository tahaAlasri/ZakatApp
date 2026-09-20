import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../views/auth/login_screen.dart';
import '../../views/auth/register_screen.dart';

class AuthGuard {
  /// Prompts the user to authenticate if they are not currently signed in.
  ///
  /// Returns `true` if the user is already authenticated or successfully
  /// logs in via biometric authentication or credentials.
  /// Returns `false` if the user cancels or closes the prompt.
  static Future<bool> requireAuth(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.lock_outline,
  }) async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (authProv.isAuthenticated) {
      return true;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AuthGuardSheet(
        title: title,
        message: message,
        icon: icon,
      ),
    );

    return result ?? false;
  }
}

class AuthGuardSheet extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;

  const AuthGuardSheet({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  State<AuthGuardSheet> createState() => _AuthGuardSheetState();
}

class _AuthGuardSheetState extends State<AuthGuardSheet> {
  bool _isBiometricLoading = false;

  void _onBiometricLogin(AuthProvider auth) async {
    setState(() => _isBiometricLoading = true);
    final success = await auth.loginWithBiometrics();
    if (!mounted) return;
    setState(() => _isBiometricLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت المصادقة بنجاح، مرحباً بك مجدداً ${auth.user?.name ?? ''}'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'تعذرت المصادقة بالبصمة'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  void _openLogin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    if (!mounted) return;
    if (result == true) {
      Navigator.of(context).pop(true);
    }
  }

  void _openRegister() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
    if (!mounted) return;
    if (result == true) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAccount = auth.hasAccountOnDevice;
    final lastKnown = auth.lastKnownUser;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top drag indicator
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),

          // Emblem / Icon Container
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.emeraldPrimary, AppColors.emeraldDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              color: AppColors.goldLight,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.emeraldPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Message
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Conditional UI: If user has registered account on device
          if (hasAccount) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.emeraldPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.emeraldPrimary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.emeraldPrimary,
                    child: Text(
                      lastKnown?.name.isNotEmpty == true
                          ? lastKnown!.name[0].toUpperCase()
                          : 'ز',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lastKnown?.name.isNotEmpty == true
                              ? 'حساب: ${lastKnown!.name}'
                              : 'حساب مسجل على هذا الجهاز',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (lastKnown?.email.isNotEmpty == true)
                          Text(
                            lastKnown!.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.verified_user,
                    color: AppColors.emeraldPrimary,
                    size: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. Biometric Fast Login
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isBiometricLoading ? null : () => _onBiometricLogin(auth),
                icon: _isBiometricLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.fingerprint, size: 24, color: AppColors.goldLight),
                label: Text(
                  _isBiometricLoading ? 'جارٍ المصادقة...' : 'المصادقة السريعة بالبصمة / Face ID',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 2. Password login
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openLogin,
                icon: const Icon(Icons.login, size: 18),
                label: const Text('تسجيل الدخول بكلمة المرور'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 3. New account option
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _openRegister,
                  child: const Text('إنشاء حساب جديد أو الدخول بحساب آخر'),
                ),
              ],
            ),
          ] else ...[
            // For a brand new user
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openLogin,
                icon: const Icon(Icons.login, size: 20),
                label: const Text(
                  'تسجيل الدخول إلى حسابك',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openRegister,
                icon: const Icon(Icons.person_add_outlined, size: 20, color: AppColors.goldDark),
                label: const Text(
                  'إنشاء حساب جديد الآن',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.goldDark),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  side: const BorderSide(color: AppColors.goldDark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          // Cancel button
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'المتابعة لاحقاً كزائر',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
