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
  PreviousYearPapersState createState() => PreviousYearPapersState();
}

class PreviousYearPapersState extends State<PreviousYearPapers> {
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

      // 1. Get the file path from the 'papers' table
      final paper = await supabase
          .from('papers')
          .select('file_path')
          .eq('filename', filename)
          .single();

      if (paper == null) {
        _showError('Paper not found.');
        return;
      }

      final filePath = paper['file_path'] as String;

      // 2. Delete the file from Supabase storage
      await supabase.storage.from('previous-papers').remove([filePath]);

      // 3. Delete the record from the 'papers' table
      await supabase.from('papers').delete().eq('filename', filename);

      await _fetchPapers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paper deleted successfully')),
        );
      }
    } catch (e) {
      _showError('Failed to delete paper: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      PlatformFile file = result.files.first;
      String fileName = '${DateTime.now().millisecondsSinceEpoch}-${file.name}';
      String filePath = 'papers/$fileName';

      if (kIsWeb) {
        if (file.bytes == null) {
          _showError('File bytes not available on web.');
          if (mounted) {
            setState(() => _isLoading = false);
          }
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
          _showError('File path not available.');
          if (mounted) {
            setState(() => _isLoading = false);
          }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully!')),
        );
      }
    } catch (e) {
      if (e is StorageException && e.statusCode == '404') {
        _showError(
          'Storage bucket "previous-papers" not found. Please create it in Supabase.',
        );
      } else {
        _showError('Failed to upload file: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchPapers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final response = await supabase.from('papers').select();
      if (mounted) {
        setState(() {
          _papers = response;
          _applyFiltersAndSort();
        });
      }
    } catch (e) {
      _showError('Failed to fetch papers: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _binarySearchPaper(List<Map<String, dynamic>> papers, String query) {
    int low = 0;
    int high = papers.length - 1;

    while (low <= high) {
      int mid = (low + high) ~/ 2;
      final midFilename = papers[mid]['filename'].toString().toLowerCase();

      if (midFilename == query) {
        return mid;
      } else if (midFilename.compareTo(query) < 0) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return -1; // Not found
  }

  void _applyFiltersAndSort() {
    var filtered = _papers;

    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      // Use binary search if the list is sorted by filename
      if (_sortOption == 'A-Z') {
        final index = _binarySearchPaper(filtered, query);
        if (index != -1) {
          filtered = [filtered[index]]; // Show only the found paper
        } else {
          filtered = []; // Show nothing if not found
        }
      } else {
        // Fallback to linear search for other sort options
        filtered = filtered.where((paper) {
          final name = paper['filename'].toString().toLowerCase();
          final tags = paper['tags'].join(' ').toLowerCase();
          return name.contains(query) || tags.contains(query);
        }).toList();
      }
    }


    if (_selectedDept != null && _selectedDept!.isNotEmpty) {
      filtered =
          filtered
              .where((paper) => paper['department'] == _selectedDept)
              .toList();
    }

    if (_selectedSemester != null) {
      filtered =
          filtered
              .where((paper) => paper['semester'] == _selectedSemester)
              .toList();
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

    if (mounted) {
      setState(() {
        _filteredPapers = filtered;
      });
    }
  }

  Future<void> _viewPdf(String filePath) async {
    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }
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
              builder:
                  (context) => PDFView(
                    filePath: tempFilePath,
                    enableSwipe: true,
                    onError: (error) => _showError('Error loading PDF: $error'),
                    onPageError:
                        (page, error) =>
                            _showError('Error on page $page: $error'),
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _errorMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
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
      appBar: AppBar(title: const Text('Previous Year Papers')),
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
            child:
                _isLoading
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
            if (mounted) {
              setState(() {
                _selectedDept = null;
                _selectedSemester = null;
                _applyFiltersAndSort();
              });
            }
          },
        ),
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.school),
            title: Text('Department'),
          ),
          onTap: () {
            _showTextInputDialog('Department', (value) {
              if (mounted) {
                setState(() {
                  _selectedDept = value.isNotEmpty ? value : null;
                  _applyFiltersAndSort();
                });
              }
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
              if (mounted) {
                setState(() {
                  _selectedSemester =
                      int.tryParse(value) != null && int.parse(value) > 0
                          ? int.parse(value)
                          : null;
                  _applyFiltersAndSort();
                });
              }
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
                    if (mounted) {
                      setState(() {
                        _sortOption = option;
                        _applyFiltersAndSort();
                      });
                    }
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
      builder:
          (context) => AlertDialog(
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
