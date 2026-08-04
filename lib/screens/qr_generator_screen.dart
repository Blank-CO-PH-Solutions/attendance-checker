import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import '../models/student.dart';
import '../providers/folder_provider.dart';
import '../providers/day_provider.dart';
import 'qr_display_screen.dart';
import 'folder_section_screen.dart';

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _studentNumberController = TextEditingController();
  final _programYearController = TextEditingController();
  final _parentNumberController = TextEditingController();
  final Uuid _uuid = const Uuid();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _studentNumberController.dispose();
    _programYearController.dispose();
    _parentNumberController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<FolderProvider>().refresh(),
      context.read<AttendanceEventProvider>().refresh(),
    ]);
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.create_new_folder, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Create Section'),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Section Name',
            hintText: 'Program And Year',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<FolderProvider>().create(controller.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog() {
    final folderProvider = context.read<FolderProvider>();
    if (folderProvider.folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create a section first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Student',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Student Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _firstNameController,
                              decoration: _inputDecoration(
                                'First Name',
                                Icons.person_outline,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter first name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _lastNameController,
                              decoration: _inputDecoration(
                                'Last Name',
                                Icons.person_outline,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter last name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _studentNumberController,
                              decoration: _inputDecoration(
                                'Student Number',
                                Icons.numbers,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter student number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _programYearController,
                              decoration: _inputDecoration(
                                'Program & Year',
                                Icons.school,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter program & year';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _parentNumberController,
                              decoration: _inputDecoration(
                                "Parent's Number",
                                Icons.phone,
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: _generateQr,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_2, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Generate QR Code',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: _massUpload,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_file, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Mass Upload',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _generateQr() {
    if (_formKey.currentState!.validate()) {
      final fp = context.read<FolderProvider>();
      final student = Student(
        id: _uuid.v4(),
        firstName: _firstNameController.text.trim(),
        middleName: '',
        lastName: _lastNameController.text.trim(),
        studentNumber: _studentNumberController.text.trim(),
        year: '',
        program: _programYearController.text.trim(),
        parentNumber: _parentNumberController.text.trim(),
      );

      fp.addStudent(fp.selectedId!, student);

      _firstNameController.clear();
      _lastNameController.clear();
      _studentNumberController.clear();
      _programYearController.clear();
      _parentNumberController.clear();
      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QrDisplayScreen(
            student: student,
            onDelete: () => fp.removeStudent(fp.selectedId ?? '', student.id),
          ),
        ),
      );
    }
  }

  Future<void> _massUpload() async {
    final folderProvider = context.read<FolderProvider>();
    if (folderProvider.folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create a section first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read the file'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;
      if (sheet == null || sheet.rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The file is empty'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final headerRow = sheet.rows.first;
      final headers = headerRow.map((cell) => cell?.value?.toString().toLowerCase().trim() ?? '').toList();

      int firstNameIdx = -1, lastNameIdx = -1, studentNumberIdx = -1, programYearIdx = -1;
      for (int i = 0; i < headers.length; i++) {
        final h = headers[i];
        if (h.contains('first') && h.contains('name')) firstNameIdx = i;
        else if (h.contains('last') && h.contains('name')) lastNameIdx = i;
        else if (h.contains('student') && h.contains('number')) studentNumberIdx = i;
        else if (h.contains('program')) programYearIdx = i;
      }

      if (firstNameIdx == -1 || lastNameIdx == -1 || studentNumberIdx == -1 || programYearIdx == -1) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Missing required columns. Need: First Name, Last Name, Student Number, Program & Year'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final students = <Student>[];
      for (int rowIdx = 1; rowIdx < sheet.rows.length; rowIdx++) {
        final row = sheet.rows[rowIdx];
        final firstName = row[firstNameIdx]?.value?.toString().trim() ?? '';
        final lastName = row[lastNameIdx]?.value?.toString().trim() ?? '';
        final studentNumber = row[studentNumberIdx]?.value?.toString().trim() ?? '';
        final programYear = row[programYearIdx]?.value?.toString().trim() ?? '';

        if (firstName.isEmpty || lastName.isEmpty || studentNumber.isEmpty || programYear.isEmpty) continue;

        students.add(Student(
          id: _uuid.v4(),
          firstName: firstName,
          middleName: '',
          lastName: lastName,
          studentNumber: studentNumber,
          year: '',
          program: programYear,
        ));
      }

      if (students.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid students found in the file'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      for (final student in students) {
        folderProvider.addStudent(folderProvider.selectedId!, student);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${students.length} students uploaded successfully'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reading file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
      ),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'QR Code Generator',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            onPressed: _showCreateFolderDialog,
            tooltip: 'Create Section',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Consumer<FolderProvider>(
          builder: (context, folderProvider, child) {
            if (folderProvider.folders.isEmpty) {
              return _buildEmptyState(folderProvider);
            }
            return _buildFolderContent(folderProvider);
          },
        ),
      ),
      floatingActionButton: Consumer<FolderProvider>(
        builder: (context, folderProvider, child) {
          if (folderProvider.folders.isEmpty) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: _showAddStudentDialog,
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add Student'),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(FolderProvider folderProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              'No Sections Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a section folder to start\ngenerating QR codes',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showCreateFolderDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Section'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderContent(FolderProvider folderProvider) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sections',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    '${folderProvider.folders.length} folders',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...folderProvider.folders.map((folder) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FolderSectionScreen(folderId: folder.id),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.folder,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                folder.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${folder.students.length} students',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {
                            _showFolderOptions(
                              folder.id,
                              folder.name,
                              folder.students.length,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  void _showFolderOptions(
    String folderId,
    String folderName,
    int studentCount,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.folder, size: 48, color: const Color(0xFFF59E0B)),
            const SizedBox(height: 12),
            Text(
              folderName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              '$studentCount students',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(Icons.folder, color: Color(0xFF2563EB)),
              title: const Text('Download Folder'),
              onTap: () {
                Navigator.pop(context);
                final folderProvider = context.read<FolderProvider>();
                try {
                  final folder = folderProvider.folders.firstWhere(
                    (f) => f.id == folderId,
                  );
                  folderProvider.downloadFolder(context, folder);
                } catch (e) {
                  // Folder not found
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.download, color: Color(0xFF10B981)),
              title: const Text('Download All QR Codes'),
              onTap: () {
                Navigator.pop(context);
                final folderProvider = context.read<FolderProvider>();
                try {
                  final folder = folderProvider.folders.firstWhere(
                    (f) => f.id == folderId,
                  );
                  folderProvider.downloadFolder(context, folder);
                } catch (e) {
                  // Folder not found
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Section',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteFolder(folderId, folderName);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFolder(String folderId, String folderName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Section?'),
        content: Text('Delete "$folderName"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<FolderProvider>().delete(folderId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
