import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/attendance_record.dart';
import '../providers/day_provider.dart';

class AttendanceDayScreen extends StatefulWidget {
  final String eventId;
  final String role;

  const AttendanceDayScreen({super.key, required this.eventId, required this.role});

  @override
  State<AttendanceDayScreen> createState() => _AttendanceDayScreenState();
}

class _AttendanceDayScreenState extends State<AttendanceDayScreen> {
  int _selectedFilter = 0;
  int _selectedAmPmFilter = 0;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFolderOptions() {
    final eventProvider = context.read<AttendanceEventProvider>();
    final events = eventProvider.events;
    if (events.isEmpty) return;
    
    AttendanceEvent event;
    try {
      event = events.firstWhere((e) => e.id == widget.eventId);
    } catch (e) {
      event = events.first;
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
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today,
                size: 32,
                color: Color(0xFF8B5CF6),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              event.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              '${event.records.length} records',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.download, color: Color(0xFF10B981)),
                      title: const Text('Download as Excel'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _downloadAsExcel(event);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.edit, color: Color(0xFF2563EB)),
                      title: const Text('Rename Event'),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showRenameDialog(event.name);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.clear_all, color: Colors.orange),
                      title: const Text('Clear All Records'),
                      onTap: widget.role == 'admin'
                          ? () {
                              Navigator.pop(ctx);
                              _confirmClearRecords();
                            }
                          : null,
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete, color: Colors.red),
                      title: const Text(
                        'Delete Event',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: widget.role == 'admin'
                          ? () {
                              Navigator.pop(ctx);
                              _confirmDeleteEvent(event.name);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadAsExcel(AttendanceEvent event) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Attendance'];

      sheet.appendRow([
        TextCellValue('Name'),
        TextCellValue('Program'),
        TextCellValue('Date'),
        TextCellValue('Time In (AM)'),
        TextCellValue('Time Out (AM)'),
        TextCellValue('Time In (PM)'),
        TextCellValue('Time Out (PM)'),
      ]);

      sheet.setColumnWidth(0, 20);
      sheet.setColumnWidth(1, 15);
      sheet.setColumnWidth(2, 15);
      sheet.setColumnWidth(3, 15);
      sheet.setColumnWidth(4, 15);
      sheet.setColumnWidth(5, 15);
      sheet.setColumnWidth(6, 15);

      final Map<String, Map<String, List<DateTime>>> studentAttendance = {};

      for (final record in event.records) {
        final key = record.student.id;
        if (!studentAttendance.containsKey(key)) {
          studentAttendance[key] = {
            'timeInAm': [],
            'timeOutAm': [],
            'timeInPm': [],
            'timeOutPm': [],
          };
        }
        final isAm = record.timestamp.hour < 12;
        if (record.type == AttendanceType.timeIn) {
          if (isAm) {
            studentAttendance[key]!['timeInAm']!.add(record.timestamp);
          } else {
            studentAttendance[key]!['timeInPm']!.add(record.timestamp);
          }
        } else {
          if (isAm) {
            studentAttendance[key]!['timeOutAm']!.add(record.timestamp);
          } else {
            studentAttendance[key]!['timeOutPm']!.add(record.timestamp);
          }
        }
      }

      final dateFormat = DateFormat('MMM dd, yyyy');
      final timeFormat = DateFormat('h:mm a');

      for (final entry in studentAttendance.entries) {
        final student = event.records.firstWhere((r) => r.student.id == entry.key).student;
        
        final timeInAmStr = entry.value['timeInAm']!.isEmpty ? '-' : entry.value['timeInAm']!.map((t) => timeFormat.format(t)).join(', ');
        final timeOutAmStr = entry.value['timeOutAm']!.isEmpty ? '-' : entry.value['timeOutAm']!.map((t) => timeFormat.format(t)).join(', ');
        final timeInPmStr = entry.value['timeInPm']!.isEmpty ? '-' : entry.value['timeInPm']!.map((t) => timeFormat.format(t)).join(', ');
        final timeOutPmStr = entry.value['timeOutPm']!.isEmpty ? '-' : entry.value['timeOutPm']!.map((t) => timeFormat.format(t)).join(', ');

        sheet.appendRow([
          TextCellValue(student.fullName),
          TextCellValue(student.program),
          TextCellValue(dateFormat.format(event.createdAt)),
          TextCellValue(timeInAmStr),
          TextCellValue(timeOutAmStr),
          TextCellValue(timeInPmStr),
          TextCellValue(timeOutPmStr),
        ]);
      }

      final cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
      for (var row in sheet.rows) {
        for (var cell in row) {
          cell?.cellStyle = cellStyle;
        }
      }

      String downloadPath;
      if (Platform.isAndroid) {
        downloadPath = '/storage/emulated/0/Download';
      } else {
        downloadPath = (await getApplicationDocumentsDirectory()).path;
      }

      final fileName = '${event.name.replaceAll(' ', '_')}_attendance.xlsx';
      final filePath = '$downloadPath/$fileName';
      final file = File(filePath);
      final bytes = excel.encode();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded to Downloads/$fileName'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showRenameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Rename Event'),
          ],
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Event Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<AttendanceEventProvider>().renameEvent(widget.eventId, controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _confirmClearRecords() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Records?'),
        content: const Text('This will remove all attendance records for this event.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AttendanceEventProvider>().clearEventRecords(widget.eventId);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteEvent(String eventName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Event?'),
        content: Text('Delete "$eventName"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AttendanceEventProvider>().deleteEvent(widget.eventId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Consumer<AttendanceEventProvider>(
          builder: (context, eventProvider, child) {
            AttendanceEvent? event;
            try {
              event = eventProvider.events.firstWhere((e) => e.id == widget.eventId);
            } catch (e) {
              event = null;
            }
            return Text(
              event?.name ?? 'Event',
              style: const TextStyle(fontWeight: FontWeight.w600),
            );
          },
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showFolderOptions,
          ),
        ],
      ),
      body: Consumer<AttendanceEventProvider>(
        builder: (context, eventProvider, child) {
          AttendanceEvent? event;
          try {
            event = eventProvider.events.firstWhere((e) => e.id == widget.eventId);
          } catch (e) {
            event = null;
          }

          if (event == null || event.records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No attendance records',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan QR codes to record attendance',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          List<AttendanceRecord> filteredRecords;
          final searchQuery = _searchController.text.toLowerCase();

          filteredRecords = event.records.where((r) {
            final nameMatch = r.student.fullName.toLowerCase().contains(searchQuery);
            bool typeMatch = true;
            if (_selectedFilter == 1) {
              typeMatch = r.type == AttendanceType.timeIn;
            } else if (_selectedFilter == 2) {
              typeMatch = r.type == AttendanceType.timeOut;
            }
            bool amPmMatch = true;
            if (_selectedAmPmFilter == 1) {
              amPmMatch = r.timestamp.hour >= 0 && r.timestamp.hour < 12;
            } else if (_selectedAmPmFilter == 2) {
              amPmMatch = r.timestamp.hour >= 12 && r.timestamp.hour < 24;
            }
            return nameMatch && typeMatch && amPmMatch;
          }).toList();

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name',
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        hintStyle: const TextStyle(color: Colors.white70),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (value) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFilterButton(0, 'All', Icons.list),
                        _buildFilterButton(1, 'Time In', Icons.login),
                        _buildFilterButton(2, 'Time Out', Icons.logout),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildAmPmFilterButton(0, 'All', Icons.access_time),
                        const SizedBox(width: 8),
                        _buildAmPmFilterButton(1, 'AM', null),
                        const SizedBox(width: 8),
                        _buildAmPmFilterButton(2, 'PM', null),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedFilter == 0 ? 'All Records' : _selectedFilter == 1 ? 'Time In Records' : 'Time Out Records',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                    ),
                    Text(
                      '${filteredRecords.length} records',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filteredRecords.isEmpty
                    ? Center(
                        child: Text(
                          'No ${_selectedFilter == 1 ? "Time In" : _selectedFilter == 2 ? "Time Out" : ""} records',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRecords.length,
                        itemBuilder: (context, index) {
                          final record = filteredRecords[index];
                          final isTimeIn = record.type == AttendanceType.timeIn;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    decoration: BoxDecoration(
                                      color: isTimeIn ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: isTimeIn ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(isTimeIn ? Icons.login : Icons.logout, color: isTimeIn ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(record.student.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1F2937))),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4)),
                                                      child: Text(record.student.program, style: const TextStyle(fontSize: 12)),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(DateFormat('h:mm a • MMM dd').format(record.timestamp), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(color: isTimeIn ? const Color(0xFF10B981) : const Color(0xFFEF4444), borderRadius: BorderRadius.circular(12)),
                                                child: Text(isTimeIn ? 'IN' : 'OUT', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                              const SizedBox(height: 4),
                                              GestureDetector(
                                                onTap: widget.role == 'admin'
                                                    ? () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (ctx) => AlertDialog(
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                            title: const Text('Delete Record?'),
                                                            content: Text('Are you sure you want to delete ${record.student.fullName}\'s attendance record?'),
                                                            actions: [
                                                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                                              ElevatedButton(
                                                                onPressed: () {
                                                                  context.read<AttendanceEventProvider>().deleteRecord(widget.eventId, record.id);
                                                                  Navigator.pop(ctx);
                                                                },
                                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                                child: const Text('Delete'),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }
                                                    : null,
                                                child: Icon(Icons.delete_outline, size: 20, color: widget.role == 'admin' ? Colors.grey[400] : Colors.grey[200]),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterButton(int index, String label, IconData icon) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(24)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? const Color(0xFF8B5CF6) : Colors.white70),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF8B5CF6) : Colors.white, fontWeight: FontWeight.w600, fontSize: 12), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmPmFilterButton(int index, String label, IconData? icon) {
    final isSelected = _selectedAmPmFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedAmPmFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? const Color(0xFF8B5CF6) : Colors.white70),
              const SizedBox(width: 4),
            ],
            Text(label, style: TextStyle(color: isSelected ? const Color(0xFF8B5CF6) : Colors.white, fontWeight: FontWeight.w500, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
