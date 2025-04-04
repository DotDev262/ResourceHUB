import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CourseDetailPage extends StatefulWidget {
  final String courseTitle;
  final int curriculumId;
  const CourseDetailPage({super.key, required this.courseTitle, required this.curriculumId});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadFilesForCourse();
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFilesForCourse() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _files.clear();
    });

    try {
      final courseResponse = await supabase
          .from('courses')
          .select('id')
          .eq('title', widget.courseTitle)
          .single();

      final courseId = courseResponse['id'] as int;
      final int curriculumId = widget.curriculumId;

      final subjectsResponse = await supabase
          .from('subjects')
          .select('id')
          .eq('course_id', courseId)
          .eq('curriculum_id', curriculumId);

      if (subjectsResponse.isEmpty) {
        setState(() {
          _errorMessage = 'No subjects found for this course in the current curriculum.';
        });
        return;
      }

      final List<int> subjectIds =
          subjectsResponse.map((subject) => subject['id'] as int).toList();

      PostgrestFilterBuilder<List<Map<String, dynamic>>> fileQuery =
          supabase.from('files').select('*').eq('curriculum_id', curriculumId);

      if (subjectIds.isNotEmpty) {
        fileQuery = fileQuery.or(
          subjectIds.map((subjectId) => 'subject_id.eq.$subjectId').toList().join(',')
        );
      }

      final filesResponse = await fileQuery;

      setState(() {
        _files = List<Map<String, dynamic>>.from(filesResponse);
      });
        } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load files: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Text(widget.courseTitle),
          ),
        ),
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_files.isEmpty) {
      return Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: const Text('No files available for this course.'),
        ),
      );
    }

    return AnimatedList(
      initialItemCount: _files.length,
      itemBuilder: (context, index, animation) {
        final file = _files[index];
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: _buildFileCard(file),
          ),
        );
      },
    );
  }

  Widget _buildFileCard(Map<String, dynamic> file) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file['name'] as String? ?? 'File Name Not Available',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Description: ${file['description'] as String? ?? 'No description'}',
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            if (file['link'] != null)
              _buildLinkButton(file['link'] as String)
            else
              const Text(
                'Link not available.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkButton(String link) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: () {
          // Implement logic to open the file link
          print('Opening link: $link');
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Open Link',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}