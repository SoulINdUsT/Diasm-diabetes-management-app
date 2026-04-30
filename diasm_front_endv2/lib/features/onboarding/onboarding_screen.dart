
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  static const int _totalPages = 2;
  int _currentPage = 0;

  // Palette
  static const Color _gradientTop = Color(0xFFB7F3F0);
  static const Color _gradientBottom = Color(0xFF9AD9A6);
  static const Color _primaryTeal = Color(0xFF028090);
  static const Color _textDark = Color(0xFF05253D);
  static const Color _bodyColor = Color(0xFF4B5A66);
  static const Color _cardBg = Colors.white; // currently unused, fine

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToLogin(BuildContext context) {
    context.go('/login');
  }

  void _goToRegister(BuildContext context) {
    context.go('/register');
  }

  void _nextPageOrLogin() {
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _goToLogin(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_gradientTop, _gradientBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: Skip on the right
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Spacer(),
                    TextButton(
                      onPressed: () => _goToLogin(context),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _primaryTeal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  children: [
                    _buildIntroPage(context, size),
                    _buildFeaturesPage(context),
                  ],
                ),
              ),

              // Page indicators
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_totalPages, (index) {
                    final bool isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(left: index == 0 ? 0 : 8),
                      height: 6,
                      width: isActive ? 24 : 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? _primaryTeal
                            : _primaryTeal.withOpacity(0.30),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ========== PAGE 1: HERO INTRO ==========

  Widget _buildIntroPage(BuildContext context, Size size) {
    final double heroDiameter = size.height * 0.45; // medium hero
    final double bottomCircleDiameter = size.height * 0.80; // green "hill"

    final h = size.height;

    // Responsive text sizes
    final double logoSize = h * 0.034; // ~28 on typical phone
    final double taglineEnSize = h * 0.022; // ~18
    final double taglineBnSize = h * 0.020; // ~16
    final double taglineSpacing = h * 0.005; // spacing between EN + BN

    return Stack(
      children: [
        // Bottom green arc
        Positioned(
          bottom: -bottomCircleDiameter * 0.40,
          left: -bottomCircleDiameter * 0.15,
          right: -bottomCircleDiameter * 0.15,
          child: Container(
            height: bottomCircleDiameter,
            decoration: const BoxDecoration(
              color: Color(0xFF7BC58E),
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Main content
        Column(
          children: [
            const SizedBox(height: 8),

            // Brand / Logo text
            Text(
              'Diasm',
              style: TextStyle(
                fontSize: logoSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: _textDark,
              ),
            ),

            SizedBox(height: h * 0.015),

            Column(
              children: [
                Text(
                  'Your control, your health',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: taglineEnSize,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
                SizedBox(height: taglineSpacing),
                Text(
                  'নিয়ন্ত্রণ থাকুক হাতে , স্বাস্থ্য থাকুক সাথে',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: taglineBnSize,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: _textDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Hero circular illustration
            Container(
              width: heroDiameter,
              height: heroDiameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                    color: Colors.black.withOpacity(0.12),
                  ),
                ],
              ),
              child: ClipOval(
                child: Transform.translate(
                  offset: const Offset(0, -30),
                  child: Transform.scale(
                    scale: 1.24,
                    child: Image.asset(
                      'assets/onboarding/heroonboardingscreen.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Bottom CTA button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryTeal,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                  onPressed: _nextPageOrLogin,
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ========== PAGE 2: FEATURES + LOGIN/SIGNUP LINKS ==========

  Widget _buildFeaturesPage(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final h = size.height;

    final double titleSize = h * 0.026; // Responsive title
    final double subtitleSize = h * 0.018; // Responsive subtitle
    final double rowSpacing = h * 0.024; // Space between rows

    return Column(
      children: [
        const SizedBox(height: 16),

        // Title
        Text(
          'Your Diabetes Companion',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            color: _textDark,
          ),
        ),

        const SizedBox(height: 6),

        // Subtitle (EN only)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Track, learn, and stay in control of your daily health.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: subtitleSize,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: _bodyColor,
            ),
          ),
        ),

        SizedBox(height: rowSpacing),

        // Animated feature rows
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform(
                  transform: Matrix4.identity()
                    ..translate(0.0, 16 * (1 - value))
                    ..scale(0.98 + 0.02 * value),
                  child: child,
                ),
              );
            },
            child: Column(
              children: [
                const _FeatureRow(
                  icon: Icons.show_chart_rounded,
                  titleEn: 'Track your health',
                  titleBn: 'স্বাস্থ্য নিয়মিত ট্র্যাক করুন',
                  bodyEn: 'Monitor glucose, weight and steps effortlessly.',
                  bodyBn: 'সহজভাবে গ্লুকোজ, ওজন ও পদক্ষেপ মনিটর করুন।',
                ),
                SizedBox(height: rowSpacing),
                const _FeatureRow(
                  icon: Icons.menu_book_rounded,
                  titleEn: 'Learn about diabetes',
                  titleBn: 'ডায়াবেটিস সম্পর্কে জানুন',
                  bodyEn:
                      'Understand diabetes with clear, simplified lessons.',
                  bodyBn:
                      'সহজ ও স্পষ্ট উপস্থাপনায় ডায়াবেটিস সম্পর্কে জানুন।',
                ),
                SizedBox(height: rowSpacing),
                const _FeatureRow(
                  icon: Icons.notifications_active_rounded,
                  titleEn: 'Stay reminded',
                  titleBn: 'রিমাইন্ডার থাকুক পাশে',
                  bodyEn:
                      'Get reminders for medication, fasting, and routines.',
                  bodyBn: 'ওষুধ, ফাস্টিং ও রুটিনের রিমাইন্ডার পান।',
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Login / Signup text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(fontSize: 13, color: _bodyColor),
                  ),
                  GestureDetector(
                    onTap: () => _goToLogin(context),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _primaryTeal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  const Text(
                    'New here? ',
                    style: TextStyle(fontSize: 13, color: _bodyColor),
                  ),
                  GestureDetector(
                    onTap: () => _goToRegister(context),
                    child: const Text(
                      'Sign up',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _primaryTeal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

// ========== MINIMAL FEATURE ROW WIDGET ==========

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String titleEn;
  final String titleBn;
  final String bodyEn;
  final String bodyBn;

  const _FeatureRow({
    required this.icon,
    required this.titleEn,
    required this.titleBn,
    required this.bodyEn,
    required this.bodyBn,
  });

  static const Color _textDark = Color(0xFF05253D);
  static const Color _bodyColor = Color(0xFF4B5A66);
  static const Color _accentTeal = Color(0xFF028090);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon in soft rounded-square background + shadow
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE5F7F2),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    color: Colors.black.withOpacity(0.05),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 24,
                color: _accentTeal,
              ),
            ),
            const SizedBox(width: 12),

            // Texts (EN + BN)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleEn,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  Text(
                    titleBn,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bodyEn,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: _bodyColor,
                    ),
                  ),
                  Text(
                    bodyBn,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: _bodyColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Softer divider line
        Divider(
          height: 1,
          thickness: 0.7,
          color: Colors.white.withOpacity(0.3),
        ),
      ],
    );
  }
}
