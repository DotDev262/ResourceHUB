import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:resourcehub/widgets/navigation_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:resourcehub/main.dart';
import 'package:resourcehub/auth/signin.dart';

const String studentDomain = '@ch.students.amrita.edu';
const String facultyDomain = '@ch.amrita.edu';

String? guessRoleFromEmail(String email) {
  if (email.endsWith(studentDomain)) {
    return 'Student';
  } else if (email.endsWith(facultyDomain)) {
    return 'Faculty';
  } else {
    return null;
  }
}

String? guessAdmissionYearFromStudentEmail(String email) {
  if (email.endsWith(studentDomain)) {
    final parts = email.split('@');
    if (parts.isNotEmpty) {
      final studentIdPart = parts[0];
      final yearMatch = RegExp(r'cse(\d{2})').firstMatch(studentIdPart);
      if (yearMatch != null && yearMatch.groupCount >= 1) {
        return '20${yearMatch.group(1)}';
      }
    }
  }
  return null;
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignUpPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;
  final Logger logger = Logger('SignupPage');
  final _formKey = GlobalKey<FormState>();

  String? _selectedRole;
  String? _selectedDepartment;
  String? _guessedAdmissionYear;
  final List<String> _departments = [
    'Computer Science',
    'Electrical Engineering',
    'Mechanical Engineering',
    'Information Technology',
  ];

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_debouncedGuessAndSetRole);
  }

  Timer? _debounceTimer;
  final Duration _debounceDelay = const Duration(milliseconds: 300);

  void _debouncedGuessAndSetRole() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(_debounceDelay, _guessAndSetRole);
  }

  void _guessAndSetRole() {
  final guessedRole = guessRoleFromEmail(_emailController.text);
  final guessedYear = guessAdmissionYearFromStudentEmail(_emailController.text);
  if (guessedRole != null && _selectedRole != guessedRole) {
    setState(() {
      _selectedRole = guessedRole;
      _guessedAdmissionYear = guessedYear;
      if (_selectedRole != 'Student') {
        _selectedDepartment = null;
      }
    });
  } else if (guessedRole == null && _selectedRole != null) {
    setState(() {
      _selectedRole = null;
      _selectedDepartment = null;
      _guessedAdmissionYear = null;
    });
  } else if (guessedRole == 'Student' && _guessedAdmissionYear != guessedYear) {
    setState(() {
      _guessedAdmissionYear = guessedYear;
    });
  }
}

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _emailController.removeListener(_debouncedGuessAndSetRole);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }


  void _navigateToSignIn() {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (context) => const SignInPage(),
    ),
  );
}
  

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedRole == null) {
      setState(() {
        _errorMessage =
            'We could not determine your role from the email. Please use a valid student or faculty email.';
      });
      return;
    }
    if (_selectedRole == 'Student' && _selectedDepartment == null) {
      setState(() {
        _errorMessage = 'Please select your department.';
      });
      return;
    }
    setState(() {
      _errorMessage = '';
      _isLoading = true;
    });

    try {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = 'Passwords do not match.';
          _isLoading = false;
        });
        return;
      }

      final response = await supabase.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final User? user = response.user;

      if (user != null && mounted) {
        final Session? session = supabase.auth.currentSession;
        if (session != null) {
         await supabase.from('users').insert([
          {
            'id': response.user!.id,
            'name': _nameController.text,
            'email': _emailController.text,
            'role': _selectedRole?.toLowerCase(),
            'department': _selectedDepartment,
            'admission_year': _guessedAdmissionYear,
          },
        ]);

          if (!mounted) return;
          final email = _emailController.text;
          if (email.endsWith(studentDomain) || email.endsWith(facultyDomain)) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const NavigationWidget()),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid Email Domain')),
            );
          }
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.message.contains('Password should be at least 6 characters')) {
          _errorMessage = 'Password must be at least 6 characters';
        } else if (e.message.contains('User already registered')) {
          _errorMessage = 'The account already exists for that email.';
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
      logger.severe('Error signing up with Supabase', e);
    }
  }

  void _onDepartmentChanged(String? value) {
    setState(() {
      _selectedDepartment = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const WelcomeText(), // Separated Widget
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
                  const SizedBox(height: 16),
                  const SignUpTitle(), // Separated Widget
                  const SizedBox(height: 24),
                  NameFormField(controller: _nameController), // Separated Widget
                  const SizedBox(height: 16),
                  EmailFormField(
                      controller: _emailController,
                      onRoleGuessed: (role, department) {
                        setState(() {
                          _selectedRole = role;
                          _selectedDepartment = department;
                        });
                      }), // Separated Widget
                  const SizedBox(height: 16),
                  if (_selectedRole == 'Student')
                    DepartmentDropdown(
                      departments: _departments,
                      selectedValue: _selectedDepartment,
                      onChanged: _onDepartmentChanged,
                    ),
                  const SizedBox(height: 16),
                  PasswordFormField(controller: _passwordController),
                  const SizedBox(height: 16),
                  ConfirmPasswordFormField(
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    CircularProgressIndicator(color: colors.primary)
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _signUp,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const SignUpButtonText(), // Separated Widget
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_errorMessage.isNotEmpty)
                    ErrorMessage(errorMessage: _errorMessage), // Separated Widget
                  const SizedBox(height: 16),
                  const AlreadyHaveAccountText(), // Separated Widget
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeText extends StatelessWidget {
  const WelcomeText({super.key});

  @override
  Widget build(BuildContext context) {
    return const WelcomeTextAnimator(welcomeText: "Hello!");
  }
}

class SignUpTitle extends StatelessWidget {
  const SignUpTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Sign Up',
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    );
  }
}

class NameFormField extends StatelessWidget {
  final TextEditingController controller;

  const NameFormField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Name',
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        prefixIcon: Icon(Icons.person, color: colors.primary),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your name';
        }
        return null;
      },
    );
  }
}

class EmailFormField extends StatefulWidget {
  final TextEditingController controller;
  final Function(String?, String?) onRoleGuessed;

  const EmailFormField({super.key, required this.controller, required this.onRoleGuessed});

  @override
  State<EmailFormField> createState() => _EmailFormFieldState();
}

class _EmailFormFieldState extends State<EmailFormField> {
  Timer? _debounceTimer;
  final Duration _debounceDelay = const Duration(milliseconds: 300);
  String? _currentRole;
  String? _currentDepartment;

  void _debouncedGuessAndSetRole() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(_debounceDelay, _guessAndSetRole);
  }

  void _guessAndSetRole() {
    final guessedRole = guessRoleFromEmail(widget.controller.text);
    String? guessedDepartment;
    if (guessedRole != null && guessedRole != 'Student') {
      guessedDepartment = null;
    }

    if (guessedRole != _currentRole || guessedDepartment != _currentDepartment) {
      widget.onRoleGuessed(guessedRole, guessedDepartment);
      _currentRole = guessedRole;
      _currentDepartment = guessedDepartment;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_debouncedGuessAndSetRole);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_debouncedGuessAndSetRole);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextFormField(
      controller: widget.controller,
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
        final guessedRole = guessRoleFromEmail(value);
        if (guessedRole == null) {
          return 'Please use a valid student or faculty email.';
        }
        return null;
      },
    );
  }
}

class SignUpButtonText extends StatelessWidget {
  const SignUpButtonText({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Sign Up',
      style: TextStyle(fontSize: 16),
    );
  }
}

class ErrorMessage extends StatelessWidget {
  final String errorMessage;

  const ErrorMessage({super.key, required this.errorMessage});

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

class AlreadyHaveAccountText extends StatelessWidget {
  const AlreadyHaveAccountText({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: () { // Wrap the method call in a function
        final state = context.findAncestorStateOfType<_SignupPageState>();
        state?._navigateToSignIn();
      },
      child: RichText(
        text: TextSpan(
          text: "Already have an account? ",
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.7),
          ),
          children: [
            TextSpan(
              text: 'Sign in',
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
  final String welcomeText;

  const WelcomeTextAnimator({super.key, required this.welcomeText});

  @override
  State<WelcomeTextAnimator> createState() => _WelcomeTextAnimatorState();
}

class _WelcomeTextAnimatorState extends State<WelcomeTextAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<int> _typingAnimation;
  int _displayTextCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _typingAnimation = IntTween(begin: 0, end: widget.welcomeText.length).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    )..addListener(() {
      setState(() {
        _displayTextCount = _typingAnimation.value;
      });
    });
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.welcomeText.substring(0, _displayTextCount),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}

class PasswordFormField extends StatefulWidget {
  final TextEditingController controller;

  const PasswordFormField({super.key, required this.controller});

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
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

class ConfirmPasswordFormField extends StatefulWidget {
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;

  const ConfirmPasswordFormField({
    super.key,
    required this.passwordController,
    required this.confirmPasswordController,
  });

  @override
  State<ConfirmPasswordFormField> createState() =>
      _ConfirmPasswordFormFieldState();
}

class _ConfirmPasswordFormFieldState extends State<ConfirmPasswordFormField> {
  bool _obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextFormField(
      controller: widget.confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        prefixIcon: Icon(
          Icons.lock_outline,
          color: colors.primary,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
            color: colors.onSurface.withValues(alpha: 0.6),
          ),
          onPressed: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please confirm your password';
        }
        if (value != widget.passwordController.text) {
          return 'Passwords do not match';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }
}

class DepartmentDropdown extends StatelessWidget {
  final List<String> departments;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  const DepartmentDropdown({
    super.key,
    required this.departments,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Department',
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        prefixIcon: Icon(Icons.school, color: colors.primary),
      ),
      value: selectedValue,
      items: departments.map((department) {
        return DropdownMenuItem<String>(
          value: department,
          child: Text(department),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        final parentState = context.findAncestorStateOfType<_SignupPageState>();
        if (parentState?._selectedRole == 'Student' &&
            (value == null || value.isEmpty)) {
          return 'Please select your department';
        }
        return null;
      },
    );
  }
}