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

class _UnifiedHomepageState extends State<UnifiedHomepage> {
  bool _isGrid = true;
  final Logger _logger = Logger('UnifiedHomepage');
  String _greeting = "Hello!";
  String? _userName;
  String? _userRole;
  List<Map<String, dynamic>> _courses = [];

  @override
  void initState() {
    super.initState();
    _loadUserDataAndCourses();
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
    print("User: ${supabase.auth.currentUser}");
    print("User Role: $_userRole");
    final user = supabase.auth.currentUser;
    if (user != null && _userRole == 'student') {
      try {
        final userData =
            await supabase
                .from('users')
                .select('department, admission_year')
                .eq('id', user.id)
                .single();
        final department = userData['department'] as String?;
        final admissionYear = userData['admission_year'] as String?;

        if (department != null && admissionYear != null) {
          final curriculumResponse =
              await supabase
                  .from('curricula')
                  .select('id')
                  .eq(
                    'name',
                    'B.Tech $department',
                  ) // Assuming curriculum name format
                  .eq('academic_year', int.tryParse(admissionYear) ?? 0)
                  .single();

          if (curriculumResponse != null) {
            final curriculumId = curriculumResponse['id'] as int?;
            if (curriculumId != null) {
              final subjectsResponse = await supabase
                  .from('subjects')
                  .select('courses(title, icon_name)')
                  .eq('curriculum_id', curriculumId);

              if (subjectsResponse != null) {
                setState(() {
                  _courses =
                      (subjectsResponse as List<dynamic>)
                          .map(
                            (subject) => {
                              'title': subject['courses']['title'] as String?,
                              'icon_name':
                                  subject['courses']['icon_name'] as String?,
                            },
                          )
                          .where(
                            (course) =>
                                course['title'] != null &&
                                course['icon_name'] != null,
                          )
                          .toList();
                  print(
                    "Loaded Courses: $_courses",
                  ); // IMPORTANT: Check this output in your Flutter console
                });
              }
            }
          }
        }
      } catch (e) {
        _logger.warning('Error fetching student courses', e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load courses.')),
          );
        }
      }
    } else if (user != null && _userRole == 'Faculty') {
      // Placeholder for faculty subjects
      setState(() {
        _courses = [
          {'title': 'Assigned Subject 1', 'icon_name': 'subject'},
          {'title': 'Assigned Subject 2', 'icon_name': 'subject'},
          {'title': 'Another Subject', 'icon_name': 'subject'},
        ];
      });
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

  void _onCoursePressed(BuildContext context, String courseTitle) async {
    _logger.info('Course pressed: $courseTitle');
    final user = supabase.auth.currentUser;
    if (user != null && _userRole == 'student') {
      try {
        final userData = await supabase
            .from('users')
            .select('curriculumId')
            .eq('id', user.id)
            .single();
        final curriculumId = userData['curriculumId'] as int?;
        if (curriculumId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseDetailPage(courseTitle: courseTitle, curriculumId: curriculumId),
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
      _showCurriculumNotApplicableSnackbar(); // Or handle differently for non-students
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showCurriculumNotApplicableSnackbar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Curriculum information not applicable for your role.')),
      );
    }
  }

  void _onUploadButtonPressed() {
    _logger.info('Upload button pressed');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Upload functionality will be implemented here.'),
      ),
    );
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
        return Icons.subject; // Default icon for faculty subjects
      default:
        return Icons.book; // Default icon if not found
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homepage'),
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
              Text(
                _greeting,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (_userRole == 'Faculty')
                FacultyUploadButton(onPressed: _onUploadButtonPressed),
              const SizedBox(height: 16),
              CoursesHeader(
                isGrid: _isGrid,
                onToggleGrid: () => setState(() => _isGrid = !_isGrid),
              ),
              const SizedBox(height: 16),
              if (_courses.isNotEmpty)
                CourseButtonsView(
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
                )
              else
                const Text('No courses available.'),
            ],
          ),
        ),
      ),
    );
  }
}

class FacultyUploadButton extends StatelessWidget {
  final VoidCallback onPressed;

  const FacultyUploadButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload Links'),
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
        IconButton(
          icon: Icon(isGrid ? Icons.list : Icons.grid_view),
          onPressed: onToggleGrid,
        ),
      ],
    );
  }
}
