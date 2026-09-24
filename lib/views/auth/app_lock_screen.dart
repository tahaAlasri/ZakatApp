import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/app_lock_manager.dart';
import '../../core/utils/responsive_helper.dart';
import '../../providers/auth_provider.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _showLogoutConfirm = false;
  String? _errorMessage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // تشغيل المصادقة البيومترية تلقائياً بعد استقرار الشاشة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBiometrics(auto: true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _passwordFocusNode.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometrics({bool auto = false}) async {
    final lockManager = Provider.of<AppLockManager>(context, listen: false);
    setState(() {
      _errorMessage = null;
    });

    try {
      final success = await lockManager.unlockWithBiometrics();
      if (!success && !auto) {
        if (mounted) {
          setState(() {
            _errorMessage = 'لم يتم تأكيد البصمة، يمكنك استخدام كلمة المرور أدناه.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final err = e.toString().replaceAll('Exception: ', '');
        // إذا كان الفحص تلقائياً ولم يدعم الجهاز البصمة، نترك الخيار لكلمة المرور بدون إزعاج
        if (!auto || !err.contains('لا يدعم')) {
          setState(() {
            _errorMessage = err;
          });
        }
      }
    }
  }

  Future<void> _unlockWithPassword() async {
    FocusScope.of(context).unfocus();
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال كلمة المرور للمتابعة';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final lockManager = Provider.of<AppLockManager>(context, listen: false);

    try {
      final success = await lockManager.unlockWithPassword(password);
      if (!success && mounted) {
        setState(() {
          _errorMessage = 'كلمة المرور غير صحيحة، يرجى المحاولة مرة أخرى.';
        });
        _passwordController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _passwordController.text.length,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
        _passwordController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _passwordController.text.length,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final userName = user?.name.trim().isNotEmpty == true ? user!.name : 'المستخدم الكريم';
    final userEmail = user?.email ?? '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showLogoutConfirm) {
          setState(() {
            _showLogoutConfirm = false;
          });
        } else {
          SystemNavigator.pop();
        }
      },
      child: Material(
        color: Colors.transparent,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: const Color(0xFF04140D),
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.emeraldDark,
                    Color(0xFF072418),
                    Color(0xFF04140D),
                  ],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: context.rPadding(horizontal: 24, vertical: 20),
                    physics: const BouncingScrollPhysics(),
                    child: ResponsiveConstraint(
                      maxWidth: 420,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Lock Icon
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldPrimary.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.goldAccent.withValues(alpha: 0.6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.goldAccent.withValues(alpha: 0.25),
                                  blurRadius: 25,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              size: 44,
                              color: AppColors.goldAccent,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // User Avatar
                          if (user?.profileImagePath != null && File(user!.profileImagePath!).existsSync())
                            CircleAvatar(
                              radius: 36,
                              backgroundImage: FileImage(File(user.profileImagePath!)),
                            )
                          else
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.goldAccent.withValues(alpha: 0.2),
                              child: Text(
                                userName.isNotEmpty ? userName.substring(0, 1) : 'ز',
                                style: GoogleFonts.cairo(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.goldAccent,
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),

                          // User Greeting
                          Text(
                            'مرحباً، $userName',
                            style: GoogleFonts.cairo(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (userEmail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              userEmail,
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.65),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                            ),
                            child: Text(
                              '🔒 تم قفل التطبيق تلقائياً لحماية حسابك وأموالك',
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.goldLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Biometric Fingerprint Button
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: GestureDetector(
                              onTap: () => _triggerBiometrics(auto: false),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1B6B48),
                                      Color(0xFF0F4D33),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(color: AppColors.goldAccent, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.goldAccent.withValues(alpha: 0.35),
                                      blurRadius: 20,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.fingerprint_rounded,
                                  size: 46,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => _triggerBiometrics(auto: false),
                            child: Text(
                              'انقر للمصادقة بالبصمة',
                              style: GoogleFonts.cairo(
                                color: AppColors.goldAccent,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Divider
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'أو بكلمة المرور',
                                  style: GoogleFonts.cairo(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Error Banner
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.15),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.cairo(
                                        color: const Color(0xFFFFB4AB),
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Password Input Field
                          TextField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: !_isPasswordVisible,
                            autocorrect: false,
                            enableSuggestions: false,
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.done,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            onChanged: (_) {
                              if (_errorMessage != null) {
                                setState(() {
                                  _errorMessage = null;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              hintText: 'كلمة المرور',
                              hintStyle: GoogleFonts.cairo(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: AppColors.goldAccent,
                                size: 20,
                              ),
                              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _passwordController,
                                builder: (context, val, _) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (val.text.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.cancel,
                                            color: Colors.white70,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _passwordController.clear();
                                            _passwordFocusNode.requestFocus();
                                            if (_errorMessage != null) {
                                              setState(() {
                                                _errorMessage = null;
                                              });
                                            }
                                          },
                                        ),
                                      IconButton(
                                        icon: Icon(
                                          _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                          color: Colors.white.withValues(alpha: 0.7),
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isPasswordVisible = !_isPasswordVisible;
                                          });
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.08),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.goldAccent, width: 1.5),
                              ),
                            ),
                            onSubmitted: (_) => _unlockWithPassword(),
                          ),

                          const SizedBox(height: 16),

                          // Unlock Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.goldAccent,
                                foregroundColor: const Color(0xFF0F3622),
                                elevation: 3,
                                minimumSize: const Size.fromHeight(52),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isLoading ? null : _unlockWithPassword,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F3622)),
                                      ),
                                    )
                                  : Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.lock_open_rounded,
                                            size: 20,
                                            color: Color(0xFF0F3622),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'إلغاء قفل التطبيق',
                                            style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              height: 1.25,
                                              color: const Color(0xFF0F3622),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Logout / Switch Account Option
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showLogoutConfirm = true;
                              });
                            },
                            icon: Icon(Icons.logout, color: Colors.white.withValues(alpha: 0.6), size: 18),
                            label: Text(
                              'تسجيل الخروج والعودة كزائر',
                              style: GoogleFonts.cairo(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Custom Logout Confirmation Modal (Independent of Navigator)
          if (_showLogoutConfirm)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.75),
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF132A20),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.goldAccent.withValues(alpha: 0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.logout, color: AppColors.error, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'تسجيل الخروج والعودة كزائر',
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'هل ترغب في تسجيل الخروج من هذا الحساب والدخول للتطبيق في وضع الزائر المفتوح؟',
                          style: GoogleFonts.cairo(
                            fontSize: 13.5,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showLogoutConfirm = false;
                                  });
                                },
                                child: Text(
                                  'إلغاء',
                                  style: GoogleFonts.cairo(color: Colors.white70),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () async {
                                  setState(() {
                                    _showLogoutConfirm = false;
                                  });
                                  final auth = Provider.of<AuthProvider>(context, listen: false);
                                  final lock = Provider.of<AppLockManager>(context, listen: false);
                                  await auth.logout();
                                  lock.unlock();
                                },
                                child: Text(
                                  'تأكيد الخروج',
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }
}
