import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../models/attendance_record.dart';
import '../providers/day_provider.dart';
import '../providers/folder_provider.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController? _controller;
  String? _lastScannedCode;
  int _selectedFilter = 0;
  bool _isProcessing = false;
  final TextEditingController _manualInputController = TextEditingController();
  bool _showManualInput = false;
  bool _isAmSelected = true;

  bool get _isWeb => identical(0, 0.0) ? true : false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<FolderProvider>().refresh(),
      context.read<AttendanceEventProvider>().refresh(),
    ]);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.format != BarcodeFormat.qrCode) continue;

      final String? code = barcode.rawValue;
      if (code != null && code != _lastScannedCode) {
        _lastScannedCode = code;
        _isProcessing = true;
        _processQrCode(code);
        break;
      }
    }
  }

  void _processQrCode(String qrData) async {
    final folderProvider = context.read<FolderProvider>();
    Student? foundStudent;

    for (final folder in folderProvider.folders) {
      for (final student in folder.students) {
        if (student.studentNumber == qrData) {
          foundStudent = student;
          break;
        }
      }
      if (foundStudent != null) break;
    }

    if (foundStudent != null) {
      _autoRecordAttendance(foundStudent);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student not found'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _processManualInput() {
    final input = _manualInputController.text.trim();
    if (input.isNotEmpty) {
      _processQrCode(input);
      _manualInputController.clear();
      setState(() {
        _showManualInput = false;
      });
    }
  }

  void _autoRecordAttendance(Student student) {
    final eventProvider = context.read<AttendanceEventProvider>();

    if (eventProvider.selectedEventId == null) {
      _showErrorSnackBar('Please select an Event first');
      return;
    }

    final AttendanceType type;
    String typeText;
    if (_selectedFilter == 2) {
      type = AttendanceType.timeOut;
      typeText = 'Time Out';
    } else {
      type = AttendanceType.timeIn;
      typeText = 'Time In';
    }

    if (type == AttendanceType.timeIn &&
        eventProvider.hasTimeIn(
          eventProvider.selectedEventId!,
          student.id,
          isAm: _isAmSelected,
        )) {
      _showWarningSnackBar(
        '${student.fullName} already timed in for ${_isAmSelected ? "AM" : "PM"}',
      );
      return;
    }

    if (type == AttendanceType.timeOut &&
        eventProvider.hasTimeOut(
          eventProvider.selectedEventId!,
          student.id,
          isAm: _isAmSelected,
        )) {
      _showWarningSnackBar(
        '${student.fullName} already timed out for ${_isAmSelected ? "AM" : "PM"}',
      );
      return;
    }

    final now = DateTime.now();
    int hour = now.hour;
    if (_isAmSelected) {
      if (hour >= 12) {
        hour = hour - 12;
      }
      if (hour == 0) hour = 12;
    } else {
      if (hour < 12) {
        hour = hour + 12;
      }
    }
    final adjustedTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      now.minute,
      now.second,
    );

    final record = AttendanceRecord(
      id: now.millisecondsSinceEpoch.toString(),
      student: student,
      timestamp: adjustedTime,
      type: type,
    );

    eventProvider.addRecordToEvent(eventProvider.selectedEventId!, record);

    final dateFormat = DateFormat('MMMM dd');
    final timeFormat = DateFormat('h:mm a');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              type == AttendanceType.timeIn ? Icons.login : Icons.logout,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${student.fullName} ${student.program} ${student.year}\n$typeText • ${dateFormat.format(record.timestamp)} ${timeFormat.format(record.timestamp)}',
              ),
            ),
          ],
        ),
        backgroundColor: type == AttendanceType.timeIn
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    _resetScanner();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
    _resetScanner();
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
    _resetScanner();
  }

  void _resetScanner() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastScannedCode = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Scan QR Code',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showManualInput ? Icons.qr_code : Icons.keyboard),
            onPressed: () {
              setState(() {
                _showManualInput = !_showManualInput;
              });
            },
            tooltip: _showManualInput ? 'Use Scanner' : 'Manual Input',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Column(
          children: [
            _buildDaySelector(),
            _buildAmPmSelector(),
            _buildScannerArea(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFilterButton(0, 'All', Icons.list),
                  _buildFilterButton(1, 'Time In', Icons.login),
                  _buildFilterButton(2, 'Time Out', Icons.logout),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildRecordsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerArea() {
    if (_showManualInput) {
      return _buildManualInput();
    }

    if (_isWeb) {
      return _buildWebPlaceholder();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      height: 250,
      child: _buildScanner(),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Consumer<AttendanceEventProvider>(
        builder: (context, eventProvider, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: eventProvider.selectedEventId,
                isExpanded: true,
                isDense: true,
                hint: const Text('Select Event'),
                icon: const Icon(Icons.calendar_today, size: 18),
                items: eventProvider.events.map((day) {
                  return DropdownMenuItem(
                    value: day.id,
                    child: Text(
                      day.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    eventProvider.selectEvent(value);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAmPmSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isAmSelected = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isAmSelected
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isAmSelected
                        ? const Color(0xFF8B5CF6)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Center(
                  child: Text(
                    'AM',
                    style: TextStyle(
                      color: _isAmSelected ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isAmSelected = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isAmSelected
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: !_isAmSelected
                        ? const Color(0xFF8B5CF6)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Center(
                  child: Text(
                    'PM',
                    style: TextStyle(
                      color: !_isAmSelected ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            MobileScanner(controller: _controller, onDetect: _onDetect),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _selectedFilter == 0
                        ? 'Recording: Time In (${_isAmSelected ? "AM" : "PM"})'
                        : _selectedFilter == 1
                        ? 'Recording: Time In (${_isAmSelected ? "AM" : "PM"})'
                        : 'Recording: Time Out (${_isAmSelected ? "AM" : "PM"})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebPlaceholder() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Camera not available on web',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showManualInput = true;
              });
            },
            icon: const Icon(Icons.keyboard),
            label: const Text('Enter QR Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualInput() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enter QR Data',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manualInputController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Paste QR JSON data here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _processManualInput,
            icon: const Icon(Icons.qr_code),
            label: const Text('Submit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    return Consumer<AttendanceEventProvider>(
      builder: (context, eventProvider, child) {
        final day = eventProvider.selectedEvent;
        if (day == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No Event selected',
                  style: TextStyle(color: Colors.grey[500], fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create an Event in Attendance to start',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        List<AttendanceRecord> filteredRecords;
        if (_selectedFilter == 1) {
          filteredRecords = day.records
              .where((r) => r.type == AttendanceType.timeIn)
              .toList();
        } else if (_selectedFilter == 2) {
          filteredRecords = day.records
              .where((r) => r.type == AttendanceType.timeOut)
              .toList();
        } else {
          filteredRecords = day.records;
        }

        filteredRecords = filteredRecords
            .where(
              (r) => _isAmSelected
                  ? r.timestamp.hour < 12
                  : r.timestamp.hour >= 12,
            )
            .toList();

        if (filteredRecords.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Icon(Icons.inbox, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFilter == 0
                        ? 'No ${_isAmSelected ? "AM" : "PM"} records yet'
                        : 'No ${_isAmSelected ? "AM" : "PM"} ${_selectedFilter == 1 ? "Time In" : "Time Out"} records',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filteredRecords.length,
          itemBuilder: (context, index) {
            final record = filteredRecords[index];
            final isTimeIn = record.type == AttendanceType.timeIn;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isTimeIn
                        ? const Color(0xFF10B981).withValues(alpha: 0.1)
                        : const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isTimeIn ? Icons.login : Icons.logout,
                    color: isTimeIn
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
                title: Text(
                  record.student.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${record.student.program} • ${isTimeIn ? "Time In" : "Time Out"} • ${DateFormat('h:mm a • MMM dd').format(record.timestamp)}',
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isTimeIn
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isTimeIn ? 'IN' : 'OUT',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onFilterSelected(int index) {
    setState(() {
      _selectedFilter = index;
    });
  }

  Widget _buildFilterButton(int index, String label, IconData icon) {
    final isSelected = _selectedFilter == index;
    final color = index == 1
        ? const Color(0xFF10B981)
        : index == 2
        ? const Color(0xFFEF4444)
        : const Color(0xFF8B5CF6);

    return GestureDetector(
      onTap: () => _onFilterSelected(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
