import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:resourcehub/widgets/navigation_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:resourcehub/main.dart';

const String studentDomain = '@ch.students.amrita.edu';
const String facultyDomain = '@ch.amrita.edu';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignupPageState();
}

String? guessRoleFromEmail(String email) {
  if (email.endsWith(studentDomain)) {
    return 'Student';
  } else if (email.endsWith(facultyDomain)) {
    return 'Faculty';
  } else {
    return null;
  }
}

class _SignupPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _errorMessage = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final Logger logger = Logger('SignupPage');
  final _formKey = GlobalKey<FormState>();

  String? _selectedRole;
  String? _selectedDepartment;
  final List<String> _departments = [
    'Computer Science',
    'Electrical Engineering',
    'Mechanical Engineering',
    'Information Technology',
  ];

  late AnimationController _animationController;
  late Animation<int> _typingAnimation;
  final String _welcomeText = "Hello!";
  int _displayTextCount = 0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _typingAnimation = IntTween(begin: 0, end: _welcomeText.length).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    )..addListener(() {
      setState(() {
        _displayTextCount = _typingAnimation.value;
      });
    });

    _animationController.forward();

    _emailController.addListener(_guessAndSetRole);
  }

  void _guessAndSetRole() {
    final guessedRole = guessRoleFromEmail(_emailController.text);
    if (guessedRole != null && _selectedRole != guessedRole) {
      setState(() {
        _selectedRole = guessedRole;

        if (_selectedRole != 'Student') {
          _selectedDepartment = null;
        }
      });
    } else if (guessedRole == null && _selectedRole != null) {
      setState(() {
        _selectedRole = null;
        _selectedDepartment = null;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.removeListener(_guessAndSetRole);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
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
            },
          ]);

          if (!mounted) return;
          final email = _emailController.text;
          if (email.endsWith(studentDomain) || email.endsWith(facultyDomain)) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const NavigationWidget()),
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _welcomeText.substring(0, _displayTextCount),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
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
                  const Text(
                    'Sign Up',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      prefixIcon: Icon(Icons.person, color: colors.primary),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
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
                    onChanged: (value) {},
                  ),
                  const SizedBox(height: 16),
                  if (_selectedRole == 'Student')
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Department',
                        filled: true,
                        fillColor: colors.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        prefixIcon: Icon(Icons.school, color: colors.primary),
                      ),
                      value: _selectedDepartment,
                      items:
                          _departments.map((department) {
                            return DropdownMenuItem<String>(
                              value: department,
                              child: Text(department),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDepartment = value;
                        });
                      },
                      validator: (value) {
                        if (_selectedRole == 'Student' &&
                            (value == null || value.isEmpty)) {
                          return 'Please select your department';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      prefixIcon: Icon(Icons.lock, color: colors.primary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
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
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      filled: true,
                      fillColor: colors.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: colors.primary,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
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
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
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
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (_errorMessage.isNotEmpty)
                    Container(
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
                              _errorMessage,
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
