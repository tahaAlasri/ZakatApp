import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/database/preferences_service.dart';
import '../auth/login_screen.dart';

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
      icon: Icons.notifications_active_outlined,
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldSubtle,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.goldAccent.withValues(alpha: 0.5), width: 2),
                          ),
                          child: Image.asset(
                            slide.imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              slide.icon,
                              size: 80,
                              color: AppColors.emeraldPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.emeraldDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                            height: 1.6,
                          ),
                        ),
                      ],
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
    );
  }
}
