import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/preferences_service.dart';
import '../../core/utils/responsive_helper.dart';
import '../dashboard/main_navigation_screen.dart';

class OnboardingSlide {
  final String title;
  final String description;
  final String imagePath;
  final IconData icon;

  OnboardingSlide({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.icon,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      title: 'حساب دقيق لكافة أنواع الزكاة',
      description: 'حساب شرعي موثوق ومفصل لزكاة النقد، الذهب والفضة، الأنعام، عروض التجارة، الحبوب، والركاز.',
      imagePath: 'assets/images/money.png',
      icon: Icons.calculate_outlined,
    ),
    OnboardingSlide(
      title: 'متتبع الحول الذكي وتنبيهات النصاب',
      description: 'سجّل تاريخ بلوغ النصاب ليتتبع التطبيق الحول الهجري تلقائياً وينبهك قبل موعد إخراج الزكاة.',
      imagePath: 'assets/images/gold.png',
      icon: Icons.timer_outlined,
    ),
    OnboardingSlide(
      title: 'تقارير رسمية وطلبات المساعدة',
      description: 'تصدير إقرارات الزكاة بصيغة PDF قابلة للمشاركة، وبوابة رقمية موثقة لتقديم خطابات المساعدة المالية.',
      imagePath: 'assets/images/trade.png',
      icon: Icons.description_outlined,
    ),
  ];

  void _onFinish() async {
    await PreferencesService.setOnboardingCompleted(true);
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
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
      body: SafeArea(
        child: Center(
          child: ResponsiveConstraint(
            maxWidth: 540,
            child: Column(
              children: [
            // Top Bar with Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _onFinish,
                    child: const Text(
                      'تخطي',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.emeraldPrimary,
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentIndex == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? AppColors.emeraldPrimary
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  final screenHeight = MediaQuery.sizeOf(context).height;
                  final circleSize = (screenHeight * 0.22).clamp(110.0, 185.0);
                  final isShort = screenHeight < 650;

                  return Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.sizeOf(context).width < 360 ? 18 : 28,
                        vertical: isShort ? 8 : 16,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: circleSize,
                            height: circleSize,
                            padding: EdgeInsets.all(isShort ? 16 : 22),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.emeraldPrimary.withValues(alpha: 0.25)
                                  : AppColors.emeraldSubtle,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.goldAccent.withValues(alpha: isDark ? 0.7 : 0.5),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.3)
                                      : AppColors.emeraldPrimary.withValues(alpha: 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              isDark
                                  ? slide.imagePath.replaceFirst('assets/images/', 'assets/images/dark/')
                                  : slide.imagePath,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                slide.icon,
                                size: circleSize * 0.45,
                                color: isDark ? AppColors.goldLight : AppColors.emeraldPrimary,
                              ),
                            ),
                          ),
                          SizedBox(height: isShort ? 20 : 32),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isShort ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.emeraldDark,
                            ),
                          ),
                          SizedBox(height: isShort ? 8 : 14),
                          Text(
                            slide.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isShort ? 13 : 15,
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom action button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentIndex == _slides.length - 1) {
                      _onFinish();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentIndex == _slides.length - 1 ? 'ابدأ الاستخدام الآن' : 'التالي',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }
}
