import 'package:flutter/material.dart';
import 'package:resourcehub/widgets/course_buttons_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'course_view.dart';

final supabase = Supabase.instance.client;

class UnifiedHomepage extends StatefulWidget {
  const UnifiedHomepage({super.key});

  @override
  State<UnifiedHomepage> createState() => _UnifiedHomepageState();
}

class _UnifiedHomepageState extends State<UnifiedHomepage>
    with SingleTickerProviderStateMixin {
  bool _isGrid = true;
  final Logger _logger = Logger('UnifiedHomepage');
  String _greeting = "Hello!";
  String? _userName;
  String? _userRole;
  List<Map<String, dynamic>> _courses = [];

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndCourses();

    // Initialize animations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _colorAnimation = ColorTween(
      begin: Colors.blue.shade100,
      end: Colors.blue.shade300,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadUserDataAndCourses() async {
    await _getUserData();
    await _loadCourses();
  }

  Future<void> _getUserData() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final response =
            await supabase
                .from('users')
                .select('name, role')
                .eq('id', user.id)
                .single();

        setState(() {
          _userName = response['name'] as String?;
          _userRole = response['role'] as String?;
          _updateGreeting();
        });
      } catch (e) {
        _logger.warning('Error fetching user data', e);
        setState(() {
          _greeting = "Hello!";
        });
      }
    } else {
      _updateGreeting();
    }
  }

  Future<void> _loadCourses() async {
    final user = supabase.auth.currentUser;
    if (user != null && _userRole == 'faculty') {
      try {
        final subjectsResponse = await supabase
            .from('subjects')
            .select('courses(title, icon_name), id') // Include subject ID
            .eq('faculty_id', user.id);

        setState(() {
          _courses =
              (subjectsResponse as List<dynamic>)
                  .map(
                    (subject) => {
                      'title': subject['courses']['title'] as String?,
                      'icon_name': subject['courses']['icon_name'] as String?,
                      'subject_id': subject['id'] as int?, // Store subject ID
                    },
                  )
                  .where(
                    (course) =>
                        course['title'] != null && course['icon_name'] != null,
                  )
                  .toList();
        });
      } catch (e) {
        _logger.warning('Error fetching faculty courses', e);
        // ... (error handling) ...
      }
    } else {
      setState(() {
        _courses = [];
      });
    }
  }

  void _updateGreeting() {
    String newGreeting;
    if (_userName?.isNotEmpty == true) {
      newGreeting = "Hello ${_userName!}!";
    } else {
      final user = supabase.auth.currentUser;
      newGreeting = "Hello ${user?.email ?? 'User'}!";
    }
    if (_greeting != newGreeting) {
      setState(() {
        _greeting = newGreeting;
      });
    }
  }

  Future<void> _showLogoutDialog() async {
    final user = supabase.auth.currentUser;
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Logged in as: ${user?.email ?? 'Unknown'}'),
              const SizedBox(height: 10),
              const Text('Are you sure you want to logout?'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (result == true) {
      try {
        await supabase.auth.signOut();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } catch (e) {
        _logger.severe('Error during logout', e);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Error signing out')));
        }
      }
    }
  }

  Future<void> _addCourseDialog(BuildContext context) async {
    final titleController = TextEditingController();
    String? selectedIconName;

    // Define your icon options
    final iconOptions = {
      'code': Icons.code,
      'account_tree': Icons.account_tree,
      'storage': Icons.storage,
      'web': Icons.web,
      'power': Icons.power,
      'straighten': Icons.straighten,
      'info': Icons.info,
      'functions': Icons.functions,
      'chip': Icons.signal_cellular_0_bar,
      'layers': Icons.layers,
      'desktop_windows': Icons.desktop_windows,
      'subject': Icons.subject,
      'book': Icons.book, // Default icon
    };

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Course and Subject'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Course/Subject Title',
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedIconName,
                      items:
                          iconOptions.keys.map((String key) {
                            return DropdownMenuItem<String>(
                              value: key,
                              child: Row(
                                children: [
                                  Icon(iconOptions[key]),
                                  const SizedBox(width: 8),
                                  Text(key),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedIconName = value;
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Icon'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (titleController.text.isNotEmpty &&
                        selectedIconName != null) {
                      await _addCourseAndSubject(
                        titleController.text,
                        selectedIconName!,
                      );
                      Navigator.of(dialogContext).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill in all fields.'),
                        ),
                      );
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addCourseAndSubject(String title, String iconName) async {
    try {
      final user = supabase.auth.currentUser;

      if (user != null) {
        // Insert new course
        final courseResponse =
            await supabase
                .from('courses')
                .insert({'title': title, 'icon_name': iconName})
                .select('id')
                .single();

        final courseId = courseResponse['id'] as int;

        // Insert new subject
        await supabase.from('subjects').insert({
          'name': title, // Use the same title for the subject
          'faculty_id': user.id,
          'course_id': courseId,
        });

        _loadCourses(); // Reload courses to reflect changes
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Course and subject added successfully'),
            ),
          );
        }
      } else {
        _logger.warning('User is null when adding course.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add course. User not logged in.'),
            ),
          );
        }
      }
    } catch (e) {
      _logger.severe('Error adding course and subject', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add course and subject')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSubjectsFromSupabase() async {
    try {
      final user = supabase.auth.currentUser;

      if (user != null) {
        final response = await supabase
            .from('subjects')
            .select('id, name, faculty_id')
            .eq('faculty_id', user.id);

        return (response as List)
            .map(
              (subject) => {
                'id': subject['id'] as int,
                'name': subject['name'] as String,
                'faculty_id': subject['faculty_id'] as String,
              },
            )
            .toList();
      } else {
        // Handle the case where user is null (e.g., user is not logged in)
        // You might want to return an empty list or fetch all subjects (if appropriate)
        // in this scenario.
        _logger.warning('User is null when fetching subjects.');
        return []; // Returning an empty list for now.
      }
    } catch (e) {
      _logger.severe('Error fetching subjects', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load subjects.')),
        );
      }
      return [];
    }
  }

  Future<void> _addCourse(String title, String iconName, int subjectId) async {
    try {
      final user = supabase.auth.currentUser;

      if (user != null) {
        await supabase.from('courses').insert({
          'title': title,
          'icon_name': iconName,
          'subject_id': subjectId,
          'faculty_id': user.id,
        });
        _loadCourses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course added successfully')),
          );
        }
      } else {
        // Handle the case where user is null (e.g., user is not logged in)
        _logger.warning('User is null when adding course.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add course. User not logged in.'),
            ),
          );
        }
      }
    } catch (e) {
      _logger.severe('Error adding course', e);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to add course')));
      }
    }
  }

  void _onCoursePressed(BuildContext context, String courseTitle) async {
    _logger.info('Course pressed: $courseTitle');
    final user = supabase.auth.currentUser;

    if (user != null) {
      try {
        final userData =
            await supabase
                .from('users')
                .select('curriculumId')
                .eq('id', user.id)
                .single();
        final curriculumId = userData['curriculumId'] as int?;

        if (curriculumId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CourseDetailPage(
                    courseTitle: courseTitle,
                    curriculumId: curriculumId,
                  ),
            ),
          );
        } else {
          _showCurriculumNotFoundSnackbar();
        }
      } catch (e) {
        _logger.warning('Error fetching curriculum ID', e);
        _showErrorSnackbar('Failed to load course details.');
      }
    } else {
      _showErrorSnackbar("User not logged in");
    }
  }

  void _showCurriculumNotFoundSnackbar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Curriculum information not found.')),
      );
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'code':
        return Icons.code;
      case 'account_tree':
        return Icons.account_tree;
      case 'storage':
        return Icons.storage;
      case 'web':
        return Icons.web;
      case 'power':
        return Icons.power;
      case 'straighten':
        return Icons.straighten;
      case 'info':
        return Icons.info;
      case 'functions':
        return Icons.functions;
      case 'chip':
        return Icons.signal_cellular_0_bar;
      case 'layers':
        return Icons.layers;
      case 'desktop_windows':
        return Icons.desktop_windows;
      case 'subject':
        return Icons.subject;
      default:
        return Icons.book;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: const Text(
                'Homepage',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
        scrolledUnderElevation: 0.0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: AnimatedBuilder(
                  animation: _colorAnimation,
                  builder: (context, child) {
                    return Text(
                      _greeting,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _colorAnimation.value,
                        shadows: [
                          Shadow(
                            blurRadius: 2.0,
                            color: _colorAnimation.value!.withValues(
                              alpha: 0.4,
                            ),
                            offset: const Offset(1.0, 1.0),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              CoursesHeader(
                isGrid: _isGrid,
                onToggleGrid: () => setState(() => _isGrid = !_isGrid),
              ),
              const SizedBox(height: 16),
              if (_courses.isNotEmpty)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: CourseButtonsView(
                    key: ValueKey<bool>(_isGrid),
                    courseTitles:
                        _courses
                            .map((course) => course['title'] as String)
                            .toList(),
                    courseIcons:
                        _courses
                            .map(
                              (course) =>
                                  _getIconData(course['icon_name'] as String?),
                            )
                            .toList(),
                    onCoursePressed:
                        (courseTitle) => _onCoursePressed(context, courseTitle),
                    isGrid: _isGrid,
                  ),
                )
              else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Text('No courses available.'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CoursesHeader extends StatelessWidget {
  final bool isGrid;
  final VoidCallback onToggleGrid;

  const CoursesHeader({
    super.key,
    required this.isGrid,
    required this.onToggleGrid,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Courses:',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: IconButton(
            key: ValueKey<bool>(isGrid),
            icon: Icon(isGrid ? Icons.list : Icons.grid_view),
            onPressed: onToggleGrid,
          ),
        ),
      ],
    );
  }
}
