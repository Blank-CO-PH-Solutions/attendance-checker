import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';

class AttendanceProvider extends ChangeNotifier {
  List<AttendanceRecord> _records = [];
  final Uuid _uuid = const Uuid();
  String? _currentUserId;
  bool _isOnline = true;

  List<AttendanceRecord> get records => _records;
  bool get isOnline => _isOnline;

  List<AttendanceRecord> get timeInRecords =>
      _records.where((r) => r.type == AttendanceType.timeIn).toList();

  List<AttendanceRecord> get timeOutRecords =>
      _records.where((r) => r.type == AttendanceType.timeOut).toList();

  AttendanceProvider() {
    _initConnectivity();
    _loadLocalRecords();
  }

  void setUserId(String userId) {
    _currentUserId = userId;
    _loadFromFirestore();
  }

  void _initConnectivity() {
    Connectivity().onConnectivityChanged.listen((result) {
      final wasOffline = !_isOnline;
      _isOnline = result.isNotEmpty && !result.contains(ConnectivityResult.none);

      if (wasOffline && _isOnline) {
        _syncPendingActions();
      }
      notifyListeners();
    });
  }

  Future<void> _loadLocalRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('attendance_records');
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      _records = jsonList
          .map((e) => AttendanceRecord.fromJsonString(e))
          .toList();
      notifyListeners();
    }
  }

  Future<void> _loadFromFirestore() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('records')
          .orderBy('timestamp', descending: true)
          .get();

      _records = snapshot.docs
          .map((doc) => AttendanceRecord.fromMap(doc.data()))
          .toList();

      _saveLocalRecords();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading from Firestore: $e');
    }
  }

  Future<void> _saveLocalRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(
      _records.map((r) => r.toJsonString()).toList(),
    );
    await prefs.setString('attendance_records', data);
  }

  Future<void> _saveToFirestore(AttendanceRecord record) async {
    if (_currentUserId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('records')
          .doc(record.id)
          .set(record.toMap());
    } catch (e) {
      debugPrint('Error saving to Firestore: $e');
    }
  }

  Future<void> _deleteFromFirestore(String recordId) async {
    if (_currentUserId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('records')
          .doc(recordId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting from Firestore: $e');
    }
  }

  Future<void> _clearFromFirestore() async {
    if (_currentUserId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('records')
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error clearing from Firestore: $e');
    }
  }

  Future<void> _syncPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = prefs.getString('pending_attendance_records');

      if (pendingData == null || pendingData.isEmpty) {
        _isOnline = true;
        notifyListeners();
        return;
      }

      final List<dynamic> pending = jsonDecode(pendingData);
      final List<dynamic> remaining = [];

      for (var i = 0; i < pending.length; i++) {
        try {
          await _executeAction(Map<String, dynamic>.from(pending[i]));
        } catch (e) {
          debugPrint('Attendance action failed, keeping queued: $e');
          remaining.addAll(pending.sublist(i));
          break;
        }
      }

      if (remaining.isEmpty) {
        await prefs.remove('pending_attendance_records');
      } else {
        await prefs.setString(
          'pending_attendance_records',
          jsonEncode(remaining),
        );
      }

      _isOnline = true;
      notifyListeners();

      try {
        await _loadFromFirestore();
      } catch (e) {
        debugPrint('Reload after attendance sync failed: $e');
        _isOnline = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error syncing pending attendance records: $e');
    }
  }

  Future<void> _executeAction(Map<String, dynamic> action) async {
    final type = action['type'] as String;

    switch (type) {
      case 'add_record':
        final record = AttendanceRecord.fromMap(
          Map<String, dynamic>.from(action['record']),
        );
        await _saveToFirestore(record);
        break;
      case 'delete_record':
        await _deleteFromFirestore(action['recordId'] as String);
        break;
      case 'clear_records':
        await _clearFromFirestore();
        break;
    }
  }

  Future<void> _addPendingAction(Map<String, dynamic> action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = prefs.getString('pending_attendance_records');
      List<dynamic> pending = [];

      if (pendingData != null && pendingData.isNotEmpty) {
        pending = jsonDecode(pendingData);
      }

      pending.add({...action, 'timestamp': DateTime.now().toIso8601String()});
      await prefs.setString('pending_attendance_records', jsonEncode(pending));
    } catch (e) {
      debugPrint('Error adding pending attendance action: $e');
    }
  }

  void addRecord(Student student, AttendanceType type) {
    final record = AttendanceRecord(
      id: _uuid.v4(),
      student: student,
      timestamp: DateTime.now(),
      type: type,
    );
    _records.insert(0, record);
    _saveLocalRecords();

    if (_currentUserId == null) return;

    if (_isOnline) {
      try {
        _saveToFirestore(record);
      } catch (e) {
        _addPendingAction({
          'type': 'add_record',
          'record': jsonDecode(record.toJsonString()),
        });
      }
    } else {
      _addPendingAction({
        'type': 'add_record',
        'record': jsonDecode(record.toJsonString()),
      });
    }
    notifyListeners();
  }

  void clearRecords() {
    _records.clear();
    _saveLocalRecords();

    if (_currentUserId != null) {
      if (_isOnline) {
        try {
          _clearFromFirestore();
        } catch (e) {
          _addPendingAction({'type': 'clear_records'});
        }
      } else {
        _addPendingAction({'type': 'clear_records'});
      }
    }
    notifyListeners();
  }

  void deleteRecord(String recordId) {
    _records.removeWhere((r) => r.id == recordId);
    _saveLocalRecords();

    if (_currentUserId != null) {
      if (_isOnline) {
        try {
          _deleteFromFirestore(recordId);
        } catch (e) {
          _addPendingAction({'type': 'delete_record', 'recordId': recordId});
        }
      } else {
        _addPendingAction({'type': 'delete_record', 'recordId': recordId});
      }
    }
    notifyListeners();
  }
}