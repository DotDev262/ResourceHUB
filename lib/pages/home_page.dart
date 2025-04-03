import 'package:flutter/material.dart';
import 'package:resourcehub/widgets/course_buttons_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    await _getUserData();
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

  void _onCoursePressed(BuildContext context, String courseTitle) {
    _logger.info('Course pressed: $courseTitle');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Pressed: $courseTitle')));
  }

  void _onUploadButtonPressed() {
    _logger.info('Upload button pressed');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Upload functionality will be implemented here.'),
      ),
    );
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
              CourseButtonsView(
                courseTitles: const [
                  'Introduction to Programming',
                  'Data Structures and Algorithms',
                  'Database Management',
                  'Web Development',
                  'Mobile App Development',
                  'Artificial Intelligence',
                ],
                courseIcons: const [
                  Icons.code,
                  Icons.account_tree,
                  Icons.storage,
                  Icons.web,
                  Icons.phone_android,
                  Icons.memory,
                ],
                onCoursePressed:
                    (courseTitle) => _onCoursePressed(context, courseTitle),
                isGrid: _isGrid,
              ),
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

  const CoursesHeader({super.key, required this.isGrid, required this.onToggleGrid});

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