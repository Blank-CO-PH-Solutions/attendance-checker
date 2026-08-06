import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/day_provider.dart';

class EventAnalyticsScreen extends StatefulWidget {
  final String eventId;

  const EventAnalyticsScreen({super.key, required this.eventId});

  @override
  State<EventAnalyticsScreen> createState() => _EventAnalyticsScreenState();
}

class _EventAnalyticsScreenState extends State<EventAnalyticsScreen> {
  static const _accent = Color(0xFF8B5CF6);
  static const _green = Color(0xFF457507);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Event Analytics',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<AttendanceEventProvider>(
        builder: (context, eventProvider, child) {
          AttendanceEvent? event;
          try {
            event = eventProvider.events.firstWhere((e) => e.id == widget.eventId);
          } catch (e) {
            event = null;
          }

          if (event == null) {
            return Center(
              child: Text(
                'Event not found',
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }

          if (event.records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insert_chart_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No analytics yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[500]),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummaryCard(event),
                const SizedBox(height: 16),
                _buildChartCard(
                  icon: Icons.calendar_view_day,
                  title: 'Students Attended Per Day',
                  child: _buildDaysChart(event),
                ),
                const SizedBox(height: 16),
                _buildChartCard(
                  icon: Icons.people,
                  title: 'Attendance Per Student',
                  child: _buildStudentsChart(event),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(AttendanceEvent event) {
    final studentsAttended = event.records.map((r) => r.student.id).toSet().length;
    final totalRecords = event.records.length;
    final days = event.records
        .map((r) => DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day))
        .toSet()
        .length;
    final avgPerDay = days == 0 ? 0.0 : studentsAttended / days;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryStat(
                  value: '$studentsAttended',
                  label: 'Students Attended',
                ),
              ),
              Expanded(
                child: _buildSummaryStat(
                  value: '$totalRecords',
                  label: 'Records',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryStat(
                  value: '$days',
                  label: 'Days',
                ),
              ),
              Expanded(
                child: _buildSummaryStat(
                  value: avgPerDay.toStringAsFixed(1),
                  label: 'Avg / Day',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildDaysChart(AttendanceEvent event) {
    final Map<DateTime, Set<String>> dayStudents = {};
    for (final record in event.records) {
      final day = DateTime(
        record.timestamp.year,
        record.timestamp.month,
        record.timestamp.day,
      );
      dayStudents.putIfAbsent(day, () => <String>{}).add(record.student.id);
    }

    final days = dayStudents.keys.toList()..sort();
    final counts = days.map((d) => dayStudents[d]!.length).toList();
    final maxCount = counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxCount + 1).toDouble(),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: counts[i].toDouble(),
                    color: _green,
                    width: 22,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                  ),
                ],
              ),
          ],
          titlesData: FlTitlesData(
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value == value.roundToDouble()) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: days.length > 8 ? (days.length / 6).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= days.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      DateFormat('MMM d').format(days[index]),
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey[200],
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => const Color(0xFF1F2937),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final index = group.x;
                if (index < 0 || index >= days.length) return null;
                return BarTooltipItem(
                  '${DateFormat('MMM d, yyyy').format(days[index])}\n',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: '${rod.toY.round()} student${rod.toY.round() == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsChart(AttendanceEvent event) {
    final Map<String, List<dynamic>> byStudent = {};
    for (final record in event.records) {
      byStudent.putIfAbsent(record.student.id, () => []).add(record);
    }

    final entries = byStudent.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    if (entries.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No attendance data',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
    }

    final maxCount = entries.first.value.length;
    final chartWidth = entries.length * 56.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = chartWidth > constraints.maxWidth
            ? chartWidth
            : constraints.maxWidth;
        return SizedBox(
          height: 280,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxCount + 1).toDouble(),
                  barGroups: [
                    for (var i = 0; i < entries.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: entries[i].value.length.toDouble(),
                            color: _accent,
                            width: 20,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ],
                      ),
                  ],
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value == value.roundToDouble()) {
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: entries.length > 10
                            ? (entries.length / 10).ceilToDouble()
                            : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          final name = entries[index].value.first.student.fullName;
                          final shortName = name.length > 8
                              ? '${name.substring(0, 7)}…'
                              : name;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              shortName,
                              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[200],
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => const Color(0xFF1F2937),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final index = group.x;
                        if (index < 0 || index >= entries.length) return null;
                        final student = entries[index].value.first.student;
                        return BarTooltipItem(
                          '${student.fullName}\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(
                              text:
                                  '${rod.toY.round()} record${rod.toY.round() == 1 ? '' : 's'}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
