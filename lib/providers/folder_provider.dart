import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';
import '../widgets/student_qr_card.dart';

class UploadedFile {
  final String id;
  final String name;
  final String path;
  final String type;
  final DateTime uploadedAt;

  UploadedFile({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.uploadedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'type': type,
    'uploadedAt': uploadedAt.toIso8601String(),
  };

  factory UploadedFile.fromJson(Map<String, dynamic> json) {
    return UploadedFile(
      id: json['id'],
      name: json['name'],
      path: json['path'],
      type: json['type'],
      uploadedAt: DateTime.parse(json['uploadedAt']),
    );
  }
}

class Folder {
  final String id;
  final String name;
  final String ownerId;
  final List<String> sharedWith;
  final DateTime createdAt;
  final List<Student> students;
  final List<UploadedFile> files;

  Folder({
    required this.id,
    required this.name,
    required this.ownerId,
    List<String>? sharedWith,
    required this.createdAt,
    List<Student>? students,
    List<UploadedFile>? files,
  }) : sharedWith = sharedWith ?? [],
       students = students ?? [],
       files = files ?? [];

  String get fileName => name.replaceAll(' ', '_');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ownerId': ownerId,
    'sharedWith': sharedWith,
    'createdAt': createdAt.toIso8601String(),
    'files': files.map((f) => f.toJson()).toList(),
    'students': students.map((s) => s.toJsonString()).toList(),
  };

  Map<String, dynamic> toFirestoreJson() => {
    'id': id,
    'name': name,
    'ownerId': ownerId,
    'sharedWith': sharedWith,
    'createdAt': createdAt.toIso8601String(),
    'files': files.map((f) => f.toJson()).toList(),
  };

  factory Folder.fromJson(Map<String, dynamic> json) {
    DateTime createdAt;
    final rawCreatedAt = json['createdAt'];
    if (rawCreatedAt is String) {
      createdAt = DateTime.parse(rawCreatedAt);
    } else if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else {
      createdAt = DateTime.now();
    }

    return Folder(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      ownerId: json['ownerId'] ?? '',
      sharedWith: (json['sharedWith'] as List?)?.cast<String>() ?? [],
      createdAt: createdAt,
      students:
          (json['students'] as List?)
              ?.map((s) => Student.fromJsonString(s))
              .toList() ??
          [],
      files:
          (json['files'] as List?)
              ?.map((f) => UploadedFile.fromJson(f))
              .toList() ??
          [],
    );
  }

  Folder copyWith({
    String? name,
    List<String>? sharedWith,
    List<Student>? students,
    List<UploadedFile>? files,
  }) {
    return Folder(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      sharedWith: sharedWith ?? this.sharedWith,
      createdAt: createdAt,
      students: students ?? this.students,
      files: files ?? this.files,
    );
  }
}

class FolderProvider extends ChangeNotifier {
  List<Folder> _folders = [];
  List<Folder> _foldersSnapshot = [];
  Map<String, List<Student>> _studentsByFolder = {};
  String? _currentUserId;
  String? _selectedId;
  bool _firestoreInitialized = false;

  List<Folder> get folders => _folders;
  String? get selectedId => _selectedId;
  Folder? get selectedFolder {
    if (_selectedId == null || _folders.isEmpty) return null;
    try {
      return _folders.firstWhere((f) => f.id == _selectedId);
    } catch (e) {
      return _folders.first;
    }
  }

  FolderProvider() {
    _loadLocal();
  }

  void setUserId(String userId) {
    _currentUserId = userId;
    _listenToFirestore();
  }

  Future<void> _loadLocal() async {
    if (_firestoreInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('folders');
    if (data != null && data.isNotEmpty) {
      final newFolders = (jsonDecode(data) as List)
          .map((e) => Folder.fromJson(e))
          .toList();
      final seenIds = <String>{};
      _folders = newFolders
          .where(
            (f) => f.id.isNotEmpty && f.name.isNotEmpty && seenIds.add(f.id),
          )
          .toList();
      if (_folders.isNotEmpty) _selectedId = _folders.first.id;
      notifyListeners();
    }
  }

  void _listenToFirestore() {
    _firestoreInitialized = true;
    FirebaseFirestore.instance
        .collection('folders')
        .snapshots()
        .listen(
          (snapshot) {
            _foldersSnapshot = snapshot.docs
                .map((doc) => Folder.fromJson(doc.data()))
                .toList();
            _reconcileFolders();
          },
          onError: (e) {
            debugPrint('Error listening to folders: $e');
            _loadLocal();
          },
        );

    FirebaseFirestore.instance
        .collection('students')
        .snapshots()
        .listen(
          (snapshot) {
            final byFolder = <String, List<Student>>{};
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final folderId = data['folderId'];
              if (folderId == null) continue;
              byFolder
                  .putIfAbsent(folderId.toString(), () => [])
                  .add(Student.fromMap(data));
            }
            _studentsByFolder = byFolder;
            _reconcileFolders();
          },
          onError: (e) {
            debugPrint('Error listening to students: $e');
          },
        );
  }

  void _reconcileFolders() {
    if (_foldersSnapshot.isEmpty) return;
    final newFolders = _foldersSnapshot.map((f) {
      final students = (_studentsByFolder[f.id] ?? f.students).toList()
        ..sort((a, b) => a.fullName.compareTo(b.fullName));
      return f.copyWith(students: students);
    }).toList();
    final seenIds = <String>{};
    _folders = newFolders
        .where(
          (f) => f.id.isNotEmpty && f.name.isNotEmpty && seenIds.add(f.id),
        )
        .toList();
    _folders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _saveLocal();
    if (_folders.isNotEmpty && _selectedId == null) {
      _selectedId = _folders.first.id;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final foldersFuture = FirebaseFirestore.instance
          .collection('folders')
          .get();
      final studentsFuture = FirebaseFirestore.instance
          .collection('students')
          .get();
      final results = await Future.wait([foldersFuture, studentsFuture]);
      final foldersSnapshot = results[0];
      final studentsSnapshot = results[1];

      _foldersSnapshot = foldersSnapshot.docs
          .map((doc) => Folder.fromJson(doc.data()))
          .toList();

      final byFolder = <String, List<Student>>{};
      for (final doc in studentsSnapshot.docs) {
        final data = doc.data();
        final folderId = data['folderId'];
        if (folderId == null) continue;
        byFolder
            .putIfAbsent(folderId.toString(), () => [])
            .add(Student.fromMap(data));
      }
      _studentsByFolder = byFolder;
      _reconcileFolders();
    } catch (e) {
      debugPrint('Error refreshing folders: $e');
    }
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'folders',
      jsonEncode(_folders.map((f) => f.toJson()).toList()),
    );
  }

  Future<void> _saveToFirestore(Folder folder) async {
    try {
      await FirebaseFirestore.instance
          .collection('folders')
          .doc(folder.id)
          .set(folder.toFirestoreJson());
    } catch (e) {
      debugPrint('Error saving to Firestore: $e');
    }
  }

  Future<void> _deleteFromFirestore(String folderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('folders')
          .doc(folderId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting from Firestore: $e');
    }
  }

  void create(String name) {
    if (_currentUserId == null) return;

    final folder = Folder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      ownerId: _currentUserId!,
      createdAt: DateTime.now(),
    );
    _folders.add(folder);
    _selectedId ??= folder.id;
    _saveLocal();
    _saveToFirestore(folder);
    notifyListeners();
  }

  void rename(String id, String newName) {
    final i = _folders.indexWhere((f) => f.id == id);
    if (i != -1) {
      _folders[i] = _folders[i].copyWith(name: newName);
      _saveLocal();
      _saveToFirestore(_folders[i]);
      notifyListeners();
    }
  }

  void delete(String id) {
    final folder = _folders.firstWhere(
      (f) => f.id == id,
      orElse: () =>
          Folder(id: '', name: '', ownerId: '', createdAt: DateTime.now()),
    );
    if (folder.ownerId != _currentUserId) return;

    _folders.removeWhere((f) => f.id == id);
    if (_selectedId == id) {
      _selectedId = _folders.isNotEmpty ? _folders.first.id : null;
    }
    _saveLocal();
    _deleteFromFirestore(id);
    notifyListeners();
  }

  void select(String id) {
    _selectedId = id;
    notifyListeners();
  }

  Future<void> addStudent(String folderId, Student student) async {
    final i = _folders.indexWhere((f) => f.id == folderId);
    if (i != -1) {
      _folders[i] = _folders[i].copyWith(
        students: [..._folders[i].students, student],
      );
      _saveLocal();
      _saveToFirestore(_folders[i]);
      notifyListeners();
    }

    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(student.id)
          .set({
            ...student.toMap(),
            'folderId': folderId,
            'ownerId': _currentUserId,
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error saving student: $e');
    }
  }

  void addFile(String folderId, UploadedFile file) {
    final i = _folders.indexWhere((f) => f.id == folderId);
    if (i != -1) {
      final updatedFiles = List<UploadedFile>.from(_folders[i].files)
        ..add(file);
      _folders[i] = _folders[i].copyWith(files: updatedFiles);
      _saveLocal();
      _saveToFirestore(_folders[i]);
      notifyListeners();
    }
  }

  Future<void> removeStudent(String folderId, String studentId) async {
    final i = _folders.indexWhere((f) => f.id == folderId);
    if (i != -1) {
      final updatedStudents = _folders[i].students
          .where((s) => s.id != studentId)
          .toList();
      _folders[i] = _folders[i].copyWith(students: updatedStudents);
      _saveLocal();
      _saveToFirestore(_folders[i]);

      await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .delete();

      notifyListeners();
    }
  }

  Future<void> updateStudent(String folderId, Student updatedStudent) async {
    final i = _folders.indexWhere((f) => f.id == folderId);
    if (i != -1) {
      final studentIndex = _folders[i].students.indexWhere(
        (s) => s.id == updatedStudent.id,
      );
      if (studentIndex != -1) {
        final updatedStudents = List<Student>.from(_folders[i].students);
        updatedStudents[studentIndex] = updatedStudent;
        _folders[i] = _folders[i].copyWith(students: updatedStudents);
        _saveLocal();
        _saveToFirestore(_folders[i]);

        await FirebaseFirestore.instance
            .collection('students')
            .doc(updatedStudent.id)
            .update(updatedStudent.toMap());

        notifyListeners();
      }
    }
  }

  void removeFile(String folderId, String fileId) {
    final i = _folders.indexWhere((f) => f.id == folderId);
    if (i != -1) {
      final file = _folders[i].files.firstWhere(
        (f) => f.id == fileId,
        orElse: () => UploadedFile(
          id: '',
          name: '',
          path: '',
          type: '',
          uploadedAt: DateTime.now(),
        ),
      );
      if (file.path.isNotEmpty) {
        final fileToDelete = File(file.path);
        if (fileToDelete.existsSync()) {
          fileToDelete.deleteSync();
        }
      }
      final updatedFiles = _folders[i].files
          .where((f) => f.id != fileId)
          .toList();
      _folders[i] = _folders[i].copyWith(files: updatedFiles);
      _saveLocal();
      _saveToFirestore(_folders[i]);
      notifyListeners();
    }
  }

  Future<void> shareFolder(String folderId, String userId) async {
    final i = _folders.indexWhere((f) => f.id == folderId);
    if (i != -1) {
      final folder = _folders[i];
      if (!folder.sharedWith.contains(userId)) {
        final updatedSharedWith = List<String>.from(folder.sharedWith)
          ..add(userId);
        _folders[i] = folder.copyWith(sharedWith: updatedSharedWith);
        _saveLocal();
        _saveToFirestore(_folders[i]);
        notifyListeners();
      }
    }
  }

  Future<void> unshareFolder(String folderId, String userId) async {
    final i = _folders.indexWhere((f) => f.id == folderId);
    if (i != -1) {
      final folder = _folders[i];
      final updatedSharedWith = folder.sharedWith
          .where((id) => id != userId)
          .toList();
      _folders[i] = folder.copyWith(sharedWith: updatedSharedWith);
      _saveLocal();
      _saveToFirestore(_folders[i]);
      notifyListeners();
    }
  }

  Future<String> getDownloadPath() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir.path;
    }
    return (await getApplicationDocumentsDirectory()).path;
  }

  Future<void> downloadFolder(BuildContext context, Folder folder) async {
    try {
      await precacheImage(
        const AssetImage('assets/cicslogo.jpeg'),
        context,
      );

      final path = await getDownloadPath();
      final folderDir = Directory('$path/${folder.fileName}_QRCodes');
      if (await folderDir.exists()) await folderDir.delete(recursive: true);
      await folderDir.create();

      for (final student in folder.students) {
        final bytes = await _captureStudentCard(context, student);
        await File(
          '${folderDir.path}/${student.fileName}.png',
        ).writeAsBytes(bytes);
      }

      final manifest = folder.students
          .map((s) => '${s.fullName}\n${s.studentNumber}\n${s.program} ${s.year}')
          .join('\n---\n');
      await File('${folderDir.path}/manifest.txt').writeAsString(manifest);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded to Downloads/${folder.fileName}_QRCodes'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Download error: $e');
    }
  }

  Future<List<int>> _captureStudentCard(
    BuildContext context,
    Student student,
  ) async {
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -4000,
        top: -4000,
        child: RepaintBoundary(
          key: boundaryKey,
          child: StudentQrCard(student: student),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } finally {
      entry.remove();
      await WidgetsBinding.instance.endOfFrame;
    }
  }
}
