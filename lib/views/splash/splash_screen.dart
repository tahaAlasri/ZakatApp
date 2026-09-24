import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/preferences_service.dart';
import '../../core/utils/responsive_helper.dart';
import '../onboarding/onboarding_screen.dart';
import '../dashboard/main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.9, curve: Curves.easeIn),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeInOutSine),
      ),
    );

    _controller.forward().then((_) => _navigateToNext());
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final isOnboardingCompleted = PreferencesService.isOnboardingCompleted;

    // Enter directly to MainNavigationScreen (as guest or authenticated user)
    final Widget nextScreen = isOnboardingCompleted
        ? const MainNavigationScreen()
        : const OnboardingScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppColors.emeraldDark,
              AppColors.emeraldPrimary,
              Color(0xFF072718),
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final screenHeight = MediaQuery.sizeOf(context).height;
            final isShort = screenHeight < 650;
            final emblemSize = isShort ? 110.0 : 140.0;

            return Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: context.rPadding(
                  horizontal: 24,
                  vertical: isShort ? 20 : 40,
                ),
                child: ResponsiveConstraint(
                  maxWidth: 480,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    if (!isShort) const SizedBox(height: 20),
                    // Animated Glowing Emblem
                    Transform.scale(
                      scale: _scaleAnimation.value * _pulseAnimation.value,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: Container(
                          width: emblemSize,
                          height: emblemSize,
                          padding: EdgeInsets.all(isShort ? 14 : 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.goldAccent.withValues(alpha: 0.4),
                                blurRadius: 30,
                                spreadRadius: 8,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/MainIcon.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.account_balance_wallet,
                              size: emblemSize * 0.5,
                              color: AppColors.emeraldPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isShort ? 20 : 32),

                    // Animated App Title
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            'الهيئة العامة للزكاة',
                            style: TextStyle(
                              fontSize: isShort ? 24 : 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.goldAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.goldAccent.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'نظام الزكاة الشامل | نماء وطهارة',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.goldLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isShort ? 30 : 60),

                    // Bottom Indicator & Bismillah
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldAccent),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '{وَأَقِيمُوا الصَّلَاةَ وَآتُوا الزَّكَاةَ}',
                            style: TextStyle(
                              fontSize: isShort ? 13 : 14,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          },
        ),
      ),
    );
  }
}
