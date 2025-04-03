import 'package:flutter/material.dart';
import 'package:resourcehub/auth/signin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _pageOffset = 0;

  final List<OnboardingItem> _onboardingItems = [
    OnboardingItem(
      title: 'Discover Resources',
      description:
          'Access thousands of academic materials organized by courses and subjects',
      image: 'assets/onboarding1.png', // Replace with your assets
      color: const Color(0xFF6C63FF),
      secondaryColor: const Color(0xFF9C94FF),
    ),
    OnboardingItem(
      title: 'Stay Organized',
      description: 'Save your favorite resources and create personalized collections',
      image: 'assets/onboarding2.png', // Replace with your assets
      color: const Color(0xFF4CAF50),
      secondaryColor: const Color(0xFF81C784),
    ),
    OnboardingItem(
      title: 'Ready to Start?',
      description: 'Join thousands of students already using ResourceHub',
      image: 'assets/onboarding3.png',
      color: const Color(0xFFFF7043),
      secondaryColor: const Color(0xFFFF8A65),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _pageOffset = _pageController.page!;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToSignIn(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SignInPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _onboardingItems[_currentPage].color,
                  _onboardingItems[_currentPage].secondaryColor,
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: () => _navigateToSignIn(context),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // Page view
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _onboardingItems.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _onboardingItems[index];
                      final delta = index - _pageOffset;
                      final angle = delta * 0.2;
                      final scale = 1 - (delta.abs() * 0.1);

                      return Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle)
                          ..scale(scale),
                        alignment: delta < 0
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: OnboardingSlide(
                          item: item,
                          isLastPage: index == _onboardingItems.length - 1,
                          onGetStarted: () => _navigateToSignIn(context),
                        ),
                      );
                    },
                  ),
                ),

                // Dots indicator
                Container(
                  height: 24,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _onboardingItems.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentPage == index
                              ? Colors.white
                              : Colors.white.withAlpha(128), // Changed here
                        ),
                      ),
                    ),
                  ),
                ),

                // Next/Get Started button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _currentPage == _onboardingItems.length - 1
                        ? ElevatedButton(
                            key: const ValueKey('get_started'),
                            onPressed: () => _navigateToSignIn(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _onboardingItems[_currentPage].color,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: const Center(
                              child: Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                        : FloatingActionButton(
                            key: const ValueKey('next'),
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutQuint,
                              );
                            },
                            backgroundColor: Colors.white,
                            elevation: 4,
                            child: const Icon(
                              Icons.arrow_forward,
                              color: Colors.black87,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingSlide extends StatelessWidget {
  final OnboardingItem item;
  final bool isLastPage;
  final VoidCallback onGetStarted;

  const OnboardingSlide({
    super.key,
    required this.item,
    required this.isLastPage,
    required this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hero image with shadow
          Container(
            height: size.height * 0.4,
            margin: const EdgeInsets.only(bottom: 40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(51), // Changed here
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                item.image,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Title with fade animation
          FadeTransition(
            opacity: AlwaysStoppedAnimation(isLastPage ? 1.0 : 0.8),
            child: Text(
              item.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith( // Using context here
                color: Colors.white,
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(
                    color: Colors.black.withAlpha(25), // Changed here
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // Description with subtle animation
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              item.description,
              key: ValueKey(item.description),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith( // Using context here
                color: Colors.white.withAlpha(230), // Changed here
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final String image;
  final Color color;
  final Color secondaryColor;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.image,
    required this.color,
    required this.secondaryColor,
  });
}
