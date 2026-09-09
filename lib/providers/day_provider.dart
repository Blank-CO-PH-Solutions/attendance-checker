import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance_record.dart';

class AttendanceEvent {
  final String id;
  final String name;
  final String ownerId;
  final List<String> sharedWith;
  final DateTime createdAt;
  List<AttendanceRecord> records;

  AttendanceEvent({
    required this.id,
    required this.name,
    required this.ownerId,
    List<String>? sharedWith,
    required this.createdAt,
    List<AttendanceRecord>? records,
  }) : sharedWith = sharedWith ?? [],
       records = records ?? [];

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'ownerId': ownerId,
    'sharedWith': sharedWith,
    'createdAt': Timestamp.fromDate(createdAt),
    'records': records.map((r) => r.toMap()).toList(),
  };

  Map<String, dynamic> toFirestoreMap() => {
    'id': id,
    'name': name,
    'ownerId': ownerId,
    'sharedWith': sharedWith,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory AttendanceEvent.fromMap(Map<String, dynamic> map) {
    DateTime createdAt;
    final rawCreatedAt = map['createdAt'];
    if (rawCreatedAt is Timestamp) {
      createdAt = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.parse(rawCreatedAt);
    } else {
      createdAt = DateTime.now();
    }

    return AttendanceEvent(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      ownerId: map['ownerId'] ?? '',
      sharedWith: (map['sharedWith'] as List?)?.cast<String>() ?? [],
      createdAt: createdAt,
      records:
          (map['records'] as List<dynamic>?)
              ?.map(
                (r) => AttendanceRecord.fromMap(Map<String, dynamic>.from(r)),
              )
              .toList() ??
          [],
    );
  }

  factory AttendanceEvent.fromJson(Map<String, dynamic> json) {
    DateTime createdAt;
    final rawCreatedAt = json['createdAt'];
    if (rawCreatedAt is String) {
      createdAt = DateTime.parse(rawCreatedAt);
    } else {
      createdAt = DateTime.now();
    }

    return AttendanceEvent(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      ownerId: json['ownerId'] ?? '',
      sharedWith: (json['sharedWith'] as List?)?.cast<String>() ?? [],
      createdAt: createdAt,
      records:
          (json['records'] as List<dynamic>?)
              ?.map(
                (r) => AttendanceRecord.fromMap(Map<String, dynamic>.from(r)),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ownerId': ownerId,
    'sharedWith': sharedWith,
    'createdAt': createdAt.toIso8601String(),
    'records': records.map((r) => r.toJson()).toList(),
  };

  AttendanceEvent copyWith({
    String? name,
    List<String>? sharedWith,
    List<AttendanceRecord>? records,
  }) {
    return AttendanceEvent(
      id: id,
      name: name ?? this.name,
      ownerId: ownerId,
      sharedWith: sharedWith ?? this.sharedWith,
      createdAt: createdAt,
      records: records ?? this.records,
    );
  }
}

class AttendanceEventProvider extends ChangeNotifier {
  List<AttendanceEvent> _events = [];
  String? _selectedEventId;
  String? _currentUserId;
  bool _isLoading = true;
  bool _isOnline = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, List<AttendanceRecord>> _recordsByEvent = {};
  final Map<String, StreamSubscription<QuerySnapshot>> _recordSubs = {};

  List<AttendanceEvent> get events => _events;
  String? get selectedEventId => _selectedEventId;
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;

  AttendanceEvent? get selectedEvent => _selectedEventId != null
      ? _events.firstWhere(
          (e) => e.id == _selectedEventId,
          orElse: () => _events.first,
        )
      : _events.isNotEmpty
      ? _events.first
      : null;

  AttendanceEventProvider() {
    _initConnectivity();
    _loadLocal();
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
        _syncPendingActions();
      }
      notifyListeners();
    });
  }

  CollectionReference<Map<String, dynamic>> _recordsRef(String eventId) {
    return _firestore
        .collection('attendance_events')
        .doc(eventId)
        .collection('records');
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_events');
      if (cachedData != null && cachedData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedData);
        final newEvents =
            decoded.map((json) => AttendanceEvent.fromJson(json)).toList();
        final seenIds = <String>{};
        _events =
            newEvents.where((e) => e.id.isNotEmpty && seenIds.add(e.id)).toList();
        _events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      if (_events.isNotEmpty && _selectedEventId == null) {
        _selectedEventId = _events.first.id;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading from cache: $e');
    }
  }

  void _listenToFirestore() {
    _isLoading = true;
    notifyListeners();

    _firestore.collection('attendance_events').snapshots().listen(
      (snapshot) {
        final newEvents =
            snapshot.docs
                .map((doc) => AttendanceEvent.fromMap(doc.data()))
                .toList();
        final seenIds = <String>{};
        _events =
            newEvents.where((e) => e.id.isNotEmpty && seenIds.add(e.id)).toList();
        _events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _syncRecordListeners();
        _applyRecordsToEvents();
        _cacheLocally();
        if (_events.isNotEmpty && _selectedEventId == null) {
          _selectedEventId = _events.first.id;
        }
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Error listening to Firestore: $e');
        _isOnline = false;
        _loadLocal();
      },
    );

    _syncRecordListeners();
  }

  void _syncRecordListeners() {
    final ids = _events.map((e) => e.id).toSet();

    for (final id in _recordSubs.keys.toList()) {
      if (!ids.contains(id)) {
        _recordSubs.remove(id)!.cancel();
        _recordsByEvent.remove(id);
      }
    }

    for (final id in ids) {
      if (!_recordSubs.containsKey(id)) {
        final sub = _recordsRef(id).snapshots().listen(
          (snap) {
            _recordsByEvent[id] = snap.docs
                .map((doc) => AttendanceRecord.fromMap(doc.data()))
                .toList()
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
            _applyRecordsToEvents();
            _cacheLocally();
          },
          onError: (e) {
            debugPrint('Error listening to records for $id: $e');
          },
        );
        _recordSubs[id] = sub;
      }
    }
  }

  void _applyRecordsToEvents() {
    for (final event in _events) {
      final recs = _recordsByEvent[event.id];
      if (recs != null) {
        event.records = recs;
      }
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final snapshot =
          await _firestore.collection('attendance_events').get();
      final newEvents =
          snapshot.docs
              .map((doc) => AttendanceEvent.fromMap(doc.data()))
              .toList();
      final seenIds = <String>{};
      _events =
          newEvents.where((e) => e.id.isNotEmpty && seenIds.add(e.id)).toList();
      _events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _syncRecordListeners();

      for (final event in _events) {
        await _fetchRecords(event.id);
      }
      _applyRecordsToEvents();
      await _cacheLocally();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing events: $e');
    }
  }

  Future<void> _fetchRecords(String eventId) async {
    try {
      final snap = await _firestore
          .collection('attendance_events')
          .doc(eventId)
          .collection('records')
          .get();
      _recordsByEvent[eventId] = snap.docs
          .map((doc) => AttendanceRecord.fromMap(doc.data()))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('Error fetching records for $eventId: $e');
    }
  }

  Future<void> _cacheLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = _events.map((e) => e.toJson()).toList();
      await prefs.setString('cached_events', jsonEncode(eventsJson));
      await prefs.setString('last_sync', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error caching locally: $e');
    }
  }

  Future<void> _syncPendingActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = prefs.getString('pending_actions');

      if (pendingData == null || pendingData.isEmpty) {
        _isOnline = true;
        notifyListeners();
        return;
      }

      final List<dynamic> pending = jsonDecode(pendingData);
      var remaining = List<dynamic>.from(pending);

      for (var i = 0; i < pending.length; i++) {
        try {
          await _executeAction(Map<String, dynamic>.from(pending[i]));
          remaining = List<dynamic>.from(pending.sublist(i + 1));
        } catch (e) {
          debugPrint('Action failed, keeping it queued: $e');
          break;
        }
      }

      if (remaining.isEmpty) {
        await prefs.remove('pending_actions');
      } else {
        await prefs.setString('pending_actions', jsonEncode(remaining));
      }

      _isOnline = true;
      notifyListeners();
      await refresh();
    } catch (e) {
      debugPrint('Error syncing pending actions: $e');
    }
  }

  Future<void> _executeAction(Map<String, dynamic> action) async {
    final type = action['type'] as String;
    final eventId = action['eventId'] as String;

    switch (type) {
      case 'add_record':
        final record = AttendanceRecord.fromMap(
          Map<String, dynamic>.from(action['record']),
        );
        await _recordsRef(eventId).doc(record.id).set(record.toMap());
        break;
      case 'delete_record':
        await _recordsRef(eventId).doc(action['recordId'] as String).delete();
        break;
      case 'remove_record':
        await _removeRecordsFromFirestore(
          eventId,
          action['studentId'] as String,
          action['attendanceType'] as String,
        );
        break;
      case 'create_event':
        final event = AttendanceEvent.fromJson(Map<String, dynamic>.from(action['event']));
        await _firestore
            .collection('attendance_events')
            .doc(event.id)
            .set(event.toFirestoreMap());
        break;
      case 'rename_event':
        await _firestore
            .collection('attendance_events')
            .doc(eventId)
            .update({'name': action['name'] as String});
        break;
      case 'delete_event':
        await _deleteEventWithRecords(eventId);
        break;
      case 'clear_records':
        await _clearRecordsFromFirestore(eventId);
        break;
    }
  }

  Future<void> _deleteEventWithRecords(String eventId) async {
    await _clearRecordsFromFirestore(eventId);
    await _firestore.collection('attendance_events').doc(eventId).delete();
  }

  Future<void> _removeRecordsFromFirestore(
    String eventId,
    String studentId,
    String type,
  ) async {
    final snap = await _recordsRef(eventId)
        .where('type', isEqualTo: type)
        .where('student.id', isEqualTo: studentId)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> _clearRecordsFromFirestore(String eventId) async {
    final snap = await _recordsRef(eventId).get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> createEvent(String name) async {
    if (_currentUserId == null) return;

    final eventId = DateTime.now().millisecondsSinceEpoch.toString();
    final event = AttendanceEvent(
      id: eventId,
      name: name,
      ownerId: _currentUserId!,
      createdAt: DateTime.now(),
    );

    if (_isOnline) {
      try {
        await _firestore
            .collection('attendance_events')
            .doc(eventId)
            .set(event.toFirestoreMap());
      } catch (e) {
        _addPendingAction({'type': 'create_event', 'event': event.toJson()});
      }
    } else {
      _addPendingAction({'type': 'create_event', 'event': event.toJson()});
    }

    _events.insert(0, event);
    _selectedEventId ??= eventId;
    _recordsByEvent[eventId] = [];
    await _cacheLocally();
    notifyListeners();
  }

  Future<void> deleteEvent(String id) async {
    if (_isOnline) {
      try {
        await _deleteEventWithRecords(id);
      } catch (e) {
        _addPendingAction({'type': 'delete_event', 'eventId': id});
      }
    } else {
      _addPendingAction({'type': 'delete_event', 'eventId': id});
    }

    _recordSubs.remove(id)?.cancel();
    _recordsByEvent.remove(id);
    _events.removeWhere((e) => e.id == id);
    if (_selectedEventId == id) {
      _selectedEventId = _events.isNotEmpty ? _events.first.id : null;
    }
    await _cacheLocally();
    notifyListeners();
  }

  void selectEvent(String id) {
    _selectedEventId = id;
    notifyListeners();
  }

  Future<void> renameEvent(String id, String newName) async {
    final index = _events.indexWhere((e) => e.id == id);
    if (index != -1) {
      final updatedEvent = _events[index].copyWith(name: newName);

      if (_isOnline) {
        try {
          await _firestore
              .collection('attendance_events')
              .doc(id)
              .update({'name': newName});
        } catch (e) {
          _addPendingAction({
            'type': 'rename_event',
            'eventId': id,
            'name': newName,
          });
        }
      } else {
        _addPendingAction({'type': 'rename_event', 'eventId': id, 'name': newName});
      }

      _events[index] = updatedEvent;
      await _cacheLocally();
      notifyListeners();
    }
  }

  bool hasTimeIn(String eventId, String studentId, {bool? isAm}) {
    final eventIndex = _events.indexWhere((e) => e.id == eventId);
    if (eventIndex == -1) return false;
    return _events[eventIndex].records.any((r) {
      if (r.student.id != studentId || r.type != AttendanceType.timeIn) return false;
      if (isAm == null) return true;
      final recordHour = r.timestamp.hour;
      final isRecordAm = recordHour < 12;
      return isRecordAm == isAm;
    });
  }

  bool hasTimeOut(String eventId, String studentId, {bool? isAm}) {
    final eventIndex = _events.indexWhere((e) => e.id == eventId);
    if (eventIndex == -1) return false;
    return _events[eventIndex].records.any((r) {
      if (r.student.id != studentId || r.type != AttendanceType.timeOut) return false;
      if (isAm == null) return true;
      final recordHour = r.timestamp.hour;
      final isRecordAm = recordHour < 12;
      return isRecordAm == isAm;
    });
  }

  Future<void> addRecordToEvent(String eventId, AttendanceRecord record) async {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      _events[index].records.insert(0, record);
      _recordsByEvent[eventId]?.insert(0, record);
      final recordMap = {
        ...record.toMap(),
        'eventId': eventId,
      };

      if (_isOnline) {
        try {
          await _recordsRef(eventId).doc(record.id).set(recordMap);
        } catch (e) {
          _addPendingAction({
            'type': 'add_record',
            'eventId': eventId,
            'record': record.toJson(),
          });
          if (_isNetworkError(e)) {
            _isOnline = false;
          }
        }
      } else {
        _addPendingAction({
          'type': 'add_record',
          'eventId': eventId,
          'record': record.toJson(),
        });
      }

      _applyRecordsToEvents();
      await _cacheLocally();
      notifyListeners();
    }
  }

  Future<void> deleteRecord(String eventId, String recordId) async {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index == -1) return;

    _events[index].records.removeWhere((r) => r.id == recordId);
    _recordsByEvent[eventId]?.removeWhere((r) => r.id == recordId);

    if (_isOnline) {
      try {
        await _recordsRef(eventId).doc(recordId).delete();
      } catch (e) {
        _addPendingAction({
          'type': 'delete_record',
          'eventId': eventId,
          'recordId': recordId,
        });
        if (_isNetworkError(e)) {
          _isOnline = false;
        }
      }
    } else {
      _addPendingAction({
        'type': 'delete_record',
        'eventId': eventId,
        'recordId': recordId,
      });
    }

    _applyRecordsToEvents();
    await _cacheLocally();
    notifyListeners();
  }

  Future<void> removeRecord(
    String eventId,
    String studentId,
    AttendanceType type,
  ) async {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      _events[index].records.removeWhere(
        (r) => r.student.id == studentId && r.type == type,
      );
      _recordsByEvent[eventId]?.removeWhere(
        (r) => r.student.id == studentId && r.type == type,
      );

      if (_isOnline) {
        try {
          await _removeRecordsFromFirestore(eventId, studentId, type.name);
        } catch (e) {
          _addPendingAction({
            'type': 'remove_record',
            'eventId': eventId,
            'studentId': studentId,
            'attendanceType': type.name,
          });
        }
      } else {
        _addPendingAction({
          'type': 'remove_record',
          'eventId': eventId,
          'studentId': studentId,
          'attendanceType': type.name,
        });
      }

      _applyRecordsToEvents();
      await _cacheLocally();
      notifyListeners();
    }
  }

  Future<void> clearEventRecords(String eventId) async {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      _events[index].records.clear();
      _recordsByEvent[eventId]?.clear();

      if (_isOnline) {
        try {
          await _clearRecordsFromFirestore(eventId);
        } catch (e) {
          _addPendingAction({'type': 'clear_records', 'eventId': eventId});
        }
      } else {
        _addPendingAction({'type': 'clear_records', 'eventId': eventId});
      }

      _applyRecordsToEvents();
      await _cacheLocally();
      notifyListeners();
    }
  }

  bool _isNetworkError(Object error) {
    return error is FirebaseException &&
        (error.code == 'unavailable' ||
            error.code == 'network-request-failed' ||
            error.code == 'aborted');
  }

  Future<void> _addPendingAction(Map<String, dynamic> action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingData = prefs.getString('pending_actions');
      List<dynamic> pending = [];

      if (pendingData != null && pendingData.isNotEmpty) {
        pending = jsonDecode(pendingData);
      }

      pending.add({...action, 'timestamp': DateTime.now().toIso8601String()});
      await prefs.setString('pending_actions', jsonEncode(pending));
    } catch (e) {
      debugPrint('Error adding pending action: $e');
    }
  }

  Future<String?> exportToExcel(String eventId) async {
    final eventIndex = _events.indexWhere((e) => e.id == eventId);
    if (eventIndex == -1) return null;

    final event = _events[eventIndex];
    final excel = Excel.createExcel();

    final timeInSheet = excel['Time In'];
    final timeOutSheet = excel['Time Out'];
    final allSheet = excel['All Records'];

    void addHeaderRow(Sheet sheet) {
      sheet.appendRow([
        TextCellValue('No.'),
        TextCellValue('Full Name'),
        TextCellValue('Program'),
        TextCellValue('Year'),
        TextCellValue('Time'),
        TextCellValue('Type'),
      ]);
    }

    void addRecords(Sheet sheet, List<AttendanceRecord> recs) {
      final timeFormat = DateFormat('h:mm a');
      final dateFormat = DateFormat('MMM dd, yyyy');
      for (var i = 0; i < recs.length; i++) {
        final record = recs[i];
        sheet.appendRow([
          TextCellValue('${i + 1}'),
          TextCellValue(record.student.fullName),
          TextCellValue(record.student.program),
          TextCellValue(record.student.year),
          TextCellValue('${dateFormat.format(record.timestamp)} ${timeFormat.format(record.timestamp)}'),
          TextCellValue(record.type == AttendanceType.timeIn ? 'Time In' : 'Time Out'),
        ]);
      }
    }

    addHeaderRow(timeInSheet);
    addRecords(timeInSheet, event.records.where((r) => r.type == AttendanceType.timeIn).toList());

    addHeaderRow(timeOutSheet);
    addRecords(timeOutSheet, event.records.where((r) => r.type == AttendanceType.timeOut).toList());

    addHeaderRow(allSheet);
    addRecords(allSheet, event.records);

    try {
      Directory? directory;
      if (Platform.isAndroid) {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final exportDir = Directory('${extDir.path}/Exports');
          if (!await exportDir.exists()) {
            await exportDir.create(recursive: true);
          }
          directory = exportDir;
        } else {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      }

      final fileName = '${event.name.replaceAll(' ', '_')}_attendance.xlsx';
      final file = File('${directory.path}/$fileName');

      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (e) {
      debugPrint('Error exporting to Excel: $e');
    }
    return null;
  }

  Future<void> shareEvent(String eventId, String userId) async {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      final event = _events[index];
      if (event.ownerId != _currentUserId) return;
      if (!event.sharedWith.contains(userId)) {
        final updatedSharedWith = List<String>.from(event.sharedWith)..add(userId);
        _events[index] = event.copyWith(sharedWith: updatedSharedWith);
        await _saveToFirestore(_events[index]);
        await _cacheLocally();
        notifyListeners();
      }
    }
  }

  Future<void> unshareEvent(String eventId, String userId) async {
    final index = _events.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      final event = _events[index];
      if (event.ownerId != _currentUserId) return;
      final updatedSharedWith = event.sharedWith.where((id) => id != userId).toList();
      _events[index] = event.copyWith(sharedWith: updatedSharedWith);
      await _saveToFirestore(_events[index]);
      await _cacheLocally();
      notifyListeners();
    }
  }

  Future<void> _saveToFirestore(AttendanceEvent event) async {
    if (_isOnline) {
      try {
        await _firestore
            .collection('attendance_events')
            .doc(event.id)
            .update({
              'sharedWith': event.sharedWith,
            });
      } catch (e) {
        debugPrint('Error saving to Firestore: $e');
      }
    }
  }
}