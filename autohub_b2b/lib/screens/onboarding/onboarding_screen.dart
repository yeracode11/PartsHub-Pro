import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/screens/onboarding/onboarding_page_model.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    OnboardingPageModel(
      title: 'Весь склад у вас в кармане',
      description:
          'Мгновенный поиск запчастей, проверка остатков и управление товарами — прямо с телефона.',
      icon: Icons.inventory_2_outlined,
      gradient: AppTheme.primaryGradient,
    ),
    OnboardingPageModel(
      title: 'Сканируй. Находи. Готово.',
      description:
          'Наведите камеру на QR-код или штрих-код — карточка запчасти откроется за секунду.',
      icon: Icons.qr_code_scanner,
      gradient: AppTheme.successGradient,
    ),
    OnboardingPageModel(
      title: 'Работает без интернета',
      description:
          'Все данные хранятся на устройстве. При появлении связи — автоматическая синхронизация.',
      icon: Icons.cloud_sync_outlined,
      gradient: AppTheme.warningGradient,
    ),
    OnboardingPageModel(
      title: 'Ваша роль — ваши инструменты',
      description:
          'Приложение адаптируется под вашу должность: кладовщик видит склад, менеджер — заказы и клиентов.',
      icon: Icons.groups_outlined,
      gradient: AppTheme.primaryGradient,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    widget.onComplete();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 520,
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: isMobile ? 12 : 16,
                      right: isMobile ? 16 : 24,
                    ),
                    child: TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Пропустить',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: isMobile ? 14 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemBuilder: (context, index) => _OnboardingPage(
                      model: _pages[index],
                      isMobile: isMobile,
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    isMobile ? 32 : 24,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _currentPage ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _currentPage
                                  ? AppTheme.primaryColor
                                  : AppTheme.borderColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 32 : 24),

                      SizedBox(
                        width: isMobile ? double.infinity : 240,
                        height: isMobile ? 56 : 44,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                isMobile ? 16 : 10,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            isLastPage ? 'Начать работу' : 'Далее',
                            style: TextStyle(
                              fontSize: isMobile ? 17 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _OnboardingPage extends StatelessWidget {
  final OnboardingPageModel model;
  final bool isMobile;

  const _OnboardingPage({required this.model, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final iconSize = isMobile ? 140.0 : 100.0;
    final iconInnerSize = isMobile ? 64.0 : 44.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 32 : 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              gradient: model.gradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: model.gradient.colors.first.withOpacity(0.35),
                  blurRadius: isMobile ? 32 : 24,
                  offset: Offset(0, isMobile ? 12 : 8),
                ),
              ],
            ),
            child: Icon(model.icon, size: iconInnerSize, color: Colors.white),
          ),
          SizedBox(height: isMobile ? 48 : 32),

          Text(
            model.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 26 : 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              height: 1.25,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 12),

          Text(
            model.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 16 : 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
