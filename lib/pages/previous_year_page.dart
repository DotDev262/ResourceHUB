import 'dart:io' show File, Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PreviousYearPapers extends StatefulWidget {
  const PreviousYearPapers({super.key});

  @override
  _PreviousYearPapersState createState() => _PreviousYearPapersState();
}

class _PreviousYearPapersState extends State<PreviousYearPapers> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _papers = [];
  List<Map<String, dynamic>> _filteredPapers = [];
  final _tagsController = TextEditingController();
  final _deptController = TextEditingController();
  final _semesterController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedDept;
  int? _selectedSemester;
  String _sortOption = 'Newest';

  @override
  void initState() {
    super.initState();
    _fetchPapers();
    _searchController.addListener(_applyFiltersAndSort);
  }

  Future<void> _deletePaper(String filename) async {
    try {
      setState(() => _isLoading = true);
      await supabase.from('papers').delete().eq('filename', filename);
      await _fetchPapers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paper deleted successfully')),
      );
    } catch (e) {
      _showError('Failed to delete paper: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadFile() async {
    try {
      if (_tagsController.text.isEmpty ||
          _deptController.text.isEmpty ||
          _semesterController.text.isEmpty) {
        _showError('Please fill in all fields');
        return;
      }
      int? semester = int.tryParse(_semesterController.text);
      if (semester == null || semester <= 0) {
        _showError('Semester must be a positive number');
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      PlatformFile file = result.files.first;
      String fileName = '${DateTime.now().millisecondsSinceEpoch}-${file.name}';
      String filePath = 'papers/$fileName';

      if (kIsWeb) {
        if (file.bytes == null) {
          _showError('File bytes not available on web');
          setState(() => _isLoading = false);
          return;
        }
        await supabase.storage
            .from('previous-papers')
            .uploadBinary(
              filePath,
              file.bytes!,
              fileOptions: const FileOptions(contentType: 'application/pdf'),
            );
      } else {
        if (file.path == null) {
          _showError('File path not available');
          setState(() => _isLoading = false);
          return;
        }
        File dartFile = File(file.path!);
        await supabase.storage
            .from('previous-papers')
            .upload(
              filePath,
              dartFile,
              fileOptions: const FileOptions(contentType: 'application/pdf'),
            );
      }

      await supabase.from('papers').insert({
        'filename': fileName,
        'file_path': filePath,
        'tags':
            _tagsController.text.split(',').map((tag) => tag.trim()).toList(),
        'department': _deptController.text,
        'semester': semester,
        'uploaded_at': DateTime.now().toIso8601String(),
      });

      await _fetchPapers();
      _clearInputs();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File uploaded successfully!')),
      );
    } catch (e) {
      if (e is StorageException && e.statusCode == '404') {
        _showError(
          'Storage bucket "previous-papers" not found. Please create it in Supabase.',
        );
      } else {
        _showError('Failed to upload file: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPapers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final response = await supabase.from('papers').select();
      setState(() {
        _papers = response;
        _applyFiltersAndSort();
      });
    } catch (e) {
      _showError('Failed to fetch papers: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndSort() {
    var filtered = _papers;

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((paper) {
        final name = paper['filename'].toString().toLowerCase();
        final tags = paper['tags'].join(' ').toLowerCase();
        return name.contains(query) || tags.contains(query);
      }).toList();
    }

    if (_selectedDept != null && _selectedDept!.isNotEmpty) {
      filtered = filtered
          .where((paper) => paper['department'] == _selectedDept)
          .toList();
    }

    if (_selectedSemester != null) {
      filtered =
          filtered.where((paper) => paper['semester'] == _selectedSemester).toList();
    }

    if (_sortOption == 'Newest') {
      filtered.sort(
        (a, b) => DateTime.parse(
          b['uploaded_at'],
        ).compareTo(DateTime.parse(a['uploaded_at'])),
      );
    } else if (_sortOption == 'Oldest') {
      filtered.sort(
        (a, b) => DateTime.parse(
          a['uploaded_at'],
        ).compareTo(DateTime.parse(b['uploaded_at'])),
      );
    } else if (_sortOption == 'A-Z') {
      filtered.sort((a, b) => a['filename'].compareTo(b['filename']));
    } else if (_sortOption == 'Z-A') {
      filtered.sort((a, b) => b['filename'].compareTo(a['filename']));
    }

    setState(() {
      _filteredPapers = filtered;
    });
  }

  Future<void> _viewPdf(String filePath) async {
    try {
      setState(() => _isLoading = true);
      final url = supabase.storage
          .from('previous-papers')
          .getPublicUrl(filePath);

      if (Platform.isAndroid) {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        } else {
          _showError('Could not launch PDF viewer.');
        }
      } else {
        final tempDir = await getTemporaryDirectory();
        final tempFilePath = '${tempDir.path}/${filePath.split('/').last}';

        final dio = Dio();
        await dio.download(url, tempFilePath);

        final file = File(tempFilePath);
        if (await file.exists() && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PDFView(
                filePath: tempFilePath,
                enableSwipe: true,
                onError: (error) => _showError('Error loading PDF: $error'),
                onPageError:
                    (page, error) => _showError('Error on page $page: $error'),
              ),
            ),
          );
        } else {
          _showError('Failed to download PDF for viewing.');
        }
      }
    } catch (e) {
      _showError('Failed to view PDF: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _clearInputs() {
    _tagsController.clear();
    _deptController.clear();
    _semesterController.clear();
  }

  void _showUploadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upload Paper'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma-separated)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _deptController,
                  decoration: const InputDecoration(
                    labelText: 'Department',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.school),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _semesterController,
                  decoration: const InputDecoration(
                    labelText: 'Semester',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload, color: Colors.white),
                  label: const Text(
                    'Upload File',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: _isLoading ? null : _uploadFile,
                  style: ElevatedButton.styleFrom(
                    // Use Theme.of(context).colorScheme.secondary for accent color
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Previous Year Papers'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUploadDialog(context),
        tooltip: 'Upload Paper',
        child: const Icon(Icons.upload_file),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search by name or tags',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.filter_list, size: 20),
                      label: const Text('Filter'),
                      onPressed: () => _showFilterMenu(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.sort, size: 20),
                      label: const Text('Sort'),
                      onPressed: () => _showSortMenu(context),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPapers.isEmpty
                    ? const Center(child: Text('No papers available yet'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredPapers.length,
                        itemBuilder: (context, index) {
                          final paper = _filteredPapers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4.0,
                              horizontal: 8.0,
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.picture_as_pdf,
                                color: Colors.red,
                              ),
                              title: Text(paper['filename']),
                              subtitle: Text(
                                'Tags: ${paper['tags'].join(', ')} | Dept: ${paper['department']} | Sem: ${paper['semester']}',
                              ),
                              onTap: () => _viewPdf(paper['file_path']),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deletePaper(paper['filename']),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showFilterMenu(BuildContext context) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 80, 0, 0),
      items: [
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.clear),
            title: Text('Clear Filters'),
          ),
          onTap: () {
            setState(() {
              _selectedDept = null;
              _selectedSemester = null;
              _applyFiltersAndSort();
            });
          },
        ),
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.school),
            title: Text('Department'),
          ),
          onTap: () {
            _showTextInputDialog('Department', (value) {
              setState(() {
                _selectedDept = value.isNotEmpty ? value : null;
                _applyFiltersAndSort();
              });
            });
          },
        ),
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.calendar_today),
            title: Text('Semester'),
          ),
          onTap: () {
            _showTextInputDialog('Semester', (value) {
              setState(() {
                _selectedSemester =
                    int.tryParse(value) != null && int.parse(value) > 0
                        ? int.parse(value)
                        : null;
                _applyFiltersAndSort();
              });
            }, keyboardType: TextInputType.number);
          },
        ),
      ],
    );
  }

  void _showSortMenu(BuildContext context) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(150, 80, 0, 0),
      items:
          ['Newest', 'Oldest', 'A-Z', 'Z-A']
              .map(
                (option) => PopupMenuItem(
                  child: ListTile(
                    leading: const Icon(Icons.sort),
                    title: Text(option),
                  ),
                  onTap: () {
                    setState(() {
                      _sortOption = option;
                      _applyFiltersAndSort();
                    });
                  },
                ),
              )
              .toList(),
    );
  }

  void _showTextInputDialog(
    String label,
    Function(String) onSubmit, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    String inputValue = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter $label'),
        content: TextField(
          keyboardType: keyboardType,
          onChanged: (value) => inputValue = value,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Submit'),
            onPressed: () {
              Navigator.pop(context);
              onSubmit(inputValue);
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tagsController.dispose();
    _deptController.dispose();
    _semesterController.dispose();
    super.dispose();
  }
}