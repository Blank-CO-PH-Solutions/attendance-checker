import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/attendance_record.dart';
import '../models/student.dart';
import '../providers/day_provider.dart';

class StudentLogScreen extends StatefulWidget {
  final Student student;
  final String section;

  const StudentLogScreen({
    super.key,
    required this.student,
    required this.section,
  });

  @override
  State<StudentLogScreen> createState() => _StudentLogScreenState();
}

class _StudentLogScreenState extends State<StudentLogScreen> {
  static const _accent = Color(0xFF0EA5E9);
  int _typeFilter = 0;
  int _amPmFilter = 0;
  String? _selectedEventId;

  List<AttendanceRecord> _filterRecords(
    AttendanceEvent event,
    String studentId,
  ) {
    return event.records.where((r) {
      if (r.student.id != studentId) return false;
      if (_typeFilter == 1 && r.type != AttendanceType.timeIn) return false;
      if (_typeFilter == 2 && r.type != AttendanceType.timeOut) return false;
      if (_amPmFilter == 1 && r.timestamp.hour >= 12) return false;
      if (_amPmFilter == 2 && r.timestamp.hour < 12) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Student Report',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<AttendanceEventProvider>(
        builder: (context, eventProvider, child) {
          final studentId = widget.student.id;

          final attendedEvents = eventProvider.events.where((event) {
            return event.records.any((r) => r.student.id == studentId);
          }).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (attendedEvents.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No attendance records',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This student has not attended any event yet',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          final filteredEvents = _selectedEventId == null
              ? attendedEvents
              : attendedEvents.where((e) => e.id == _selectedEventId).toList();

          final allFilteredRecords = filteredEvents
              .expand((event) => _filterRecords(event, studentId))
              .toList();

          final timeIns = allFilteredRecords
              .where((r) => r.type == AttendanceType.timeIn)
              .length;
          final timeOuts = allFilteredRecords
              .where((r) => r.type == AttendanceType.timeOut)
              .length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStudentHeader(),
              const SizedBox(height: 16),
              _buildSummaryRow(
                eventsAttended: filteredEvents.length,
                timeIns: timeIns,
                timeOuts: timeOuts,
              ),
              const SizedBox(height: 16),
              _buildFilterBar(attendedEvents),
              const SizedBox(height: 24),
              const Text(
                'Attendance Log',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              if (allFilteredRecords.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'No records match the selected filters',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                )
              else
                for (final event in filteredEvents) _buildEventLog(event),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.student.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.section,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
                if (widget.student.studentNumber.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.student.studentNumber,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required int eventsAttended,
    required int timeIns,
    required int timeOuts,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryStat(
            value: '$eventsAttended',
            label: 'Events',
            color: _accent,
            icon: Icons.calendar_today,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryStat(
            value: '$timeIns',
            label: 'Time Ins',
            color: const Color(0xFF10B981),
            icon: Icons.login,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryStat(
            value: '$timeOuts',
            label: 'Time Outs',
            color: const Color(0xFFEF4444),
            icon: Icons.logout,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStat({
    required String value,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<AttendanceEvent> attendedEvents) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            'Filter',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedEventId,
            decoration: InputDecoration(
              labelText: 'Event',
              prefixIcon: const Icon(Icons.event, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Events'),
              ),
              for (final event in attendedEvents)
                DropdownMenuItem<String>(
                  value: event.id,
                  child: Text(
                    event.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _selectedEventId = value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTypeFilterButton(0, 'All', Icons.list),
              const SizedBox(width: 8),
              _buildTypeFilterButton(1, 'Time In', Icons.login),
              const SizedBox(width: 8),
              _buildTypeFilterButton(2, 'Time Out', Icons.logout),
            ],
          ),
          const SizedBox(height: 12),
          Row(
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
    );
  }

  Widget _buildTypeFilterButton(int index, String label, IconData icon) {
    final isSelected = _typeFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _typeFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _accent : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _accent : Colors.grey[300]!,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmPmFilterButton(int index, String label, IconData? icon) {
    final isSelected = _amPmFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _amPmFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _accent : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _accent : Colors.grey[300]!,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventLog(AttendanceEvent event) {
    final records = _filterRecords(event, widget.student.id);

    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event, color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dateFormat.format(event.createdAt)} • ${records.length} record${records.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...records.map(
            (record) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (record.type == AttendanceType.timeIn
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444))
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      record.type == AttendanceType.timeIn
                          ? Icons.login
                          : Icons.logout,
                      size: 18,
                      color: record.type == AttendanceType.timeIn
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      record.type == AttendanceType.timeIn
                          ? 'Time In'
                          : 'Time Out',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeFormat.format(record.timestamp),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        dateFormat.format(record.timestamp),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
