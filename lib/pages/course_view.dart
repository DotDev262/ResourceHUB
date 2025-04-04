import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

final supabase = Supabase.instance.client;
final Logger _log = Logger('CourseDetailPage');

class CourseDetailPage extends StatefulWidget {
  final String courseTitle;
  final int curriculumId;
  const CourseDetailPage({
    super.key,
    required this.courseTitle,
    required this.curriculumId,
  });

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _userRole;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // For custom searching
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  // For custom sorting
  String _sortCriteria = 'name';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadFilesForCourse();
    _getUserRole();
  }

  Future<void> _getUserRole() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final response =
            await supabase
                .from('users')
                .select('role')
                .eq('id', user.id)
                .single();

        if (mounted) {
          // Added mounted check
          setState(() {
            _userRole = response['role'] as String?;
          });
          _log.info('User role fetched: $_userRole');
        }
      } catch (e) {
        _log.severe('Error fetching user role: $e');
      }
    }
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFilesForCourse() async {
    if (mounted) {
      // Added mounted check
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _files.clear();
        _searchResults.clear();
        _searchController.clear();
      });
    }

    try {
      final courseResponse =
          await supabase
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
        if (mounted) {
          // Added mounted check
          setState(() {
            _errorMessage =
                'No subjects found for this course in the current curriculum.';
          });
        }
        return;
      }

      final List<int> subjectIds =
          subjectsResponse.map((subject) => subject['id'] as int).toList();

      PostgrestFilterBuilder<List<Map<String, dynamic>>> fileQuery = supabase
          .from('files')
          .select('*')
          .eq('curriculum_id', curriculumId);

      if (subjectIds.isNotEmpty) {
        fileQuery = fileQuery.or(
          subjectIds
              .map((subjectId) => 'subject_id.eq.$subjectId')
              .toList()
              .join(','),
        );
      }

      final filesResponse = await fileQuery;

      if (mounted) {
        // Added mounted check
        setState(() {
          _files = List<Map<String, dynamic>>.from(filesResponse);
          _sortFiles();
        });
      }
    } catch (e) {
      if (mounted) {
        // Added mounted check
        setState(() {
          _errorMessage = 'Failed to load files: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        // Added mounted check
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterFiles(String query) {
    final lowerCaseQuery = query.toLowerCase();
    final results =
        _files.where((file) {
          final name = (file['name'] as String? ?? '').toLowerCase();
          final description =
              (file['description'] as String? ?? '').toLowerCase();
          return name.contains(lowerCaseQuery) ||
              description.contains(lowerCaseQuery);
        }).toList();

    if (mounted) {
      // Added mounted check
      setState(() {
        _searchResults = results;
      });
    }
  }

  void _sortFiles() {
    if (mounted) {
      // Added mounted check
      setState(() {
        _files.sort((a, b) {
          final aValue = (a[_sortCriteria] as String? ?? '').toLowerCase();
          final bValue = (b[_sortCriteria] as String? ?? '').toLowerCase();
          return aValue.compareTo(bValue);
        });
        if (_searchController.text.isNotEmpty) {
          _filterFiles(_searchController.text);
        }
      });
    }
  }

  Future<void> _showUploadFileDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final linkController = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Upload File Link'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'File Name'),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: linkController,
                  decoration: const InputDecoration(labelText: 'Link'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              child: const Text('Upload'),
              onPressed: () {
                _uploadFile(
                  nameController.text,
                  descriptionController.text,
                  linkController.text,
                );
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadFile(String name, String description, String link) async {
    try {
      final courseResponse =
          await supabase
              .from('courses')
              .select('id')
              .eq('title', widget.courseTitle)
              .single();
      final courseId = courseResponse['id'] as int;

      final subjectsResponse = await supabase
          .from('subjects')
          .select('id')
          .eq('course_id', courseId)
          .eq('curriculum_id', widget.curriculumId);

      if (subjectsResponse.isEmpty) {
        if (mounted) {
          // Added mounted check
          setState(() {
            _errorMessage =
                'No subjects found for this course in the current curriculum.';
          });
        }
        return;
      }

      final subjectId = subjectsResponse.first['id'] as int;

      await supabase.from('files').insert([
        {
          'name': name,
          'description': description,
          'link': link,
          'subject_id': subjectId,
          'curriculum_id': widget.curriculumId,
        },
      ]);

      _loadFilesForCourse(); // Reload and sort
      if (mounted) {
        // Added mounted check
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        // Added mounted check
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload file: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteFile(int fileId) async {
    try {
      await supabase.from('files').delete().eq('id', fileId);
      _loadFilesForCourse(); // Reload and sort
      if (mounted) {
        // Added mounted check
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        // Added mounted check
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete file: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmationDialog(Map<String, dynamic> file) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete "${file['name']}"?'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Dismiss the dialog
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                _deleteFile(file['id'] as int);
                Navigator.of(dialogContext).pop(); // Dismiss the dialog
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> displayedFiles =
        _searchController.text.isNotEmpty ? _searchResults : _files;

    return Scaffold(
      appBar: AppBar(
        title: ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Text(widget.courseTitle),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterFiles,
                  decoration: const InputDecoration(
                    labelText: 'Search files',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Sort by:'),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _sortCriteria,
                      items:
                          <String>['name', 'description'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value.toUpperCase()),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _sortCriteria = newValue;
                            _sortFiles();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildBodyContent(displayedFiles),
      floatingActionButton:
          _userRole == 'faculty'
              ? FloatingActionButton(
                heroTag: "upload_file_fab",
                onPressed: () {
                  _showUploadFileDialog();
                },
                child: const Icon(Icons.upload_file),
              )
              : null,
    );
  }

  Widget _buildBodyContent(List<Map<String, dynamic>> filesToShow) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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

    if (filesToShow.isEmpty) {
      return Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            _searchController.text.isNotEmpty
                ? 'No files found matching your search.'
                : 'No files available for this course.',
          ),
        ),
      );
    }

    return AnimatedList(
      initialItemCount: filesToShow.length,
      itemBuilder: (context, index, animation) {
        final file = filesToShow[index];
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(
            opacity: animation,
            child: _buildFileCardWithDelete(file),
          ),
        );
      },
    );
  }

  Widget _buildFileCardWithDelete(Map<String, dynamic> file) {
    return GestureDetector(
      onLongPress:
          _userRole == 'faculty'
              ? () {
                _showDeleteConfirmationDialog(file);
              }
              : null,
      child: Card(
        margin: const EdgeInsets.all(8.0),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                style: TextStyle(color: Colors.grey[700]),
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
            color: Colors.blue.withValues(alpha: 0.3),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () async {
          try {
            final Uri url = Uri.parse(link);
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            } else {
              _log.warning('Could not launch URL: $link');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not open link. Please ensure you are logged into your Microsoft account or try copying the link into your browser.',
                    ),
                  ),
                );
              }
            }
          } catch (e) {
            _log.severe('Error launching URL: $link', e);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to open link: ${e.toString()}')),
              );
            }
          }
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, color: Colors.white),
            SizedBox(width: 8),
            Text('Open Link', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
