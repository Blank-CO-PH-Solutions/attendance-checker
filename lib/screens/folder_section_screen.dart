import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import '../models/student.dart';
import '../providers/folder_provider.dart';
import '../providers/day_provider.dart';
import 'qr_display_screen.dart';

class FolderSectionScreen extends StatefulWidget {
  final String folderId;

  const FolderSectionScreen({super.key, required this.folderId});

  @override
  State<FolderSectionScreen> createState() => _FolderSectionScreenState();
}

class _FolderSectionScreenState extends State<FolderSectionScreen> {
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

  void _showAddStudentDialog() {
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
      final folderProvider = context.read<FolderProvider>();
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

      folderProvider.addStudent(widget.folderId, student);

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
            onDelete: () {
              context.read<FolderProvider>().removeStudent(
                widget.folderId,
                student.id,
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _massUpload() async {
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The file is empty'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final headerRow = sheet.rows.first;
      final headers = headerRow.map((cell) => cell?.value?.toString().toLowerCase().trim() ?? '').toList();

      int firstNameIdx = -1, lastNameIdx = -1, studentNumberIdx = -1, programYearIdx = -1, parentNumberIdx = -1;
      for (int i = 0; i < headers.length; i++) {
        final h = headers[i];
        if (h.contains('first') && h.contains('name')) firstNameIdx = i;
        else if (h.contains('last') && h.contains('name')) lastNameIdx = i;
        else if (h.contains('student') && h.contains('number')) studentNumberIdx = i;
        else if (h.contains('program')) programYearIdx = i;
        else if (h.contains('parent')) parentNumberIdx = i;
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
        final parentNumber = parentNumberIdx == -1
            ? ''
            : (row[parentNumberIdx]?.value?.toString().trim() ?? '');

        if (firstName.isEmpty || lastName.isEmpty || studentNumber.isEmpty || programYear.isEmpty) continue;

        students.add(Student(
          id: _uuid.v4(),
          firstName: firstName,
          middleName: '',
          lastName: lastName,
          studentNumber: studentNumber,
          year: '',
          program: programYear,
          parentNumber: parentNumber,
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

      final folderProvider = context.read<FolderProvider>();
      for (final student in students) {
        folderProvider.addStudent(widget.folderId, student);
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

  void _showEditStudentDialog(Student student) {
    final firstNameController = TextEditingController(text: student.firstName);
    final lastNameController = TextEditingController(text: student.lastName);
    final studentNumberController = TextEditingController(
      text: student.studentNumber,
    );
    final programYearController = TextEditingController(text: student.program);
    final parentNumberController = TextEditingController(
      text: student.parentNumber,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
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
                    'Edit Student',
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
                child: Column(
                  children: [
                    TextField(
                      controller: firstNameController,
                      decoration: _inputDecoration(
                        'First Name',
                        Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lastNameController,
                      decoration: _inputDecoration(
                        'Last Name',
                        Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: studentNumberController,
                      decoration: _inputDecoration(
                        'Student Number',
                        Icons.numbers,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: programYearController,
                      decoration: _inputDecoration(
                        'Program & Year',
                        Icons.school,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: parentNumberController,
                      decoration: _inputDecoration(
                        "Parent's Number",
                        Icons.phone,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          final updatedStudent = Student(
                            id: student.id,
                            firstName: firstNameController.text.trim(),
                            middleName: '',
                            lastName: lastNameController.text.trim(),
                            studentNumber: studentNumberController.text.trim(),
                            year: '',
                            program: programYearController.text.trim(),
                            parentNumber: parentNumberController.text.trim(),
                          );
                          context.read<FolderProvider>().updateStudent(
                            widget.folderId,
                            updatedStudent,
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Save Changes'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFolderOptions() {
    final folderProvider = context.read<FolderProvider>();
    Folder folder;
    try {
      folder = folderProvider.folders.firstWhere(
        (f) => f.id == widget.folderId,
      );
    } catch (e) {
      if (folderProvider.folders.isEmpty) return;
      folder = folderProvider.folders.first;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
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
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder,
                size: 32,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              folder.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              '${folder.students.length} students',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(Icons.folder, color: Color(0xFF2563EB)),
              title: const Text('Download Folder'),
              onTap: () {
                Navigator.pop(ctx);
                folderProvider.downloadFolder(context, folder);
              },
            ),
            ListTile(
              leading: Icon(Icons.download, color: Color(0xFF10B981)),
              title: const Text('Download All QR Codes'),
              onTap: () {
                Navigator.pop(ctx);
                folderProvider.downloadFolder(context, folder);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Section',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteFolder(folder.name);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteFolder(String folderName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Section?'),
        content: Text('Delete "$folderName"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<FolderProvider>().delete(widget.folderId);
              Navigator.pop(ctx);
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
        title: Consumer<FolderProvider>(
          builder: (context, folderProvider, child) {
            final folder = folderProvider.folders.firstWhere(
              (f) => f.id == widget.folderId,
              orElse: () => Folder(
                id: '',
                name: 'Section',
                ownerId: '',
                createdAt: DateTime.now(),
              ),
            );
            return Text(
              folder.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            );
          },
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showFolderOptions,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Consumer<FolderProvider>(
          builder: (context, folderProvider, child) {
            final folder = folderProvider.folders.firstWhere(
              (f) => f.id == widget.folderId,
              orElse: () => Folder(
                id: '',
                name: '',
                ownerId: '',
                createdAt: DateTime.now(),
                students: [],
              ),
            );

            if (folder.students.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No students yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add a student',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: folder.students.length,
            itemBuilder: (context, index) {
              final student = folder.students[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person, color: Color(0xFF10B981)),
                  ),
                  title: Text(
                    student.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(student.program),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Color(0xFF2563EB)),
                        onPressed: () => _showEditStudentDialog(student),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.qr_code,
                          color: Color(0xFF2563EB),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QrDisplayScreen(
                                student: student,
                                onDelete: () {
                                  context.read<FolderProvider>().removeStudent(
                                    widget.folderId,
                                    student.id,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                        tooltip: 'View QR',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          folderProvider.removeStudent(
                            widget.folderId,
                            student.id,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStudentDialog,
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Student'),
      ),
    );
  }
}
