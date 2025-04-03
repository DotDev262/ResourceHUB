import 'package:flutter/material.dart';
import 'package:resourcehub/auth/signin.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnimationTask {
  final int priority;
  final VoidCallback action;
  final String tag;

  AnimationTask({
    required this.priority,
    required this.action,
    required this.tag,
  });

  @override
  String toString() => 'AnimationTask[$tag] (priority: $priority)';
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _pageOffset = 0;
  
  final List<AnimationTask> _animationQueue = [];
  late AnimationController _queueController;

  final List<OnboardingItem> _onboardingItems = [
    OnboardingItem(
      title: 'Discover Resources',
      description: 'Access thousands of academic materials organized by courses and subjects',
      image: 'assets/images/onboarding1.jpg',
      color: const Color(0xFF6C63FF),
      secondaryColor: const Color(0xFF9C94FF),
    ),
    OnboardingItem(
      title: 'Stay Organized',
      description: 'Save your favorite resources and create personalized collections',
      image: 'assets/images/onboarding2.jpg',
      color: const Color(0xFF4CAF50),
      secondaryColor: const Color(0xFF81C784),
    ),
    OnboardingItem(
      title: 'Ready to Start?',
      description: 'Join thousands of students already using ResourceHub',
      image: 'assets/images/onboarding3.jpg',
      color: const Color(0xFFFF7043),
      secondaryColor: const Color(0xFFFF8A65),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _queueController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(_processAnimationQueue);
    
    _pageController.addListener(() {
      setState(() {
        _pageOffset = _pageController.page ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _queueController.dispose();
    _animationQueue.clear();
    super.dispose();
  }

  void _queueAnimation(AnimationTask task) {
    _animationQueue.add(task);
    _animationQueue.sort((a, b) => a.priority.compareTo(b.priority));
    if (!_queueController.isAnimating) {
      _queueController.forward(from: 0);
    }
  }

  void _processAnimationQueue() {
    if (_animationQueue.isNotEmpty) {
      final task = _animationQueue.removeAt(0);
      task.action();
      
      if (_animationQueue.isNotEmpty) {
        _queueController.forward(from: 0);
      }
    }
  }

  void _addPageTransitionAnimations() {
    if (!mounted) return;
    
    _queueAnimation(AnimationTask(
      priority: 1,
      tag: 'background_gradient',
      action: () {
        if (mounted) setState(() {});
      },
    ));

    _queueAnimation(AnimationTask(
      priority: 2,
      tag: 'content_transform',
      action: () {
        if (mounted) setState(() {});
      },
    ));

    _queueAnimation(AnimationTask(
      priority: 3, 
      tag: 'dots_indicator',
      action: () {
        if (mounted) setState(() {});
      },
    ));
  }

  Future<void> _navigateToSignIn(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const SignInPage(),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && mounted) {
        _addPageTransitionAnimations();
      }
    });

    return Scaffold(
      body: Stack(
        children: [
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

          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: AnimatedOpacity(
                    opacity: _currentPage == _onboardingItems.length - 1 ? 0 : 1,
                    duration: const Duration(milliseconds: 300),
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
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _onboardingItems.length,
                    onPageChanged: (index) {
                      if (mounted) {
                        setState(() {
                          _currentPage = index;
                        });
                      }
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
                              : Colors.white.withAlpha(128),
                        ),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                        : _BouncingNextButton(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutQuint,
                              );
                            },
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
          _AnimatedImageContainer(
            height: size.height * 0.4,
            image: item.image,
          ),

          _AnimatedTitleText(
            text: item.title,
            isLastPage: isLastPage,
          ),

          const SizedBox(height: 16),

          Text(
            item.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withAlpha(230),
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AnimatedImageContainer extends StatelessWidget {
  final double height;
  final String image;

  const _AnimatedImageContainer({
    required this.height,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.9, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            height: height,
            margin: const EdgeInsets.only(bottom: 40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                image,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedTitleText extends StatelessWidget {
  final String text;
  final bool isLastPage;

  const _AnimatedTitleText({
    required this.text,
    required this.isLastPage,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Text(
              text,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 4,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}

class _BouncingNextButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _BouncingNextButton({
    required this.onPressed,
  });

  @override
  State<_BouncingNextButton> createState() => _BouncingNextButtonState();
}

class _BouncingNextButtonState extends State<_BouncingNextButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animation.value, 0),
          child: FloatingActionButton(
            onPressed: widget.onPressed,
            backgroundColor: Colors.white,
            elevation: 4,
            child: const Icon(
              Icons.arrow_forward,
              color: Colors.black87,
            ),
          ),
        );
      },
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