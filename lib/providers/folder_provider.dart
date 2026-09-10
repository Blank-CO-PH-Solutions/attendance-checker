import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';
import '../services/connectivity_service.dart';
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
  bool _isOnline = true;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _foldersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _studentsSub;

  List<Folder> get folders => _folders;
  String? get selectedId => _selectedId;
  bool get isOnline => _isOnline;
  Folder? get selectedFolder {
    if (_selectedId == null || _folders.isEmpty) return null;
    try {
      return _folders.firstWhere((f) => f.id == _selectedId);
    } catch (e) {
      return _folders.first;
    }
  }

  FolderProvider() {
    _initConnectivity();
  }

  void setUserId(String userId) {
    _currentUserId = userId;
    _listenToFirestore();
  }

  void _initConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) {
      final wasOffline = !_isOnline;
      _isOnline = result.isNotEmpty && !result.contains(ConnectivityResult.none);

      if (wasOffline && _isOnline) {
        _syncPendingFolderActions();
        if (_firestoreInitialized) {
          _listenToFirestore();
        }
      } else if (!_isOnline) {
        _loadLocal();
      }
      notifyListeners();
    });

    ConnectivityService.checkConnectivity().then((online) {
      _isOnline = online;
      if (!online) {
        _loadLocal();
      }
      notifyListeners();
    });
  }

  Future<void> _loadLocal() async {
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
    _foldersSub?.cancel();
    _studentsSub?.cancel();
    _firestoreInitialized = true;
    _foldersSub = FirebaseFirestore.instance
        .collection('folders')
        .snapshots()
        .listen(
          (snapshot) {
            _foldersSnapshot = snapshot.docs
                .map((doc) => Folder.fromJson(doc.data()))
                .toList();
            _reconcileFolders();
          },
          onError: (e) async {
            debugPrint('Error listening to folders: $e');
            final online = await ConnectivityService.checkConnectivity();
            _isOnline = online;
            notifyListeners();
            if (!online) _loadLocal();
          },
        );

    _studentsSub = FirebaseFirestore.instance
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
          onError: (e) async {
            debugPrint('Error listening to students: $e');
            final online = await ConnectivityService.checkConnectivity();
            _isOnline = online;
            notifyListeners();
            if (!online) _loadLocal();
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
    if (!_isOnline) return;
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
    if (!_isOnline) return;
    try {
      await FirebaseFirestore.instance
          .collection('folders')
          .doc(folderId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting from Firestore: $e');
    }
  }

  Future<void> _syncPendingFolderActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = prefs.getString('pending_folder_actions');

      if (pendingData == null || pendingData.isEmpty) {
        _isOnline = true;
        notifyListeners();
        try {
          await refresh();
        } catch (e) {
          debugPrint('Refresh after folder sync failed: $e');
          final online = await ConnectivityService.checkConnectivity();
          _isOnline = online;
          notifyListeners();
        }
        return;
      }

      final List<dynamic> pending = jsonDecode(pendingData);
      final List<dynamic> remaining = [];

      for (var i = 0; i < pending.length; i++) {
        try {
          await _executeFolderAction(Map<String, dynamic>.from(pending[i]));
        } catch (e) {
          debugPrint('Folder action failed, keeping queued: $e');
          remaining.addAll(pending.sublist(i));
          break;
        }
      }

      if (remaining.isEmpty) {
        await prefs.remove('pending_folder_actions');
      } else {
        await prefs.setString('pending_folder_actions', jsonEncode(remaining));
      }

      _isOnline = true;
      notifyListeners();
      try {
        await refresh();
      } catch (e) {
        debugPrint('Refresh after folder sync failed: $e');
        final online = await ConnectivityService.checkConnectivity();
        _isOnline = online;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error syncing pending folder actions: $e');
    }
  }

  Future<void> _executeFolderAction(Map<String, dynamic> action) async {
    final type = action['type'] as String;
    final firestore = FirebaseFirestore.instance;

    switch (type) {
      case 'create_folder':
      case 'rename_folder':
      case 'add_file':
      case 'remove_file':
      case 'share_folder':
      case 'unshare_folder':
        final folder = Folder.fromJson(Map<String, dynamic>.from(action['folder']));
        await firestore.collection('folders').doc(folder.id).set(folder.toFirestoreJson());
        break;
      case 'delete_folder':
        await firestore.collection('folders').doc(action['folderId'] as String).delete();
        break;
      case 'add_student':
        final student = Student.fromMap(Map<String, dynamic>.from(action['student']));
        await firestore.collection('students').doc(student.id).set({
          ...student.toMap(),
          'folderId': action['folderId'],
          'createdAt': FieldValue.serverTimestamp(),
        });
        break;
      case 'update_student':
        final s = Student.fromMap(Map<String, dynamic>.from(action['student']));
        await firestore.collection('students').doc(s.id).update(s.toMap());
        break;
      case 'remove_student':
        await firestore.collection('students').doc(action['studentId'] as String).delete();
        break;
    }
  }

  Future<void> _addPendingFolderAction(Map<String, dynamic> action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = prefs.getString('pending_folder_actions');
      List<dynamic> pending = [];

      if (pendingData != null && pendingData.isNotEmpty) {
        pending = jsonDecode(pendingData);
      }

      pending.add({...action, 'timestamp': DateTime.now().toIso8601String()});
      await prefs.setString('pending_folder_actions', jsonEncode(pending));
    } catch (e) {
      debugPrint('Error adding pending folder action: $e');
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

    if (_isOnline) {
      _saveToFirestore(folder);
    } else {
      _addPendingFolderAction({'type': 'create_folder', 'folder': folder.toJson()});
    }
    _saveLocal();
    notifyListeners();
  }

  void rename(String id, String newName) {
    final i = _folders.indexWhere((f) => f.id == id);
    if (i != -1) {
      _folders[i] = _folders[i].copyWith(name: newName);
      if (_isOnline) {
        _saveToFirestore(_folders[i]);
      } else {
        _addPendingFolderAction({'type': 'rename_folder', 'folder': _folders[i].toJson()});
      }
      _saveLocal();
      notifyListeners();
    }
  }

  void delete(String id) {
    final folder = _folders.firstWhere(
      (f) => f.id == id,
      orElse: () =>
          Folder(id: '', name: '', ownerId: '', createdAt: DateTime.now()),
    );
    if (folder.id.isEmpty) return;

    _folders.removeWhere((f) => f.id == id);
    if (_selectedId == id) {
      _selectedId = _folders.isNotEmpty ? _folders.first.id : null;
    }

    if (_isOnline) {
      _deleteFromFirestore(id);
    } else {
      _addPendingFolderAction({'type': 'delete_folder', 'folderId': id});
    }
    _saveLocal();
    notifyListeners();
  }

  void select(String id) {
    _selectedId = id;
    notifyListeners();
  }

  Future<void> addStudent(String folderId, Student student) async {
    final i = _folders.indexWhere((f) => f.id == folderId);
    if (i == -1) return;

    _folders[i] = _folders[i].copyWith(
      students: [..._folders[i].students, student],
    );

    if (_isOnline) {
      try {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(student.id)
            .set({
              ...student.toMap(),
              'folderId': folderId,
              'createdAt': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        debugPrint('Error saving student: $e');
        _addPendingFolderAction({
          'type': 'add_student',
          'folderId': folderId,
          'student': student.toMap(),
        });
      }
    } else {
      _addPendingFolderAction({
        'type': 'add_student',
        'folderId': folderId,
        'student': student.toMap(),
      });
    }

    _saveLocal();
    notifyListeners();
  }

  void addFile(String folderId, UploadedFile file) {
    final i = _folders.indexWhere((f) => f.id == folderId);
    if (i != -1) {
      final updatedFiles = List<UploadedFile>.from(_folders[i].files)
        ..add(file);
      _folders[i] = _folders[i].copyWith(files: updatedFiles);
      if (_isOnline) {
        _saveToFirestore(_folders[i]);
      } else {
        _addPendingFolderAction({'type': 'add_file', 'folder': _folders[i].toJson()});
      }
      _saveLocal();
      notifyListeners();
    }
  }

  Future<void> removeStudent(String folderId, String studentId) async {
    final i = _folders.indexWhere((f) => f.id == folderId);
    if (i == -1) return;

    final updatedStudents = _folders[i].students
        .where((s) => s.id != studentId)
        .toList();
    _folders[i] = _folders[i].copyWith(students: updatedStudents);

    if (_isOnline) {
      try {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .delete();
      } catch (e) {
        debugPrint('Error removing student: $e');
        _addPendingFolderAction({
          'type': 'remove_student',
          'studentId': studentId,
        });
      }
    } else {
      _addPendingFolderAction({'type': 'remove_student', 'studentId': studentId});
    }

    _saveLocal();
    notifyListeners();
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

        if (_isOnline) {
          try {
            await FirebaseFirestore.instance
                .collection('students')
                .doc(updatedStudent.id)
                .update(updatedStudent.toMap());
          } catch (e) {
            debugPrint('Error updating student: $e');
            _addPendingFolderAction({
              'type': 'update_student',
              'student': updatedStudent.toMap(),
            });
          }
        } else {
          _addPendingFolderAction({
            'type': 'update_student',
            'student': updatedStudent.toMap(),
          });
        }

        _saveLocal();
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
      if (_isOnline) {
        _saveToFirestore(_folders[i]);
      } else {
        _addPendingFolderAction({'type': 'remove_file', 'folder': _folders[i].toJson()});
      }
      _saveLocal();
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
        if (_isOnline) {
          _saveToFirestore(_folders[i]);
        } else {
          _addPendingFolderAction({'type': 'share_folder', 'folder': _folders[i].toJson()});
        }
        _saveLocal();
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
      if (_isOnline) {
        _saveToFirestore(_folders[i]);
      } else {
        _addPendingFolderAction({'type': 'unshare_folder', 'folder': _folders[i].toJson()});
      }
      _saveLocal();
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
        if (!context.mounted) return;
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