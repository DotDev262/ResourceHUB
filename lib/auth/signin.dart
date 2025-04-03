import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:resourcehub/widgets/navigation_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:resourcehub/auth/signup.dart';
import 'package:resourcehub/main.dart';

const String studentDomain = '@ch.students.amrita.edu';
const String facultyDomain = '@ch.amrita.edu';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;
  final Logger logger = Logger('SignInPage');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (response.user != null) {
        if (!mounted) return;
        final email = _emailController.text;
        if (email.endsWith(studentDomain) || email.endsWith(facultyDomain)) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const NavigationWidget()),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid Email Domain')));
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.message.contains('Invalid credentials')) {
          _errorMessage = 'Invalid email or password.';
        } else if (e.message.contains('Email not confirmed')) {
          _errorMessage = 'Please confirm your email address.';
        } else {
          _errorMessage = e.message;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An unexpected error occurred.';
        _isLoading = false;
      });
      logger.severe('Sign-in error: $e');
    }
  }

  void _navigateToSignUp() {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (context) => const SignUpPage(),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const SignInWelcomeText(), // Separated Widget
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width:
                MediaQuery.of(context).size.width > 600 ? 400 : double.infinity,
            padding: const EdgeInsets.all(24.0),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  const SignInTitle(), // Separated Widget
                  const SizedBox(height: 24),
                  SignInEmailFormField(controller: _emailController), // Separated Widget
                  const SizedBox(height: 20),
                  SignInPasswordFormField(controller: _passwordController), // Separated Widget
                  const SizedBox(height: 24),
                  if (_isLoading)
                    CircularProgressIndicator(color: colors.primary)
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _signIn,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const SignInButtonText(), // Separated Widget
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_errorMessage.isNotEmpty)
                    SignInErrorMessage(errorMessage: _errorMessage), // Separated Widget
                  const SizedBox(height: 16),
                  const DontHaveAccountText(), // Separated Widget
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignInWelcomeText extends StatelessWidget {
  const SignInWelcomeText({super.key});

  @override
  Widget build(BuildContext context) {
    return const WelcomeTextAnimator();
  }
}

class SignInTitle extends StatelessWidget {
  const SignInTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Sign In',
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    );
  }
}

class SignInEmailFormField extends StatelessWidget {
  final TextEditingController controller;

  const SignInEmailFormField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Email',
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        prefixIcon: Icon(Icons.email, color: colors.primary),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }
}

class SignInPasswordFormField extends StatefulWidget {
  final TextEditingController controller;

  const SignInPasswordFormField({super.key, required this.controller});

  @override
  State<SignInPasswordFormField> createState() => _SignInPasswordFormFieldState();
}

class _SignInPasswordFormFieldState extends State<SignInPasswordFormField> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Password',
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        prefixIcon: Icon(Icons.lock, color: colors.primary),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: colors.onSurface.withValues(alpha: 0.6),
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
          return 'Please enter your password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }
}

class SignInButtonText extends StatelessWidget {
  const SignInButtonText({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Sign In',
      style: TextStyle(fontSize: 16),
    );
  }
}

class SignInErrorMessage extends StatelessWidget {
  final String errorMessage;

  const SignInErrorMessage({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(color: colors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class DontHaveAccountText extends StatelessWidget {
  const DontHaveAccountText({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: () { // Wrap the method call in a function
        final state = context.findAncestorStateOfType<_SignInPageState>();
        state?._navigateToSignUp();
      },
      child: RichText(
        text: TextSpan(
          text: "Don't have an account? ",
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.7),
          ),
          children: [
            TextSpan(
              text: 'Sign up',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomeTextAnimator extends StatefulWidget {
  const WelcomeTextAnimator({super.key});

  @override
  State<WelcomeTextAnimator> createState() => _WelcomeTextAnimatorState();
}

class _WelcomeTextAnimatorState extends State<WelcomeTextAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<int> _typingAnimation;
  final String _welcomeText = "Welcome";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _typingAnimation = IntTween(begin: 0, end: _welcomeText.length).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>( // Using ValueListenableBuilder
      valueListenable: _typingAnimation,
      builder: (context, value, child) {
        return Text(
          _welcomeText.substring(0, value),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        );
      },
    );
  }
}