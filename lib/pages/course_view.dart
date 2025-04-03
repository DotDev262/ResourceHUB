import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher

final supabase = Supabase.instance.client;

class CourseDetailPage extends StatefulWidget {
  final String courseTitle;
  final int curriculumId;
  const CourseDetailPage(
      {super.key, required this.courseTitle, required this.curriculumId});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFilesForCourse();
  }

  Future<void> _loadFilesForCourse() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _files.clear();
    });

    try {
      // 1. Get the course ID based on the course title
      final courseResponse = await supabase
          .from('courses')
          .select('id')
          .eq('title', widget.courseTitle)
          .single();

      if (courseResponse == null) {
        setState(() {
          _errorMessage = 'Course not found.';
        });
        return;
      }

      final courseId = courseResponse['id'] as int;
      final int curriculumId = widget.curriculumId;

      // 3. Get the subject IDs associated with the course ID and curriculum ID
      final subjectsResponse = await supabase
          .from('subjects')
          .select('id')
          .eq('course_id', courseId)
          .eq('curriculum_id', curriculumId);

      if (subjectsResponse == null ||
          subjectsResponse is! List ||
          subjectsResponse.isEmpty) {
        setState(() {
          _errorMessage =
              'No subjects found for this course in the current curriculum.';
        });
        return;
      }

      final List<int> subjectIds =
          subjectsResponse.map((subject) => subject['id'] as int).toList();

      // 4. Build the file query with .or() conditions
      PostgrestFilterBuilder<List<Map<String, dynamic>>> fileQuery =
          supabase.from('files').select('*').eq('curriculum_id', curriculumId);

      if (subjectIds.isNotEmpty) {
        fileQuery = fileQuery.or(
            subjectIds.map((subjectId) => 'subject_id.eq.$subjectId').toList().join(','));
      }

      final filesResponse = await fileQuery;

      if (filesResponse != null && filesResponse is List) {
        setState(() {
          _files = List<Map<String, dynamic>>.from(filesResponse);
        });
      } else {
        setState(() {
          _errorMessage =
              'No files found for this course in the current curriculum.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load files: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseTitle),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _files.isEmpty
                  ? const Center(child: Text('No files available for this course.'))
                  : ListView.builder(
                      itemCount: _files.length,
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        return Card(
                          margin: const EdgeInsets.all(8.0),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file['name'] as String? ??
                                      'File Name Not Available',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    'Description: ${file['description'] as String? ?? 'No description'}'),
                                const SizedBox(height: 8),
                                if (file['link'] != null)
                                  ElevatedButton.icon(
                                    onPressed: () => _launchUrl(file['link']),
                                    icon: const Icon(Icons.link),
                                    label: const Text('Open Link'),
                                  )
                                else
                                  const Text('Link not available.'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}